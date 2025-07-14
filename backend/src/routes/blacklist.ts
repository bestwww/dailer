/**
 * Роутер для управления черным списком номеров
 */

import { Router } from 'express';
import {
  getBlacklistEntries,
  addToBlacklist,
  bulkAddToBlacklist,
  getBlacklistEntryById,
  checkBlacklist,
  updateBlacklistEntry,
  removeFromBlacklist,
  deleteBlacklistEntry,
  getBlacklistStats,
  cleanupExpiredEntries,
  exportBlacklistCSV,
  importBlacklistCSV
} from '@/controllers/blacklist';

const router = Router();

// Основные CRUD операции
router.get('/', getBlacklistEntries);
router.post('/', addToBlacklist);
router.post('/bulk', bulkAddToBlacklist);
router.get('/stats', getBlacklistStats);
router.get('/:id', getBlacklistEntryById);
router.put('/:id', updateBlacklistEntry);
router.delete('/:id', removeFromBlacklist); // Деактивация
router.delete('/:id/permanent', deleteBlacklistEntry); // Физическое удаление

// Проверка номера
router.get('/check/:phone', checkBlacklist);

// Служебные операции
router.post('/cleanup', cleanupExpiredEntries);

// Импорт/экспорт
router.get('/export/csv', exportBlacklistCSV);
router.post('/import/csv', importBlacklistCSV);

export default router; 