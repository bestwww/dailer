/**
 * Контроллер кампаний автодозвона
 */

import { Request, Response } from 'express';
import { campaignModel } from '@/models/campaign';
import { contactModel } from '@/models/contact';
import { dialerService } from '@/services/dialer';
import { schedulerService } from '@/services/scheduler';
import { log } from '@/utils/logger';
import { CreateCampaignRequest, UpdateCampaignRequest, CampaignStatus } from '@/types';

/**
 * Валидация и парсинг ID из параметров запроса
 */
function validateAndParseId(req: Request, res: Response, paramName: string = 'id'): number | null {
  const idParam = req.params[paramName];
  if (!idParam) {
    res.status(400).json({
      success: false,
      error: `${paramName} не указан`
    });
    return null;
  }

  const id = parseInt(idParam);
  if (isNaN(id) || id <= 0) {
    res.status(400).json({
      success: false,
      error: `${paramName} должен быть положительным числом`
    });
    return null;
  }

  return id;
}

/**
 * Получение списка кампаний
 */
export async function getCampaigns(req: Request, res: Response): Promise<void> {
  try {
    const page = parseInt(req.query.page as string) || 1;
    const limit = parseInt(req.query.limit as string) || 10;
    const status = req.query.status as CampaignStatus;
    const createdBy = req.query.createdBy ? parseInt(req.query.createdBy as string) : undefined;

    const result = await campaignModel.getCampaigns(page, limit, status, createdBy);

    log.api(`Retrieved ${result.campaigns.length} campaigns (page ${page})`);

    res.json({
      success: true,
      data: result.campaigns,
      pagination: {
        page: result.page,
        limit,
        total: result.total,
        totalPages: result.totalPages,
      },
      message: 'Список кампаний получен успешно'
    });
  } catch (error) {
    log.error('Error getting campaigns:', error);
    res.status(500).json({
      success: false,
      error: 'Ошибка получения списка кампаний'
    });
  }
}

/**
 * Создание новой кампании
 */
export async function createCampaign(req: Request, res: Response): Promise<void> {
  try {
    const userId = (req as any).user?.id; // Из middleware авторизации
    
    const campaignData: CreateCampaignRequest = {
      ...req.body,
      createdBy: userId
    };

    const campaign = await campaignModel.createCampaign(campaignData, userId);

    log.info(`Created campaign: ${campaign.name} (ID: ${campaign.id}) by user ${userId}`);

    res.status(201).json({
      success: true,
      data: campaign,
      message: 'Кампания создана успешно'
    });
  } catch (error) {
    log.error('Error creating campaign:', error);
    res.status(500).json({
      success: false,
      error: 'Ошибка создания кампании'
    });
  }
}

/**
 * Получение кампании по ID
 */
export async function getCampaignById(req: Request, res: Response): Promise<void> {
  try {
    const id = validateAndParseId(req, res);
    if (id === null) {
      return;
    }

    const campaign = await campaignModel.getCampaignById(id);

    if (!campaign) {
      res.status(404).json({
        success: false,
        error: 'Кампания не найдена'
      });
      return;
    }

    // Получаем статистику по контактам
    const contactStats = await contactModel.getContactsStatsByCampaign(id);

    res.json({
      success: true,
      data: {
        campaign,
        contactStats,
      },
      message: 'Кампания получена успешно'
    });
  } catch (error) {
    log.error(`Error getting campaign ${req.params.id || 'unknown'}:`, error);
    res.status(500).json({
      success: false,
      error: 'Ошибка получения кампании'
    });
  }
}

/**
 * Обновление кампании
 */
export async function updateCampaign(req: Request, res: Response): Promise<void> {
  try {
    const id = validateAndParseId(req, res);
    if (id === null) {
      return;
    }

    const updateData: UpdateCampaignRequest = req.body;
    const campaign = await campaignModel.updateCampaign(id, updateData);

    if (!campaign) {
      res.status(404).json({
        success: false,
        error: 'Кампания не найдена'
      });
      return;
    }

    log.info(`Updated campaign: ${campaign.name} (ID: ${id})`);

    res.json({
      success: true,
      data: campaign,
      message: 'Кампания обновлена успешно'
    });
  } catch (error) {
    log.error(`Error updating campaign ${req.params.id || 'unknown'}:`, error);
    res.status(500).json({
      success: false,
      error: 'Ошибка обновления кампании'
    });
  }
}

/**
 * Удаление кампании
 */
export async function deleteCampaign(req: Request, res: Response): Promise<void> {
  try {
    const id = validateAndParseId(req, res);
    if (id === null) {
      return;
    }

    // Проверяем, что кампания не активна
    const campaign = await campaignModel.getCampaignById(id);
    if (!campaign) {
      res.status(404).json({
        success: false,
        error: 'Кампания не найдена'
      });
      return;
    }

    if (campaign.status === 'active') {
      res.status(400).json({
        success: false,
        error: 'Нельзя удалить активную кампанию'
      });
      return;
    }

    await campaignModel.deleteCampaign(id);

    log.info(`Deleted campaign ID: ${id}`);

    res.json({
      success: true,
      message: 'Кампания удалена успешно'
    });
  } catch (error) {
    log.error(`Error deleting campaign ${req.params.id || 'unknown'}:`, error);
    res.status(500).json({
      success: false,
      error: 'Ошибка удаления кампании'
    });
  }
}

/**
 * Запуск кампании
 */
export async function startCampaign(req: Request, res: Response): Promise<void> {
  try {
    const id = validateAndParseId(req, res);
    if (id === null) {
      return;
    }

    // Проверка возможности запуска
    const canStart = await campaignModel.canStartCampaign(id);
    if (!canStart.canStart) {
      res.status(400).json({
        success: false,
        error: canStart.reason
      });
      return;
    }

    // Запускаем кампанию в диалере
    await dialerService.startCampaign(id);

    // Получаем обновленную кампанию
    const updatedCampaign = await campaignModel.getCampaignById(id);

    log.info(`Started campaign ID: ${id}`);

    res.json({
      success: true,
      message: 'Кампания запущена успешно',
      data: updatedCampaign
    });
  } catch (error) {
    log.error(`Error starting campaign ${req.params.id || 'unknown'}:`, error);
    res.status(500).json({
      success: false,
      error: 'Ошибка запуска кампании'
    });
  }
}

/**
 * Остановка кампании
 */
export async function stopCampaign(req: Request, res: Response): Promise<void> {
  try {
    const id = validateAndParseId(req, res);
    if (id === null) {
      return;
    }

    // Останавливаем кампанию в диалере
    await dialerService.stopCampaign(id);

    // Получаем обновленную кампанию
    const updatedCampaign = await campaignModel.getCampaignById(id);

    log.info(`Stopped campaign ID: ${id}`);

    res.json({
      success: true,
      message: 'Кампания остановлена успешно',
      data: updatedCampaign
    });
  } catch (error) {
    log.error(`Error stopping campaign ${req.params.id || 'unknown'}:`, error);
    res.status(500).json({
      success: false,
      error: 'Ошибка остановки кампании'
    });
  }
}

/**
 * Приостановка кампании
 */
export async function pauseCampaign(req: Request, res: Response): Promise<void> {
  try {
    const id = validateAndParseId(req, res);
    if (id === null) {
      return;
    }

    // Приостанавливаем кампанию в диалере
    await dialerService.pauseCampaign(id);

    // Получаем обновленную кампанию
    const updatedCampaign = await campaignModel.getCampaignById(id);

    log.info(`Paused campaign ID: ${id}`);

    res.json({
      success: true,
      message: 'Кампания приостановлена успешно',
      data: updatedCampaign
    });
  } catch (error) {
    log.error(`Error pausing campaign ${req.params.id || 'unknown'}:`, error);
    res.status(500).json({
      success: false,
      error: 'Ошибка приостановки кампании'
    });
  }
}

/**
 * Получение статистики кампаний
 */
export async function getCampaignsStats(_req: Request, res: Response): Promise<void> {
  try {
    const stats = await campaignModel.getCampaignsSummary();
    
    res.json({
      success: true,
      data: stats,
      message: 'Статистика кампаний получена успешно'
    });
  } catch (error) {
    log.error('Error getting campaigns stats:', error);
    res.status(500).json({
      success: false,
      error: 'Ошибка получения статистики кампаний'
    });
  }
}

/**
 * Загрузка аудио файла для кампании
 */
export async function uploadCampaignAudio(req: Request, res: Response): Promise<void> {
  try {
    const id = validateAndParseId(req, res);
    if (id === null) {
      return;
    }

    log.info(`🔍 DEBUG: Загрузка аудио файла для кампании ${id}`);
    log.info(`📁 Файл получен:`, req.file ? `${req.file.originalname} (${req.file.size} bytes)` : 'нет файла');

    const file = req.file;
    if (!file) {
      log.warn(`❌ Аудио файл не предоставлен для кампании ${id}`);
      res.status(400).json({
        success: false,
        error: 'Аудио файл не предоставлен'
      });
      return;
    }

    // Проверяем, что кампания существует
    const campaign = await campaignModel.getCampaignById(id);
    if (!campaign) {
      log.warn(`❌ Кампания ${id} не найдена`);
      res.status(404).json({
        success: false,
        error: 'Кампания не найдена'
      });
      return;
    }

    log.info(`📂 Файл для загрузки: ${file.originalname}, размер: ${file.size}, путь: ${file.path}`);

    // Обновляем информацию об аудио файле
    // TODO: Добавить определение длительности аудио
    const audioDuration = 30; // Заглушка
    
    // Сохраняем только имя файла без пути (убираем префикс "audio\")
    const fileName = file.filename; // multer уже генерирует уникальное имя
    
    // Исправляем кодировку оригинального имени файла (для корректной работы с кириллицей)
    const originalName = Buffer.from(file.originalname, 'latin1').toString('utf8');
    log.info(`📝 Оригинальное имя файла после декодирования: ${originalName}`);
    
    const updatedCampaign = await campaignModel.updateCampaignAudio(id, fileName, originalName, audioDuration);

    log.info(`✅ Uploaded audio for campaign ${id}: ${file.originalname}`);

    res.json({
      success: true,
      data: updatedCampaign,
      message: 'Аудио файл загружен успешно'
    });
  } catch (error) {
    log.error(`❌ Error uploading audio for campaign ${req.params.id || 'unknown'}:`, error);
    res.status(500).json({
      success: false,
      error: 'Ошибка загрузки аудио файла'
    });
  }
}

/**
 * Планирование кампании
 */
export async function scheduleCampaign(req: Request, res: Response): Promise<void> {
  try {
    const id = validateAndParseId(req, res);
    if (id === null) {
      return;
    }

    const { scheduledStart, scheduledStop, isRecurring, cronExpression } = req.body;

    // Валидация расписания
    if (!scheduledStart) {
      res.status(400).json({
        success: false,
        error: 'Время запуска не указано'
      });
      return;
    }

    if (isRecurring && !cronExpression) {
      res.status(400).json({
        success: false,
        error: 'Для повторяющихся кампаний требуется cron выражение'
      });
      return;
    }

    // Обновляем кампанию
    const updateData: UpdateCampaignRequest = {
      isScheduled: true,
      scheduledStart: new Date(scheduledStart),
      isRecurring,
      cronExpression
    };
    
    if (scheduledStop) {
      updateData.scheduledStop = new Date(scheduledStop);
    }
    
    const campaign = await campaignModel.updateCampaign(id, updateData);

    if (!campaign) {
      res.status(404).json({
        success: false,
        error: 'Кампания не найдена'
      });
      return;
    }

    // Планируем в планировщике
    await schedulerService.scheduleCampaign(campaign);

    log.info(`Scheduled campaign: ${campaign.name} (ID: ${id})`);

    res.json({
      success: true,
      data: campaign,
      message: 'Кампания запланирована успешно'
    });
  } catch (error) {
    log.error(`Error scheduling campaign ${req.params.id || 'unknown'}:`, error);
    res.status(500).json({
      success: false,
      error: 'Ошибка планирования кампании'
    });
  }
}

/**
 * Отмена планирования кампании
 */
export async function unscheduleCampaign(req: Request, res: Response): Promise<void> {
  try {
    const id = validateAndParseId(req, res);
    if (id === null) {
      return;
    }

    // Обновляем кампанию
    const updateData: UpdateCampaignRequest = {
      isScheduled: false,
      isRecurring: false
    };
    
    const campaign = await campaignModel.updateCampaign(id, updateData);

    if (!campaign) {
      res.status(404).json({
        success: false,
        error: 'Кампания не найдена'
      });
      return;
    }

    // Отменяем планирование
    await schedulerService.unscheduleCampaign(id);

    log.info(`Unscheduled campaign: ${campaign.name} (ID: ${id})`);

    res.json({
      success: true,
      data: campaign,
      message: 'Планирование кампании отменено успешно'
    });
  } catch (error) {
    log.error(`Error unscheduling campaign ${req.params.id || 'unknown'}:`, error);
    res.status(500).json({
      success: false,
      error: 'Ошибка отмены планирования кампании'
    });
  }
}

/**
 * Получение запланированных кампаний
 */
export async function getScheduledCampaigns(_req: Request, res: Response): Promise<void> {
  try {
    const campaigns = await campaignModel.getScheduledCampaigns();
    
    res.json({
      success: true,
      data: campaigns,
      message: 'Запланированные кампании получены успешно'
    });
  } catch (error) {
    log.error('Error getting scheduled campaigns:', error);
    res.status(500).json({
      success: false,
      error: 'Ошибка получения запланированных кампаний'
    });
  }
}

/**
 * Получение статуса планировщика
 */
export async function getSchedulerStatus(_req: Request, res: Response): Promise<void> {
  try {
    const status = await schedulerService.getStatus();
    
    res.json({
      success: true,
      data: status,
      message: 'Статус планировщика получен успешно'
    });
  } catch (error) {
    log.error('Error getting scheduler status:', error);
    res.status(500).json({
      success: false,
      error: 'Ошибка получения статуса планировщика'
    });
  }
}

/**
 * Валидация cron выражения
 */
export async function validateCronExpression(req: Request, res: Response): Promise<void> {
  try {
    const { cronExpression } = req.body;
    
    if (!cronExpression) {
      res.status(400).json({
        success: false,
        error: 'Cron выражение не указано'
      });
      return;
    }

    const isValid = await schedulerService.validateCronExpression(cronExpression);
    
    res.json({
      success: true,
      data: { isValid },
      message: isValid ? 'Cron выражение корректно' : 'Cron выражение некорректно'
    });
  } catch (error) {
    log.error('Error validating cron expression:', error);
    res.status(500).json({
      success: false,
      error: 'Ошибка валидации cron выражения'
    });
  }
} 