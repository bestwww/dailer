/**
 * Сервис для отправки webhook уведомлений
 */

import { EventEmitter } from 'events';
import axios, { AxiosError } from 'axios';
import crypto from 'crypto';
import { v4 as uuidv4 } from 'uuid';
import { webhookModel } from '../models/webhook';
import { 
  WebhookEvent, 
  WebhookEventType, 
  WebhookEndpoint, 
  WebhookCallEvent,
  WebhookCampaignEvent,
  WebhookLeadEvent,
  WebhookBlacklistEvent,
  WebhookSystemEvent
} from '../types';
import { log } from '../utils/logger';

export class WebhookService extends EventEmitter {
  private retryQueue: Map<string, RetryInfo> = new Map();
  private isProcessingRetries = false;
  private retryProcessInterval: NodeJS.Timeout | null = null;

  constructor() {
    super();
    this.startRetryProcessor();
  }

  /**
   * Отправка webhook события
   */
  async sendWebhookEvent(eventType: WebhookEventType, data: any, campaignId?: number): Promise<void> {
    try {
      // Получаем активные endpoints для данного типа события
      const endpoints = await webhookModel.getEndpointsForEvent(eventType, campaignId);
      
      if (endpoints.length === 0) {
        log.debug(`Нет активных webhook endpoints для события ${eventType}`);
        return;
      }

      // Создаем событие с уникальным ID
      const event: WebhookEvent = {
        id: uuidv4(),
        eventType,
        data,
        timestamp: new Date().toISOString(),
        ...(campaignId && { campaignId }),
        ...(data.contactId && { contactId: data.contactId }),
        metadata: {
          version: '1.0',
          source: 'dialer_system'
        }
      };

      // Отправляем на все endpoints параллельно
      const sendPromises = endpoints.map(endpoint => 
        this.sendToEndpoint(endpoint, event)
      );

      await Promise.allSettled(sendPromises);
      
      log.info(`📡 Webhook событие ${eventType} отправлено на ${endpoints.length} endpoints`);

    } catch (error) {
      log.error(`Ошибка отправки webhook события ${eventType}:`, error);
      throw error;
    }
  }

  /**
   * Отправка события звонка
   */
  async sendCallEvent(eventType: 'call.started' | 'call.answered' | 'call.completed' | 'call.failed' | 'call.dtmf' | 'call.amd_detected' | 'call.blocked', data: WebhookCallEvent): Promise<void> {
    await this.sendWebhookEvent(eventType, data, data.campaignId);
  }

  /**
   * Отправка события кампании
   */
  async sendCampaignEvent(eventType: 'campaign.started' | 'campaign.stopped' | 'campaign.completed', data: WebhookCampaignEvent): Promise<void> {
    await this.sendWebhookEvent(eventType, data, data.campaignId);
  }

  /**
   * Отправка события лида
   */
  async sendLeadEvent(eventType: 'lead.created' | 'lead.failed', data: WebhookLeadEvent): Promise<void> {
    await this.sendWebhookEvent(eventType, data, data.campaignId);
  }

  /**
   * Отправка события черного списка
   */
  async sendBlacklistEvent(data: WebhookBlacklistEvent): Promise<void> {
    await this.sendWebhookEvent('blacklist.added', data);
  }

  /**
   * Отправка системного события
   */
  async sendSystemEvent(data: WebhookSystemEvent): Promise<void> {
    await this.sendWebhookEvent('system.error', data);
  }

  /**
   * Отправка webhook на конкретный endpoint
   */
  private async sendToEndpoint(endpoint: WebhookEndpoint, event: WebhookEvent): Promise<void> {
    const startTime = Date.now();
    
    try {
      const payload = this.preparePayload(event);
      const headers = this.prepareHeaders(endpoint, payload);
      
      // Отправляем HTTP запрос
      const response = await axios({
        method: endpoint.httpMethod,
        url: endpoint.url,
        headers,
        data: payload,
        timeout: endpoint.timeout,
        validateStatus: (status) => status < 500 // Retry только при серверных ошибках
      });

      const processingTime = Date.now() - startTime;
      
      // Логируем успешную доставку
      await this.logDelivery(endpoint, event, {
        statusCode: response.status,
        responseBody: JSON.stringify(response.data),
        responseHeaders: response.headers,
        processingTime,
        status: 'delivered'
      });

      // Обновляем статистику endpoint
      await webhookModel.updateEndpointStats(endpoint.id, true);

      log.info(`✅ Webhook доставлен: ${endpoint.name} (${response.status}) за ${processingTime}ms`);

    } catch (error) {
      const processingTime = Date.now() - startTime;
      
      await this.handleDeliveryError(endpoint, event, error as AxiosError, processingTime);
    }
  }

  /**
   * Обработка ошибок доставки
   */
  private async handleDeliveryError(endpoint: WebhookEndpoint, event: WebhookEvent, error: AxiosError, processingTime: number): Promise<void> {
    const errorMessage = error.response?.data 
      ? `${error.message}: ${JSON.stringify(error.response.data)}`
      : error.message;

          // Логируем неудачную доставку
              await this.logDelivery(endpoint, event, {
          statusCode: error.response?.status || 0,
          responseBody: error.response?.data ? JSON.stringify(error.response.data) : '',
          responseHeaders: error.response?.headers,
          processingTime,
          status: 'failed',
          error: errorMessage
        });

    // Обновляем статистику endpoint
    await webhookModel.updateEndpointStats(endpoint.id, false, errorMessage);

    // Определяем, нужно ли retry
    const shouldRetry = this.shouldRetryRequest(error, 1);
    
    if (shouldRetry && endpoint.maxRetries > 0) {
      // Добавляем в очередь retry
      const retryInfo: RetryInfo = {
        endpoint,
        event,
        attemptNumber: 1,
        nextRetryAt: new Date(Date.now() + endpoint.retryDelay),
        lastError: errorMessage
      };

      this.retryQueue.set(`${endpoint.id}-${event.id}`, retryInfo);
      
      log.warn(`⚠️ Webhook будет повторен: ${endpoint.name} (попытка 1/${endpoint.maxRetries})`);
    } else {
      log.error(`❌ Webhook не доставлен: ${endpoint.name} - ${errorMessage}`);
    }
  }

  /**
   * Логирование доставки
   */
  private async logDelivery(endpoint: WebhookEndpoint, event: WebhookEvent, result: {
    statusCode?: number;
    responseBody?: string;
    responseHeaders?: any;
    processingTime: number;
    status: 'delivered' | 'failed';
    error?: string;
  }): Promise<void> {
    try {
      const payload = this.preparePayload(event);
      const headers = this.prepareHeaders(endpoint, payload);

      const deliveryData: any = {
        webhookEndpointId: endpoint.id,
        eventId: event.id,
        eventType: event.eventType,
        requestUrl: endpoint.url,
        requestMethod: endpoint.httpMethod,
        requestHeaders: headers,
        requestBody: JSON.stringify(payload),
        statusCode: result.statusCode || 0,
        responseBody: result.responseBody || '',
        responseHeaders: result.responseHeaders,
        attemptNumber: 1,
        processingTime: result.processingTime,
        status: result.status,
        error: result.error || '',
        sentAt: new Date()
      };

      if (result.status === 'delivered') {
        deliveryData.deliveredAt = new Date();
      }
      if (result.status === 'failed') {
        deliveryData.failedAt = new Date();
      }

      await webhookModel.createDelivery(deliveryData);

    } catch (error) {
      log.error('Ошибка логирования доставки webhook:', error);
    }
  }

  /**
   * Подготовка payload для отправки
   */
  private preparePayload(event: WebhookEvent): any {
    return {
      id: event.id,
      type: event.eventType,
      timestamp: event.timestamp,
      data: event.data,
      campaign_id: event.campaignId,
      contact_id: event.contactId,
      metadata: event.metadata
    };
  }

  /**
   * Подготовка заголовков HTTP запроса
   */
  private prepareHeaders(endpoint: WebhookEndpoint, payload: any): Record<string, string> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'User-Agent': 'Dialer-Webhook/1.0',
      'X-Webhook-Id': uuidv4(),
      'X-Webhook-Timestamp': new Date().toISOString(),
      ...endpoint.customHeaders
    };

    // Добавляем подпись, если есть секретный ключ
    if (endpoint.secret) {
      const signature = this.signPayload(payload, endpoint.secret);
      headers['X-Webhook-Signature'] = signature;
    }

    return headers;
  }

  /**
   * Создание подписи для payload
   */
  private signPayload(payload: any, secret: string): string {
    const payloadString = JSON.stringify(payload);
    const hmac = crypto.createHmac('sha256', secret);
    hmac.update(payloadString);
    return `sha256=${hmac.digest('hex')}`;
  }

  /**
   * Проверка, нужно ли повторять запрос
   */
  private shouldRetryRequest(error: AxiosError, _attemptNumber: number): boolean {
    // Не повторяем при клиентских ошибках (4xx)
    if (error.response && error.response.status >= 400 && error.response.status < 500) {
      return false;
    }

    // Повторяем при серверных ошибках (5xx) и сетевых ошибках
    return true;
  }

  /**
   * Запуск процессора retry очереди
   */
  private startRetryProcessor(): void {
    if (this.retryProcessInterval) {
      clearInterval(this.retryProcessInterval);
    }

    this.retryProcessInterval = setInterval(() => {
      this.processRetryQueue();
    }, 5000); // Проверяем каждые 5 секунд
  }

  /**
   * Обработка очереди retry
   */
  private async processRetryQueue(): Promise<void> {
    if (this.isProcessingRetries || this.retryQueue.size === 0) {
      return;
    }

    this.isProcessingRetries = true;

    try {
      const now = new Date();
      const readyForRetry: string[] = [];

      // Находим записи, готовые для повторной отправки
      for (const [key, retryInfo] of this.retryQueue.entries()) {
        if (retryInfo.nextRetryAt <= now) {
          readyForRetry.push(key);
        }
      }

      // Обрабатываем retry запросы
      for (const key of readyForRetry) {
        const retryInfo = this.retryQueue.get(key);
        if (!retryInfo) continue;

        try {
          await this.retryWebhookDelivery(retryInfo);
          this.retryQueue.delete(key);
          
        } catch (error) {
          // Если retry не удался, планируем следующую попытку
          await this.scheduleNextRetry(key, retryInfo, error as AxiosError);
        }
      }

    } catch (error) {
      log.error('Ошибка обработки retry очереди:', error);
    } finally {
      this.isProcessingRetries = false;
    }
  }

  /**
   * Повторная отправка webhook
   */
  private async retryWebhookDelivery(retryInfo: RetryInfo): Promise<void> {
    const startTime = Date.now();
    
    try {
      const payload = this.preparePayload(retryInfo.event);
      const headers = this.prepareHeaders(retryInfo.endpoint, payload);
      
      const response = await axios({
        method: retryInfo.endpoint.httpMethod,
        url: retryInfo.endpoint.url,
        headers,
        data: payload,
        timeout: retryInfo.endpoint.timeout,
        validateStatus: (status) => status < 500
      });

      const processingTime = Date.now() - startTime;
      
      // Логируем успешную retry доставку
      await this.logRetryDelivery(retryInfo, {
        statusCode: response.status,
        responseBody: JSON.stringify(response.data),
        responseHeaders: response.headers,
        processingTime,
        status: 'delivered'
      });

      // Обновляем статистику endpoint
      await webhookModel.updateEndpointStats(retryInfo.endpoint.id, true);

      log.info(`✅ Webhook retry доставлен: ${retryInfo.endpoint.name} (попытка ${retryInfo.attemptNumber + 1})`);

    } catch (error) {
      const processingTime = Date.now() - startTime;
      const axiosError = error as AxiosError;
      
      const retryResult: any = {
        responseBody: axiosError.response?.data ? JSON.stringify(axiosError.response.data) : '',
        responseHeaders: axiosError.response?.headers,
        processingTime,
        status: 'failed',
        error: axiosError.message
      };

      if (axiosError.response?.status) {
        retryResult.statusCode = axiosError.response.status;
      }

      await this.logRetryDelivery(retryInfo, retryResult);

      throw error;
    }
  }

  /**
   * Планирование следующей попытки retry
   */
  private async scheduleNextRetry(key: string, retryInfo: RetryInfo, error: AxiosError): Promise<void> {
    retryInfo.attemptNumber++;
    retryInfo.lastError = error.message;

    if (retryInfo.attemptNumber >= retryInfo.endpoint.maxRetries) {
      // Исчерпали все попытки
      this.retryQueue.delete(key);
      
      await webhookModel.updateEndpointStats(retryInfo.endpoint.id, false, error.message);
      
      log.error(`❌ Webhook retry исчерпан: ${retryInfo.endpoint.name} (${retryInfo.attemptNumber} попыток)`);
      return;
    }

    // Экспоненциальная задержка с jitter
    const baseDelay = retryInfo.endpoint.retryDelay;
    const exponentialDelay = baseDelay * Math.pow(2, retryInfo.attemptNumber - 1);
    const jitter = Math.random() * 1000; // До 1 секунды случайности
    const finalDelay = exponentialDelay + jitter;

    retryInfo.nextRetryAt = new Date(Date.now() + finalDelay);
    
    log.warn(`⚠️ Планирование retry: ${retryInfo.endpoint.name} (попытка ${retryInfo.attemptNumber + 1}/${retryInfo.endpoint.maxRetries} через ${Math.round(finalDelay / 1000)}s)`);
  }

  /**
   * Логирование retry доставки
   */
  private async logRetryDelivery(retryInfo: RetryInfo, result: {
    statusCode?: number;
    responseBody?: string;
    responseHeaders?: any;
    processingTime: number;
    status: 'delivered' | 'failed';
    error?: string;
  }): Promise<void> {
    try {
      const payload = this.preparePayload(retryInfo.event);
      const headers = this.prepareHeaders(retryInfo.endpoint, payload);

      const retryDeliveryData: any = {
        webhookEndpointId: retryInfo.endpoint.id,
        eventId: retryInfo.event.id,
        eventType: retryInfo.event.eventType,
        requestUrl: retryInfo.endpoint.url,
        requestMethod: retryInfo.endpoint.httpMethod,
        requestHeaders: headers,
        requestBody: JSON.stringify(payload),
        statusCode: result.statusCode || 0,
        responseBody: result.responseBody || '',
        responseHeaders: result.responseHeaders,
        attemptNumber: retryInfo.attemptNumber + 1,
        processingTime: result.processingTime,
        status: result.status,
        error: result.error || '',
        sentAt: new Date()
      };

      if (result.status === 'delivered') {
        retryDeliveryData.deliveredAt = new Date();
      }
      if (result.status === 'failed') {
        retryDeliveryData.failedAt = new Date();
      }

      await webhookModel.createDelivery(retryDeliveryData);

    } catch (error) {
      log.error('Ошибка логирования retry доставки:', error);
    }
  }

  /**
   * Остановка сервиса
   */
  async shutdown(): Promise<void> {
    if (this.retryProcessInterval) {
      clearInterval(this.retryProcessInterval);
      this.retryProcessInterval = null;
    }

    log.info('🔄 Webhook сервис остановлен');
  }
}

interface RetryInfo {
  endpoint: WebhookEndpoint;
  event: WebhookEvent;
  attemptNumber: number;
  nextRetryAt: Date;
  lastError: string;
}

// Создаем единственный экземпляр сервиса
export const webhookService = new WebhookService(); 