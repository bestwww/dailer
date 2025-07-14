/**
 * Контроллер для управления черным списком номеров
 */

import { Request, Response } from 'express';
import { blacklistModel } from '@/models/blacklist';
import { log } from '@/utils/logger';
import { CreateBlacklistRequest, UpdateBlacklistRequest, BulkBlacklistRequest, BlacklistReason } from '@/types';

/**
 * Получение списка записей черного списка
 */
export async function getBlacklistEntries(req: Request, res: Response): Promise<void> {
  try {
    const page = parseInt(req.query.page as string) || 1;
    const limit = parseInt(req.query.limit as string) || 10;
    const reasonType = req.query.reasonType as BlacklistReason;
    const isActive = req.query.isActive ? req.query.isActive === 'true' : undefined;
    const search = req.query.search as string;

    const result = await blacklistModel.getBlacklistEntries(page, limit, reasonType, isActive, search);

    log.api(`Retrieved ${result.entries.length} blacklist entries (page ${page})`);

    res.json({
      success: true,
      data: result.entries,
      pagination: {
        page: result.page,
        limit,
        total: result.total,
        totalPages: result.totalPages,
      },
      message: 'Список черного списка получен успешно'
    });
  } catch (error) {
    log.error('Error getting blacklist entries:', error);
    res.status(500).json({
      success: false,
      error: 'Ошибка получения черного списка'
    });
  }
}

/**
 * Добавление номера в черный список
 */
export async function addToBlacklist(req: Request, res: Response): Promise<void> {
  try {
    const userId = (req as any).user?.id; // Из middleware авторизации
    const requestData: CreateBlacklistRequest = req.body;

    // Валидация данных
    if (!requestData.phone || requestData.phone.trim().length === 0) {
      res.status(400).json({
        success: false,
        error: 'Номер телефона обязателен'
      });
      return;
    }

    if (!requestData.reasonType) {
      res.status(400).json({
        success: false,
        error: 'Тип причины обязателен'
      });
      return;
    }

    const entry = await blacklistModel.addToBlacklist(requestData, userId);

    log.info(`Added phone ${entry.phone} to blacklist by user ${userId}`);

    res.status(201).json({
      success: true,
      data: entry,
      message: 'Номер добавлен в черный список успешно'
    });
  } catch (error) {
    log.error('Error adding to blacklist:', error);
    
    if (error instanceof Error && error.message.includes('уже находится в черном списке')) {
      res.status(409).json({
        success: false,
        error: error.message
      });
    } else {
      res.status(500).json({
        success: false,
        error: 'Ошибка добавления в черный список'
      });
    }
  }
}

/**
 * Массовое добавление номеров в черный список
 */
export async function bulkAddToBlacklist(req: Request, res: Response): Promise<void> {
  try {
    const userId = (req as any).user?.id;
    const requestData: BulkBlacklistRequest = req.body;

    // Валидация данных
    if (!requestData.phones || !Array.isArray(requestData.phones) || requestData.phones.length === 0) {
      res.status(400).json({
        success: false,
        error: 'Список номеров телефонов обязателен'
      });
      return;
    }

    if (!requestData.reasonType) {
      res.status(400).json({
        success: false,
        error: 'Тип причины обязателен'
      });
      return;
    }

    const result = await blacklistModel.bulkAddToBlacklist(requestData, userId);

    log.info(`Bulk blacklist operation by user ${userId}: ${result.added} added, ${result.skipped} skipped, ${result.errors.length} errors`);

    res.json({
      success: true,
      data: result,
      message: `Операция завершена: добавлено ${result.added}, пропущено ${result.skipped}, ошибок ${result.errors.length}`
    });
  } catch (error) {
    log.error('Error bulk adding to blacklist:', error);
    res.status(500).json({
      success: false,
      error: 'Ошибка массового добавления в черный список'
    });
  }
}

/**
 * Получение записи черного списка по ID
 */
export async function getBlacklistEntryById(req: Request, res: Response): Promise<void> {
  try {
    const idParam = req.params.id;
    if (!idParam) {
      res.status(400).json({
        success: false,
        error: 'ID записи обязателен'
      });
      return;
    }

    const id = parseInt(idParam);
    if (isNaN(id)) {
      res.status(400).json({
        success: false,
        error: 'Некорректный ID записи'
      });
      return;
    }

    const entry = await blacklistModel.getById(id);

    if (!entry) {
      res.status(404).json({
        success: false,
        error: 'Запись черного списка не найдена'
      });
      return;
    }

    res.json({
      success: true,
      data: entry,
      message: 'Запись черного списка получена успешно'
    });
  } catch (error) {
    log.error(`Error getting blacklist entry ${req.params.id || 'unknown'}:`, error);
    res.status(500).json({
      success: false,
      error: 'Ошибка получения записи черного списка'
    });
  }
}

/**
 * Проверка номера в черном списке
 */
export async function checkBlacklist(req: Request, res: Response): Promise<void> {
  try {
    const phone = req.params.phone;

    if (!phone) {
      res.status(400).json({
        success: false,
        error: 'Номер телефона обязателен'
      });
      return;
    }

    const result = await blacklistModel.isBlacklisted(phone);

    res.json({
      success: true,
      data: result,
      message: result.isBlacklisted ? 'Номер заблокирован' : 'Номер не заблокирован'
    });
  } catch (error) {
    log.error(`Error checking blacklist for phone ${req.params.phone || 'unknown'}:`, error);
    res.status(500).json({
      success: false,
      error: 'Ошибка проверки черного списка'
    });
  }
}

/**
 * Обновление записи черного списка
 */
export async function updateBlacklistEntry(req: Request, res: Response): Promise<void> {
  try {
    const idParam = req.params.id;
    if (!idParam) {
      res.status(400).json({
        success: false,
        error: 'ID записи обязателен'
      });
      return;
    }

    const id = parseInt(idParam);
    const updateData: UpdateBlacklistRequest = req.body;

    if (isNaN(id)) {
      res.status(400).json({
        success: false,
        error: 'Некорректный ID записи'
      });
      return;
    }

    const entry = await blacklistModel.updateBlacklistEntry(id, updateData);

    if (!entry) {
      res.status(404).json({
        success: false,
        error: 'Запись черного списка не найдена'
      });
      return;
    }

    log.info(`Updated blacklist entry ID: ${id}`);

    res.json({
      success: true,
      data: entry,
      message: 'Запись черного списка обновлена успешно'
    });
  } catch (error) {
    log.error(`Error updating blacklist entry ${req.params.id || 'unknown'}:`, error);
    res.status(500).json({
      success: false,
      error: 'Ошибка обновления записи черного списка'
    });
  }
}

/**
 * Удаление записи из черного списка (деактивация)
 */
export async function removeFromBlacklist(req: Request, res: Response): Promise<void> {
  try {
    const idParam = req.params.id;
    if (!idParam) {
      res.status(400).json({
        success: false,
        error: 'ID записи обязателен'
      });
      return;
    }

    const id = parseInt(idParam);
    if (isNaN(id)) {
      res.status(400).json({
        success: false,
        error: 'Некорректный ID записи'
      });
      return;
    }

    const removed = await blacklistModel.removeFromBlacklist(id);

    if (!removed) {
      res.status(404).json({
        success: false,
        error: 'Запись черного списка не найдена'
      });
      return;
    }

    log.info(`Removed from blacklist ID: ${id}`);

    res.json({
      success: true,
      message: 'Номер удален из черного списка успешно'
    });
  } catch (error) {
    log.error(`Error removing from blacklist ${req.params.id || 'unknown'}:`, error);
    res.status(500).json({
      success: false,
      error: 'Ошибка удаления из черного списка'
    });
  }
}

/**
 * Физическое удаление записи черного списка
 */
export async function deleteBlacklistEntry(req: Request, res: Response): Promise<void> {
  try {
    const idParam = req.params.id;
    if (!idParam) {
      res.status(400).json({
        success: false,
        error: 'ID записи обязателен'
      });
      return;
    }

    const id = parseInt(idParam);
    if (isNaN(id)) {
      res.status(400).json({
        success: false,
        error: 'Некорректный ID записи'
      });
      return;
    }

    const deleted = await blacklistModel.deleteBlacklistEntry(id);

    if (!deleted) {
      res.status(404).json({
        success: false,
        error: 'Запись черного списка не найдена'
      });
      return;
    }

    log.info(`Deleted blacklist entry ID: ${id}`);

    res.json({
      success: true,
      message: 'Запись черного списка удалена навсегда'
    });
  } catch (error) {
    log.error(`Error deleting blacklist entry ${req.params.id || 'unknown'}:`, error);
    res.status(500).json({
      success: false,
      error: 'Ошибка удаления записи черного списка'
    });
  }
}

/**
 * Получение статистики черного списка
 */
export async function getBlacklistStats(_req: Request, res: Response): Promise<void> {
  try {
    const stats = await blacklistModel.getBlacklistStats();

    res.json({
      success: true,
      data: stats,
      message: 'Статистика черного списка получена успешно'
    });
  } catch (error) {
    log.error('Error getting blacklist statistics:', error);
    res.status(500).json({
      success: false,
      error: 'Ошибка получения статистики черного списка'
    });
  }
}

/**
 * Очистка истекших записей
 */
export async function cleanupExpiredEntries(_req: Request, res: Response): Promise<void> {
  try {
    const deactivated = await blacklistModel.cleanupExpiredEntries();

    log.info(`Manual cleanup: deactivated ${deactivated} expired entries`);

    res.json({
      success: true,
      data: { deactivated },
      message: `Деактивировано ${deactivated} истекших записей`
    });
  } catch (error) {
    log.error('Error cleaning up expired blacklist entries:', error);
    res.status(500).json({
      success: false,
      error: 'Ошибка очистки истекших записей'
    });
  }
}

/**
 * Экспорт черного списка в CSV
 */
export async function exportBlacklistCSV(_req: Request, res: Response): Promise<void> {
  try {
    const csvData = await blacklistModel.exportToCSV();

    const filename = `blacklist_export_${new Date().toISOString().split('T')[0]}.csv`;

    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.setHeader('Content-Length', Buffer.byteLength(csvData, 'utf8'));

    log.info('Exported blacklist to CSV');

    res.send(csvData);
  } catch (error) {
    log.error('Error exporting blacklist to CSV:', error);
    res.status(500).json({
      success: false,
      error: 'Ошибка экспорта черного списка'
    });
  }
}

/**
 * Импорт номеров из CSV файла
 */
export async function importBlacklistCSV(req: Request, res: Response): Promise<void> {
  try {
    const userId = (req as any).user?.id;
    const { file } = req.body; // Предполагаем, что файл обработан middleware
    const { reasonType, reason, source } = req.body;

    if (!file || !file.content) {
      res.status(400).json({
        success: false,
        error: 'CSV файл не найден'
      });
      return;
    }

    if (!reasonType) {
      res.status(400).json({
        success: false,
        error: 'Тип причины обязателен'
      });
      return;
    }

    // Парсинг CSV данных
    const lines = file.content.split('\n').filter((line: string) => line.trim().length > 0);
    const phones = lines.slice(1) // Пропускаем заголовок
      .map((line: string) => {
        const parts = line.split(',');
        return parts[0] ? parts[0].replace(/['"]/g, '').trim() : '';
      })
      .filter((phone: string) => phone.length > 0);

    if (phones.length === 0) {
      res.status(400).json({
        success: false,
        error: 'В файле не найдено номеров телефонов'
      });
      return;
    }

    const result = await blacklistModel.bulkAddToBlacklist({
      phones,
      reasonType,
      reason,
      source: source || 'csv_import'
    }, userId);

    log.info(`CSV import by user ${userId}: ${result.added} added, ${result.skipped} skipped, ${result.errors.length} errors`);

    res.json({
      success: true,
      data: result,
      message: `Импорт завершен: добавлено ${result.added}, пропущено ${result.skipped}, ошибок ${result.errors.length}`
    });
  } catch (error) {
    log.error('Error importing blacklist from CSV:', error);
    res.status(500).json({
      success: false,
      error: 'Ошибка импорта черного списка'
    });
  }
} 