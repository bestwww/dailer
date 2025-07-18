/**
 * Система логирования на основе Winston
 */

const winston = require('winston');
const DailyRotateFile = require('winston-daily-rotate-file');
const path = require('path');

import { config, isDevelopment } from '@/config';

/**
 * Создание директории для логов
 */
function ensureLogDirectory(): string {
  const fs = require('fs');
  const logDir = path.dirname(config.logFilePath);
  
  if (!fs.existsSync(logDir)) {
    fs.mkdirSync(logDir, { recursive: true });
  }
  
  return logDir;
}

/**
 * Форматтер для логов
 */
const logFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.errors({ stack: true }),
  winston.format.printf((info: any) => {
    const { timestamp, level, message, ...meta } = info;
    let log = `${timestamp} [${level.toUpperCase()}]: ${message}`;
    
    if (Object.keys(meta).length > 0) {
      log += `\n${JSON.stringify(meta, null, 2)}`;
    }
    
    return log;
  })
);

/**
 * Форматтер для консоли в development режиме
 */
const consoleFormat = winston.format.combine(
  winston.format.colorize(),
  winston.format.timestamp({ format: 'HH:mm:ss' }),
  winston.format.printf((info: any) => {
    const { timestamp, level, message, ...meta } = info;
    let log = `${timestamp} ${level}: ${message}`;
    
    if (Object.keys(meta).length > 0) {
      log += `\n${JSON.stringify(meta, null, 2)}`;
    }
    
    return log;
  })
);

/**
 * Создание транспортов для логирования
 */
function createTransports(): any[] {
  const logDir = ensureLogDirectory();
  const transports: any[] = [];

  // Консольный вывод
  if (isDevelopment) {
    transports.push(
      new winston.transports.Console({
        level: config.logLevel,
        format: consoleFormat,
      })
    );
  }

  // Файл для всех логов с ротацией
  transports.push(
    new DailyRotateFile({
      filename: path.join(logDir, 'app-%DATE%.log'),
      datePattern: 'YYYY-MM-DD',
      maxSize: '20m',
      maxFiles: '14d',
      level: config.logLevel,
      format: logFormat,
    })
  );

  // Отдельный файл для ошибок
  transports.push(
    new DailyRotateFile({
      filename: path.join(logDir, 'error-%DATE%.log'),
      datePattern: 'YYYY-MM-DD',
      maxSize: '20m',
      maxFiles: '30d',
      level: 'error',
      format: logFormat,
    })
  );

  // Для production - отправка критических ошибок можно добавить Slack/Email транспорт
  if (!isDevelopment) {
    transports.push(
      new winston.transports.Console({
        level: 'error',
        format: winston.format.simple(),
      })
    );
  }

  return transports;
}

/**
 * Создание logger'а
 */
const logger = winston.createLogger({
  level: config.logLevel,
  transports: createTransports(),
  // Предотвращение краха приложения на ошибки логирования
  exitOnError: false,
});

/**
 * Обработка uncaught exceptions
 */
logger.exceptions.handle(
  new DailyRotateFile({
    filename: path.join(ensureLogDirectory(), 'exceptions-%DATE%.log'),
    datePattern: 'YYYY-MM-DD',
    maxSize: '20m',
    maxFiles: '30d',
    format: logFormat,
  })
);

/**
 * Обработка unhandled rejections
 */
logger.rejections.handle(
  new DailyRotateFile({
    filename: path.join(ensureLogDirectory(), 'rejections-%DATE%.log'),
    datePattern: 'YYYY-MM-DD',
    maxSize: '20m',
    maxFiles: '30d',
    format: logFormat,
  })
);

/**
 * Дополнительные методы логирования
 */
export const log = {
  // Основные уровни
  error: (message: string, meta?: any) => logger.error(message, meta),
  warn: (message: string, meta?: any) => logger.warn(message, meta),
  info: (message: string, meta?: any) => logger.info(message, meta),
  http: (message: string, meta?: any) => logger.http(message, meta),
  verbose: (message: string, meta?: any) => logger.verbose(message, meta),
  debug: (message: string, meta?: any) => logger.debug(message, meta),
  silly: (message: string, meta?: any) => logger.silly(message, meta),

  // Специализированные методы
  database: (message: string, meta?: any) => logger.info(`[DB] ${message}`, meta),
  freeswitch: (message: string, meta?: any) => logger.info(`[FreeSWITCH] ${message}`, meta),
  dialer: (message: string, meta?: any) => logger.info(`[DIALER] ${message}`, meta),
  bitrix: (message: string, meta?: any) => logger.info(`[BITRIX24] ${message}`, meta),
  auth: (message: string, meta?: any) => logger.info(`[AUTH] ${message}`, meta),
  api: (message: string, meta?: any) => logger.info(`[API] ${message}`, meta),

  // Логирование вызовов
  call: {
    started: (phone: string, campaignId: number, meta?: any) => 
      logger.info(`[CALL] Started call to ${phone} (Campaign: ${campaignId})`, meta),
    answered: (phone: string, duration: number, meta?: any) => 
      logger.info(`[CALL] Call answered: ${phone} (Duration: ${duration}s)`, meta),
    failed: (phone: string, reason: string, meta?: any) => 
      logger.warn(`[CALL] Call failed: ${phone} (Reason: ${reason})`, meta),
    dtmf: (phone: string, response: string, meta?: any) => 
      logger.info(`[CALL] DTMF response: ${phone} -> ${response}`, meta),
    amd: (phone: string, result: string, confidence: number, meta?: any) => 
      logger.info(`[CALL] AMD result: ${phone} -> ${result} (${confidence}%)`, meta),
  },

  // Производительность
  performance: (operation: string, duration: number, meta?: any) => {
    const level = duration > 1000 ? 'warn' : 'debug';
    logger[level](`[PERF] ${operation} took ${duration}ms`, meta);
  },

  // Безопасность
  security: {
    loginAttempt: (username: string, ip: string, success: boolean) => 
      logger.info(`[SECURITY] Login attempt: ${username} from ${ip} - ${success ? 'SUCCESS' : 'FAILED'}`),
    rateLimitHit: (ip: string, endpoint: string) => 
      logger.warn(`[SECURITY] Rate limit exceeded: ${ip} -> ${endpoint}`),
    suspiciousActivity: (message: string, meta?: any) => 
      logger.warn(`[SECURITY] Suspicious activity: ${message}`, meta),
  },
};

/**
 * Мониторинг производительности логирования
 */
let logCount = 0;
let logErrors = 0;

logger.on('data', () => {
  logCount++;
});

logger.on('error', (error: Error) => {
  logErrors++;
  console.error('Logger error:', error);
});

/**
 * Получение статистики логирования
 */
export function getLogStats(): {
  totalLogs: number;
  errors: number;
  level: string;
  transports: number;
} {
  return {
    totalLogs: logCount,
    errors: logErrors,
    level: config.logLevel,
    transports: logger.transports.length,
  };
}

/**
 * Изменение уровня логирования во время выполнения
 */
export function setLogLevel(level: string): void {
  logger.level = level;
  logger.transports.forEach((transport: any) => {
    transport.level = level;
  });
  logger.info(`Log level changed to: ${level}`);
}

/**
 * Очистка старых логов
 */
export function cleanupOldLogs(daysToKeep: number = 30): void {
  const fs = require('fs');
  const logDir = ensureLogDirectory();
  
  try {
    const files = fs.readdirSync(logDir);
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - daysToKeep);

    files.forEach((file: string) => {
      const filePath = path.join(logDir, file);
      const stats = fs.statSync(filePath);
      
      if (stats.mtime < cutoffDate) {
        fs.unlinkSync(filePath);
        logger.info(`Cleaned up old log file: ${file}`);
      }
    });
  } catch (error) {
    logger.error('Failed to cleanup old logs:', error);
  }
}

/**
 * Graceful shutdown логгера
 * Закрывает все транспорты и завершает логирование
 */
export function shutdownLogger(): Promise<void> {
  return new Promise((resolve) => {
    let transportsClosed = 0;
    const totalTransports = logger.transports.length;

    if (totalTransports === 0) {
      resolve();
      return;
    }

    // Закрываем каждый транспорт
    logger.transports.forEach((transport: any) => {
      if (transport.close) {
        transport.close(() => {
          transportsClosed++;
          if (transportsClosed === totalTransports) {
            resolve();
          }
        });
      } else {
        transportsClosed++;
        if (transportsClosed === totalTransports) {
          resolve();
        }
      }
    });

    // Fallback timeout если транспорты не закрываются
    setTimeout(() => {
      resolve();
    }, 5000); // 5 секунд максимум ждем
  });
}

// Экспортируем сам winston logger для случаев, когда нужен прямой доступ
export { logger };

// Экспорт по умолчанию
export default log; 