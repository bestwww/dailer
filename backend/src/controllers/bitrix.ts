/**
 * Контроллер интеграции с Битрикс24
 * Обеспечивает OAuth авторизацию и управление лидами
 */

import { Router, Request, Response } from 'express';
import { ApiResponse } from '@/types';
import { log } from '@/utils/logger';
import bitrix24Service, { BitrixLeadCreateParams } from '@/services/bitrix24';

const router = Router();

/**
 * GET /api/bitrix/status
 * Получение статуса интеграции с Bitrix24
 */
router.get('/status', async (_req: Request, res: Response) => {
  try {
    const status = bitrix24Service.getAuthStatus();
    const config = bitrix24Service.getConfig();
    
    const response: ApiResponse = {
      success: true,
      data: {
        ...status,
        domain: config.domain,
        isConnected: await bitrix24Service.checkConnection(),
      },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error: any) {
    log.error('Ошибка получения статуса Bitrix24:', error);
    
    const response: ApiResponse = {
      success: false,
      error: error.message,
      timestamp: new Date().toISOString(),
    };
    
    res.status(500).json(response);
  }
});

/**
 * GET /api/bitrix/auth
 * Получение URL для OAuth авторизации
 */
router.get('/auth', async (req: Request, res: Response) => {
  try {
    const { state } = req.query;
    const stateParam = typeof state === 'string' ? state : 'default';
    const authUrl = bitrix24Service.getAuthUrl(stateParam);
    
    const response: ApiResponse = {
      success: true,
      data: {
        authUrl,
        message: 'Перейдите по ссылке для авторизации в Bitrix24',
      },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error: any) {
    log.error('Ошибка генерации URL авторизации Bitrix24:', error);
    
    const response: ApiResponse = {
      success: false,
      error: error.message,
      timestamp: new Date().toISOString(),
    };
    
    res.status(400).json(response);
  }
});

/**
 * GET /api/bitrix/callback
 * Обработка callback после OAuth авторизации
 */
router.get('/callback', async (req: Request, res: Response) => {
  try {
    const { code, error: authError, error_description } = req.query;

    if (authError) {
      log.error('Ошибка авторизации Bitrix24:', {
        error: authError,
        description: error_description,
      });
      
      return res.redirect(`/settings?error=${encodeURIComponent(authError as string)}`);
    }

    if (!code) {
      return res.redirect('/settings?error=no_code');
    }

    // Обмениваем код на токены
    const tokens = await bitrix24Service.exchangeCodeForTokens(code as string);
    
    log.info('Успешная авторизация в Bitrix24', {
      expiresAt: tokens.expiresAt,
    });

    // Перенаправляем пользователя на страницу настроек с успехом
    res.redirect('/settings?success=bitrix_connected');
  } catch (error: any) {
    log.error('Ошибка обработки callback Bitrix24:', error);
    res.redirect(`/settings?error=${encodeURIComponent(error.message)}`);
  }
});

/**
 * POST /api/bitrix/config
 * Обновление конфигурации Bitrix24
 */
router.post('/config', async (req: Request, res: Response) => {
  try {
    const { domain, clientId, clientSecret, redirectUri } = req.body;

    if (!domain || !clientId || !clientSecret || !redirectUri) {
      const response: ApiResponse = {
        success: false,
        error: 'Все поля конфигурации обязательны',
        timestamp: new Date().toISOString(),
      };
      
      return res.status(400).json(response);
    }

    // Обновляем конфигурацию
    bitrix24Service.updateConfig({
      domain: domain.replace(/^https?:\/\//, '').replace(/\/$/, ''),
      clientId,
      clientSecret,
      redirectUri,
    });

    // Очищаем старые токены при смене конфигурации
    bitrix24Service.clearTokens();

    const response: ApiResponse = {
      success: true,
      data: {
        message: 'Конфигурация Bitrix24 обновлена',
        authUrl: bitrix24Service.getAuthUrl(),
      },
      timestamp: new Date().toISOString(),
    };

    return res.json(response);
  } catch (error: any) {
    log.error('Ошибка обновления конфигурации Bitrix24:', error);
    
    const response: ApiResponse = {
      success: false,
      error: error.message,
      timestamp: new Date().toISOString(),
    };
    
    return res.status(500).json(response);
  }
});

/**
 * POST /api/bitrix/lead
 * Создание лида в Bitrix24
 */
router.post('/lead', async (req: Request, res: Response) => {
  try {
    const leadParams: BitrixLeadCreateParams = req.body;

    if (!leadParams.title || !leadParams.phone) {
      const response: ApiResponse = {
        success: false,
        error: 'Название лида и телефон обязательны',
        timestamp: new Date().toISOString(),
      };
      
      return res.status(400).json(response);
    }

    const lead = await bitrix24Service.createLead(leadParams);

    const response: ApiResponse = {
      success: true,
      data: lead,
      message: 'Лид успешно создан в Bitrix24',
      timestamp: new Date().toISOString(),
    };

    return res.json(response);
  } catch (error: any) {
    log.error('Ошибка создания лида Bitrix24:', error);
    
    const response: ApiResponse = {
      success: false,
      error: error.message,
      timestamp: new Date().toISOString(),
    };
    
    return res.status(500).json(response);
  }
});

/**
 * GET /api/bitrix/leads
 * Получение списка лидов из Bitrix24
 */
router.get('/leads', async (req: Request, res: Response) => {
  try {
    const { phone, campaignName, startDate, endDate } = req.query;
    
    // Строим фильтр для поиска
    const filter: Record<string, any> = {};
    
    if (phone) {
      filter.PHONE = phone;
    }
    
    if (campaignName) {
      filter.COMMENTS = `%${campaignName}%`;
    }
    
    if (startDate) {
      filter['>=DATE_CREATE'] = startDate;
    }
    
    if (endDate) {
      filter['<=DATE_CREATE'] = endDate;
    }

    const leads = await bitrix24Service.getLeads(filter);

    const response: ApiResponse = {
      success: true,
      data: leads,
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error: any) {
    log.error('Ошибка получения лидов Bitrix24:', error);
    
    const response: ApiResponse = {
      success: false,
      error: error.message,
      timestamp: new Date().toISOString(),
    };
    
    res.status(500).json(response);
  }
});

/**
 * GET /api/bitrix/lead/:id
 * Получение лида по ID
 */
router.get('/lead/:id', async (req: Request, res: Response) => {
  try {
    const leadIdParam = req.params.id;
    
    if (!leadIdParam) {
      const response: ApiResponse = {
        success: false,
        error: 'ID лида не указан',
        timestamp: new Date().toISOString(),
      };
      
      return res.status(400).json(response);
    }

    const leadId = parseInt(leadIdParam);

    if (isNaN(leadId)) {
      const response: ApiResponse = {
        success: false,
        error: 'Некорректный ID лида',
        timestamp: new Date().toISOString(),
      };
      
      return res.status(400).json(response);
    }

    const lead = await bitrix24Service.getLead(leadId);

    const response: ApiResponse = {
      success: true,
      data: lead,
      timestamp: new Date().toISOString(),
    };

    return res.json(response);
  } catch (error: any) {
    log.error('Ошибка получения лида Bitrix24:', error);
    
    const response: ApiResponse = {
      success: false,
      error: error.message,
      timestamp: new Date().toISOString(),
    };
    
    return res.status(404).json(response);
  }
});

/**
 * GET /api/bitrix/profile
 * Получение профиля текущего пользователя Bitrix24
 */
router.get('/profile', async (_req: Request, res: Response) => {
  try {
    const profile = await bitrix24Service.getCurrentUser();

    const response: ApiResponse = {
      success: true,
      data: profile,
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error: any) {
    log.error('Ошибка получения профиля Bitrix24:', error);
    
    const response: ApiResponse = {
      success: false,
      error: error.message,
      timestamp: new Date().toISOString(),
    };
    
    res.status(500).json(response);
  }
});

/**
 * POST /api/bitrix/disconnect
 * Отключение от Bitrix24 (очистка токенов)
 */
router.post('/disconnect', async (_req: Request, res: Response) => {
  try {
    bitrix24Service.clearTokens();

    const response: ApiResponse = {
      success: true,
      data: {
        message: 'Отключение от Bitrix24 выполнено успешно',
      },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error: any) {
    log.error('Ошибка отключения от Bitrix24:', error);
    
    const response: ApiResponse = {
      success: false,
      error: error.message,
      timestamp: new Date().toISOString(),
    };
    
    res.status(500).json(response);
  }
});

/**
 * POST /api/bitrix/test-connection
 * Тестирование соединения с Bitrix24
 */
router.post('/test-connection', async (_req: Request, res: Response) => {
  try {
    const isConnected = await bitrix24Service.checkConnection();

    const response: ApiResponse = {
      success: true,
      data: {
        isConnected,
        message: isConnected 
          ? 'Соединение с Bitrix24 работает' 
          : 'Соединение с Bitrix24 не установлено',
      },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error: any) {
    log.error('Ошибка тестирования соединения Bitrix24:', error);
    
    const response: ApiResponse = {
      success: false,
      error: error.message,
      timestamp: new Date().toISOString(),
    };
    
    res.status(500).json(response);
  }
});

export default router; 