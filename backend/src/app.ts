/**
 * Главный файл приложения
 * Настройка Express сервера с middleware и маршрутами
 */

import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import morgan from 'morgan';
import { createServer } from 'http';
import { Server as SocketIOServer } from 'socket.io';

import { config, validateCriticalConfig, logConfigInfo, isDevelopment } from '@/config';
import { checkConnection } from '@/config/database';
import { log, shutdownLogger } from '@/utils/logger';
import { dialerService } from '@/services/dialer';
import { schedulerService } from '@/services/scheduler';
import { monitoringService } from '@/services/monitoring';
import { alertingService } from '@/services/alerting';
import { monitoringMiddleware } from '@/middleware/monitoring';

/**
 * Создание Express приложения
 */
function createApp(): express.Application {
  const app = express();

  // === Базовые middleware ===
  
  // Безопасность
  app.use(helmet({
    ...(isDevelopment && { contentSecurityPolicy: false }),
    crossOriginEmbedderPolicy: false,
  }));

  // Сжатие ответов
  app.use(compression());

  // CORS для frontend
  if (isDevelopment) {
    app.use(cors({
      origin: ['http://localhost:5173', 'http://localhost:3000', 'http://46.173.16.147:5173'],
      credentials: true,
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'HEAD'],
      allowedHeaders: ['Content-Type', 'Authorization', 'Range', 'Accept'],
      exposedHeaders: ['Content-Range', 'Content-Length', 'Accept-Ranges'],
    }));
  } else {
    app.use(cors({
      origin: process.env.FRONTEND_URL || false,
      credentials: true,
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'HEAD'],
      allowedHeaders: ['Content-Type', 'Authorization', 'Range', 'Accept'],
      exposedHeaders: ['Content-Range', 'Content-Length', 'Accept-Ranges'],
    }));
  }

  // Rate limiting
  const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 минут
    max: isDevelopment ? 1000 : 100, // ограничение запросов
    message: {
      error: 'Too many requests from this IP, please try again later.',
    },
    standardHeaders: true,
    legacyHeaders: false,
  });
  app.use('/api/', limiter);

  // Логирование HTTP запросов
  if (isDevelopment) {
    app.use(morgan('dev'));
  } else {
    app.use(morgan('combined', {
      stream: {
        write: (message: string) => {
          log.info(message.trim());
        },
      },
    }));
  }

  // Устанавливаем правильную кодировку UTF-8 для ответов
  app.use((_req, res, next) => {
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    next();
  });

  // Парсинг JSON
  app.use(express.json({ limit: config.bodyParserLimit }));
  app.use(express.urlencoded({ extended: true, limit: config.bodyParserLimit }));

  // === Middleware мониторинга ===
  app.use(monitoringMiddleware.correlation);
  app.use(monitoringMiddleware.monitoringContext);
  app.use(monitoringMiddleware.healthCheckExclusion);
  app.use(monitoringMiddleware.httpMetrics);
  app.use(monitoringMiddleware.slowRequest(3000)); // Алерт для запросов > 3 сек
  app.use(monitoringMiddleware.sizeTracking);
  app.use(monitoringMiddleware.securityMonitoring);
  app.use(monitoringMiddleware.rateLimitMonitoring);

  // Статические файлы
  // Обработка OPTIONS запросов для аудио файлов
  app.options('/audio/*', (req, res) => {
    // Разрешаем для development локальные хосты
    const allowedOrigins = isDevelopment 
      ? ['http://localhost:5173', 'http://localhost:3000', 'http://127.0.0.1:5173', 'http://127.0.0.1:3000']
      : ['*'];
    
    const origin = req.headers.origin;
    if (isDevelopment && origin && allowedOrigins.includes(origin)) {
      res.setHeader('Access-Control-Allow-Origin', origin);
    } else if (!isDevelopment) {
      res.setHeader('Access-Control-Allow-Origin', '*');
    }
    
    res.setHeader('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Range, Content-Range, Content-Type, Accept, Authorization');
    res.setHeader('Access-Control-Expose-Headers', 'Content-Range, Content-Length, Accept-Ranges');
    res.setHeader('Access-Control-Allow-Credentials', 'true');
    res.setHeader('Access-Control-Max-Age', '86400');
    res.status(204).send();
  });

  app.use('/audio', express.static(config.audioUploadPath, {
    setHeaders: (res, path, _stat) => {
      // Устанавливаем правильный Content-Type для аудио файлов
      if (path.endsWith('.mp3')) {
        res.setHeader('Content-Type', 'audio/mpeg');
      } else if (path.endsWith('.wav')) {
        res.setHeader('Content-Type', 'audio/wav');
      } else if (path.endsWith('.m4a')) {
        res.setHeader('Content-Type', 'audio/mp4');
      }
      
      // Добавляем CORS заголовки для аудио файлов
      // Для development разрешаем любые localhost порты
      if (isDevelopment) {
        res.setHeader('Access-Control-Allow-Origin', '*');
        res.setHeader('Access-Control-Allow-Credentials', 'true');
      } else {
        res.setHeader('Access-Control-Allow-Origin', '*');
      }
      
      res.setHeader('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
      res.setHeader('Access-Control-Allow-Headers', 'Range, Content-Range, Content-Type, Accept, Authorization');
      res.setHeader('Access-Control-Expose-Headers', 'Content-Range, Content-Length, Accept-Ranges');
      
      // Добавляем заголовки для лучшей совместимости с браузерами и поддержки range запросов
      res.setHeader('Accept-Ranges', 'bytes');
      res.setHeader('Cache-Control', 'public, max-age=3600');
      
      // Заголовки для предотвращения кэширования в development
      if (isDevelopment) {
        res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
        res.setHeader('Pragma', 'no-cache');
        res.setHeader('Expires', '0');
      }
      
      // Логирование для отладки
      if (isDevelopment) {
        log.info(`🎵 Статический файл запрошен: ${path}`);
        log.info(`📡 CORS Origin: ${res.getHeader('Access-Control-Allow-Origin')}`);
        log.info(`📋 Все заголовки:`, {
          'Content-Type': res.getHeader('Content-Type'),
          'Access-Control-Allow-Origin': res.getHeader('Access-Control-Allow-Origin'),
          'Accept-Ranges': res.getHeader('Accept-Ranges'),
          'Cache-Control': res.getHeader('Cache-Control')
        });
      }
    }
  }));
  app.use('/public', express.static('public'));

  // === Маршруты ===

  // Healthcheck - добавляем оба роута для совместимости
  app.get('/health', async (_req, res) => {
    try {
      const dbStatus = await checkConnection();
      const status = {
        status: 'ok',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        environment: config.nodeEnv,
        database: dbStatus ? 'connected' : 'disconnected',
        memory: {
          used: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
          total: Math.round(process.memoryUsage().heapTotal / 1024 / 1024),
        },
      };

      res.status(dbStatus ? 200 : 503).json(status);
    } catch (error) {
      res.status(503).json({
        status: 'error',
        message: 'Health check failed',
        error: error instanceof Error ? error.message : 'Unknown error',
      });
    }
  });

  // Дублируем healthcheck для API роута
  app.get('/api/health', async (_req, res) => {
    try {
      const dbStatus = await checkConnection();
      const status = {
        status: 'ok',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        environment: config.nodeEnv,
        database: dbStatus ? 'connected' : 'disconnected',
        memory: {
          used: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
          total: Math.round(process.memoryUsage().heapTotal / 1024 / 1024),
        },
      };

      res.status(dbStatus ? 200 : 503).json(status);
    } catch (error) {
      res.status(503).json({
        status: 'error',
        message: 'Health check failed',
        error: error instanceof Error ? error.message : 'Unknown error',
      });
    }
  });

  // API маршруты
  app.use('/api/auth', require('./controllers/auth').default);
  app.use('/api/campaigns', require('./routes/campaigns').default);
  app.use('/api/blacklist', require('./routes/blacklist').default);
  app.use('/api/contacts', require('./routes/contacts').default);
  app.use('/api/calls', require('./controllers/calls').default);
  app.use('/api/call-results', require('./controllers/calls').default); // Алиас для call-results
  app.use('/api/stats', require('./controllers/stats').default);
  app.use('/api/settings', require('./controllers/settings').default);
  app.use('/api/bitrix', require('./controllers/bitrix').default);
  app.use('/api/webhook', require('./routes/webhook').default);
  app.use('/api/time-settings', require('./routes/time-settings').default);
  app.use('/api/monitoring', require('./routes/monitoring').default);
  app.use('/api/audio', require('./routes/audio').default);

  // Swagger документация
  if (isDevelopment) {
    const swaggerUi = require('swagger-ui-express');
    const swaggerJsdoc = require('swagger-jsdoc');

    const swaggerOptions = {
      definition: {
        openapi: '3.0.0',
        info: {
          title: 'Dialer API',
          version: '1.0.0',
          description: 'API для системы автодозвона',
        },
        servers: [
          {
            url: `http://localhost:${config.port}`,
            description: 'Development server',
          },
        ],
        components: {
          securitySchemes: {
            bearerAuth: {
              type: 'http',
              scheme: 'bearer',
              bearerFormat: 'JWT',
            },
          },
        },
      },
      apis: ['./src/controllers/*.ts', './src/routes/*.ts'],
    };

    const specs = swaggerJsdoc(swaggerOptions);
    app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(specs));
  }

  // Middleware обработки ошибок
  app.use(monitoringMiddleware.errorTracking);

  // Обработка 404
  app.use('*', (req, res) => {
    res.status(404).json({
      success: false,
      message: 'Route not found',
      path: req.originalUrl,
    });
  });

  // Глобальный обработчик ошибок
  app.use((error: any, req: express.Request, res: express.Response, _next: express.NextFunction) => {
    log.error('Unhandled error:', {
      error: error.message,
      stack: error.stack,
      url: req.url,
      method: req.method,
      body: req.body,
      query: req.query,
      params: req.params,
    });

    const status = error.status || error.statusCode || 500;
    const message = isDevelopment ? error.message : 'Internal server error';

    res.status(status).json({
      success: false,
      error: message,
      ...(isDevelopment && { stack: error.stack }),
    });
  });

  return app;
}

/**
 * Инициализация сервера
 */
async function initializeServer(): Promise<{ app: express.Application; server: any; io: SocketIOServer }> {
  try {
    // Валидация конфигурации
    validateCriticalConfig();
    logConfigInfo();

    // Создание приложения
    const app = createApp();
    const server = createServer(app);

    // Настройка WebSocket
    const io = new SocketIOServer(server, {
      cors: {
        origin: isDevelopment ? ["http://localhost:5173"] : false,
        methods: ["GET", "POST"],
      },
    });

    // WebSocket события
    io.on('connection', (socket) => {
      log.info(`WebSocket client connected: ${socket.id}`);

      socket.on('join_campaign', (campaignId: number) => {
        socket.join(`campaign_${campaignId}`);
        log.info(`Client ${socket.id} joined campaign ${campaignId}`);
      });

      socket.on('leave_campaign', (campaignId: number) => {
        socket.leave(`campaign_${campaignId}`);
        log.info(`Client ${socket.id} left campaign ${campaignId}`);
      });

      socket.on('disconnect', (reason) => {
        log.info(`WebSocket client disconnected: ${socket.id}, reason: ${reason}`);
      });
    });

    // Проверка подключения к базе данных
    const dbConnected = await checkConnection();
    if (!dbConnected) {
      log.warn('⚠️  Database not available - running in demo mode');
    }

    // Инициализация сервисов
    if (dbConnected) {
      try {
        // Подписка на события диалера для отправки через WebSocket (ДО запуска диалера!)
        dialerService.on('campaign:started', (data) => {
          log.info(`📡 Broadcasting campaign started: ${data.campaignId}`);
          io.emit('campaign_updated', {
            campaignId: data.campaignId,
            status: 'active',
            campaign: data.campaign
          });
        });

        dialerService.on('campaign:stopped', (data) => {
          log.info(`📡 Broadcasting campaign stopped: ${data.campaignId}`);
          io.emit('campaign_updated', {
            campaignId: data.campaignId,
            status: 'cancelled'
          });
        });

        dialerService.on('campaign:paused', (data) => {
          log.info(`📡 Broadcasting campaign paused: ${data.campaignId}`);
          io.emit('campaign_updated', {
            campaignId: data.campaignId,
            status: 'paused'
          });
        });

        // Запуск диалера
        await dialerService.start();
        log.info('✅ Dialer service started');

        // Запуск планировщика
        await schedulerService.start();
        log.info('✅ Scheduler service started');

        // Запуск системы мониторинга
        monitoringService.start();
        log.info('✅ Monitoring service started');

        // Запуск системы алертов
        alertingService.start();
        log.info('✅ Alerting service started');
      } catch (error) {
        log.error('❌ Failed to start services:', error);
        // Не завершаем процесс, продолжаем работу сервера
      }
    }

    log.info('🚀 Server initialized successfully');
    return { app, server, io };

  } catch (error) {
    log.error('❌ Failed to initialize server:', error);
    throw error;
  }
}

/**
 * Запуск сервера
 */
async function startServer(): Promise<void> {
  try {
    const { server, io: _io } = await initializeServer();

    // Запуск сервера
    server.listen(config.port, () => {
      log.info(`🌟 Server running on port ${config.port}`);
      log.info(`📚 API Documentation: http://localhost:${config.port}/api-docs`);
      log.info(`💚 Health check: http://localhost:${config.port}/health`);
    });

    // Глобальные обработчики процесса
    process.on('uncaughtException', async (error) => {
      log.error('Uncaught Exception:', error);
      await shutdownLogger(); // Закрываем логгер gracefully
      process.exit(1);
    });

    process.on('unhandledRejection', async (reason, promise) => {
      log.error('Unhandled Rejection at:', promise, 'reason:', reason);
      await shutdownLogger(); // Закрываем логгер gracefully
      process.exit(1);
    });

    process.on('SIGTERM', async () => {
      log.info('SIGTERM received, shutting down gracefully');
      
      // Остановка сервисов
      try {
        await schedulerService.stop();
        log.info('✅ Scheduler service stopped');
        
        await dialerService.stop();
        log.info('✅ Dialer service stopped');
      } catch (error) {
        log.error('❌ Error stopping services:', error);
      }
      
      server.close(async () => {
        log.info('Process terminated');
        await shutdownLogger(); // Закрываем логгер gracefully
        process.exit(0);
      });
    });

    process.on('SIGINT', async () => {
      log.info('SIGINT received, shutting down gracefully');
      
      // Остановка сервисов
      try {
        await schedulerService.stop();
        log.info('✅ Scheduler service stopped');
        
        await dialerService.stop();
        log.info('✅ Dialer service stopped');
      } catch (error) {
        log.error('❌ Error stopping services:', error);
      }
      
      server.close(async () => {
        log.info('Process terminated');
        await shutdownLogger(); // Закрываем логгер gracefully
        process.exit(0);
      });
    });

  } catch (error) {
    log.error('❌ Failed to start server:', error);
    process.exit(1);
  }
}

// Запуск если файл выполняется напрямую
if (require.main === module) {
  startServer();
}

export { createApp, initializeServer, startServer }; 