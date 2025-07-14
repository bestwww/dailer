/**
 * Middleware для мониторинга HTTP запросов
 * Этап 6.3: Система логирования и мониторинга
 */

import { Request, Response, NextFunction } from 'express';
import { monitoringService } from '@/services/monitoring';
import { log } from '@/utils/logger';

// Расширяем типы Express для добавления данных мониторинга
declare global {
  namespace Express {
    interface Request {
      startTime?: number;
      requestId?: string;
    }
  }
}

/**
 * Middleware для отслеживания производительности HTTP запросов
 */
export function httpMetricsMiddleware(req: Request, res: Response, next: NextFunction): void {
  // Запоминаем время начала запроса
  req.startTime = Date.now();
  
  // Генерируем уникальный ID запроса для correlation
  req.requestId = generateRequestId();
  
  // Добавляем ID в заголовки ответа
  res.setHeader('X-Request-ID', req.requestId);

  // Перехватываем завершение ответа
  const originalSend = res.send;
  res.send = function(data) {
    // Вычисляем время выполнения
    const duration = Date.now() - (req.startTime || Date.now());
    
    // Отслеживаем метрики
    monitoringService.trackHttpRequest(duration, res.statusCode);
    
    // Логируем запрос
    logHttpRequest(req, res, duration);
    
    // Обновляем gauge активных подключений
    const activeConnectionsGauge = monitoringService.getGauge('active_connections');
    if (activeConnectionsGauge) {
      activeConnectionsGauge.decrement();
    }
    
    // Вызываем оригинальный метод send
    return originalSend.call(this, data);
  };

  // Увеличиваем счетчик активных подключений
  const activeConnectionsGauge = monitoringService.getGauge('active_connections');
  if (activeConnectionsGauge) {
    activeConnectionsGauge.increment();
  }

  next();
}

/**
 * Middleware для отслеживания медленных запросов
 */
export function slowRequestMiddleware(thresholdMs: number = 5000) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const startTime = Date.now();
    
    const originalSend = res.send;
    res.send = function(data) {
      const duration = Date.now() - startTime;
      
      if (duration > thresholdMs) {
        log.performance(`Медленный запрос: ${req.method} ${req.path}`, duration, {
          method: req.method,
          path: req.path,
          duration,
          statusCode: res.statusCode,
          userAgent: req.get('User-Agent'),
          ip: req.ip,
          requestId: req.requestId
        });
      }
      
      return originalSend.call(this, data);
    };

    next();
  };
}

/**
 * Middleware для отслеживания ошибок
 */
export function errorTrackingMiddleware(error: any, req: Request, res: Response, next: NextFunction): void {
  // Увеличиваем счетчик ошибок
  const errorsCounter = monitoringService.getCounter('http_errors_total');
  errorsCounter?.increment();

  // Логируем ошибку с контекстом
  log.error('HTTP Error:', {
    error: error.message,
    stack: error.stack,
    method: req.method,
    path: req.path,
    statusCode: res.statusCode,
    requestId: req.requestId,
    userAgent: req.get('User-Agent'),
    ip: req.ip,
    body: req.body,
    query: req.query
  });

  // Записываем метрику ошибки
  monitoringService.recordMetric({
    name: 'http_error_occurred',
    value: 1,
    type: 'counter',
    tags: {
      method: req.method,
      path: req.path,
      statusCode: res.statusCode.toString(),
      errorType: error.constructor.name
    }
  });

  next(error);
}

/**
 * Middleware для добавления correlation ID
 */
export function correlationMiddleware(req: Request, res: Response, next: NextFunction): void {
  // Используем существующий X-Request-ID или создаем новый
  const correlationId = req.get('X-Request-ID') || req.requestId || generateRequestId();
  
  req.requestId = correlationId;
  res.setHeader('X-Request-ID', correlationId);
  
  // Добавляем в контекст логирования
  (req as any).logContext = {
    requestId: correlationId,
    method: req.method,
    path: req.path,
    ip: req.ip,
    userAgent: req.get('User-Agent')
  };

  next();
}

/**
 * Middleware для отслеживания размера запросов/ответов
 */
export function sizeTrackingMiddleware(req: Request, res: Response, next: NextFunction): void {
  // Отслеживаем размер входящего запроса
  const requestSize = parseInt(req.get('Content-Length') || '0');
  
  if (requestSize > 0) {
    monitoringService.recordMetric({
      name: 'http_request_size_bytes',
      value: requestSize,
      type: 'histogram',
      tags: {
        method: req.method,
        path: req.path
      }
    });
  }

  // Перехватываем ответ для измерения размера
  const originalSend = res.send;
  res.send = function(data) {
    const responseSize = Buffer.byteLength(data || '', 'utf8');
    
    monitoringService.recordMetric({
      name: 'http_response_size_bytes',
      value: responseSize,
      type: 'histogram',
      tags: {
        method: req.method,
        path: req.path,
        statusCode: res.statusCode.toString()
      }
    });
    
    return originalSend.call(this, data);
  };

  next();
}

/**
 * Middleware для rate limiting мониторинга
 */
export function rateLimitMonitoringMiddleware(req: Request, res: Response, next: NextFunction): void {
  // Проверяем заголовки rate limiting
  const rateLimit = res.get('X-RateLimit-Limit');
  const rateLimitRemaining = res.get('X-RateLimit-Remaining');
  
  if (rateLimit && rateLimitRemaining) {
    const limit = parseInt(rateLimit);
    const remaining = parseInt(rateLimitRemaining);
    const used = limit - remaining;
    
    monitoringService.recordMetric({
      name: 'rate_limit_usage',
      value: (used / limit) * 100, // Процент использования
      type: 'gauge',
      tags: {
        endpoint: req.path,
        ip: req.ip || 'unknown'
      }
    });

    // Алерт при высоком использовании rate limit
    if ((used / limit) > 0.9) {
      log.warn('Высокое использование rate limit', {
        endpoint: req.path,
        ip: req.ip,
        used,
        limit,
        remaining,
        usagePercent: (used / limit) * 100
      });
    }
  }

  next();
}

/**
 * Middleware для мониторинга безопасности
 */
export function securityMonitoringMiddleware(req: Request, _res: Response, next: NextFunction): void {
  // Отслеживаем подозрительные паттерны
  const suspiciousPatterns = [
    /\.\./,  // Directory traversal
    /<script>/i,  // XSS
    /union.*select/i,  // SQL injection
    /eval\(/i,  // Code injection
  ];

  const url = req.url.toLowerCase();
  const body = JSON.stringify(req.body || '').toLowerCase();
  
  for (const pattern of suspiciousPatterns) {
    if (pattern.test(url) || pattern.test(body)) {
      log.security.suspiciousActivity('Подозрительный запрос обнаружен', {
        pattern: pattern.toString(),
        url: req.url,
        method: req.method,
        ip: req.ip,
        userAgent: req.get('User-Agent'),
        requestId: req.requestId
      });

      monitoringService.recordMetric({
        name: 'security_suspicious_request',
        value: 1,
        type: 'counter',
               tags: {
         pattern: pattern.toString(),
         method: req.method,
         ip: req.ip || 'unknown'
       }
      });
      
      break;
    }
  }

  next();
}

/**
 * Логирование HTTP запроса
 */
function logHttpRequest(req: Request, res: Response, duration: number): void {
  const level = res.statusCode >= 500 ? 'error' : res.statusCode >= 400 ? 'warn' : 'info';
  
  const logData = {
    method: req.method,
    path: req.path,
    statusCode: res.statusCode,
    duration,
    ip: req.ip,
    userAgent: req.get('User-Agent'),
    requestId: req.requestId,
    contentLength: res.get('Content-Length'),
    referer: req.get('Referer')
  };

  log[level](`${req.method} ${req.path} ${res.statusCode} ${duration}ms`, logData);
}

/**
 * Генерация уникального ID запроса
 */
function generateRequestId(): string {
  const timestamp = Date.now().toString(36);
  const random = Math.random().toString(36).substr(2, 9);
  return `req_${timestamp}_${random}`;
}

/**
 * Middleware для health check endpoints (исключаем из метрик)
 */
export function healthCheckExclusionMiddleware(req: Request, _res: Response, next: NextFunction): void {
  // Исключаем health check endpoints из обычного мониторинга
  if (req.path === '/api/monitoring/health/simple' || req.path === '/health') {
    // Помечаем запрос как health check
    (req as any).isHealthCheck = true;
  }

  next();
}

/**
 * Middleware для создания контекста мониторинга
 */
export function monitoringContextMiddleware(req: Request, _res: Response, next: NextFunction): void {
  // Создаем контекст мониторинга для запроса
  (req as any).monitoring = {
    startTime: Date.now(),
    metrics: new Map(),
    
    // Метод для записи кастомной метрики
    recordMetric(name: string, value: number, type: 'counter' | 'gauge' | 'timer' = 'gauge') {
      monitoringService.recordMetric({
        name: `request_${name}`,
        value,
        type,
        tags: {
          method: req.method,
          path: req.path,
          requestId: req.requestId || 'unknown'
        }
      });
    },

    // Метод для засечения времени операции
    timeOperation(name: string) {
      const startTime = Date.now();
      return () => {
        const duration = Date.now() - startTime;
        this.recordMetric(`${name}_duration`, duration, 'timer');
        return duration;
      };
    }
  };

  next();
}

/**
 * Экспорт всех middleware функций
 */
export const monitoringMiddleware = {
  httpMetrics: httpMetricsMiddleware,
  slowRequest: slowRequestMiddleware,
  errorTracking: errorTrackingMiddleware,
  correlation: correlationMiddleware,
  sizeTracking: sizeTrackingMiddleware,
  rateLimitMonitoring: rateLimitMonitoringMiddleware,
  securityMonitoring: securityMonitoringMiddleware,
  healthCheckExclusion: healthCheckExclusionMiddleware,
  monitoringContext: monitoringContextMiddleware
}; 