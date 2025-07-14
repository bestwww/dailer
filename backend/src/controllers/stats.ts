/**
 * Контроллер статистики - детальная аналитика по кампаниям и звонкам
 * Этап 6: Расширенная функциональность
 */

import { Router, Request, Response } from 'express';
import { CallResultModel } from '@/models/call-result';
import { CampaignModel } from '@/models/campaign';
import { query } from '@/config/database';
import { log } from '@/utils/logger';

const router = Router();
const callResultModel = new CallResultModel();
const campaignModel = new CampaignModel();
// const contactModel = new ContactModel(); // Временно закомментировано, не используется

/**
 * Общая статистика по всем кампаниям
 * GET /api/stats/overview
 */
router.get('/overview', async (_req: Request, res: Response) => {
  try {
    // Получаем сводку по кампаниям
    const campaignsSummary = await campaignModel.getCampaignsSummary();
    
    // Получаем статистику по звонкам за последние 30 дней
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    
    const recentCallsStats = await query<any>(`
      SELECT 
        COUNT(*) as total_calls,
        COUNT(CASE WHEN call_status = 'answered' THEN 1 END) as answered_calls,
        COUNT(CASE WHEN call_status = 'busy' THEN 1 END) as busy_calls,
        COUNT(CASE WHEN call_status = 'no_answer' THEN 1 END) as no_answer_calls,
        COUNT(CASE WHEN call_status = 'failed' THEN 1 END) as failed_calls,
        COUNT(CASE WHEN dtmf_response = '1' THEN 1 END) as interested_responses,
        COUNT(CASE WHEN is_answering_machine = true THEN 1 END) as machine_answers,
        AVG(call_duration) as avg_call_duration,
        AVG(ring_duration) as avg_ring_duration,
        COUNT(CASE WHEN bitrix_lead_created = true THEN 1 END) as leads_created
      FROM call_results 
      WHERE created_at >= $1
    `, [thirtyDaysAgo]);

    const callStats = recentCallsStats.rows[0];
    const totalCalls = Number(callStats.total_calls || 0);
    const answeredCalls = Number(callStats.answered_calls || 0);
    const interestedResponses = Number(callStats.interested_responses || 0);
    
    const answerRate = totalCalls > 0 
      ? ((answeredCalls / totalCalls) * 100).toFixed(2)
      : '0';
    const conversionRate = answeredCalls > 0
      ? ((interestedResponses / answeredCalls) * 100).toFixed(2)
      : '0';

    res.json({
      success: true,
      data: {
        campaigns: campaignsSummary,
        callsLast30Days: {
          totalCalls,
          answeredCalls,
          busyCalls: Number(callStats.busy_calls || 0),
          noAnswerCalls: Number(callStats.no_answer_calls || 0),
          failedCalls: Number(callStats.failed_calls || 0),
          interestedResponses,
          machineAnswers: Number(callStats.machine_answers || 0),
          leadsCreated: Number(callStats.leads_created || 0),
          answerRate: parseFloat(answerRate),
          conversionRate: parseFloat(conversionRate),
          avgCallDuration: parseFloat(callStats.avg_call_duration) || 0,
          avgRingDuration: parseFloat(callStats.avg_ring_duration) || 0,
        }
      }
    });

  } catch (error) {
    log.error('Failed to get overview stats:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка получения общей статистики',
      error: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

/**
 * Детальная статистика по кампании
 * GET /api/stats/campaign/:id
 */
router.get('/campaign/:id', async (req: Request, res: Response) => {
  try {
    const campaignIdParam = req.params.id;
    if (!campaignIdParam) {
      return res.status(400).json({
        success: false,
        message: 'Некорректный ID кампании'
      });
    }
    
    const campaignId = parseInt(campaignIdParam);
    if (isNaN(campaignId)) {
      return res.status(400).json({
        success: false,
        message: 'Некорректный ID кампании'
      });
    }

    // Проверяем существование кампании
    const campaign = await campaignModel.getCampaignById(campaignId);
    if (!campaign) {
      return res.status(404).json({
        success: false,
        message: 'Кампания не найдена'
      });
    }

    // Получаем детальную статистику по кампании
    const callStats = await callResultModel.getCallStatsByCampaign(campaignId);
    
    // Получаем временную динамику звонков (по часам за последние 24 часа)
    const timeseries = await callResultModel.getCallStatsTimeseries(campaignId, 1);
    
    // Получаем топ номеров по количеству звонков
    const topNumbers = await callResultModel.getTopCallNumbers(campaignId, 10);

    // Статистика по дням недели
    const weekdayStats = await query<any>(`
      SELECT 
        EXTRACT(DOW FROM created_at) as day_of_week,
        COUNT(*) as total_calls,
        COUNT(CASE WHEN call_status = 'answered' THEN 1 END) as answered_calls,
        AVG(call_duration) as avg_duration
      FROM call_results 
      WHERE campaign_id = $1
      GROUP BY EXTRACT(DOW FROM created_at)
      ORDER BY day_of_week
    `, [campaignId]);

    // Статистика по часам дня
    const hourlyStats = await query<any>(`
      SELECT 
        EXTRACT(HOUR FROM created_at) as hour,
        COUNT(*) as total_calls,
        COUNT(CASE WHEN call_status = 'answered' THEN 1 END) as answered_calls,
        AVG(call_duration) as avg_duration
      FROM call_results 
      WHERE campaign_id = $1
      GROUP BY EXTRACT(HOUR FROM created_at)
      ORDER BY hour
    `, [campaignId]);

    return res.json({
      success: true,
      data: {
        campaign: {
          id: campaign.id,
          name: campaign.name,
          status: campaign.status,
          createdAt: campaign.createdAt
        },
        callStats,
        timeseries,
        topNumbers,
        weekdayStats: weekdayStats.rows.map(row => ({
          dayOfWeek: parseInt(row.day_of_week),
          totalCalls: parseInt(row.total_calls),
          answeredCalls: parseInt(row.answered_calls),
          avgDuration: parseFloat(row.avg_duration) || 0
        })),
        hourlyStats: hourlyStats.rows.map(row => ({
          hour: parseInt(row.hour),
          totalCalls: parseInt(row.total_calls),
          answeredCalls: parseInt(row.answered_calls),
          avgDuration: parseFloat(row.avg_duration) || 0
        }))
      }
    });

  } catch (error) {
    log.error('Failed to get campaign stats:', error);
    return res.status(500).json({
      success: false,
      message: 'Ошибка получения статистики кампании',
      error: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

/**
 * Сравнение кампаний
 * POST /api/stats/compare
 */
router.post('/compare', async (req: Request, res: Response) => {
  try {
    const { campaignIds } = req.body;
    
    if (!Array.isArray(campaignIds) || campaignIds.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Необходимо указать ID кампаний для сравнения'
      });
    }

    const comparisons = [];

    for (const campaignId of campaignIds) {
      const campaign = await campaignModel.getCampaignById(campaignId);
      if (campaign) {
        const stats = await callResultModel.getCallStatsByCampaign(campaignId);
        comparisons.push({
          campaign: {
            id: campaign.id,
            name: campaign.name,
            status: campaign.status,
            createdAt: campaign.createdAt
          },
          stats
        });
      }
    }

    return res.json({
      success: true,
      data: {
        comparisons,
        totalCampaigns: comparisons.length
      }
    });

  } catch (error) {
    log.error('Failed to compare campaigns:', error);
    return res.status(500).json({
      success: false,
      message: 'Ошибка сравнения кампаний',
      error: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

/**
 * Экспорт статистики в CSV
 * GET /api/stats/export/campaign/:id
 */
router.get('/export/campaign/:id', async (req: Request, res: Response) => {
  try {
    const campaignIdParam = req.params.id;
    if (!campaignIdParam) {
      return res.status(400).json({
        success: false,
        message: 'Некорректный ID кампании'
      });
    }
    
    const campaignId = parseInt(campaignIdParam);
    const format = (req.query.format as string) || 'csv';
    
    if (isNaN(campaignId)) {
      return res.status(400).json({
        success: false,
        message: 'Некорректный ID кампании'
      });
    }

    // Получаем все результаты звонков по кампании
    const callResults = await query<any>(`
      SELECT 
        cr.*,
        c.name as contact_name,
        c.phone as contact_phone,
        cam.name as campaign_name
      FROM call_results cr
      LEFT JOIN contacts c ON cr.contact_id = c.id
      LEFT JOIN campaigns cam ON cr.campaign_id = cam.id
      WHERE cr.campaign_id = $1
      ORDER BY cr.created_at DESC
    `, [campaignId]);

    if (format === 'csv') {
      // Генерируем CSV
      const csvHeaders = [
        'ID',
        'Номер телефона',
        'Имя контакта',
        'Статус звонка',
        'Длительность (сек)',
        'DTMF ответ',
        'Автоответчик',
        'Лид создан',
        'Дата звонка'
      ].join(',');

      const csvRows = callResults.rows.map(row => [
        row.id,
        row.phone_number,
        row.contact_name || '',
        row.call_status,
        row.call_duration || 0,
        row.dtmf_response || '',
        row.is_answering_machine ? 'Да' : 'Нет',
        row.bitrix_lead_created ? 'Да' : 'Нет',
        new Date(row.created_at).toLocaleString('ru-RU')
      ].join(','));

      const csvContent = [csvHeaders, ...csvRows].join('\n');

      res.setHeader('Content-Type', 'text/csv; charset=utf-8');
      res.setHeader('Content-Disposition', `attachment; filename="campaign_${campaignId}_stats.csv"`);
      return res.send('\uFEFF' + csvContent); // BOM для корректного отображения в Excel

    } else {
      return res.json({
        success: true,
        data: callResults.rows
      });
    }

  } catch (error) {
    log.error('Failed to export campaign stats:', error);
    return res.status(500).json({
      success: false,
      message: 'Ошибка экспорта статистики',
      error: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

/**
 * Real-time статистика для дашборда
 * GET /api/stats/realtime
 */
router.get('/realtime', async (_req: Request, res: Response) => {
  try {
    const now = new Date();
    const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);

    // Статистика за последний час
    const realtimeStats = await query<any>(`
      SELECT 
        COUNT(*) as calls_last_hour,
        COUNT(CASE WHEN call_status = 'answered' THEN 1 END) as answered_last_hour,
        COUNT(CASE WHEN dtmf_response = '1' THEN 1 END) as interested_last_hour,
        COUNT(CASE WHEN created_at >= $2 THEN 1 END) as calls_last_10min
      FROM call_results 
      WHERE created_at >= $1
    `, [oneHourAgo, new Date(now.getTime() - 10 * 60 * 1000)]);

    // Активные кампании
    const activeCampaigns = await campaignModel.getActiveCampaigns();

    const stats = realtimeStats.rows[0];

    res.json({
      success: true,
      data: {
        callsLastHour: parseInt(stats.calls_last_hour),
        answeredLastHour: parseInt(stats.answered_last_hour),
        interestedLastHour: parseInt(stats.interested_last_hour),
        callsLast10Min: parseInt(stats.calls_last_10min),
        activeCampaigns: activeCampaigns.length,
        timestamp: now.toISOString()
      }
    });

  } catch (error) {
    log.error('Failed to get realtime stats:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка получения realtime статистики',
      error: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

/**
 * Системная статистика
 * GET /api/stats/system
 */
router.get('/system', async (_req: Request, res: Response) => {
  try {
    // Получаем базовую статистику системы
    const now = new Date();
    const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
    const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    
    // Статистика за последний час
    const hourlyStats = await query<any>(`
      SELECT 
        COUNT(*) as total_calls,
        COUNT(CASE WHEN call_status = 'answered' THEN 1 END) as answered_calls,
        COUNT(CASE WHEN call_status = 'failed' THEN 1 END) as failed_calls,
        AVG(call_duration) as avg_call_duration
      FROM call_results 
      WHERE created_at >= $1
    `, [oneHourAgo]);

    // Статистика за последние 24 часа
    const dailyStats = await query<any>(`
      SELECT 
        COUNT(*) as total_calls,
        COUNT(CASE WHEN call_status = 'answered' THEN 1 END) as answered_calls,
        COUNT(CASE WHEN call_status = 'failed' THEN 1 END) as failed_calls,
        COUNT(CASE WHEN dtmf_response = '1' THEN 1 END) as interested_responses,
        AVG(call_duration) as avg_call_duration
      FROM call_results 
      WHERE created_at >= $1
    `, [oneDayAgo]);

    // Активные кампании
    const activeCampaigns = await campaignModel.getActiveCampaigns();

    // Статистика по памяти процесса
    const memoryUsage = process.memoryUsage();

    const hourStats = hourlyStats.rows[0];
    const dayStats = dailyStats.rows[0];

    res.json({
      success: true,
      data: {
        // Статистика за час
        hourly: {
          totalCalls: parseInt(hourStats.total_calls || 0),
          answeredCalls: parseInt(hourStats.answered_calls || 0),
          failedCalls: parseInt(hourStats.failed_calls || 0),
          avgCallDuration: parseFloat(hourStats.avg_call_duration || 0),
          answerRate: hourStats.total_calls > 0 ? 
            (hourStats.answered_calls / hourStats.total_calls * 100).toFixed(2) : 0
        },
        // Статистика за день
        daily: {
          totalCalls: parseInt(dayStats.total_calls || 0),
          answeredCalls: parseInt(dayStats.answered_calls || 0),
          failedCalls: parseInt(dayStats.failed_calls || 0),
          interestedResponses: parseInt(dayStats.interested_responses || 0),
          avgCallDuration: parseFloat(dayStats.avg_call_duration || 0),
          answerRate: dayStats.total_calls > 0 ? 
            (dayStats.answered_calls / dayStats.total_calls * 100).toFixed(2) : 0
        },
        // Системная информация
        system: {
          uptime: process.uptime(),
          activeCampaigns: activeCampaigns.length,
          memory: {
            used: Math.round(memoryUsage.heapUsed / 1024 / 1024),
            total: Math.round(memoryUsage.heapTotal / 1024 / 1024),
            external: Math.round(memoryUsage.external / 1024 / 1024),
            rss: Math.round(memoryUsage.rss / 1024 / 1024)
          }
        },
        timestamp: now.toISOString()
      }
    });

  } catch (error) {
    log.error('Failed to get system stats:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка получения системной статистики',
      error: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

export default router; 