/**
 * Контроллер настроек времени - управление временными настройками кампаний
 * Этап 6.2.4: Настройки времени обзвона и часовые пояса
 */

import { Request, Response } from 'express';
import { timezoneService } from '@/services/timezone';
import { campaignModel } from '@/models/campaign';
import { contactModel } from "@/models/contact";
import { query } from "@/config/database";
import { log } from '@/utils/logger';
import { UpdateCampaignRequest } from '@/types';

/**
 * Получение списка поддерживаемых часовых поясов
 * GET /api/time-settings/timezones
 */
export async function getSupportedTimezones(_req: Request, res: Response): Promise<void> {
  try {
    const timezones = timezoneService.getSupportedTimezones();
    const timezoneInfos = timezones.map(tz => {
      const info = timezoneService.getTimezoneInfo(tz);
      return {
        timezone: tz,
        offset: info.offset,
        isDST: info.isDST,
        name: info.name,
        abbreviation: info.abbreviation,
        offsetString: timezoneService.getTimezoneOffsetString(tz)
      };
    });

    res.json({
      success: true,
      data: {
        timezones: timezoneInfos,
        defaultTimezone: timezoneService.getDefaultTimezone()
      },
      message: 'Список часовых поясов получен успешно'
    });
  } catch (error) {
    log.error('Ошибка получения часовых поясов:', error);
    res.status(500).json({
      success: false,
      error: 'Ошибка получения часовых поясов'
    });
  }
}

/**
 * Получение информации о часовом поясе
 * GET /api/time-settings/timezone/:timezone
 */
export async function getTimezoneInfo(req: Request, res: Response): Promise<void> {
  try {
    const { timezone } = req.params;

    if (!timezone) {
      res.status(400).json({
        success: false,
        error: 'Часовой пояс не указан'
      });
      return;
    }

    // Декодируем URL-encoded строку
    const decodedTimezone = decodeURIComponent(timezone);

    if (!timezoneService.isValidTimezone(decodedTimezone)) {
      res.status(400).json({
        success: false,
        error: 'Некорректный часовой пояс'
      });
      return;
    }

    const info = timezoneService.getTimezoneInfo(decodedTimezone);
    const offsetString = timezoneService.getTimezoneOffsetString(decodedTimezone);
    const currentTime = timezoneService.getCurrentTimeInTimezone(decodedTimezone);

    res.json({
      success: true,
      data: {
        ...info,
        offsetString,
        currentTime: timezoneService.formatTimeForDisplay(currentTime, decodedTimezone)
      },
      message: 'Информация о часовом поясе получена успешно'
    });
  } catch (error) {
    log.error('Ошибка получения информации о часовом поясе:', error);
    res.status(500).json({
      success: false,
      error: 'Ошибка получения информации о часовом поясе'
    });
  }
}

/**
 * Обновление настроек времени кампании
 * PUT /api/time-settings/campaign/:id
 */
export async function updateCampaignTimeSettings(req: Request, res: Response): Promise<void> {
  try {
    const campaignIdParam = req.params.id; if (!campaignIdParam) { res.status(400).json({ success: false, error: "ID кампании не указан" }); return; } const campaignId = parseInt(campaignIdParam);
    const { workTimeStart, workTimeEnd, workDays, timezone } = req.body;

    if (isNaN(campaignId)) {
      res.status(400).json({
        success: false,
        error: 'Некорректный ID кампании'
      });
      return;
    }

    // Проверка существования кампании
    const campaign = await campaignModel.getCampaignById(campaignId);
    if (!campaign) {
      res.status(404).json({
        success: false,
        error: 'Кампания не найдена'
      });
      return;
    }

    // Валидация времени
    if (workTimeStart && workTimeEnd) {
      try {
        timezoneService.parseTimeSlot(workTimeStart);
        timezoneService.parseTimeSlot(workTimeEnd);
      } catch (error) {
        res.status(400).json({
          success: false,
          error: 'Некорректный формат времени. Используйте формат HH:mm'
        });
        return;
      }
    }

    // Валидация дней недели
    if (workDays && Array.isArray(workDays)) {
      const validDays = workDays.every(day => typeof day === 'number' && day >= 1 && day <= 7);
      if (!validDays) {
        res.status(400).json({
          success: false,
          error: 'Некорректные дни недели. Используйте числа от 1 до 7'
        });
        return;
      }
    }

    // Валидация часового пояса
    if (timezone && !timezoneService.isValidTimezone(timezone)) {
      res.status(400).json({
        success: false,
        error: 'Некорректный часовой пояс'
      });
      return;
    }

    // Обновление кампании
    const updateData: UpdateCampaignRequest = {};
    if (workTimeStart) updateData.workTimeStart = workTimeStart;
    if (workTimeEnd) updateData.workTimeEnd = workTimeEnd;
    if (workDays) updateData.workDays = workDays;
    if (timezone) updateData.timezone = timezone;

    const updatedCampaign = await campaignModel.updateCampaign(campaignId, updateData);

    if (!updatedCampaign) {
      res.status(500).json({
        success: false,
        error: 'Ошибка обновления настроек времени кампании'
      });
      return;
    }

    log.info(`Обновлены настройки времени кампании ${campaignId}`, {
      workTimeStart,
      workTimeEnd,
      workDays,
      timezone
    });

    res.json({
      success: true,
      data: updatedCampaign,
      message: 'Настройки времени кампании обновлены успешно'
    });
  } catch (error) {
    log.error('Ошибка обновления настроек времени кампании:', error);
    res.status(500).json({
      success: false,
      error: 'Ошибка обновления настроек времени кампании'
    });
  }
}

/**
 * Проверка рабочего времени кампании
 * GET /api/time-settings/campaign/:id/working-time
 */
export async function checkCampaignWorkingTime(req: Request, res: Response): Promise<void> {
  try {
    const campaignIdParam = req.params.id; if (!campaignIdParam) { res.status(400).json({ success: false, error: "ID кампании не указан" }); return; } const campaignId = parseInt(campaignIdParam);
    const { checkDate } = req.query;

    if (isNaN(campaignId)) {
      res.status(400).json({
        success: false,
        error: 'Некорректный ID кампании'
      });
      return;
    }

    const campaign = await campaignModel.getCampaignById(campaignId);
    if (!campaign) {
      res.status(404).json({
        success: false,
        error: 'Кампания не найдена'
      });
      return;
    }

    const testDate = checkDate ? new Date(checkDate as string) : undefined;
    const isWorking = timezoneService.isCampaignWorkingTime(campaign, testDate);
    const nextWorkingTime = timezoneService.getNextWorkingTime(campaign, testDate);

    res.json({
      success: true,
      data: {
        isWorkingTime: isWorking,
        nextWorkingTime: nextWorkingTime.toISOString(),
        nextWorkingTimeFormatted: timezoneService.formatTimeForDisplay(nextWorkingTime, campaign.timezone),
        campaignTimezone: campaign.timezone,
        currentTime: timezoneService.formatTimeForDisplay(
          timezoneService.getCurrentTimeInTimezone(campaign.timezone),
          campaign.timezone
        )
      },
      message: 'Проверка рабочего времени выполнена успешно'
    });
  } catch (error) {
    log.error('Ошибка проверки рабочего времени кампании:', error);
    res.status(500).json({
      success: false,
      error: 'Ошибка проверки рабочего времени кампании'
    });
  }
}

/**
 * Массовое обновление часовых поясов контактов
 * PUT /api/time-settings/contacts/timezone
 */
export async function updateContactsTimezone(req: Request, res: Response): Promise<void> {
  try {
    const { contactIds, timezone } = req.body;

    if (!Array.isArray(contactIds) || contactIds.length === 0) {
      res.status(400).json({
        success: false,
        error: 'Необходимо указать ID контактов'
      });
      return;
    }

    if (!timezone || !timezoneService.isValidTimezone(timezone)) {
      res.status(400).json({
        success: false,
        error: 'Некорректный часовой пояс'
      });
      return;
    }

    let updatedCount = 0;
    const errors: string[] = [];

    for (const contactId of contactIds) {
      try {
        await contactModel.updateContact(contactId, { timezone });
        updatedCount++;
      } catch (error) {
        errors.push(`Ошибка обновления контакта ${contactId}: ${error}`);
      }
    }

    log.info(`Обновлен часовой пояс для ${updatedCount} контактов`, {
      timezone,
      totalRequested: contactIds.length,
      errors: errors.length
    });

    res.json({
      success: true,
      data: {
        updatedCount,
        totalRequested: contactIds.length,
        errors: errors.length > 0 ? errors : undefined
      },
      message: `Часовой пояс обновлен для ${updatedCount} из ${contactIds.length} контактов`
    });
  } catch (error) {
    log.error('Ошибка массового обновления часовых поясов контактов:', error);
    res.status(500).json({
      success: false,
      error: 'Ошибка обновления часовых поясов контактов'
    });
  }
}

/**
 * Получение статистики по часовым поясам
 * GET /api/time-settings/stats
 */
export async function getTimezoneStats(req: Request, res: Response): Promise<void> {
  try {
    const { campaignId } = req.query;

    // Базовый SQL запрос для статистики часовых поясов
    let queryStr = `
      SELECT 
        timezone,
        COUNT(*) as contact_count,
        COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_count,
        COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed_count
      FROM contacts
    `;

    const params: any[] = [];

    if (campaignId) {
      queryStr += ` WHERE campaign_id = $1`;
      params.push(parseInt(campaignId as string));
    }

    queryStr += `
      GROUP BY timezone
      ORDER BY contact_count DESC
    `;

    const result = await query(queryStr, params);

    const stats = result.rows.map((row: any) => ({
      timezone: row.timezone,
      contactCount: parseInt(row.contact_count),
      completedCount: parseInt(row.completed_count),
      failedCount: parseInt(row.failed_count),
      timezoneInfo: timezoneService.getTimezoneInfo(row.timezone),
      offsetString: timezoneService.getTimezoneOffsetString(row.timezone),
      currentTime: timezoneService.formatTimeForDisplay(
        timezoneService.getCurrentTimeInTimezone(row.timezone),
        row.timezone
      )
    }));

    res.json({
      success: true,
      data: {
        stats,
        totalTimezones: stats.length,
        totalContacts: stats.reduce((sum: number, stat: any) => sum + stat.contactCount, 0)
      },
      message: 'Статистика часовых поясов получена успешно'
    });
  } catch (error) {
    log.error('Ошибка получения статистики часовых поясов:', error);
    res.status(500).json({
      success: false,
      error: 'Ошибка получения статистики часовых поясов'
    });
  }
}

/**
 * Валидация настроек времени
 * POST /api/time-settings/validate
 */
export async function validateTimeSettings(req: Request, res: Response): Promise<void> {
  try {
    const { workTimeStart, workTimeEnd, workDays, timezone } = req.body;

    const validationErrors: string[] = [];

    // Валидация времени
    if (workTimeStart) {
      try {
        timezoneService.parseTimeSlot(workTimeStart);
             } catch (error) {
         validationErrors.push(`Некорректное время начала: ${String(error)}`);
       }
    }

    if (workTimeEnd) {
      try {
        timezoneService.parseTimeSlot(workTimeEnd);
      } catch (error) {
        validationErrors.push(`Некорректное время окончания: ${error}`);
      }
    }

    // Валидация дней недели
    if (workDays && Array.isArray(workDays)) {
      const validDays = workDays.every(day => typeof day === 'number' && day >= 1 && day <= 7);
      if (!validDays) {
        validationErrors.push('Некорректные дни недели. Используйте числа от 1 до 7');
      }
    }

    // Валидация часового пояса
    if (timezone && !timezoneService.isValidTimezone(timezone)) {
      validationErrors.push('Некорректный часовой пояс');
    }

    const isValid = validationErrors.length === 0;

    res.json({
      success: true,
      data: {
        isValid,
        errors: validationErrors
      },
      message: isValid ? 'Настройки времени корректны' : 'Найдены ошибки в настройках времени'
    });
  } catch (error) {
    log.error('Ошибка валидации настроек времени:', error);
    res.status(500).json({
      success: false,
      error: 'Ошибка валидации настроек времени'
    });
  }
} 