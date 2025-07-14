/**
 * Контроллер для управления webhook endpoints
 */

import { Request, Response } from 'express';
import { webhookModel } from '../models/webhook';
import { webhookService } from '../services/webhook';
import { 
  CreateWebhookEndpointRequest, 
  UpdateWebhookEndpointRequest, 
  WebhookEventType,
  ApiResponse 
} from '../types';
import { log } from '../utils/logger';

export class WebhookController {
  
  /**
   * Создание нового webhook endpoint
   */
  async createWebhookEndpoint(req: Request, res: Response): Promise<void> {
    try {
      const data: CreateWebhookEndpointRequest = req.body;
      
      // Валидация обязательных полей
      if (!data.url || !data.name || !data.eventTypes || data.eventTypes.length === 0) {
        res.status(400).json({
          success: false,
          error: 'Обязательные поля: url, name, eventTypes',
          timestamp: new Date().toISOString()
        } as ApiResponse);
        return;
      }

      // Валидация URL
      try {
        new URL(data.url);
      } catch (error) {
        res.status(400).json({
          success: false,
          error: 'Некорректный URL',
          timestamp: new Date().toISOString()
        } as ApiResponse);
        return;
      }

      // Валидация типов событий
      const validEventTypes: WebhookEventType[] = [
        'call.started', 'call.answered', 'call.completed', 'call.failed',
        'call.dtmf', 'call.amd_detected', 'call.blocked',
        'campaign.started', 'campaign.stopped', 'campaign.completed',
        'lead.created', 'lead.failed', 'system.error', 'blacklist.added'
      ];

      const invalidEventTypes = data.eventTypes.filter(type => 
        !validEventTypes.includes(type as WebhookEventType)
      );

      if (invalidEventTypes.length > 0) {
        res.status(400).json({
          success: false,
          error: `Недопустимые типы событий: ${invalidEventTypes.join(', ')}`,
          timestamp: new Date().toISOString()
        } as ApiResponse);
        return;
      }

      const endpoint = await webhookModel.createWebhookEndpoint(data);
      
      res.status(201).json({
        success: true,
        data: endpoint,
        message: 'Webhook endpoint успешно создан',
        timestamp: new Date().toISOString()
      } as ApiResponse);

    } catch (error) {
      log.error('Ошибка создания webhook endpoint:', error);
      res.status(500).json({
        success: false,
        error: 'Внутренняя ошибка сервера',
        timestamp: new Date().toISOString()
      } as ApiResponse);
    }
  }

  /**
   * Получение всех webhook endpoints
   */
  async getAllWebhookEndpoints(req: Request, res: Response): Promise<void> {
    try {
      const {
        includeInactive = 'false',
        campaignId,
        eventType,
        page = '1',
        limit = '50'
      } = req.query;

      const options: any = {
        includeInactive: includeInactive === 'true',
        page: parseInt(page as string),
        limit: parseInt(limit as string)
      };
      
      if (campaignId) {
        options.campaignId = parseInt(campaignId as string);
      }
      
      if (eventType) {
        options.eventType = eventType as WebhookEventType;
      }

      const result = await webhookModel.getAllWebhookEndpoints(options);
      
      res.json({
        success: true,
        data: result.endpoints,
        pagination: {
          page: options.page,
          limit: options.limit,
          total: result.total,
          totalPages: Math.ceil(result.total / options.limit)
        },
        timestamp: new Date().toISOString()
      } as ApiResponse);

    } catch (error) {
      log.error('Ошибка получения webhook endpoints:', error);
      res.status(500).json({
        success: false,
        error: 'Внутренняя ошибка сервера',
        timestamp: new Date().toISOString()
      } as ApiResponse);
    }
  }

  /**
   * Получение webhook endpoint по ID
   */
  async getWebhookEndpointById(req: Request, res: Response): Promise<void> {
    try {
      const { id } = req.params;
      if (!id) { res.status(400).json({ success: false, error: "ID не указан" }); return; } const endpointId = parseInt(id);

      if (isNaN(endpointId)) {
        res.status(400).json({
          success: false,
          error: 'Некорректный ID endpoint',
          timestamp: new Date().toISOString()
        } as ApiResponse);
        return;
      }

      const endpoint = await webhookModel.getWebhookEndpointById(endpointId);
      
      if (!endpoint) {
        res.status(404).json({
          success: false,
          error: 'Webhook endpoint не найден',
          timestamp: new Date().toISOString()
        } as ApiResponse);
        return;
      }

      res.json({
        success: true,
        data: endpoint,
        timestamp: new Date().toISOString()
      } as ApiResponse);

    } catch (error) {
      log.error('Ошибка получения webhook endpoint:', error);
      res.status(500).json({
        success: false,
        error: 'Внутренняя ошибка сервера',
        timestamp: new Date().toISOString()
      } as ApiResponse);
    }
  }

  /**
   * Обновление webhook endpoint
   */
  async updateWebhookEndpoint(req: Request, res: Response): Promise<void> {
    try {
      const { id } = req.params;
      if (!id) { res.status(400).json({ success: false, error: "ID не указан" }); return; } const endpointId = parseInt(id);
      const data: UpdateWebhookEndpointRequest = req.body;

      if (isNaN(endpointId)) {
        res.status(400).json({
          success: false,
          error: 'Некорректный ID endpoint',
          timestamp: new Date().toISOString()
        } as ApiResponse);
        return;
      }

      // Валидация URL если предоставлен
      if (data.url) {
        try {
          new URL(data.url);
        } catch (error) {
          res.status(400).json({
            success: false,
            error: 'Некорректный URL',
            timestamp: new Date().toISOString()
          } as ApiResponse);
          return;
        }
      }

      const endpoint = await webhookModel.updateWebhookEndpoint(endpointId, data);
      
      if (!endpoint) {
        res.status(404).json({
          success: false,
          error: 'Webhook endpoint не найден',
          timestamp: new Date().toISOString()
        } as ApiResponse);
        return;
      }

      res.json({
        success: true,
        data: endpoint,
        message: 'Webhook endpoint успешно обновлен',
        timestamp: new Date().toISOString()
      } as ApiResponse);

    } catch (error) {
      log.error('Ошибка обновления webhook endpoint:', error);
      res.status(500).json({
        success: false,
        error: 'Внутренняя ошибка сервера',
        timestamp: new Date().toISOString()
      } as ApiResponse);
    }
  }

  /**
   * Удаление webhook endpoint
   */
  async deleteWebhookEndpoint(req: Request, res: Response): Promise<void> {
    try {
      const { id } = req.params;
      if (!id) { res.status(400).json({ success: false, error: "ID не указан" }); return; } const endpointId = parseInt(id);

      if (isNaN(endpointId)) {
        res.status(400).json({
          success: false,
          error: 'Некорректный ID endpoint',
          timestamp: new Date().toISOString()
        } as ApiResponse);
        return;
      }

      const deleted = await webhookModel.deleteWebhookEndpoint(endpointId);
      
      if (!deleted) {
        res.status(404).json({
          success: false,
          error: 'Webhook endpoint не найден',
          timestamp: new Date().toISOString()
        } as ApiResponse);
        return;
      }

      res.json({
        success: true,
        message: 'Webhook endpoint успешно удален',
        timestamp: new Date().toISOString()
      } as ApiResponse);

    } catch (error) {
      log.error('Ошибка удаления webhook endpoint:', error);
      res.status(500).json({
        success: false,
        error: 'Внутренняя ошибка сервера',
        timestamp: new Date().toISOString()
      } as ApiResponse);
    }
  }

  /**
   * Тестирование webhook endpoint
   */
  async testWebhookEndpoint(req: Request, res: Response): Promise<void> {
    try {
      const { id } = req.params;
      if (!id) { res.status(400).json({ success: false, error: "ID не указан" }); return; } const endpointId = parseInt(id);

      if (isNaN(endpointId)) {
        res.status(400).json({
          success: false,
          error: 'Некорректный ID endpoint',
          timestamp: new Date().toISOString()
        } as ApiResponse);
        return;
      }

      const endpoint = await webhookModel.getWebhookEndpointById(endpointId);
      
      if (!endpoint) {
        res.status(404).json({
          success: false,
          error: 'Webhook endpoint не найден',
          timestamp: new Date().toISOString()
        } as ApiResponse);
        return;
      }

      // Отправляем тестовое событие
      await webhookService.sendWebhookEvent('system.error', {
        test: true,
        message: 'Тестовое webhook событие',
        timestamp: new Date().toISOString()
      });

      res.json({
        success: true,
        message: 'Тестовое webhook событие отправлено',
        timestamp: new Date().toISOString()
      } as ApiResponse);

    } catch (error) {
      log.error('Ошибка тестирования webhook endpoint:', error);
      res.status(500).json({
        success: false,
        error: 'Внутренняя ошибка сервера',
        timestamp: new Date().toISOString()
      } as ApiResponse);
    }
  }

  /**
   * Получение статистики webhook
   */
  async getWebhookStats(req: Request, res: Response): Promise<void> {
    try {
      const { 
        startDate, 
        endDate, 
        campaignId 
      } = req.query;

      const options: any = {};
      
      if (startDate) {
        options.startDate = new Date(startDate as string);
      }
      
      if (endDate) {
        options.endDate = new Date(endDate as string);
      }
      
      if (campaignId) {
        options.campaignId = parseInt(campaignId as string);
      }

      const stats = await webhookModel.getWebhookStats(options);
      
      res.json({
        success: true,
        data: stats,
        timestamp: new Date().toISOString()
      } as ApiResponse);

    } catch (error) {
      log.error('Ошибка получения статистики webhook:', error);
      res.status(500).json({
        success: false,
        error: 'Внутренняя ошибка сервера',
        timestamp: new Date().toISOString()
      } as ApiResponse);
    }
  }

  /**
   * Получение доступных типов событий
   */
  async getAvailableEventTypes(_req: Request, res: Response): Promise<void> {
    try {
      const eventTypes: { value: WebhookEventType; label: string; description: string }[] = [
        { value: 'call.started', label: 'Звонок начат', description: 'Исходящий звонок инициирован' },
        { value: 'call.answered', label: 'Звонок отвечен', description: 'Абонент ответил на звонок' },
        { value: 'call.completed', label: 'Звонок завершен', description: 'Звонок успешно завершен' },
        { value: 'call.failed', label: 'Звонок не удался', description: 'Звонок завершился с ошибкой' },
        { value: 'call.dtmf', label: 'DTMF ответ', description: 'Получен DTMF ответ от абонента' },
        { value: 'call.amd_detected', label: 'AMD обнаружен', description: 'Обнаружен автоответчик' },
        { value: 'call.blocked', label: 'Звонок заблокирован', description: 'Звонок заблокирован черным списком' },
        { value: 'campaign.started', label: 'Кампания запущена', description: 'Кампания обзвона начата' },
        { value: 'campaign.stopped', label: 'Кампания остановлена', description: 'Кампания обзвона приостановлена' },
        { value: 'campaign.completed', label: 'Кампания завершена', description: 'Кампания обзвона завершена' },
        { value: 'lead.created', label: 'Лид создан', description: 'Лид создан в CRM системе' },
        { value: 'lead.failed', label: 'Ошибка создания лида', description: 'Ошибка при создании лида' },
        { value: 'system.error', label: 'Системная ошибка', description: 'Критическая ошибка системы' },
        { value: 'blacklist.added', label: 'Номер в черном списке', description: 'Номер добавлен в черный список' }
      ];

      res.json({
        success: true,
        data: eventTypes,
        timestamp: new Date().toISOString()
      } as ApiResponse);

    } catch (error) {
      log.error('Ошибка получения типов событий:', error);
      res.status(500).json({
        success: false,
        error: 'Внутренняя ошибка сервера',
        timestamp: new Date().toISOString()
      } as ApiResponse);
    }
  }

  /**
   * Получение логов доставки webhook
   */
  async getWebhookDeliveries(_req: Request, res: Response): Promise<void> {
    try {
      // const { page = "1", limit = "50" } = req.query; // Временно не используется

      // TODO: Реализовать метод в модели для получения логов доставки
      // const deliveries = await webhookModel.getWebhookDeliveries({
      //   endpointId: endpointId ? parseInt(endpointId as string) : undefined,
      //   eventType: eventType as WebhookEventType,
      //   status: status as 'pending' | 'delivered' | 'failed',
      //   page: parseInt(page as string),
      //   limit: parseInt(limit as string)
      // });

      res.json({
        success: true,
        data: [], // deliveries
        message: 'Функция в разработке',
        timestamp: new Date().toISOString()
      } as ApiResponse);

    } catch (error) {
      log.error('Ошибка получения логов доставки webhook:', error);
      res.status(500).json({
        success: false,
        error: 'Внутренняя ошибка сервера',
        timestamp: new Date().toISOString()
      } as ApiResponse);
    }
  }
}

export const webhookController = new WebhookController(); 