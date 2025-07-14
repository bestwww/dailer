/**
 * Маршруты для управления настройками времени
 * Этап 6.2.4: Настройки времени обзвона и часовые пояса
 */

import { Router } from 'express';
import {
  getSupportedTimezones,
  getTimezoneInfo,
  updateCampaignTimeSettings,
  checkCampaignWorkingTime,
  updateContactsTimezone,
  getTimezoneStats,
  validateTimeSettings
} from '@/controllers/time-settings';

const router = Router();

// Документация маршрутов
/**
 * @swagger
 * components:
 *   schemas:
 *     TimeZoneInfo:
 *       type: object
 *       properties:
 *         timezone:
 *           type: string
 *           description: Название часового пояса
 *         offset:
 *           type: number
 *           description: Смещение от UTC в минутах
 *         isDST:
 *           type: boolean
 *           description: Активно ли летнее время
 *         name:
 *           type: string
 *           description: Полное название часового пояса
 *         abbreviation:
 *           type: string
 *           description: Сокращение часового пояса
 *         offsetString:
 *           type: string
 *           description: Смещение в формате UTC±HH:mm
 *     
 *     TimeSettings:
 *       type: object
 *       properties:
 *         workTimeStart:
 *           type: string
 *           format: time
 *           description: Время начала работы (HH:mm)
 *         workTimeEnd:
 *           type: string
 *           format: time
 *           description: Время окончания работы (HH:mm)
 *         workDays:
 *           type: array
 *           items:
 *             type: integer
 *             minimum: 1
 *             maximum: 7
 *           description: Рабочие дни недели (1=понедельник, 7=воскресенье)
 *         timezone:
 *           type: string
 *           description: Часовой пояс
 */

/**
 * @swagger
 * /api/time-settings/timezones:
 *   get:
 *     summary: Получение списка поддерживаемых часовых поясов
 *     tags: [Time Settings]
 *     responses:
 *       200:
 *         description: Список часовых поясов
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
 *                     timezones:
 *                       type: array
 *                       items:
 *                         $ref: '#/components/schemas/TimeZoneInfo'
 *                     defaultTimezone:
 *                       type: string
 *                 message:
 *                   type: string
 */
router.get('/timezones', getSupportedTimezones);

/**
 * @swagger
 * /api/time-settings/timezone/{timezone}:
 *   get:
 *     summary: Получение информации о часовом поясе
 *     tags: [Time Settings]
 *     parameters:
 *       - in: path
 *         name: timezone
 *         required: true
 *         schema:
 *           type: string
 *         description: Название часового пояса (URL-encoded)
 *     responses:
 *       200:
 *         description: Информация о часовом поясе
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   allOf:
 *                     - $ref: '#/components/schemas/TimeZoneInfo'
 *                     - type: object
 *                       properties:
 *                         currentTime:
 *                           type: string
 *                           description: Текущее время в этом часовом поясе
 *                 message:
 *                   type: string
 *       400:
 *         description: Некорректный часовой пояс
 */
router.get('/timezone/:timezone', getTimezoneInfo);

/**
 * @swagger
 * /api/time-settings/campaign/{id}:
 *   put:
 *     summary: Обновление настроек времени кампании
 *     tags: [Time Settings]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID кампании
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/TimeSettings'
 *     responses:
 *       200:
 *         description: Настройки времени кампании обновлены
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: object
 *                   description: Обновленная кампания
 *                 message:
 *                   type: string
 *       400:
 *         description: Некорректные данные
 *       404:
 *         description: Кампания не найдена
 */
router.put('/campaign/:id', updateCampaignTimeSettings);

/**
 * @swagger
 * /api/time-settings/campaign/{id}/working-time:
 *   get:
 *     summary: Проверка рабочего времени кампании
 *     tags: [Time Settings]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID кампании
 *       - in: query
 *         name: checkDate
 *         schema:
 *           type: string
 *           format: date-time
 *         description: Дата для проверки (по умолчанию текущее время)
 *     responses:
 *       200:
 *         description: Результат проверки рабочего времени
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
 *                     isWorkingTime:
 *                       type: boolean
 *                       description: Сейчас рабочее время
 *                     nextWorkingTime:
 *                       type: string
 *                       format: date-time
 *                       description: Следующее рабочее время
 *                     nextWorkingTimeFormatted:
 *                       type: string
 *                       description: Следующее рабочее время в удобном формате
 *                     campaignTimezone:
 *                       type: string
 *                       description: Часовой пояс кампании
 *                     currentTime:
 *                       type: string
 *                       description: Текущее время в часовом поясе кампании
 *                 message:
 *                   type: string
 *       404:
 *         description: Кампания не найдена
 */
router.get('/campaign/:id/working-time', checkCampaignWorkingTime);

/**
 * @swagger
 * /api/time-settings/contacts/timezone:
 *   put:
 *     summary: Массовое обновление часовых поясов контактов
 *     tags: [Time Settings]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               contactIds:
 *                 type: array
 *                 items:
 *                   type: integer
 *                 description: ID контактов для обновления
 *               timezone:
 *                 type: string
 *                 description: Новый часовой пояс
 *             required:
 *               - contactIds
 *               - timezone
 *     responses:
 *       200:
 *         description: Результат массового обновления
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
 *                     updatedCount:
 *                       type: integer
 *                       description: Количество обновленных контактов
 *                     totalRequested:
 *                       type: integer
 *                       description: Общее количество запрошенных контактов
 *                     errors:
 *                       type: array
 *                       items:
 *                         type: string
 *                       description: Ошибки обновления (если есть)
 *                 message:
 *                   type: string
 *       400:
 *         description: Некорректные данные
 */
router.put('/contacts/timezone', updateContactsTimezone);

/**
 * @swagger
 * /api/time-settings/stats:
 *   get:
 *     summary: Получение статистики по часовым поясам
 *     tags: [Time Settings]
 *     parameters:
 *       - in: query
 *         name: campaignId
 *         schema:
 *           type: integer
 *         description: ID кампании для фильтрации статистики
 *     responses:
 *       200:
 *         description: Статистика по часовым поясам
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
 *                     stats:
 *                       type: array
 *                       items:
 *                         type: object
 *                         properties:
 *                           timezone:
 *                             type: string
 *                           contactCount:
 *                             type: integer
 *                           completedCount:
 *                             type: integer
 *                           failedCount:
 *                             type: integer
 *                           timezoneInfo:
 *                             $ref: '#/components/schemas/TimeZoneInfo'
 *                           offsetString:
 *                             type: string
 *                           currentTime:
 *                             type: string
 *                     totalTimezones:
 *                       type: integer
 *                     totalContacts:
 *                       type: integer
 *                 message:
 *                   type: string
 */
router.get('/stats', getTimezoneStats);

/**
 * @swagger
 * /api/time-settings/validate:
 *   post:
 *     summary: Валидация настроек времени
 *     tags: [Time Settings]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/TimeSettings'
 *     responses:
 *       200:
 *         description: Результат валидации
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
 *                     isValid:
 *                       type: boolean
 *                       description: Корректны ли настройки
 *                     errors:
 *                       type: array
 *                       items:
 *                         type: string
 *                       description: Список ошибок валидации
 *                 message:
 *                   type: string
 */
router.post('/validate', validateTimeSettings);

export default router; 