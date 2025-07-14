/**
 * Маршруты для работы с контактами
 */

import { Router } from 'express';
import {
  getContacts,
  getContact,
  createContact,
  updateContact,
  deleteContact,
  importContacts,
  getContactsStats,
  getNextContactsForCalling,
} from '@/controllers/contacts';

const router = Router();

/**
 * Получение списка контактов
 * GET /api/contacts
 */
router.get('/', getContacts);

/**
 * Получение контакта по ID
 * GET /api/contacts/:id
 */
router.get('/:id', getContact);

/**
 * Создание контакта
 * POST /api/contacts
 */
router.post('/', createContact);

/**
 * Обновление контакта
 * PUT /api/contacts/:id
 */
router.put('/:id', updateContact);

/**
 * Удаление контакта
 * DELETE /api/contacts/:id
 */
router.delete('/:id', deleteContact);

/**
 * Импорт контактов
 * POST /api/contacts/import
 */
router.post('/import', importContacts);

/**
 * Статистика контактов по кампании
 * GET /api/contacts/stats/:campaignId
 */
router.get('/stats/:campaignId', getContactsStats);

/**
 * Получение контактов для звонков
 * GET /api/contacts/next-for-calling/:campaignId
 */
router.get('/next-for-calling/:campaignId', getNextContactsForCalling);

export default router; 