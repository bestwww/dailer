/**
 * Сервис планировщика кампаний - управление автоматическим запуском кампаний по расписанию
 */

import * as cron from 'node-cron';
import { campaignModel } from '@/models/campaign';
import { dialerService } from '@/services/dialer';
import { log } from '@/utils/logger';
import { Campaign } from '@/types';

interface ScheduledJob {
  campaignId: number;
  task: cron.ScheduledTask;
  type: 'start' | 'stop' | 'recurring';
  description: string;
}

/**
 * Сервис планировщика кампаний
 */
export class SchedulerService {
  private scheduledJobs: Map<string, ScheduledJob> = new Map();
  private isRunning: boolean = false;

  /**
   * Запуск планировщика
   */
  async start(): Promise<void> {
    try {
      if (this.isRunning) {
        log.warn('Scheduler is already running');
        return;
      }

      log.info('🕐 Starting scheduler service...');

      // Загрузка запланированных кампаний
      await this.loadScheduledCampaigns();

      this.isRunning = true;
      log.info('✅ Scheduler service started successfully');

    } catch (error) {
      log.error('❌ Failed to start scheduler service:', error);
      throw error;
    }
  }

  /**
   * Остановка планировщика
   */
  async stop(): Promise<void> {
    try {
      log.info('🛑 Stopping scheduler service...');

      // Остановка всех запланированных задач
      this.stopAllScheduledJobs();

      this.isRunning = false;
      log.info('✅ Scheduler service stopped');

    } catch (error) {
      log.error('❌ Failed to stop scheduler service:', error);
      throw error;
    }
  }

  /**
   * Планирование кампании
   */
  async scheduleCampaign(campaign: Campaign): Promise<void> {
    try {
      if (!campaign.isScheduled) {
        log.warn(`Campaign ${campaign.id} is not scheduled`);
        return;
      }

      // Удаление существующих задач для этой кампании
      await this.unscheduleCampaign(campaign.id);

      // Планирование запуска
      if (campaign.scheduledStart) {
        await this.scheduleStart(campaign);
      }

      // Планирование остановки
      if (campaign.scheduledStop) {
        await this.scheduleStop(campaign);
      }

      // Планирование повторяющихся задач
      if (campaign.isRecurring && campaign.cronExpression) {
        await this.scheduleRecurring(campaign);
      }

      log.info(`📅 Scheduled campaign: ${campaign.name} (ID: ${campaign.id})`);

    } catch (error) {
      log.error(`Failed to schedule campaign ${campaign.id}:`, error);
      throw error;
    }
  }

  /**
   * Отмена планирования кампании
   */
  async unscheduleCampaign(campaignId: number): Promise<void> {
    try {
      const keysToRemove: string[] = [];

      // Поиск всех задач для данной кампании
      for (const [key, job] of this.scheduledJobs) {
        if (job.campaignId === campaignId) {
          job.task.stop();
          job.task.destroy();
          keysToRemove.push(key);
        }
      }

      // Удаление из карты
      keysToRemove.forEach(key => {
        this.scheduledJobs.delete(key);
      });

      log.info(`🗑️ Unscheduled campaign: ${campaignId}`);

    } catch (error) {
      log.error(`Failed to unschedule campaign ${campaignId}:`, error);
      throw error;
    }
  }

  /**
   * Загрузка всех запланированных кампаний
   */
  private async loadScheduledCampaigns(): Promise<void> {
    try {
      const campaigns = await campaignModel.getScheduledCampaigns();

      log.info(`Loading ${campaigns.length} scheduled campaigns...`);

      for (const campaign of campaigns) {
        await this.scheduleCampaign(campaign);
      }

      log.info(`✅ Loaded ${campaigns.length} scheduled campaigns`);

    } catch (error) {
      log.error('Failed to load scheduled campaigns:', error);
      throw error;
    }
  }

  /**
   * Планирование запуска кампании
   */
  private async scheduleStart(campaign: Campaign): Promise<void> {
    const startTime = new Date(campaign.scheduledStart!);
    const now = new Date();

    // Проверка, что время запуска в будущем
    if (startTime <= now) {
      log.warn(`Campaign ${campaign.id} scheduled start time is in the past`);
      return;
    }

    // Создание cron выражения для конкретного времени
    const cronExpression = this.dateToCronExpression(startTime);

    const task = cron.schedule(cronExpression, async () => {
      try {
        log.info(`🚀 Auto-starting campaign: ${campaign.name} (ID: ${campaign.id})`);
        
        // Проверка, что кампания не активна
        const currentCampaign = await campaignModel.getCampaignById(campaign.id);
        if (currentCampaign?.status === 'active') {
          log.warn(`Campaign ${campaign.id} is already active`);
          return;
        }

        // Запуск кампании
        await dialerService.startCampaign(campaign.id);

        log.info(`✅ Auto-started campaign: ${campaign.name} (ID: ${campaign.id})`);

      } catch (error) {
        log.error(`Failed to auto-start campaign ${campaign.id}:`, error);
      }
    }, {
      timezone: campaign.timezone || 'UTC'
    });

    const jobKey = `start_${campaign.id}`;
    this.scheduledJobs.set(jobKey, {
      campaignId: campaign.id,
      task,
      type: 'start',
      description: `Auto-start campaign ${campaign.name} at ${startTime.toISOString()}`
    });

    log.info(`📅 Scheduled start for campaign ${campaign.id} at ${startTime.toISOString()}`);
  }

  /**
   * Планирование остановки кампании
   */
  private async scheduleStop(campaign: Campaign): Promise<void> {
    const stopTime = new Date(campaign.scheduledStop!);
    const now = new Date();

    // Проверка, что время остановки в будущем
    if (stopTime <= now) {
      log.warn(`Campaign ${campaign.id} scheduled stop time is in the past`);
      return;
    }

    // Создание cron выражения для конкретного времени
    const cronExpression = this.dateToCronExpression(stopTime);

    const task = cron.schedule(cronExpression, async () => {
      try {
        log.info(`⏹️ Auto-stopping campaign: ${campaign.name} (ID: ${campaign.id})`);
        
        // Проверка, что кампания активна
        const currentCampaign = await campaignModel.getCampaignById(campaign.id);
        if (currentCampaign?.status !== 'active') {
          log.warn(`Campaign ${campaign.id} is not active`);
          return;
        }

        // Остановка кампании
        await dialerService.stopCampaign(campaign.id);

        log.info(`✅ Auto-stopped campaign: ${campaign.name} (ID: ${campaign.id})`);

      } catch (error) {
        log.error(`Failed to auto-stop campaign ${campaign.id}:`, error);
      }
    }, {
      timezone: campaign.timezone || 'UTC'
    });

    const jobKey = `stop_${campaign.id}`;
    this.scheduledJobs.set(jobKey, {
      campaignId: campaign.id,
      task,
      type: 'stop',
      description: `Auto-stop campaign ${campaign.name} at ${stopTime.toISOString()}`
    });

    log.info(`📅 Scheduled stop for campaign ${campaign.id} at ${stopTime.toISOString()}`);
  }

  /**
   * Планирование повторяющихся задач
   */
  private async scheduleRecurring(campaign: Campaign): Promise<void> {
    const cronExpression = campaign.cronExpression!;

    // Валидация cron выражения
    if (!cron.validate(cronExpression)) {
      throw new Error(`Invalid cron expression: ${cronExpression}`);
    }

    const task = cron.schedule(cronExpression, async () => {
      try {
        log.info(`🔄 Recurring start for campaign: ${campaign.name} (ID: ${campaign.id})`);
        
        // Проверка, что кампания не активна
        const currentCampaign = await campaignModel.getCampaignById(campaign.id);
        if (currentCampaign?.status === 'active') {
          log.warn(`Campaign ${campaign.id} is already active, skipping recurring start`);
          return;
        }

        // Запуск кампании
        await dialerService.startCampaign(campaign.id);

        log.info(`✅ Recurring started campaign: ${campaign.name} (ID: ${campaign.id})`);

      } catch (error) {
        log.error(`Failed to recurring start campaign ${campaign.id}:`, error);
      }
    }, {
      timezone: campaign.timezone || 'UTC'
    });

    const jobKey = `recurring_${campaign.id}`;
    this.scheduledJobs.set(jobKey, {
      campaignId: campaign.id,
      task,
      type: 'recurring',
      description: `Recurring start for campaign ${campaign.name} (${cronExpression})`
    });

    log.info(`📅 Scheduled recurring task for campaign ${campaign.id}: ${cronExpression}`);
  }

  /**
   * Преобразование даты в cron выражение
   */
  private dateToCronExpression(date: Date): string {
    const minute = date.getMinutes();
    const hour = date.getHours();
    const dayOfMonth = date.getDate();
    const month = date.getMonth() + 1;

    // Создаем cron выражение для конкретного времени
    return `${minute} ${hour} ${dayOfMonth} ${month} *`;
  }

  /**
   * Остановка всех запланированных задач
   */
  private stopAllScheduledJobs(): void {
    for (const [_key, job] of this.scheduledJobs) {
      job.task.stop();
      job.task.destroy();
    }
    this.scheduledJobs.clear();
    log.info('🗑️ Stopped all scheduled jobs');
  }

  /**
   * Получение статуса планировщика
   */
  getStatus(): {
    isRunning: boolean;
    scheduledJobs: Array<{
      campaignId: number;
      type: 'start' | 'stop' | 'recurring';
      description: string;
      isRunning: boolean;
    }>;
  } {
    const jobs = Array.from(this.scheduledJobs.values()).map(job => ({
      campaignId: job.campaignId,
      type: job.type,
      description: job.description,
      isRunning: true // node-cron не предоставляет способ проверки статуса задачи
    }));

    return {
      isRunning: this.isRunning,
      scheduledJobs: jobs
    };
  }

  /**
   * Валидация cron выражения
   */
  validateCronExpression(cronExpression: string): boolean {
    return cron.validate(cronExpression);
  }
}

// Экспорт синглтона
export const schedulerService = new SchedulerService(); 