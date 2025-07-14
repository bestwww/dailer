/**
 * Маршруты для системы мониторинга
 * Этап 6.3: Система логирования и мониторинга
 */

import { Router } from 'express';
import {
  getSystemMetrics,
  getSpecificMetrics,
  getMetricsHistory,
  runHealthChecks,
  simpleHealthCheck,
  getAlerts,
  getActiveAlerts,
  acknowledgeAlert,
  resolveAlert,
  createAlert,
  getPerformanceStats,
  resetMetrics,
  getMonitoringStatus,
  exportPrometheusMetrics
} from '@/controllers/monitoring';

const router = Router();

/**
 * @swagger
 * components:
 *   schemas:
 *     SystemMetrics:
 *       type: object
 *       properties:
 *         uptime:
 *           type: number
 *           description: Время работы системы в секундах
 *         memoryUsage:
 *           type: object
 *           properties:
 *             heapUsed:
 *               type: number
 *             heapTotal:
 *               type: number
 *             external:
 *               type: number
 *             rss:
 *               type: number
 *         totalRequests:
 *           type: number
 *           description: Общее количество HTTP запросов
 *         errorRate:
 *           type: number
 *           description: Процент ошибок
 *         responseTime:
 *           type: number
 *           description: Среднее время ответа в мс
 *         activeCalls:
 *           type: number
 *           description: Количество активных звонков
 *         totalCallsToday:
 *           type: number
 *           description: Общее количество звонков сегодня
 *         activeCampaigns:
 *           type: number
 *           description: Количество активных кампаний
 *     
 *     HealthCheckResult:
 *       type: object
 *       properties:
 *         name:
 *           type: string
 *           description: Название проверки
 *         status:
 *           type: string
 *           enum: [healthy, unhealthy, degraded]
 *           description: Статус проверки
 *         message:
 *           type: string
 *           description: Сообщение о результате
 *         duration:
 *           type: number
 *           description: Время выполнения проверки в мс
 *         timestamp:
 *           type: string
 *           format: date-time
 *         details:
 *           type: object
 *           description: Дополнительные детали проверки
 *     
 *     Alert:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *           description: Уникальный идентификатор алерта
 *         name:
 *           type: string
 *           description: Название алерта
 *         level:
 *           type: string
 *           enum: [info, warning, error, critical]
 *           description: Уровень критичности
 *         message:
 *           type: string
 *           description: Сообщение алерта
 *         timestamp:
 *           type: string
 *           format: date-time
 *           description: Время создания алерта
 *         resolved:
 *           type: string
 *           format: date-time
 *           description: Время разрешения алерта
 *         acknowledgedBy:
 *           type: string
 *           description: Кто подтвердил алерт
 *         acknowledgedAt:
 *           type: string
 *           format: date-time
 *           description: Время подтверждения
 *         details:
 *           type: object
 *           description: Дополнительные детали алерта
 */

/**
 * @swagger
 * /api/monitoring/metrics:
 *   get:
 *     summary: Получение системных метрик
 *     tags: [Monitoring]
 *     responses:
 *       200:
 *         description: Системные метрики
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   $ref: '#/components/schemas/SystemMetrics'
 *                 message:
 *                   type: string
 */
router.get('/metrics', getSystemMetrics);

/**
 * @swagger
 * /api/monitoring/metrics/{names}:
 *   get:
 *     summary: Получение конкретных метрик по именам
 *     tags: [Monitoring]
 *     parameters:
 *       - in: path
 *         name: names
 *         required: true
 *         schema:
 *           type: string
 *         description: Имена метрик через запятую
 *         example: "http_requests_total,active_calls,memory_usage_mb"
 *     responses:
 *       200:
 *         description: Запрошенные метрики
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: object
 *                   additionalProperties:
 *                     type: object
 *                     properties:
 *                       type:
 *                         type: string
 *                         enum: [counter, gauge, timer, unknown]
 *                       value:
 *                         type: number
 *                       stats:
 *                         type: object
 *                 message:
 *                   type: string
 */
router.get('/metrics/:names', getSpecificMetrics);

/**
 * @swagger
 * /api/monitoring/metrics/history:
 *   get:
 *     summary: Получение истории метрик
 *     tags: [Monitoring]
 *     parameters:
 *       - in: query
 *         name: since
 *         schema:
 *           type: string
 *           format: date-time
 *         description: Получить метрики с указанной даты
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           minimum: 1
 *         description: Ограничить количество записей
 *     responses:
 *       200:
 *         description: История метрик
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: object
 *                   properties:
 *                     metrics:
 *                       type: array
 *                       items:
 *                         type: object
 *                         properties:
 *                           name:
 *                             type: string
 *                           value:
 *                             type: number
 *                           type:
 *                             type: string
 *                           timestamp:
 *                             type: string
 *                             format: date-time
 *                     count:
 *                       type: number
 *                 message:
 *                   type: string
 */
router.get('/metrics/history', getMetricsHistory);

/**
 * @swagger
 * /api/monitoring/metrics/prometheus:
 *   get:
 *     summary: Экспорт метрик в формате Prometheus
 *     tags: [Monitoring]
 *     responses:
 *       200:
 *         description: Метрики в формате Prometheus
 *         content:
 *           text/plain:
 *             schema:
 *               type: string
 *               example: |
 *                 # HELP system_uptime_seconds System uptime in seconds
 *                 # TYPE system_uptime_seconds gauge
 *                 system_uptime_seconds 3600
 */
router.get('/metrics/prometheus', exportPrometheusMetrics);

/**
 * @swagger
 * /api/monitoring/metrics/reset:
 *   post:
 *     summary: Сброс всех метрик
 *     tags: [Monitoring]
 *     responses:
 *       200:
 *         description: Метрики сброшены
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 message:
 *                   type: string
 */
router.post('/metrics/reset', resetMetrics);

/**
 * @swagger
 * /api/monitoring/health:
 *   get:
 *     summary: Выполнение health checks
 *     tags: [Monitoring]
 *     responses:
 *       200:
 *         description: Система здорова
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: object
 *                   properties:
 *                     status:
 *                       type: string
 *                       enum: [healthy, degraded, unhealthy]
 *                     checks:
 *                       type: array
 *                       items:
 *                         $ref: '#/components/schemas/HealthCheckResult'
 *                     timestamp:
 *                       type: string
 *                       format: date-time
 *                 message:
 *                   type: string
 *       207:
 *         description: Система частично работает
 *       503:
 *         description: Система неисправна
 */
router.get('/health', runHealthChecks);

/**
 * @swagger
 * /api/monitoring/health/simple:
 *   get:
 *     summary: Простой health check для load balancers
 *     tags: [Monitoring]
 *     responses:
 *       200:
 *         description: Система работает
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 status:
 *                   type: string
 *                   example: "OK"
 *                 uptime:
 *                   type: number
 *                 memory:
 *                   type: number
 *       503:
 *         description: Система неисправна
 */
router.get('/health/simple', simpleHealthCheck);

/**
 * @swagger
 * /api/monitoring/alerts:
 *   get:
 *     summary: Получение алертов
 *     tags: [Monitoring]
 *     parameters:
 *       - in: query
 *         name: level
 *         schema:
 *           type: string
 *           enum: [info, warning, error, critical]
 *         description: Фильтр по уровню критичности
 *       - in: query
 *         name: resolved
 *         schema:
 *           type: boolean
 *         description: Фильтр по статусу разрешения
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           minimum: 1
 *         description: Ограничить количество записей
 *     responses:
 *       200:
 *         description: Список алертов
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: object
 *                   properties:
 *                     alerts:
 *                       type: array
 *                       items:
 *                         $ref: '#/components/schemas/Alert'
 *                     stats:
 *                       type: object
 *                       properties:
 *                         total:
 *                           type: number
 *                         active:
 *                           type: number
 *                         byLevel:
 *                           type: object
 *                         acknowledged:
 *                           type: number
 *                     count:
 *                       type: number
 *                 message:
 *                   type: string
 */
router.get('/alerts', getAlerts);

/**
 * @swagger
 * /api/monitoring/alerts:
 *   post:
 *     summary: Создание пользовательского алерта
 *     tags: [Monitoring]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name:
 *                 type: string
 *                 description: Название алерта
 *               level:
 *                 type: string
 *                 enum: [info, warning, error, critical]
 *                 description: Уровень критичности
 *               message:
 *                 type: string
 *                 description: Сообщение алерта
 *               details:
 *                 type: object
 *                 description: Дополнительные детали
 *             required:
 *               - name
 *               - level
 *               - message
 *     responses:
 *       201:
 *         description: Алерт создан
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   $ref: '#/components/schemas/Alert'
 *                 message:
 *                   type: string
 */
router.post('/alerts', createAlert);

/**
 * @swagger
 * /api/monitoring/alerts/active:
 *   get:
 *     summary: Получение активных алертов
 *     tags: [Monitoring]
 *     responses:
 *       200:
 *         description: Активные алерты
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: object
 *                   properties:
 *                     alerts:
 *                       type: array
 *                       items:
 *                         $ref: '#/components/schemas/Alert'
 *                     count:
 *                       type: number
 *                     stats:
 *                       type: object
 *                 message:
 *                   type: string
 */
router.get('/alerts/active', getActiveAlerts);

/**
 * @swagger
 * /api/monitoring/alerts/{id}/acknowledge:
 *   post:
 *     summary: Подтверждение алерта
 *     tags: [Monitoring]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: ID алерта
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               acknowledgedBy:
 *                 type: string
 *                 description: Пользователь, подтверждающий алерт
 *             required:
 *               - acknowledgedBy
 *     responses:
 *       200:
 *         description: Алерт подтвержден
 *       404:
 *         description: Алерт не найден
 */
router.post('/alerts/:id/acknowledge', acknowledgeAlert);

/**
 * @swagger
 * /api/monitoring/alerts/{id}/resolve:
 *   post:
 *     summary: Разрешение алерта
 *     tags: [Monitoring]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: ID алерта
 *     responses:
 *       200:
 *         description: Алерт разрешен
 *       404:
 *         description: Алерт не найден
 */
router.post('/alerts/:id/resolve', resolveAlert);

/**
 * @swagger
 * /api/monitoring/performance:
 *   get:
 *     summary: Получение статистики производительности
 *     tags: [Monitoring]
 *     responses:
 *       200:
 *         description: Статистика производительности
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: object
 *                   properties:
 *                     http:
 *                       type: object
 *                       properties:
 *                         count:
 *                           type: number
 *                         min:
 *                           type: number
 *                         max:
 *                           type: number
 *                         avg:
 *                           type: number
 *                         p95:
 *                           type: number
 *                         p99:
 *                           type: number
 *                     database:
 *                       type: object
 *                     calls:
 *                       type: object
 *                     webhooks:
 *                       type: object
 *                 message:
 *                   type: string
 */
router.get('/performance', getPerformanceStats);

/**
 * @swagger
 * /api/monitoring/status:
 *   get:
 *     summary: Получение статуса системы мониторинга
 *     tags: [Monitoring]
 *     responses:
 *       200:
 *         description: Статус системы мониторинга
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: object
 *                   properties:
 *                     monitoring:
 *                       type: object
 *                       properties:
 *                         isRunning:
 *                           type: boolean
 *                         counters:
 *                           type: number
 *                         gauges:
 *                           type: number
 *                         timers:
 *                           type: number
 *                         healthChecks:
 *                           type: number
 *                     alerting:
 *                       type: object
 *                     dialer:
 *                       type: object
 *                     timestamp:
 *                       type: string
 *                       format: date-time
 *                 message:
 *                   type: string
 */
router.get('/status', getMonitoringStatus);

export default router; 