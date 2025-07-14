/**
 * Система мониторинга и метрик
 * Этап 6.3: Система логирования и мониторинга
 */

import { EventEmitter } from 'events';
import { log } from '@/utils/logger';
// import { config } from '@/config'; // Временно не используется

export interface Metric {
  name: string;
  value: number;
  type: 'counter' | 'gauge' | 'histogram' | 'timer';
  tags?: Record<string, string>;
  timestamp: Date;
}

export interface Counter {
  name: string;
  value: number;
  increment(value?: number): void;
  reset(): void;
}

export interface Gauge {
  name: string;
  value: number;
  set(value: number): void;
  increment(value?: number): void;
  decrement(value?: number): void;
}

export interface Timer {
  name: string;
  start(): () => number; // Returns duration in ms
  record(duration: number): void;
  getStats(): {
    count: number;
    min: number;
    max: number;
    avg: number;
    p95: number;
    p99: number;
  };
}

export interface HealthCheckResult {
  name: string;
  status: 'healthy' | 'unhealthy' | 'degraded';
  message?: string;
  duration: number;
  timestamp: Date;
  details?: Record<string, any>;
}

export interface SystemMetrics {
  // System metrics
  uptime: number;
  memoryUsage: NodeJS.MemoryUsage;
  cpuUsage: NodeJS.CpuUsage;
  
  // Application metrics
  totalRequests: number;
  activeConnections: number;
  errorRate: number;
  responseTime: number;
  
  // Dialer metrics
  activeCalls: number;
  totalCallsToday: number;
  successfulCallsToday: number;
  failedCallsToday: number;
  callsPerMinute: number;
  avgCallDuration: number;
  
  // Campaign metrics
  activeCampaigns: number;
  totalCampaigns: number;
  completedCampaigns: number;
  
  // Database metrics
  activeDbConnections: number;
  queryCount: number;
  slowQueries: number;
  
  timestamp: Date;
}

export class MonitoringService extends EventEmitter {
  private static instance: MonitoringService;
  
  private counters = new Map<string, Counter>();
  private gauges = new Map<string, Gauge>();
  private timers = new Map<string, Timer>();
  private healthChecks = new Map<string, () => Promise<HealthCheckResult>>();
  
  private metricsHistory: Metric[] = [];
  private maxHistorySize = 10000;
  private isRunning = false;
  private collectInterval?: NodeJS.Timeout;
  
  // Performance tracking
  private requestCount = 0;
  private errorCount = 0;
  private responseTimeSum = 0;
  private lastResetTime = new Date();
  
  private constructor() {
    super();
    this.initializeDefaultMetrics();
  }

  static getInstance(): MonitoringService {
    if (!MonitoringService.instance) {
      MonitoringService.instance = new MonitoringService();
    }
    return MonitoringService.instance;
  }

  /**
   * Инициализация базовых метрик
   */
  private initializeDefaultMetrics(): void {
    // Счетчики
    this.createCounter('http_requests_total', 'Общее количество HTTP запросов');
    this.createCounter('http_errors_total', 'Общее количество HTTP ошибок');
    this.createCounter('calls_total', 'Общее количество звонков');
    this.createCounter('calls_successful', 'Успешные звонки');
    this.createCounter('calls_failed', 'Неуспешные звонки');
    this.createCounter('leads_created', 'Созданные лиды в Bitrix24');
    this.createCounter('webhook_deliveries', 'Доставки webhook');
    this.createCounter('blacklist_blocks', 'Блокировки по черному списку');
    
    // Gauge метрики
    this.createGauge('active_calls', 'Активные звонки');
    this.createGauge('active_campaigns', 'Активные кампании');
    this.createGauge('memory_usage_mb', 'Использование памяти (MB)');
    this.createGauge('cpu_usage_percent', 'Использование CPU (%)');
    this.createGauge('database_connections', 'Активные подключения к БД');
    
    // Таймеры
    this.createTimer('http_request_duration', 'Время выполнения HTTP запросов');
    this.createTimer('database_query_duration', 'Время выполнения SQL запросов');
    this.createTimer('call_duration', 'Длительность звонков');
    this.createTimer('webhook_delivery_duration', 'Время доставки webhook');
  }

  /**
   * Запуск мониторинга
   */
  start(): void {
    if (this.isRunning) {
      return;
    }

    this.isRunning = true;
    this.startMetricsCollection();
    this.registerHealthChecks();
    
    log.info('Система мониторинга запущена');
    this.emit('monitoring:started');
  }

  /**
   * Остановка мониторинга
   */
  stop(): void {
    if (!this.isRunning) {
      return;
    }

    this.isRunning = false;
    
    if (this.collectInterval) {
      clearInterval(this.collectInterval);
    }
    
    log.info('Система мониторинга остановлена');
    this.emit('monitoring:stopped');
  }

  /**
   * Создание счетчика
   */
  createCounter(name: string, description?: string): Counter {
    const counter: Counter = {
      name,
      value: 0,
      increment(value = 1) {
        this.value += value;
      },
      reset() {
        this.value = 0;
      }
    };

    this.counters.set(name, counter);
    
    if (description) {
      log.debug(`Создан счетчик: ${name} - ${description}`);
    }
    
    return counter;
  }

  /**
   * Создание gauge метрики
   */
  createGauge(name: string, description?: string): Gauge {
    const gauge: Gauge = {
      name,
      value: 0,
      set(value: number) {
        this.value = value;
      },
      increment(value = 1) {
        this.value += value;
      },
      decrement(value = 1) {
        this.value -= value;
      }
    };

    this.gauges.set(name, gauge);
    
    if (description) {
      log.debug(`Создан gauge: ${name} - ${description}`);
    }
    
    return gauge;
  }

  /**
   * Создание таймера
   */
  createTimer(name: string, description?: string): Timer {
    const measurements: number[] = [];
    
    const timer: Timer = {
      name,
      start() {
        const startTime = Date.now();
        return () => {
          const duration = Date.now() - startTime;
          timer.record(duration);
          return duration;
        };
      },
      record(duration: number) {
        measurements.push(duration);
        // Ограничиваем размер массива для экономии памяти
        if (measurements.length > 1000) {
          measurements.shift();
        }
      },
      getStats() {
        if (measurements.length === 0) {
          return { count: 0, min: 0, max: 0, avg: 0, p95: 0, p99: 0 };
        }
        
        const sorted = [...measurements].sort((a, b) => a - b);
        const count = sorted.length;
        const min = sorted[0] || 0;
        const max = sorted[count - 1] || 0;
        const avg = sorted.reduce((sum, val) => sum + val, 0) / count;
        const p95 = sorted[Math.floor(count * 0.95)] || 0;
        const p99 = sorted[Math.floor(count * 0.99)] || 0;
        
        return { count, min, max, avg, p95, p99 };
      }
    };

    this.timers.set(name, timer);
    
    if (description) {
      log.debug(`Создан таймер: ${name} - ${description}`);
    }
    
    return timer;
  }

  /**
   * Получение метрики по имени
   */
  getCounter(name: string): Counter | undefined {
    return this.counters.get(name);
  }

  getGauge(name: string): Gauge | undefined {
    return this.gauges.get(name);
  }

  getTimer(name: string): Timer | undefined {
    return this.timers.get(name);
  }

  /**
   * Запись метрики в историю
   */
  recordMetric(metric: Omit<Metric, 'timestamp'>): void {
    const fullMetric: Metric = {
      ...metric,
      timestamp: new Date()
    };

    this.metricsHistory.push(fullMetric);
    
    // Ограничиваем размер истории
    if (this.metricsHistory.length > this.maxHistorySize) {
      this.metricsHistory.shift();
    }

    this.emit('metric:recorded', fullMetric);
  }

  /**
   * Отслеживание HTTP запроса
   */
  trackHttpRequest(duration: number, statusCode: number): void {
    const requestsCounter = this.getCounter('http_requests_total');
    const errorsCounter = this.getCounter('http_errors_total');
    const durationTimer = this.getTimer('http_request_duration');
    
    requestsCounter?.increment();
    durationTimer?.record(duration);
    
    if (statusCode >= 400) {
      errorsCounter?.increment();
    }
    
    // Обновляем внутренние счетчики для расчета метрик
    this.requestCount++;
    this.responseTimeSum += duration;
    
    if (statusCode >= 500) {
      this.errorCount++;
    }
  }

  /**
   * Отслеживание звонка
   */
  trackCall(duration: number, status: 'successful' | 'failed'): void {
    const totalCounter = this.getCounter('calls_total');
    const successCounter = this.getCounter('calls_successful');
    const failedCounter = this.getCounter('calls_failed');
    const durationTimer = this.getTimer('call_duration');
    
    totalCounter?.increment();
    durationTimer?.record(duration);
    
    if (status === 'successful') {
      successCounter?.increment();
    } else {
      failedCounter?.increment();
    }
  }

  /**
   * Отслеживание создания лида
   */
  trackLeadCreated(): void {
    const counter = this.getCounter('leads_created');
    counter?.increment();
  }

  /**
   * Отслеживание доставки webhook
   */
  trackWebhookDelivery(duration: number, _success: boolean): void {
    const counter = this.getCounter('webhook_deliveries');
    const timer = this.getTimer('webhook_delivery_duration');
    
    counter?.increment();
    timer?.record(duration);
  }

  /**
   * Отслеживание блокировки по черному списку
   */
  trackBlacklistBlock(): void {
    const counter = this.getCounter('blacklist_blocks');
    counter?.increment();
  }

  /**
   * Регистрация health check
   */
  registerHealthCheck(name: string, check: () => Promise<HealthCheckResult>): void {
    this.healthChecks.set(name, check);
    log.debug(`Зарегистрирован health check: ${name}`);
  }

  /**
   * Выполнение всех health checks
   */
  async runHealthChecks(): Promise<HealthCheckResult[]> {
    const results: HealthCheckResult[] = [];
    
    for (const [name, check] of this.healthChecks) {
      try {
        const result = await check();
        results.push(result);
      } catch (error) {
        results.push({
          name,
          status: 'unhealthy',
          message: `Health check failed: ${error}`,
          duration: 0,
          timestamp: new Date()
        });
      }
    }
    
    return results;
  }

  /**
   * Получение системных метрик
   */
  async getSystemMetrics(): Promise<SystemMetrics> {
    const memUsage = process.memoryUsage();
    const cpuUsage = process.cpuUsage();
    
    // Расчет производительности
    const timeSinceReset = Date.now() - this.lastResetTime.getTime();
    const requestsPerSecond = this.requestCount / (timeSinceReset / 1000);
    const avgResponseTime = this.requestCount > 0 ? this.responseTimeSum / this.requestCount : 0;
    const errorRate = this.requestCount > 0 ? (this.errorCount / this.requestCount) * 100 : 0;

    return {
      uptime: process.uptime(),
      memoryUsage: memUsage,
      cpuUsage,
      
      totalRequests: this.requestCount,
      activeConnections: 0, // Будет обновлено из других сервисов
      errorRate,
      responseTime: avgResponseTime,
      
      activeCalls: this.getGauge('active_calls')?.value || 0,
      totalCallsToday: this.getCounter('calls_total')?.value || 0,
      successfulCallsToday: this.getCounter('calls_successful')?.value || 0,
      failedCallsToday: this.getCounter('calls_failed')?.value || 0,
      callsPerMinute: requestsPerSecond * 60, // Примерный расчет
      avgCallDuration: this.getTimer('call_duration')?.getStats().avg || 0,
      
      activeCampaigns: this.getGauge('active_campaigns')?.value || 0,
      totalCampaigns: 0, // Будет обновлено из campaign service
      completedCampaigns: 0,
      
      activeDbConnections: 0, // Будет обновлено из database service
      queryCount: 0, // Будет обновлено из database service
      slowQueries: 0,
      
      timestamp: new Date()
    };
  }

  /**
   * Получение истории метрик
   */
  getMetricsHistory(since?: Date): Metric[] {
    if (!since) {
      return [...this.metricsHistory];
    }
    
    return this.metricsHistory.filter(metric => metric.timestamp >= since);
  }

  /**
   * Сброс всех метрик
   */
  reset(): void {
    this.counters.forEach(counter => counter.reset());
    this.gauges.forEach(gauge => gauge.set(0));
    this.metricsHistory = [];
    this.requestCount = 0;
    this.errorCount = 0;
    this.responseTimeSum = 0;
    this.lastResetTime = new Date();
    
    log.info('Метрики мониторинга сброшены');
  }

  /**
   * Запуск сбора метрик
   */
  private startMetricsCollection(): void {
    this.collectInterval = setInterval(async () => {
      try {
        await this.collectSystemMetrics();
      } catch (error) {
        log.error('Ошибка сбора системных метрик:', error);
      }
    }, 30000); // Каждые 30 секунд
  }

  /**
   * Сбор системных метрик
   */
  private async collectSystemMetrics(): Promise<void> {
    const memUsage = process.memoryUsage();
    const memoryGauge = this.getGauge('memory_usage_mb');
    
    if (memoryGauge) {
      memoryGauge.set(Math.round(memUsage.heapUsed / 1024 / 1024));
    }

    // Запись в историю для дальнейшего анализа
    this.recordMetric({
      name: 'system_memory_heap_used',
      value: memUsage.heapUsed,
      type: 'gauge'
    });

    this.recordMetric({
      name: 'system_uptime',
      value: process.uptime(),
      type: 'gauge'
    });
  }

  /**
   * Регистрация базовых health checks
   */
  private registerHealthChecks(): void {
    // Health check для памяти
    this.registerHealthCheck('memory', async (): Promise<HealthCheckResult> => {
      const start = Date.now();
      const memUsage = process.memoryUsage();
      const memoryUsageMB = memUsage.heapUsed / 1024 / 1024;
      const maxMemoryMB = 512; // Лимит в MB
      
      const status = memoryUsageMB > maxMemoryMB ? 'unhealthy' : 'healthy';
      const message = `Memory usage: ${memoryUsageMB.toFixed(2)}MB / ${maxMemoryMB}MB`;
      
      return {
        name: 'memory',
        status,
        message,
        duration: Date.now() - start,
        timestamp: new Date(),
        details: {
          heapUsed: memUsage.heapUsed,
          heapTotal: memUsage.heapTotal,
          external: memUsage.external,
          rss: memUsage.rss
        }
      };
    });

    // Health check для uptime
    this.registerHealthCheck('uptime', async (): Promise<HealthCheckResult> => {
      const start = Date.now();
      const uptime = process.uptime();
      
      return {
        name: 'uptime',
        status: 'healthy',
        message: `Uptime: ${Math.floor(uptime / 3600)}h ${Math.floor((uptime % 3600) / 60)}m`,
        duration: Date.now() - start,
        timestamp: new Date(),
        details: { uptime }
      };
    });
  }

  /**
   * Получение статуса мониторинга
   */
  getStatus(): {
    isRunning: boolean;
    counters: number;
    gauges: number;
    timers: number;
    healthChecks: number;
    metricsInHistory: number;
  } {
    return {
      isRunning: this.isRunning,
      counters: this.counters.size,
      gauges: this.gauges.size,
      timers: this.timers.size,
      healthChecks: this.healthChecks.size,
      metricsInHistory: this.metricsHistory.length
    };
  }
}

// Экспорт singleton instance
export const monitoringService = MonitoringService.getInstance(); 