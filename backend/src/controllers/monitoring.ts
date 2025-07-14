/**
 * Контроллер мониторинга - API для метрик, health checks и алертов
 * Этап 6.3: Система логирования и мониторинга
 */

import { Request, Response } from 'express';
import { monitoringService } from '@/services/monitoring';
import { alertingService } from '@/services/alerting';
import { dialerService } from '@/services/dialer';
import { campaignModel } from '@/models/campaign';
import { log } from '@/utils/logger';
import { ApiResponse } from '@/types';

/**
 * Получение общих метрик системы
 * GET /api/monitoring/metrics
 */
export async function getSystemMetrics(_req: Request, res: Response): Promise<void> {
  try {
    const metrics = await monitoringService.getSystemMetrics();
    
    // Дополняем метриками из диалера
    const dialerStats = dialerService.getStats();
    const activeCampaigns = await campaignModel.getActiveCampaigns();
    
    const enhancedMetrics = {
      ...metrics,
      activeCalls: dialerStats.activeCalls,
      totalCallsToday: dialerStats.totalCallsToday,
      successfulCallsToday: dialerStats.successfulCallsToday,
      failedCallsToday: dialerStats.failedCallsToday,
      callsPerMinute: dialerStats.callsPerMinute,
      activeCampaigns: dialerStats.activeCampaigns,
      totalCampaigns: activeCampaigns.length
    };

    res.json({
      success: true,
      data: enhancedMetrics,
      message: 'Системные метрики получены успешно'
    } as ApiResponse);
  } catch (error) {
    log.error('Ошибка получения системных метрик:', error);
    res.status(500).json({
      success: false,
      error: 'Ошибка получения системных метрик'
    } as ApiResponse);
  }
}

/**
 * Получение конкретных метрик по именам
 * GET /api/monitoring/metrics/:names
 */
export async function getSpecificMetrics(req: Request, res: Response): Promise<void> {
  try {
    const { names } = req.params;
    if (!names) {
      res.status(400).json({
        success: false,
        error: 'Параметр names не указан'
      });
      return;
    }
    const metricNames = names.split(',');
    
    const metrics: any = {};
    
    for (const name of metricNames) {
      const counter = monitoringService.getCounter(name);
      const gauge = monitoringService.getGauge(name);
      const timer = monitoringService.getTimer(name);
      
      if (counter) {
        metrics[name] = { type: 'counter', value: counter.value };
      } else if (gauge) {
        metrics[name] = { type: 'gauge', value: gauge.value };
      } else if (timer) {
        metrics[name] = { type: 'timer', stats: timer.getStats() };
      } else {
        metrics[name] = { type: 'unknown', value: null };
      }
    }

    res.json({
      success: true,
      data: metrics,
      message: 'Метрики получены успешно'
    } as ApiResponse);
  } catch (error) {
    log.error('Ошибка получения конкретных метрик:', error);
    res.status(500).json({
      success: false,
      error: 'Ошибка получения метрик'
    } as ApiResponse);
  }
}

/**
 * Получение истории метрик
 * GET /api/monitoring/metrics/history
 */
export async function getMetricsHistory(req: Request, res: Response): Promise<void> {
  try {
    const { since, limit } = req.query;
    
    let sinceDate: Date | undefined;
    if (since) {
      sinceDate = new Date(since as string);
      if (isNaN(sinceDate.getTime())) {
        res.status(400).json({
          success: false,
          error: 'Некорректная дата в параметре since'
        } as ApiResponse);
        return;
      }
    }

    let history = monitoringService.getMetricsHistory(sinceDate);
    
    if (limit) {
      const limitNum = parseInt(limit as string);
      if (!isNaN(limitNum) && limitNum > 0) {
        history = history.slice(-limitNum);
      }
    }

    res.json({
      success: true,
      data: {
        metrics: history,
        count: history.length
      },
      message: 'История метрик получена успешно'
    } as ApiResponse);
  } catch (error) {
    log.error('Ошибка получения истории метрик:', error);
    res.status(500).json({
      success: false,
      error: 'Ошибка получения истории метрик'
    } as ApiResponse);
  }
}

/**
 * Выполнение health checks
 * GET /api/monitoring/health
 */
export async function runHealthChecks(_req: Request, res: Response): Promise<void> {
  try {
    const healthResults = await monitoringService.runHealthChecks();
    
    const overallStatus = healthResults.every(result => result.status === 'healthy') 
      ? 'healthy' 
      : healthResults.some(result => result.status === 'unhealthy')
      ? 'unhealthy'
      : 'degraded';

    // Устанавливаем соответствующий HTTP статус
    const httpStatus = overallStatus === 'healthy' ? 200 : overallStatus === 'degraded' ? 207 : 503;

    res.status(httpStatus).json({
      success: overallStatus !== 'unhealthy',
      data: {
        status: overallStatus,
        checks: healthResults,
        timestamp: new Date().toISOString()
      },
      message: `Система ${overallStatus === 'healthy' ? 'здорова' : overallStatus === 'degraded' ? 'частично работает' : 'неисправна'}`
    } as ApiResponse);
  } catch (error) {
    log.error('Ошибка выполнения health checks:', error);
    res.status(500).json({
      success: false,
      error: 'Ошибка выполнения health checks'
    } as ApiResponse);
  }
}

/**
 * Простой health check endpoint (для load balancers)
 * GET /api/monitoring/health/simple
 */
export async function simpleHealthCheck(_req: Request, res: Response): Promise<void> {
  try {
    const memUsage = process.memoryUsage();
    const memUsageMB = memUsage.heapUsed / 1024 / 1024;
    const uptime = process.uptime();
    
    // Простые проверки
    const isHealthy = memUsageMB < 1024 && uptime > 0; // Память < 1GB и система работает
    
    if (isHealthy) {
      res.status(200).json({
        status: 'OK',
        uptime: Math.floor(uptime),
        memory: Math.round(memUsageMB)
      });
    } else {
      res.status(503).json({
        status: 'UNHEALTHY',
        uptime: Math.floor(uptime),
        memory: Math.round(memUsageMB)
      });
    }
  } catch (error) {
    res.status(500).json({
      status: 'ERROR',
      error: 'Internal server error'
    });
  }
}

/**
 * Получение всех алертов
 * GET /api/monitoring/alerts
 */
export async function getAlerts(req: Request, res: Response): Promise<void> {
  try {
    const { level, resolved, limit } = req.query;
    
    const options: any = {};
    
    if (level && ['info', 'warning', 'error', 'critical'].includes(level as string)) {
      options.level = level as string;
    }
    
    if (resolved !== undefined) {
      options.resolved = resolved === 'true';
    }
    
    if (limit) {
      const limitNum = parseInt(limit as string);
      if (!isNaN(limitNum) && limitNum > 0) {
        options.limit = limitNum;
      }
    }

    const alerts = alertingService.getAlerts(options);
    const stats = alertingService.getAlertStats();

    res.json({
      success: true,
      data: {
        alerts,
        stats,
        count: alerts.length
      },
      message: 'Алерты получены успешно'
    } as ApiResponse);
  } catch (error) {
    log.error('Ошибка получения алертов:', error);
    res.status(500).json({
      success: false,
      error: 'Ошибка получения алертов'
    } as ApiResponse);
  }
}

/**
 * Получение активных алертов
 * GET /api/monitoring/alerts/active
 */
export async function getActiveAlerts(_req: Request, res: Response): Promise<void> {
  try {
    const activeAlerts = alertingService.getActiveAlerts();
    const stats = alertingService.getAlertStats();

    res.json({
      success: true,
      data: {
        alerts: activeAlerts,
        count: activeAlerts.length,
        stats
      },
      message: 'Активные алерты получены успешно'
    } as ApiResponse);
  } catch (error) {
    log.error('Ошибка получения активных алертов:', error);
    res.status(500).json({
      success: false,
      error: 'Ошибка получения активных алертов'
    } as ApiResponse);
  }
}

/**
 * Подтверждение алерта
 * POST /api/monitoring/alerts/:id/acknowledge
 */
export async function acknowledgeAlert(req: Request, res: Response): Promise<void> {
  try {
    const { id } = req.params;
    const { acknowledgedBy } = req.body;

    if (!id) {
      res.status(400).json({
        success: false,
        error: 'ID алерта не указан'
      } as ApiResponse);
      return;
    }

    if (!acknowledgedBy) {
      res.status(400).json({
        success: false,
        error: 'Необходимо указать пользователя (acknowledgedBy)'
      } as ApiResponse);
      return;
    }

    const success = alertingService.acknowledgeAlert(id, acknowledgedBy);

    if (success) {
      res.json({
        success: true,
        message: 'Алерт подтвержден успешно'
      } as ApiResponse);
    } else {
      res.status(404).json({
        success: false,
        error: 'Алерт не найден'
      } as ApiResponse);
    }
  } catch (error) {
    log.error('Ошибка подтверждения алерта:', error);
    res.status(500).json({
      success: false,
      error: 'Ошибка подтверждения алерта'
    } as ApiResponse);
  }
}

/**
 * Разрешение алерта
 * POST /api/monitoring/alerts/:id/resolve
 */
export async function resolveAlert(req: Request, res: Response): Promise<void> {
  try {
    const { id } = req.params;

    if (!id) {
      res.status(400).json({
        success: false,
        error: 'ID алерта не указан'
      } as ApiResponse);
      return;
    }

    const success = alertingService.resolveAlert(id);

    if (success) {
      res.json({
        success: true,
        message: 'Алерт разрешен успешно'
      } as ApiResponse);
    } else {
      res.status(404).json({
        success: false,
        error: 'Алерт не найден'
      } as ApiResponse);
    }
  } catch (error) {
    log.error('Ошибка разрешения алерта:', error);
    res.status(500).json({
      success: false,
      error: 'Ошибка разрешения алерта'
    } as ApiResponse);
  }
}

/**
 * Создание пользовательского алерта
 * POST /api/monitoring/alerts
 */
export async function createAlert(req: Request, res: Response): Promise<void> {
  try {
    const { name, level, message, details } = req.body;

    if (!name || !level || !message) {
      res.status(400).json({
        success: false,
        error: 'Необходимы параметры: name, level, message'
      } as ApiResponse);
      return;
    }

    if (!['info', 'warning', 'error', 'critical'].includes(level)) {
      res.status(400).json({
        success: false,
        error: 'level должен быть одним из: info, warning, error, critical'
      } as ApiResponse);
      return;
    }

    const alert = alertingService.createAlert(name, level, message, details);

    res.status(201).json({
      success: true,
      data: alert,
      message: 'Алерт создан успешно'
    } as ApiResponse);
  } catch (error) {
    log.error('Ошибка создания алерта:', error);
    res.status(500).json({
      success: false,
      error: 'Ошибка создания алерта'
    } as ApiResponse);
  }
}

/**
 * Получение статистики производительности
 * GET /api/monitoring/performance
 */
export async function getPerformanceStats(_req: Request, res: Response): Promise<void> {
  try {
    // Получаем статистику таймеров
    const httpTimer = monitoringService.getTimer('http_request_duration');
    const dbTimer = monitoringService.getTimer('database_query_duration');
    const callTimer = monitoringService.getTimer('call_duration');
    const webhookTimer = monitoringService.getTimer('webhook_delivery_duration');

    const performance = {
      http: httpTimer?.getStats() || { count: 0, min: 0, max: 0, avg: 0, p95: 0, p99: 0 },
      database: dbTimer?.getStats() || { count: 0, min: 0, max: 0, avg: 0, p95: 0, p99: 0 },
      calls: callTimer?.getStats() || { count: 0, min: 0, max: 0, avg: 0, p95: 0, p99: 0 },
      webhooks: webhookTimer?.getStats() || { count: 0, min: 0, max: 0, avg: 0, p95: 0, p99: 0 }
    };

    res.json({
      success: true,
      data: performance,
      message: 'Статистика производительности получена успешно'
    } as ApiResponse);
  } catch (error) {
    log.error('Ошибка получения статистики производительности:', error);
    res.status(500).json({
      success: false,
      error: 'Ошибка получения статистики производительности'
    } as ApiResponse);
  }
}

/**
 * Сброс метрик
 * POST /api/monitoring/metrics/reset
 */
export async function resetMetrics(_req: Request, res: Response): Promise<void> {
  try {
    monitoringService.reset();
    
    log.info('Метрики мониторинга сброшены через API');

    res.json({
      success: true,
      message: 'Метрики сброшены успешно'
    } as ApiResponse);
  } catch (error) {
    log.error('Ошибка сброса метрик:', error);
    res.status(500).json({
      success: false,
      error: 'Ошибка сброса метрик'
    } as ApiResponse);
  }
}

/**
 * Получение статуса системы мониторинга
 * GET /api/monitoring/status
 */
export async function getMonitoringStatus(_req: Request, res: Response): Promise<void> {
  try {
    const monitoringStatus = monitoringService.getStatus();
    const alertingStatus = alertingService.getStatus();
    const dialerStatus = dialerService.getStatus();

    const status = {
      monitoring: monitoringStatus,
      alerting: alertingStatus,
      dialer: dialerStatus,
      timestamp: new Date().toISOString()
    };

    res.json({
      success: true,
      data: status,
      message: 'Статус системы мониторинга получен успешно'
    } as ApiResponse);
  } catch (error) {
    log.error('Ошибка получения статуса мониторинга:', error);
    res.status(500).json({
      success: false,
      error: 'Ошибка получения статуса мониторинга'
    } as ApiResponse);
  }
}

/**
 * Экспорт метрик в формате Prometheus
 * GET /api/monitoring/metrics/prometheus
 */
export async function exportPrometheusMetrics(_req: Request, res: Response): Promise<void> {
  try {
    const metrics = await monitoringService.getSystemMetrics();
    const dialerStats = dialerService.getStats();
    
    // Генерируем метрики в формате Prometheus
    let prometheusOutput = '';
    
    // Системные метрики
    prometheusOutput += `# HELP system_uptime_seconds System uptime in seconds\n`;
    prometheusOutput += `# TYPE system_uptime_seconds gauge\n`;
    prometheusOutput += `system_uptime_seconds ${metrics.uptime}\n\n`;
    
    prometheusOutput += `# HELP system_memory_heap_used_bytes Memory heap used in bytes\n`;
    prometheusOutput += `# TYPE system_memory_heap_used_bytes gauge\n`;
    prometheusOutput += `system_memory_heap_used_bytes ${metrics.memoryUsage.heapUsed}\n\n`;
    
    // HTTP метрики
    const requestsCounter = monitoringService.getCounter('http_requests_total');
    const errorsCounter = monitoringService.getCounter('http_errors_total');
    
    if (requestsCounter) {
      prometheusOutput += `# HELP http_requests_total Total HTTP requests\n`;
      prometheusOutput += `# TYPE http_requests_total counter\n`;
      prometheusOutput += `http_requests_total ${requestsCounter.value}\n\n`;
    }
    
    if (errorsCounter) {
      prometheusOutput += `# HELP http_errors_total Total HTTP errors\n`;
      prometheusOutput += `# TYPE http_errors_total counter\n`;
      prometheusOutput += `http_errors_total ${errorsCounter.value}\n\n`;
    }
    
    // Диалер метрики
    prometheusOutput += `# HELP dialer_active_calls Active calls count\n`;
    prometheusOutput += `# TYPE dialer_active_calls gauge\n`;
    prometheusOutput += `dialer_active_calls ${dialerStats.activeCalls}\n\n`;
    
    prometheusOutput += `# HELP dialer_calls_total Total calls made today\n`;
    prometheusOutput += `# TYPE dialer_calls_total counter\n`;
    prometheusOutput += `dialer_calls_total ${dialerStats.totalCallsToday}\n\n`;

    res.set('Content-Type', 'text/plain; charset=utf-8');
    res.send(prometheusOutput);
  } catch (error) {
    log.error('Ошибка экспорта метрик Prometheus:', error);
    res.status(500).send('# Error exporting metrics\n');
  }
} 