/**
 * Контроллер результатов звонков
 * Базовая функциональность для отображения результатов звонков
 */

import { Router, Request, Response } from 'express';
import { query } from '@/config/database';
import { log } from '@/utils/logger';

const router = Router();

/**
 * Получить результаты звонков с пагинацией
 * GET /api/calls/results (для роута `/call-results`)
 */
router.get('/results', async (req: Request, res: Response) => {
  try {
    const { 
      campaignId, 
      limit = 10, 
      offset = 0,
      status,
      startDate,
      endDate 
    } = req.query;

    // Построение SQL запроса с фильтрами
    let whereClause = '1=1';
    const params: any[] = [];
    let paramIndex = 1;

    if (campaignId) {
      whereClause += ` AND campaign_id = $${paramIndex}`;
      params.push(parseInt(campaignId as string));
      paramIndex++;
    }

    if (status) {
      whereClause += ` AND call_status = $${paramIndex}`;
      params.push(status);
      paramIndex++;
    }

    if (startDate) {
      whereClause += ` AND created_at >= $${paramIndex}`;
      params.push(new Date(startDate as string));
      paramIndex++;
    }

    if (endDate) {
      whereClause += ` AND created_at <= $${paramIndex}`;
      params.push(new Date(endDate as string));
      paramIndex++;
    }

    // Подсчет общего количества записей
    const countQuery = `
      SELECT COUNT(*) as total 
      FROM call_results 
      WHERE ${whereClause}
    `;
    const countResult = await query<{ total: string }>(countQuery, params);
    const totalCount = parseInt(countResult.rows[0]?.total || '0');

    // Получение данных с пагинацией
    const dataQuery = `
      SELECT 
        id, 
        campaign_id,
        contact_id,
        phone_number,
        call_status,
        call_duration,
        ring_duration,
        dtmf_response,
        is_answering_machine,
        call_started_at,
        call_ended_at,
        created_at,
        bitrix_lead_created
      FROM call_results 
      WHERE ${whereClause}
      ORDER BY created_at DESC
      LIMIT $${paramIndex} OFFSET $${paramIndex + 1}
    `;
    
    params.push(parseInt(limit as string));
    params.push(parseInt(offset as string));
    
    const dataResult = await query<any>(dataQuery, params);

    res.json({
      success: true,
      data: {
        results: dataResult.rows,
        pagination: {
          total: totalCount,
          limit: parseInt(limit as string),
          offset: parseInt(offset as string),
          hasMore: (parseInt(offset as string) + parseInt(limit as string)) < totalCount
        }
      }
    });

  } catch (error) {
    log.error('Failed to get call results:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка получения результатов звонков',
      error: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

/**
 * Получить результат звонка по ID
 * GET /api/calls/results/:id
 */
router.get('/results/:id', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    
    if (!id) {
      return res.status(400).json({
        success: false,
        message: 'ID результата звонка обязателен'
      });
    }
    
    const result = await query<any>(
      `SELECT * FROM call_results WHERE id = $1`,
      [parseInt(id)]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Результат звонка не найден'
      });
    }

    return res.json({
      success: true,
      data: result.rows[0]
    });

  } catch (error) {
    log.error('Failed to get call result:', error);
    return res.status(500).json({
      success: false,
      message: 'Ошибка получения результата звонка',
      error: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

// Прямой роут для /call-results (когда вызывается через /api/call-results)
router.get('/', async (req: Request, res: Response) => {
  try {
    const { 
      campaignId, 
      limit = 10, 
      offset = 0,
      status,
      startDate,
      endDate 
    } = req.query;

    // Построение SQL запроса с фильтрами
    let whereClause = '1=1';
    const params: any[] = [];
    let paramIndex = 1;

    if (campaignId) {
      whereClause += ` AND campaign_id = $${paramIndex}`;
      params.push(parseInt(campaignId as string));
      paramIndex++;
    }

    if (status) {
      whereClause += ` AND call_status = $${paramIndex}`;
      params.push(status);
      paramIndex++;
    }

    if (startDate) {
      whereClause += ` AND created_at >= $${paramIndex}`;
      params.push(new Date(startDate as string));
      paramIndex++;
    }

    if (endDate) {
      whereClause += ` AND created_at <= $${paramIndex}`;
      params.push(new Date(endDate as string));
      paramIndex++;
    }

    // Подсчет общего количества записей
    const countQuery = `
      SELECT COUNT(*) as total 
      FROM call_results 
      WHERE ${whereClause}
    `;
    const countResult = await query<{ total: string }>(countQuery, params);
    const totalCount = parseInt(countResult.rows[0]?.total || '0');

    // Получение данных с пагинацией
    const dataQuery = `
      SELECT 
        id, 
        campaign_id,
        contact_id,
        phone_number,
        call_status,
        call_duration,
        ring_duration,
        dtmf_response,
        is_answering_machine,
        call_started_at,
        call_ended_at,
        created_at,
        bitrix_lead_created
      FROM call_results 
      WHERE ${whereClause}
      ORDER BY created_at DESC
      LIMIT $${paramIndex} OFFSET $${paramIndex + 1}
    `;
    
    params.push(parseInt(limit as string));
    params.push(parseInt(offset as string));
    
    const dataResult = await query<any>(dataQuery, params);

    res.json({
      success: true,
      data: {
        results: dataResult.rows,
        pagination: {
          total: totalCount,
          limit: parseInt(limit as string),
          offset: parseInt(offset as string),
          hasMore: (parseInt(offset as string) + parseInt(limit as string)) < totalCount
        }
      }
    });

  } catch (error) {
    log.error('Failed to get call results:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка получения результатов звонков',
      error: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

// Временная заглушка для обратной совместимости
router.get('/info', (_req, res) => {
  res.json({
    success: true,
    message: 'Calls controller - use /results endpoint for call results',
    timestamp: new Date().toISOString(),
  });
});

export default router; 