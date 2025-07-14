/**
 * Модель Campaign - управление кампаниями автодозвона
 */

import { BaseModel } from '@/config/database';
import { Campaign, CampaignStatus, CreateCampaignRequest, UpdateCampaignRequest } from '@/types';
import { log } from '@/utils/logger';

export class CampaignModel extends BaseModel {
  private tableName = 'campaigns';

  /**
   * Создание новой кампании
   */
  async createCampaign(data: CreateCampaignRequest, createdBy?: number): Promise<Campaign> {
    try {
      const campaignData = {
        name: data.name,
        description: data.description || null,
        status: 'draft' as CampaignStatus,
        
        // Настройки аудио (будут добавлены позже)
        audio_file_path: null,
        audio_file_name: null,
        audio_duration: 0,
        
        // Настройки обзвона
        max_concurrent_calls: data.maxConcurrentCalls || 10,
        calls_per_minute: data.callsPerMinute || 30,
        retry_attempts: data.retryAttempts || 3,
        retry_delay: data.retryDelay || 300,
        
        // Настройки времени работы
        work_time_start: data.workTimeStart || '09:00',
        work_time_end: data.workTimeEnd || '18:00',
        work_days: data.workDays || [1, 2, 3, 4, 5], // Пн-Пт
        timezone: data.timezone || 'UTC',
        
        // Планировщик кампаний
        is_scheduled: data.isScheduled || false,
        scheduled_start: data.scheduledStart || null,
        scheduled_stop: data.scheduledStop || null,
        is_recurring: data.isRecurring || false,
        cron_expression: data.cronExpression || null,
        
        // Битрикс24 интеграция
        bitrix_create_leads: data.bitrixCreateLeads || false,
        bitrix_responsible_id: data.bitrixResponsibleId || null,
        bitrix_source_id: data.bitrixSourceId || 'CALL',
        
        // Метаданные
        created_by: createdBy || null,
        
        // Статистика (начальные значения)
        total_contacts: 0,
        completed_calls: 0,
        successful_calls: 0,
        failed_calls: 0,
        interested_responses: 0,
      };

      const campaign = await this.create<Campaign>(this.tableName, campaignData);

      log.info(`Created campaign: ${campaign.name} (ID: ${campaign.id})`);
      return this.formatCampaign(campaign);

    } catch (error) {
      log.error('Failed to create campaign:', error);
      throw error;
    }
  }

  /**
   * Получение кампании по ID
   */
  async getCampaignById(id: number): Promise<Campaign | null> {
    try {
      const campaign = await this.findById<any>(this.tableName, id);
      return campaign ? this.formatCampaign(campaign) : null;
    } catch (error) {
      log.error(`Failed to get campaign ${id}:`, error);
      throw error;
    }
  }

  /**
   * Получение списка кампаний с пагинацией
   */
  async getCampaigns(
    page: number = 1,
    limit: number = 10,
    status?: CampaignStatus,
    createdBy?: number
  ): Promise<{
    campaigns: Campaign[];
    total: number;
    page: number;
    totalPages: number;
  }> {
    try {
      let whereClause = '';
      const params: any[] = [];

      if (status) {
        whereClause += 'status = $1';
        params.push(status);
      }

      if (createdBy) {
        whereClause += whereClause ? ' AND ' : '';
        whereClause += `created_by = $${params.length + 1}`;
        params.push(createdBy);
      }

      const result = await this.paginate<any>(
        this.tableName,
        page,
        limit,
        whereClause || undefined,
        'created_at DESC',
        params.length > 0 ? params : undefined
      );

      return {
        campaigns: result.items.map(item => this.formatCampaign(item)),
        total: result.total,
        page: result.page,
        totalPages: result.totalPages,
      };

    } catch (error) {
      log.error('Failed to get campaigns:', error);
      throw error;
    }
  }

  /**
   * Обновление кампании
   */
  async updateCampaign(id: number, data: UpdateCampaignRequest): Promise<Campaign | null> {
    try {
      log.info(`🔍 DEBUG: Обновление кампании ${id}`);
      log.info(`📋 Входные данные:`, data);

      const updateData: any = {};

      // Основные поля
      if (data.name !== undefined) updateData.name = data.name;
      if (data.description !== undefined) updateData.description = data.description;
      if (data.status !== undefined) updateData.status = data.status;

      // Аудио файлы
      if (data.audioFilePath !== undefined) {
        updateData.audio_file_path = data.audioFilePath;
        log.info(`🎵 Обновление audioFilePath: "${data.audioFilePath}"`);
        
        // Если audioFilePath пустой, также очищаем audioFileName
        if (data.audioFilePath === '') {
          updateData.audio_file_name = '';
          log.info(`🎵 Очистка audioFileName т.к. audioFilePath пустой`);
        }
      }
      if (data.audioFileName !== undefined) {
        updateData.audio_file_name = data.audioFileName;
        log.info(`🎵 Обновление audioFileName: "${data.audioFileName}"`);
      }

      // Настройки обзвона
      if (data.maxConcurrentCalls !== undefined) updateData.max_concurrent_calls = data.maxConcurrentCalls;
      if (data.callsPerMinute !== undefined) updateData.calls_per_minute = data.callsPerMinute;
      if (data.retryAttempts !== undefined) updateData.retry_attempts = data.retryAttempts;
      if (data.retryDelay !== undefined) updateData.retry_delay = data.retryDelay;

      // Настройки времени работы
      if (data.workTimeStart !== undefined) updateData.work_time_start = data.workTimeStart;
      if (data.workTimeEnd !== undefined) updateData.work_time_end = data.workTimeEnd;
      if (data.workDays !== undefined) updateData.work_days = data.workDays;
      if (data.timezone !== undefined) updateData.timezone = data.timezone;

      // Планировщик кампаний
      if (data.isScheduled !== undefined) updateData.is_scheduled = data.isScheduled;
      if (data.scheduledStart !== undefined) updateData.scheduled_start = data.scheduledStart;
      if (data.scheduledStop !== undefined) updateData.scheduled_stop = data.scheduledStop;
      if (data.isRecurring !== undefined) updateData.is_recurring = data.isRecurring;
      if (data.cronExpression !== undefined) updateData.cron_expression = data.cronExpression;

      // Битрикс24
      if (data.bitrixCreateLeads !== undefined) updateData.bitrix_create_leads = data.bitrixCreateLeads;
      if (data.bitrixResponsibleId !== undefined) updateData.bitrix_responsible_id = data.bitrixResponsibleId;
      if (data.bitrixSourceId !== undefined) updateData.bitrix_source_id = data.bitrixSourceId;

      log.info(`📝 Данные для обновления в БД:`, updateData);

      const campaign = await this.update<any>(this.tableName, id, updateData);

      if (campaign) {
        log.info(`✅ Updated campaign: ${campaign.name} (ID: ${id})`);
        log.info(`📊 Результат из БД:`, campaign);
        
        const formattedCampaign = this.formatCampaign(campaign);
        log.info(`🎯 Отформатированная кампания:`, formattedCampaign);
        
        return formattedCampaign;
      }

      log.warn(`⚠️ Кампания ${id} не найдена для обновления`);
      return null;

    } catch (error) {
      log.error(`Failed to update campaign ${id}:`, error);
      throw error;
    }
  }

  /**
   * Удаление кампании
   */
  async deleteCampaign(id: number): Promise<boolean> {
    try {
      const deleted = await this.delete(this.tableName, id);
      
      if (deleted) {
        log.info(`Deleted campaign ID: ${id}`);
      }
      
      return deleted;
    } catch (error) {
      log.error(`Failed to delete campaign ${id}:`, error);
      throw error;
    }
  }

  /**
   * Обновление статистики кампании
   */
  async updateCampaignStats(
    id: number, 
    stats: {
      totalContacts?: number;
      completedCalls?: number;
      successfulCalls?: number;
      failedCalls?: number;
      interestedResponses?: number;
    }
  ): Promise<void> {
    try {
      const updateData: any = {};

      if (stats.totalContacts !== undefined) updateData.total_contacts = stats.totalContacts;
      if (stats.completedCalls !== undefined) updateData.completed_calls = stats.completedCalls;
      if (stats.successfulCalls !== undefined) updateData.successful_calls = stats.successfulCalls;
      if (stats.failedCalls !== undefined) updateData.failed_calls = stats.failedCalls;
      if (stats.interestedResponses !== undefined) updateData.interested_responses = stats.interestedResponses;

      await this.update(this.tableName, id, updateData);
      log.debug(`Updated campaign ${id} statistics`);

    } catch (error) {
      log.error(`Failed to update campaign ${id} stats:`, error);
      throw error;
    }
  }

  /**
   * Обновление аудио файла кампании
   */
  async updateCampaignAudio(
    id: number,
    audioFilePath: string,
    audioFileName: string,
    audioDuration: number
  ): Promise<Campaign | null> {
    try {
      log.info(`🔍 DEBUG: Обновление аудио файла для кампании ${id}`);
      log.info(`📁 Путь к файлу: ${audioFilePath}`);
      log.info(`📂 Имя файла: ${audioFileName}`);
      log.info(`⏱️ Длительность: ${audioDuration}`);

      const updateData = {
        audio_file_path: audioFilePath,
        audio_file_name: audioFileName,
        audio_duration: audioDuration,
      };

      log.info(`📝 Данные для обновления:`, updateData);

      const campaign = await this.update<any>(this.tableName, id, updateData);

      if (campaign) {
        log.info(`✅ Updated audio for campaign ${id}: ${audioFileName}`);
        log.info(`📊 Результат обновления:`, campaign);
        
        const formattedCampaign = this.formatCampaign(campaign);
        log.info(`🎯 Отформатированная кампания:`, formattedCampaign);
        
        return formattedCampaign;
      }

      log.warn(`⚠️ Кампания ${id} не найдена для обновления аудио`);
      return null;

    } catch (error) {
      log.error(`❌ Failed to update campaign ${id} audio:`, error);
      throw error;
    }
  }

  /**
   * Получение активных кампаний
   */
  async getActiveCampaigns(): Promise<Campaign[]> {
    try {
      const result = await this.query<any>(
        'SELECT * FROM campaigns WHERE status = $1 ORDER BY created_at DESC',
        ['active']
      );

      return result.rows.map(row => this.formatCampaign(row));

    } catch (error) {
      log.error('Failed to get active campaigns:', error);
      throw error;
    }
  }

  /**
   * Проверка возможности запуска кампании
   */
  async canStartCampaign(id: number): Promise<{ canStart: boolean; reason?: string }> {
    try {
      const campaign = await this.getCampaignById(id);
      
      if (!campaign) {
        return { canStart: false, reason: 'Campaign not found' };
      }

      if (campaign.status === 'active') {
        return { canStart: false, reason: 'Campaign is already active' };
      }

      if (campaign.totalContacts === 0) {
        return { canStart: false, reason: 'No contacts in campaign' };
      }

      if (!campaign.audioFilePath) {
        return { canStart: false, reason: 'No audio file uploaded' };
      }

      return { canStart: true };

    } catch (error) {
      log.error(`Failed to check if campaign ${id} can start:`, error);
      return { canStart: false, reason: 'Internal error' };
    }
  }

  /**
   * Получение статистики по всем кампаниям
   */
  async getCampaignsSummary(): Promise<{
    total: number;
    active: number;
    completed: number;
    totalCalls: number;
    totalContacts: number;
  }> {
    try {
      const result = await this.query<any>(`
        SELECT 
          COUNT(*) as total,
          COUNT(CASE WHEN status = 'active' THEN 1 END) as active,
          COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed,
          SUM(completed_calls) as total_calls,
          SUM(total_contacts) as total_contacts
        FROM campaigns
      `);

      const row = result.rows[0];
      
      return {
        total: parseInt(row.total || '0', 10),
        active: parseInt(row.active || '0', 10),
        completed: parseInt(row.completed || '0', 10),
        totalCalls: parseInt(row.total_calls || '0', 10),
        totalContacts: parseInt(row.total_contacts || '0', 10),
      };

    } catch (error) {
      log.error('Failed to get campaigns summary:', error);
      throw error;
    }
  }

  /**
   * Получение запланированных кампаний
   */
  async getScheduledCampaigns(): Promise<Campaign[]> {
    try {
      const result = await this.query<any>(
        'SELECT * FROM campaigns WHERE is_scheduled = true ORDER BY created_at DESC'
      );

      return result.rows.map(row => this.formatCampaign(row));

    } catch (error) {
      log.error('Failed to get scheduled campaigns:', error);
      throw error;
    }
  }

  /**
   * Форматирование данных кампании для API
   */
  private formatCampaign(row: any): Campaign {
    return {
      id: row.id,
      name: row.name,
      description: row.description,
      
      // Настройки аудио
      audioFilePath: row.audio_file_path,
      audioFileName: row.audio_file_name,
      audioDuration: row.audio_duration,
      
      // Статус кампании
      status: row.status,
      
      // Настройки обзвона
      maxConcurrentCalls: row.max_concurrent_calls,
      callsPerMinute: row.calls_per_minute,
      retryAttempts: row.retry_attempts,
      retryDelay: row.retry_delay,
      
      // Настройки времени работы
      workTimeStart: row.work_time_start,
      workTimeEnd: row.work_time_end,
      workDays: Array.isArray(row.work_days) ? row.work_days : [],
      timezone: row.timezone,
      
      // Планировщик кампаний
      isScheduled: row.is_scheduled || false,
      ...(row.scheduled_start && { scheduledStart: new Date(row.scheduled_start) }),
      ...(row.scheduled_stop && { scheduledStop: new Date(row.scheduled_stop) }),
      isRecurring: row.is_recurring || false,
      ...(row.cron_expression && { cronExpression: row.cron_expression }),
      
      // Битрикс24 интеграция
      bitrixCreateLeads: row.bitrix_create_leads,
      bitrixResponsibleId: row.bitrix_responsible_id,
      bitrixSourceId: row.bitrix_source_id,
      
      // Метаданные
      createdBy: row.created_by,
      
      // Статистика
      totalContacts: row.total_contacts,
      completedCalls: row.completed_calls,
      successfulCalls: row.successful_calls,
      failedCalls: row.failed_calls,
      interestedResponses: row.interested_responses,
      
      // Временные метки
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at),
    };
  }
}

/**
 * Singleton экземпляр модели кампании
 */
export const campaignModel = new CampaignModel(); 