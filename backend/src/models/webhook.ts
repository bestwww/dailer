/**
 * Модель для работы с webhook endpoints и доставками
 */

import { query } from '../config/database';
import { 
  WebhookEndpoint, 
  WebhookDelivery, 
  CreateWebhookEndpointRequest, 
  UpdateWebhookEndpointRequest,
  WebhookEventType,
  WebhookStats
} from '../types';
import { log } from '../utils/logger';

export class WebhookModel {
  
  /**
   * Создание нового webhook endpoint
   */
  async createWebhookEndpoint(data: CreateWebhookEndpointRequest): Promise<WebhookEndpoint> {
    try {
      const result = await query(`
        INSERT INTO webhook_endpoints (
          url, name, description, is_active, secret, 
          event_types, campaign_ids, max_retries, retry_delay, timeout,
          allowed_ips, http_method, custom_headers, created_by
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
        RETURNING *
      `, [
        data.url,
        data.name,
        data.description,
        data.isActive ?? true,
        data.secret,
        JSON.stringify(data.eventTypes),
        data.campaignIds ? JSON.stringify(data.campaignIds) : null,
        data.maxRetries ?? 3,
        data.retryDelay ?? 5000,
        data.timeout ?? 30000,
        data.allowedIPs ? JSON.stringify(data.allowedIPs) : null,
        data.httpMethod ?? 'POST',
        data.customHeaders ? JSON.stringify(data.customHeaders) : null,
        1 // TODO: получать из контекста авторизации
      ]);

      const endpoint = this.mapToWebhookEndpoint(result.rows[0]);
      
      log.info(`✅ Webhook endpoint создан: ${endpoint.name} (${endpoint.url})`);
      return endpoint;
      
    } catch (error) {
      log.error('Ошибка создания webhook endpoint:', error);
      throw error;
    }
  }

  /**
   * Получение webhook endpoint по ID
   */
  async getWebhookEndpointById(id: number): Promise<WebhookEndpoint | null> {
    try {
      const result = await query(`
        SELECT * FROM webhook_endpoints 
        WHERE id = $1
      `, [id]);

      return result.rows[0] ? this.mapToWebhookEndpoint(result.rows[0]) : null;
      
    } catch (error) {
      log.error('Ошибка получения webhook endpoint:', error);
      throw error;
    }
  }

  /**
   * Получение всех webhook endpoints
   */
  async getAllWebhookEndpoints(options: {
    includeInactive?: boolean;
    campaignId?: number;
    eventType?: WebhookEventType;
    page?: number;
    limit?: number;
  } = {}): Promise<{
    endpoints: WebhookEndpoint[];
    total: number;
  }> {
    try {
      const { includeInactive = false, campaignId, eventType, page = 1, limit = 50 } = options;
      const offset = (page - 1) * limit;
      
      let whereClause = '';
      const params: any[] = [];
      let paramIndex = 1;

      // Фильтр по статусу
      if (!includeInactive) {
        whereClause = 'WHERE is_active = true';
      }

      // Фильтр по кампании
      if (campaignId) {
        whereClause += whereClause ? ' AND ' : 'WHERE ';
        whereClause += `(campaign_ids IS NULL OR campaign_ids::jsonb @> $${paramIndex})`;
        params.push(JSON.stringify([campaignId]));
        paramIndex++;
      }

      // Фильтр по типу события
      if (eventType) {
        whereClause += whereClause ? ' AND ' : 'WHERE ';
        whereClause += `event_types::jsonb @> $${paramIndex}`;
        params.push(JSON.stringify([eventType]));
        paramIndex++;
      }

      // Запрос данных
      const dataResult = await query(`
        SELECT * FROM webhook_endpoints 
        ${whereClause}
        ORDER BY created_at DESC
        LIMIT $${paramIndex} OFFSET $${paramIndex + 1}
      `, [...params, limit, offset]);

      // Запрос общего количества
      const countResult = await query(`
        SELECT COUNT(*) as total FROM webhook_endpoints 
        ${whereClause}
      `, params);

      const endpoints = dataResult.rows.map(row => this.mapToWebhookEndpoint(row));
      const total = parseInt(countResult.rows[0].total);

      return { endpoints, total };
      
    } catch (error) {
      log.error('Ошибка получения webhook endpoints:', error);
      throw error;
    }
  }

  /**
   * Обновление webhook endpoint
   */
  async updateWebhookEndpoint(id: number, data: UpdateWebhookEndpointRequest): Promise<WebhookEndpoint | null> {
    try {
      const updates: string[] = [];
      const params: any[] = [];
      let paramIndex = 1;

      // Строим динамический запрос обновления
      Object.entries(data).forEach(([key, value]) => {
        if (value !== undefined) {
          const dbKey = this.camelToSnake(key);
          
          if (key === 'eventTypes' || key === 'campaignIds' || key === 'allowedIPs' || key === 'customHeaders') {
            updates.push(`${dbKey} = $${paramIndex}`);
            params.push(JSON.stringify(value));
          } else {
            updates.push(`${dbKey} = $${paramIndex}`);
            params.push(value);
          }
          paramIndex++;
        }
      });

      if (updates.length === 0) {
        return this.getWebhookEndpointById(id);
      }

      updates.push(`updated_at = NOW()`);
      params.push(id);

      const result = await query(`
        UPDATE webhook_endpoints 
        SET ${updates.join(', ')} 
        WHERE id = $${paramIndex}
        RETURNING *
      `, params);

      if (result.rows.length === 0) {
        return null;
      }

      const endpoint = this.mapToWebhookEndpoint(result.rows[0]);
      
      log.info(`✅ Webhook endpoint обновлен: ${endpoint.name} (ID: ${id})`);
      return endpoint;
      
    } catch (error) {
      log.error('Ошибка обновления webhook endpoint:', error);
      throw error;
    }
  }

  /**
   * Удаление webhook endpoint
   */
  async deleteWebhookEndpoint(id: number): Promise<boolean> {
    try {
      const result = await query(`
        DELETE FROM webhook_endpoints 
        WHERE id = $1
        RETURNING id
      `, [id]);

      const deleted = result.rows.length > 0;
      
      if (deleted) {
        log.info(`✅ Webhook endpoint удален: ID ${id}`);
      }
      
      return deleted;
      
    } catch (error) {
      log.error('Ошибка удаления webhook endpoint:', error);
      throw error;
    }
  }

  /**
   * Получение активных endpoints для отправки события
   */
  async getEndpointsForEvent(eventType: WebhookEventType, campaignId?: number): Promise<WebhookEndpoint[]> {
    try {
      let whereClause = `
        WHERE is_active = true 
        AND event_types::jsonb @> $1
      `;
      const params: any[] = [JSON.stringify([eventType])];

      // Фильтр по кампании
      if (campaignId) {
        whereClause += ` AND (campaign_ids IS NULL OR campaign_ids::jsonb @> $2)`;
        params.push(JSON.stringify([campaignId]));
      }

      const result = await query(`
        SELECT * FROM webhook_endpoints 
        ${whereClause}
        ORDER BY created_at ASC
      `, params);

      return result.rows.map(row => this.mapToWebhookEndpoint(row));
      
    } catch (error) {
      log.error('Ошибка получения endpoints для события:', error);
      throw error;
    }
  }

  /**
   * Обновление статистики endpoint
   */
  async updateEndpointStats(endpointId: number, success: boolean, error?: string): Promise<void> {
    try {
      const updateQuery = success 
        ? `
          UPDATE webhook_endpoints 
          SET 
            total_sent = total_sent + 1,
            last_sent_at = NOW(),
            updated_at = NOW()
          WHERE id = $1
        `
        : `
          UPDATE webhook_endpoints 
          SET 
            total_failed = total_failed + 1,
            last_failed_at = NOW(),
            last_error = $2,
            updated_at = NOW()
          WHERE id = $1
        `;

      const params = success ? [endpointId] : [endpointId, error];
      await query(updateQuery, params);
      
    } catch (error) {
      log.error('Ошибка обновления статистики endpoint:', error);
      throw error;
    }
  }

  /**
   * Создание записи доставки webhook
   */
  async createDelivery(data: Omit<WebhookDelivery, 'id' | 'createdAt' | 'updatedAt'>): Promise<WebhookDelivery> {
    try {
      const result = await query(`
        INSERT INTO webhook_deliveries (
          webhook_endpoint_id, event_id, event_type, 
          request_url, request_method, request_headers, request_body,
          status_code, response_body, response_headers,
          attempt_number, processing_time, status, error,
          sent_at, delivered_at, failed_at, next_retry_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18)
        RETURNING *
      `, [
        data.webhookEndpointId,
        data.eventId,
        data.eventType,
        data.requestUrl,
        data.requestMethod,
        JSON.stringify(data.requestHeaders),
        data.requestBody,
        data.statusCode,
        data.responseBody,
        data.responseHeaders ? JSON.stringify(data.responseHeaders) : null,
        data.attemptNumber,
        data.processingTime,
        data.status,
        data.error,
        data.sentAt,
        data.deliveredAt,
        data.failedAt,
        data.nextRetryAt
      ]);

      return this.mapToWebhookDelivery(result.rows[0]);
      
    } catch (error) {
      log.error('Ошибка создания записи доставки:', error);
      throw error;
    }
  }

  /**
   * Получение статистики webhook
   */
  async getWebhookStats(options: {
    startDate?: Date;
    endDate?: Date;
    campaignId?: number;
  } = {}): Promise<WebhookStats> {
    try {
      const { startDate, endDate } = options;
      
      let whereClause = '';
      const params: any[] = [];
      let paramIndex = 1;

      if (startDate) {
        whereClause += `WHERE created_at >= $${paramIndex}`;
        params.push(startDate);
        paramIndex++;
      }

      if (endDate) {
        whereClause += whereClause ? ' AND ' : 'WHERE ';
        whereClause += `created_at <= $${paramIndex}`;
        params.push(endDate);
        paramIndex++;
      }

      // Основная статистика
      const mainStatsResult = await query(`
        SELECT 
          COUNT(*) as total_deliveries,
          SUM(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END) as successful_deliveries,
          SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failed_deliveries,
          SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending_deliveries,
          AVG(processing_time) as average_delivery_time
        FROM webhook_deliveries
        ${whereClause}
      `, params);

      const endpointsResult = await query(`
        SELECT 
          COUNT(*) as total_endpoints,
          SUM(CASE WHEN is_active = true THEN 1 ELSE 0 END) as active_endpoints
        FROM webhook_endpoints
      `);

      const mainStats = mainStatsResult.rows[0];
      const endpointStats = endpointsResult.rows[0];

      // Статистика по типам событий
      const eventTypeStatsResult = await query(`
        SELECT 
          event_type,
          COUNT(*) as count,
          (SUM(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END) * 100.0 / COUNT(*)) as success_rate
        FROM webhook_deliveries
        ${whereClause}
        GROUP BY event_type
        ORDER BY count DESC
      `, params);

      // Статистика по endpoints
      const endpointStatsResult = await query(`
        SELECT 
          we.id as endpoint_id,
          we.name as endpoint_name,
          COUNT(wd.id) as total_sent,
          (SUM(CASE WHEN wd.status = 'delivered' THEN 1 ELSE 0 END) * 100.0 / COUNT(wd.id)) as success_rate,
          AVG(wd.processing_time) as average_response_time,
          MAX(wd.created_at) as last_sent_at
        FROM webhook_endpoints we
        LEFT JOIN webhook_deliveries wd ON we.id = wd.webhook_endpoint_id
        ${whereClause.replace('created_at', 'wd.created_at')}
        GROUP BY we.id, we.name
        ORDER BY total_sent DESC
      `, params);

      return {
        totalEndpoints: parseInt(endpointStats.total_endpoints),
        activeEndpoints: parseInt(endpointStats.active_endpoints),
        totalDeliveries: parseInt(mainStats.total_deliveries),
        successfulDeliveries: parseInt(mainStats.successful_deliveries),
        failedDeliveries: parseInt(mainStats.failed_deliveries),
        pendingDeliveries: parseInt(mainStats.pending_deliveries),
        averageDeliveryTime: parseFloat(mainStats.average_delivery_time) || 0,
        
        eventTypeStats: eventTypeStatsResult.rows.map(row => ({
          eventType: row.event_type as WebhookEventType,
          count: parseInt(row.count),
          successRate: parseFloat(row.success_rate) || 0
        })),
        
        endpointStats: endpointStatsResult.rows.map(row => ({
          endpointId: row.endpoint_id,
          endpointName: row.endpoint_name,
          totalSent: parseInt(row.total_sent) || 0,
          successRate: parseFloat(row.success_rate) || 0,
          averageResponseTime: parseFloat(row.average_response_time) || 0,
          lastSentAt: row.last_sent_at
        }))
      };
      
    } catch (error) {
      log.error('Ошибка получения статистики webhook:', error);
      throw error;
    }
  }

  /**
   * Маппинг строки БД в объект WebhookEndpoint
   */
  private mapToWebhookEndpoint(row: any): WebhookEndpoint {
    return {
      id: row.id,
      url: row.url,
      name: row.name,
      description: row.description,
      isActive: row.is_active,
      secret: row.secret,
      eventTypes: JSON.parse(row.event_types || '[]'),
      campaignIds: row.campaign_ids ? JSON.parse(row.campaign_ids) : null,
      maxRetries: row.max_retries,
      retryDelay: row.retry_delay,
      timeout: row.timeout,
      totalSent: row.total_sent,
      totalFailed: row.total_failed,
      lastSentAt: row.last_sent_at,
      lastFailedAt: row.last_failed_at,
      lastError: row.last_error,
      allowedIPs: row.allowed_ips ? JSON.parse(row.allowed_ips) : null,
      httpMethod: row.http_method,
      customHeaders: row.custom_headers ? JSON.parse(row.custom_headers) : null,
      createdBy: row.created_by,
      createdAt: row.created_at,
      updatedAt: row.updated_at
    };
  }

  /**
   * Маппинг строки БД в объект WebhookDelivery
   */
  private mapToWebhookDelivery(row: any): WebhookDelivery {
    return {
      id: row.id,
      webhookEndpointId: row.webhook_endpoint_id,
      eventId: row.event_id,
      eventType: row.event_type,
      requestUrl: row.request_url,
      requestMethod: row.request_method,
      requestHeaders: JSON.parse(row.request_headers || '{}'),
      requestBody: row.request_body,
      statusCode: row.status_code,
      responseBody: row.response_body,
      responseHeaders: row.response_headers ? JSON.parse(row.response_headers) : null,
      attemptNumber: row.attempt_number,
      processingTime: row.processing_time,
      status: row.status,
      error: row.error,
      sentAt: row.sent_at,
      deliveredAt: row.delivered_at,
      failedAt: row.failed_at,
      nextRetryAt: row.next_retry_at,
      createdAt: row.created_at,
      updatedAt: row.updated_at
    };
  }

  /**
   * Преобразование camelCase в snake_case
   */
  private camelToSnake(str: string): string {
    return str.replace(/[A-Z]/g, letter => `_${letter.toLowerCase()}`);
  }
}

export const webhookModel = new WebhookModel(); 