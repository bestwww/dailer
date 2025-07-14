/**
 * Система оповещений и алертов
 * Этап 6.3: Система логирования и мониторинга
 */

import { EventEmitter } from 'events';
import { log } from '@/utils/logger';
import { monitoringService } from './monitoring';

export interface Alert {
  id: string;
  name: string;
  level: 'info' | 'warning' | 'error' | 'critical';
  message: string;
  details?: Record<string, any>;
  timestamp: Date;
  resolved?: Date;
  acknowledgedBy?: string;
  acknowledgedAt?: Date;
}

export interface AlertRule {
  name: string;
  condition: (metrics: any) => boolean;
  level: 'info' | 'warning' | 'error' | 'critical';
  message: string;
  cooldown: number; // Минимальное время между повторными алертами (в мс)
  enabled: boolean;
}

export interface AlertChannel {
  name: string;
  type: 'console' | 'email' | 'slack' | 'webhook' | 'telegram';
  config: Record<string, any>;
  enabled: boolean;
  levels: ('info' | 'warning' | 'error' | 'critical')[];
}

export class AlertingService extends EventEmitter {
  private static instance: AlertingService;
  
  private alerts = new Map<string, Alert>();
  private rules = new Map<string, AlertRule>();
  private channels = new Map<string, AlertChannel>();
  private lastAlertTime = new Map<string, number>();
  
  private isRunning = false;
  private checkInterval?: NodeJS.Timeout;
  
  private constructor() {
    super();
    this.initializeDefaultRules();
    this.initializeDefaultChannels();
  }

  static getInstance(): AlertingService {
    if (!AlertingService.instance) {
      AlertingService.instance = new AlertingService();
    }
    return AlertingService.instance;
  }

  /**
   * Инициализация правил по умолчанию
   */
  private initializeDefaultRules(): void {
    // Высокое использование памяти
    this.addRule({
      name: 'high_memory_usage',
      condition: (metrics) => {
        const memUsage = metrics.memoryUsage?.heapUsed || 0;
        const memUsageMB = memUsage / 1024 / 1024;
        return memUsageMB > 512; // Больше 512MB
      },
      level: 'warning',
      message: 'Высокое использование памяти',
      cooldown: 300000, // 5 минут
      enabled: true
    });

    // Критическое использование памяти
    this.addRule({
      name: 'critical_memory_usage',
      condition: (metrics) => {
        const memUsage = metrics.memoryUsage?.heapUsed || 0;
        const memUsageMB = memUsage / 1024 / 1024;
        return memUsageMB > 1024; // Больше 1GB
      },
      level: 'critical',
      message: 'Критическое использование памяти',
      cooldown: 60000, // 1 минута
      enabled: true
    });

    // Высокий процент ошибок
    this.addRule({
      name: 'high_error_rate',
      condition: (metrics) => {
        return metrics.errorRate > 10; // Больше 10% ошибок
      },
      level: 'error',
      message: 'Высокий процент ошибок в HTTP запросах',
      cooldown: 180000, // 3 минуты
      enabled: true
    });

    // Критический процент ошибок
    this.addRule({
      name: 'critical_error_rate',
      condition: (metrics) => {
        return metrics.errorRate > 25; // Больше 25% ошибок
      },
      level: 'critical',
      message: 'Критический процент ошибок в HTTP запросах',
      cooldown: 60000, // 1 минута
      enabled: true
    });

    // Медленные запросы
    this.addRule({
      name: 'slow_response_time',
      condition: (metrics) => {
        return metrics.responseTime > 5000; // Больше 5 секунд
      },
      level: 'warning',
      message: 'Медленное время ответа HTTP запросов',
      cooldown: 300000, // 5 минут
      enabled: true
    });

    // Нет активных звонков долгое время (только для рабочих часов)
    this.addRule({
      name: 'no_active_calls',
      condition: (metrics) => {
        const hour = new Date().getHours();
        const isWorkingHours = hour >= 9 && hour <= 18;
        return isWorkingHours && metrics.activeCalls === 0 && metrics.activeCampaigns > 0;
      },
      level: 'info',
      message: 'Нет активных звонков при наличии активных кампаний',
      cooldown: 900000, // 15 минут
      enabled: true
    });

    // Высокий процент неуспешных звонков
    this.addRule({
      name: 'high_call_failure_rate',
      condition: (metrics) => {
        const totalCalls = metrics.totalCallsToday;
        const failedCalls = metrics.failedCallsToday;
        if (totalCalls < 10) return false; // Не алертим при малом количестве звонков
        
        const failureRate = (failedCalls / totalCalls) * 100;
        return failureRate > 30; // Больше 30% неуспешных
      },
      level: 'warning',
      message: 'Высокий процент неуспешных звонков',
      cooldown: 600000, // 10 минут
      enabled: true
    });

    // Проблемы с FreeSWITCH
    this.addRule({
      name: 'freeswitch_disconnected',
      condition: (metrics) => {
        // Этот флаг должен быть установлен из DialerService
        return metrics.freeswitchConnected === false;
      },
      level: 'critical',
      message: 'Потеряно соединение с FreeSWITCH',
      cooldown: 60000, // 1 минута
      enabled: true
    });
  }

  /**
   * Инициализация каналов по умолчанию
   */
  private initializeDefaultChannels(): void {
    // Консольный вывод
    this.addChannel({
      name: 'console',
      type: 'console',
      config: {},
      enabled: true,
      levels: ['info', 'warning', 'error', 'critical']
    });

    // Логи (всегда включен)
    this.addChannel({
      name: 'logs',
      type: 'console', // Специальный тип для логирования
      config: {},
      enabled: true,
      levels: ['warning', 'error', 'critical']
    });
  }

  /**
   * Запуск системы алертов
   */
  start(): void {
    if (this.isRunning) {
      return;
    }

    this.isRunning = true;
    this.startRuleChecking();
    
    // Подписка на события мониторинга
    monitoringService.on('metric:recorded', this.handleMetricRecorded.bind(this));
    
    log.info('Система алертов запущена');
    this.emit('alerting:started');
  }

  /**
   * Остановка системы алертов
   */
  stop(): void {
    if (!this.isRunning) {
      return;
    }

    this.isRunning = false;
    
    if (this.checkInterval) {
      clearInterval(this.checkInterval);
    }
    
    monitoringService.removeListener('metric:recorded', this.handleMetricRecorded.bind(this));
    
    log.info('Система алертов остановлена');
    this.emit('alerting:stopped');
  }

  /**
   * Добавление правила алерта
   */
  addRule(rule: AlertRule): void {
    this.rules.set(rule.name, rule);
    log.debug(`Добавлено правило алерта: ${rule.name}`);
  }

  /**
   * Удаление правила алерта
   */
  removeRule(name: string): boolean {
    const removed = this.rules.delete(name);
    if (removed) {
      log.debug(`Удалено правило алерта: ${name}`);
    }
    return removed;
  }

  /**
   * Добавление канала уведомлений
   */
  addChannel(channel: AlertChannel): void {
    this.channels.set(channel.name, channel);
    log.debug(`Добавлен канал уведомлений: ${channel.name} (${channel.type})`);
  }

  /**
   * Удаление канала уведомлений
   */
  removeChannel(name: string): boolean {
    const removed = this.channels.delete(name);
    if (removed) {
      log.debug(`Удален канал уведомлений: ${name}`);
    }
    return removed;
  }

  /**
   * Создание алерта
   */
  createAlert(
    name: string,
    level: Alert['level'],
    message: string,
    details?: Record<string, any>
  ): Alert {
    const alert: Alert = {
      id: this.generateAlertId(),
      name,
      level,
      message,
      ...(details && { details }),
      timestamp: new Date()
    };

    this.alerts.set(alert.id, alert);
    
    // Отправка через каналы
    this.sendAlert(alert);
    
    // Логирование
    const logLevel = level === 'critical' ? 'error' : level === 'error' ? 'error' : 'warn';
    log[logLevel](`[ALERT] ${message}`, { 
      alertId: alert.id, 
      level, 
      details 
    });

    this.emit('alert:created', alert);
    return alert;
  }

  /**
   * Подтверждение алерта
   */
  acknowledgeAlert(alertId: string, acknowledgedBy: string): boolean {
    const alert = this.alerts.get(alertId);
    if (!alert) {
      return false;
    }

    alert.acknowledgedBy = acknowledgedBy;
    alert.acknowledgedAt = new Date();

    log.info(`Алерт подтвержден: ${alert.name} пользователем ${acknowledgedBy}`, {
      alertId: alert.id
    });

    this.emit('alert:acknowledged', alert);
    return true;
  }

  /**
   * Разрешение алерта
   */
  resolveAlert(alertId: string): boolean {
    const alert = this.alerts.get(alertId);
    if (!alert) {
      return false;
    }

    alert.resolved = new Date();

    log.info(`Алерт разрешен: ${alert.name}`, {
      alertId: alert.id,
      duration: alert.resolved.getTime() - alert.timestamp.getTime()
    });

    this.emit('alert:resolved', alert);
    return true;
  }

  /**
   * Получение всех алертов
   */
  getAlerts(options?: {
    level?: Alert['level'];
    resolved?: boolean;
    limit?: number;
  }): Alert[] {
    let alerts = Array.from(this.alerts.values());

    if (options?.level) {
      alerts = alerts.filter(alert => alert.level === options.level);
    }

    if (options?.resolved !== undefined) {
      alerts = alerts.filter(alert => !!alert.resolved === options.resolved);
    }

    // Сортировка по времени (новые первыми)
    alerts.sort((a, b) => b.timestamp.getTime() - a.timestamp.getTime());

    if (options?.limit) {
      alerts = alerts.slice(0, options.limit);
    }

    return alerts;
  }

  /**
   * Получение активных алертов
   */
  getActiveAlerts(): Alert[] {
    return this.getAlerts({ resolved: false });
  }

  /**
   * Получение статистики алертов
   */
  getAlertStats(): {
    total: number;
    active: number;
    byLevel: Record<Alert['level'], number>;
    acknowledged: number;
  } {
    const alerts = Array.from(this.alerts.values());
    const active = alerts.filter(alert => !alert.resolved);
    const acknowledged = alerts.filter(alert => !!alert.acknowledgedBy);

    const byLevel = {
      info: 0,
      warning: 0,
      error: 0,
      critical: 0
    };

    alerts.forEach(alert => {
      byLevel[alert.level]++;
    });

    return {
      total: alerts.length,
      active: active.length,
      byLevel,
      acknowledged: acknowledged.length
    };
  }

  /**
   * Проверка health checks и создание алертов
   */
  async checkHealthAndAlert(): Promise<void> {
    try {
      const healthResults = await monitoringService.runHealthChecks();
      
      for (const result of healthResults) {
        if (result.status === 'unhealthy') {
          this.createAlert(
            `health_check_${result.name}`,
            'error',
            `Health check failed: ${result.name}`,
            {
              healthCheck: result.name,
              message: result.message,
              duration: result.duration
            }
          );
        } else if (result.status === 'degraded') {
          this.createAlert(
            `health_check_${result.name}`,
            'warning',
            `Health check degraded: ${result.name}`,
            {
              healthCheck: result.name,
              message: result.message,
              duration: result.duration
            }
          );
        }
      }
    } catch (error) {
      this.createAlert(
        'health_check_error',
        'error',
        'Ошибка выполнения health checks',
        { error: String(error) }
      );
    }
  }

  /**
   * Получение статуса системы алертов
   */
  getStatus(): {
    isRunning: boolean;
    rules: number;
    channels: number;
    totalAlerts: number;
    activeAlerts: number;
  } {
    return {
      isRunning: this.isRunning,
      rules: this.rules.size,
      channels: this.channels.size,
      totalAlerts: this.alerts.size,
      activeAlerts: this.getActiveAlerts().length
    };
  }

  /**
   * Очистка старых алертов
   */
  cleanupOldAlerts(daysToKeep: number = 30): void {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - daysToKeep);

    let removedCount = 0;

    for (const [id, alert] of this.alerts) {
      if (alert.timestamp < cutoffDate && alert.resolved) {
        this.alerts.delete(id);
        removedCount++;
      }
    }

    if (removedCount > 0) {
      log.info(`Очищено ${removedCount} старых алертов`);
    }
  }

  /**
   * Запуск проверки правил
   */
  private startRuleChecking(): void {
    this.checkInterval = setInterval(async () => {
      try {
        await this.checkRules();
      } catch (error) {
        log.error('Ошибка проверки правил алертов:', error);
      }
    }, 60000); // Каждую минуту
  }

  /**
   * Проверка всех правил
   */
  private async checkRules(): Promise<void> {
    const metrics = await monitoringService.getSystemMetrics();

    for (const [ruleName, rule] of this.rules) {
      if (!rule.enabled) {
        continue;
      }

      try {
        const shouldAlert = rule.condition(metrics);
        
        if (shouldAlert) {
          const lastAlert = this.lastAlertTime.get(ruleName) || 0;
          const now = Date.now();
          
          // Проверка cooldown
          if (now - lastAlert < rule.cooldown) {
            continue;
          }

          this.createAlert(ruleName, rule.level, rule.message, {
            rule: ruleName,
            metrics: {
              memoryUsageMB: Math.round(metrics.memoryUsage.heapUsed / 1024 / 1024),
              errorRate: metrics.errorRate,
              responseTime: metrics.responseTime,
              activeCalls: metrics.activeCalls,
              activeCampaigns: metrics.activeCampaigns
            }
          });

          this.lastAlertTime.set(ruleName, now);
        }
      } catch (error) {
        log.error(`Ошибка выполнения правила алерта ${ruleName}:`, error);
      }
    }
  }

  /**
   * Обработка записи метрики
   */
  private handleMetricRecorded(_metric: any): void {
    // Можно добавить логику для реагирования на конкретные метрики
    // Например, если метрика превышает определенный порог
  }

  /**
   * Отправка алерта через каналы
   */
  private async sendAlert(alert: Alert): Promise<void> {
    for (const [channelName, channel] of this.channels) {
      if (!channel.enabled || !channel.levels.includes(alert.level)) {
        continue;
      }

      try {
        await this.sendAlertToChannel(alert, channel);
      } catch (error) {
        log.error(`Ошибка отправки алерта ${alert.id} через канал ${channelName}:`, error);
      }
    }
  }

  /**
   * Отправка алерта в конкретный канал
   */
  private async sendAlertToChannel(alert: Alert, channel: AlertChannel): Promise<void> {
    switch (channel.type) {
      case 'console':
        if (channel.name === 'logs') {
          // Специальное логирование для канала logs
          return; // Уже логируется в createAlert
        }
        console.log(`🚨 [${alert.level.toUpperCase()}] ${alert.message}`, alert.details);
        break;

      case 'webhook':
        // Здесь можно добавить отправку webhook
        // await this.sendWebhook(channel.config.url, alert);
        break;

      case 'email':
        // Здесь можно добавить отправку email
        // await this.sendEmail(channel.config, alert);
        break;

      case 'slack':
        // Здесь можно добавить отправку в Slack
        // await this.sendSlack(channel.config, alert);
        break;

      case 'telegram':
        // Здесь можно добавить отправку в Telegram
        // await this.sendTelegram(channel.config, alert);
        break;
    }
  }

  /**
   * Генерация ID алерта
   */
  private generateAlertId(): string {
    return `alert_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }
}

// Экспорт singleton instance
export const alertingService = AlertingService.getInstance(); 