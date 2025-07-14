/**
 * Маршруты для webhook API
 */

import { Router } from 'express';
import { webhookController } from '../controllers/webhook';

const router = Router();

/**
 * @swagger
 * /api/webhook/endpoints:
 *   get:
 *     summary: Получить все webhook endpoints
 *     tags: [Webhook]
 *     parameters:
 *       - in: query
 *         name: includeInactive
 *         schema:
 *           type: boolean
 *         description: Включить неактивные endpoints
 *       - in: query
 *         name: campaignId
 *         schema:
 *           type: integer
 *         description: Фильтр по ID кампании
 *       - in: query
 *         name: eventType
 *         schema:
 *           type: string
 *         description: Фильтр по типу события
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           default: 1
 *         description: Номер страницы
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 50
 *         description: Количество элементов на странице
 *     responses:
 *       200:
 *         description: Список webhook endpoints
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/WebhookEndpoint'
 *                 pagination:
 *                   $ref: '#/components/schemas/Pagination'
 */
router.get('/endpoints', webhookController.getAllWebhookEndpoints);

/**
 * @swagger
 * /api/webhook/endpoints:
 *   post:
 *     summary: Создать новый webhook endpoint
 *     tags: [Webhook]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/CreateWebhookEndpointRequest'
 *     responses:
 *       201:
 *         description: Webhook endpoint создан
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   $ref: '#/components/schemas/WebhookEndpoint'
 *                 message:
 *                   type: string
 *       400:
 *         description: Ошибка валидации
 *       500:
 *         description: Внутренняя ошибка сервера
 */
router.post('/endpoints', webhookController.createWebhookEndpoint);

/**
 * @swagger
 * /api/webhook/endpoints/{id}:
 *   get:
 *     summary: Получить webhook endpoint по ID
 *     tags: [Webhook]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID webhook endpoint
 *     responses:
 *       200:
 *         description: Webhook endpoint
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   $ref: '#/components/schemas/WebhookEndpoint'
 *       404:
 *         description: Webhook endpoint не найден
 *       500:
 *         description: Внутренняя ошибка сервера
 */
router.get('/endpoints/:id', webhookController.getWebhookEndpointById);

/**
 * @swagger
 * /api/webhook/endpoints/{id}:
 *   put:
 *     summary: Обновить webhook endpoint
 *     tags: [Webhook]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID webhook endpoint
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/UpdateWebhookEndpointRequest'
 *     responses:
 *       200:
 *         description: Webhook endpoint обновлен
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   $ref: '#/components/schemas/WebhookEndpoint'
 *                 message:
 *                   type: string
 *       404:
 *         description: Webhook endpoint не найден
 *       500:
 *         description: Внутренняя ошибка сервера
 */
router.put('/endpoints/:id', webhookController.updateWebhookEndpoint);

/**
 * @swagger
 * /api/webhook/endpoints/{id}:
 *   delete:
 *     summary: Удалить webhook endpoint
 *     tags: [Webhook]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID webhook endpoint
 *     responses:
 *       200:
 *         description: Webhook endpoint удален
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 message:
 *                   type: string
 *       404:
 *         description: Webhook endpoint не найден
 *       500:
 *         description: Внутренняя ошибка сервера
 */
router.delete('/endpoints/:id', webhookController.deleteWebhookEndpoint);

/**
 * @swagger
 * /api/webhook/endpoints/{id}/test:
 *   post:
 *     summary: Тестировать webhook endpoint
 *     tags: [Webhook]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID webhook endpoint
 *     responses:
 *       200:
 *         description: Тестовое событие отправлено
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 message:
 *                   type: string
 *       404:
 *         description: Webhook endpoint не найден
 *       500:
 *         description: Внутренняя ошибка сервера
 */
router.post('/endpoints/:id/test', webhookController.testWebhookEndpoint);

/**
 * @swagger
 * /api/webhook/event-types:
 *   get:
 *     summary: Получить доступные типы событий
 *     tags: [Webhook]
 *     responses:
 *       200:
 *         description: Список доступных типов событий
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       value:
 *                         type: string
 *                       label:
 *                         type: string
 *                       description:
 *                         type: string
 *       500:
 *         description: Внутренняя ошибка сервера
 */
router.get('/event-types', webhookController.getAvailableEventTypes);

/**
 * @swagger
 * /api/webhook/stats:
 *   get:
 *     summary: Получить статистику webhook
 *     tags: [Webhook]
 *     parameters:
 *       - in: query
 *         name: startDate
 *         schema:
 *           type: string
 *           format: date
 *         description: Дата начала периода
 *       - in: query
 *         name: endDate
 *         schema:
 *           type: string
 *           format: date
 *         description: Дата окончания периода
 *       - in: query
 *         name: campaignId
 *         schema:
 *           type: integer
 *         description: ID кампании
 *     responses:
 *       200:
 *         description: Статистика webhook
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   $ref: '#/components/schemas/WebhookStats'
 *       500:
 *         description: Внутренняя ошибка сервера
 */
router.get('/stats', webhookController.getWebhookStats);

/**
 * @swagger
 * /api/webhook/deliveries:
 *   get:
 *     summary: Получить логи доставки webhook
 *     tags: [Webhook]
 *     parameters:
 *       - in: query
 *         name: endpointId
 *         schema:
 *           type: integer
 *         description: ID webhook endpoint
 *       - in: query
 *         name: eventType
 *         schema:
 *           type: string
 *         description: Тип события
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *           enum: [pending, delivered, failed]
 *         description: Статус доставки
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           default: 1
 *         description: Номер страницы
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 50
 *         description: Количество элементов на странице
 *     responses:
 *       200:
 *         description: Логи доставки webhook
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/WebhookDelivery'
 *                 pagination:
 *                   $ref: '#/components/schemas/Pagination'
 *       500:
 *         description: Внутренняя ошибка сервера
 */
router.get('/deliveries', webhookController.getWebhookDeliveries);

export default router; 