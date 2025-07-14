/**
 * Сервис интеграции с Bitrix24 API
 * Обеспечивает OAuth авторизацию и создание лидов
 */

import axios, { AxiosInstance } from 'axios';
import { BitrixConfig } from '@/types';
import { log } from '@/utils/logger';
import { config } from '@/config';

export interface BitrixAuthTokens {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  expiresAt: Date;
}

export interface BitrixLeadCreateParams {
  title: string;
  name?: string;
  lastName?: string;
  phone: string;
  email?: string;
  sourceId?: string;
  responsibleId?: number;
  comments?: string;
  campaignName?: string;
  dtmfResponse?: string;
  customFields?: Record<string, any>;
}

export interface BitrixLeadResponse {
  id: number;
  title: string;
  name?: string | undefined;
  phone?: string | undefined;
  email?: string | undefined;
  createdTime: string;
  responsibleId?: number | undefined;
}

export class Bitrix24Service {
  private httpClient: AxiosInstance;
  private config: BitrixConfig;
  private accessToken?: string;
  private refreshToken?: string;
  private expiresAt?: Date;

  constructor(bitrixConfig?: BitrixConfig) {
    this.config = bitrixConfig || {
      domain: config.bitrix24Domain || '',
      clientId: config.bitrix24ClientId || '',
      clientSecret: config.bitrix24ClientSecret || '',
      redirectUri: config.bitrix24RedirectUri || '',
    };

    this.httpClient = axios.create({
      timeout: 30000,
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'Dailer-System/1.0',
      },
    });

    // Добавляем перехватчик для автоматического обновления токенов
    this.setupInterceptors();
  }

  /**
   * Настройка перехватчиков для автоматической авторизации
   */
  private setupInterceptors(): void {
    // Перехватчик запросов - добавляем токен
    this.httpClient.interceptors.request.use(
      (config) => {
        if (this.accessToken && this.isTokenValid()) {
          config.headers.Authorization = `Bearer ${this.accessToken}`;
        }
        return config;
      },
      (error) => {
        log.error('Ошибка в перехватчике запросов Bitrix24:', error);
        return Promise.reject(error);
      }
    );

    // Перехватчик ответов - обработка ошибок авторизации
    this.httpClient.interceptors.response.use(
      (response) => response,
      async (error) => {
        const originalRequest = error.config;

        if (
          error.response?.status === 401 &&
          !originalRequest._retry &&
          this.refreshToken
        ) {
          originalRequest._retry = true;
          
          try {
            await this.refreshAccessToken();
            originalRequest.headers.Authorization = `Bearer ${this.accessToken}`;
            return this.httpClient.request(originalRequest);
          } catch (refreshError) {
            log.error('Ошибка обновления токена Bitrix24:', refreshError);
            this.clearTokens();
            throw refreshError;
          }
        }

        return Promise.reject(error);
      }
    );
  }

  /**
   * Получение URL для OAuth авторизации
   */
  getAuthUrl(state?: string): string {
    if (!this.config.domain || !this.config.clientId) {
      throw new Error('Не настроены параметры Bitrix24 для авторизации');
    }

    const params = new URLSearchParams({
      response_type: 'code',
      client_id: this.config.clientId,
      redirect_uri: this.config.redirectUri,
      scope: 'crm,im,user',
      state: state || 'default',
    });

    return `https://${this.config.domain}/oauth/authorize/?${params.toString()}`;
  }

  /**
   * Обмен кода авторизации на токены доступа
   */
  async exchangeCodeForTokens(code: string): Promise<BitrixAuthTokens> {
    try {
      const response = await axios.post(
        `https://${this.config.domain}/oauth/token/`,
        {
          grant_type: 'authorization_code',
          client_id: this.config.clientId,
          client_secret: this.config.clientSecret,
          redirect_uri: this.config.redirectUri,
          code,
        },
        {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        }
      );

      const { access_token, refresh_token, expires_in } = response.data;

      if (!access_token) {
        throw new Error('Не удалось получить токен доступа от Bitrix24');
      }

      const expiresAt = new Date(Date.now() + (expires_in * 1000));

      // Сохраняем токены
      this.setTokens({
        accessToken: access_token,
        refreshToken: refresh_token,
        expiresIn: expires_in,
        expiresAt,
      });

      log.info('Успешно получены токены Bitrix24', {
        domain: this.config.domain,
        expiresAt: expiresAt.toISOString(),
      });

      return {
        accessToken: access_token,
        refreshToken: refresh_token,
        expiresIn: expires_in,
        expiresAt,
      };
    } catch (error: any) {
      log.error('Ошибка обмена кода на токены Bitrix24:', {
        error: error.message,
        response: error.response?.data,
      });
      throw new Error('Ошибка авторизации в Bitrix24: ' + error.message);
    }
  }

  /**
   * Обновление токена доступа
   */
  async refreshAccessToken(): Promise<void> {
    if (!this.refreshToken) {
      throw new Error('Отсутствует refresh token для обновления');
    }

    try {
      const response = await axios.post(
        `https://${this.config.domain}/oauth/token/`,
        {
          grant_type: 'refresh_token',
          client_id: this.config.clientId,
          client_secret: this.config.clientSecret,
          refresh_token: this.refreshToken,
        },
        {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        }
      );

      const { access_token, refresh_token, expires_in } = response.data;
      const expiresAt = new Date(Date.now() + (expires_in * 1000));

      this.setTokens({
        accessToken: access_token,
        refreshToken: refresh_token,
        expiresIn: expires_in,
        expiresAt,
      });

      log.info('Токен Bitrix24 успешно обновлен');
    } catch (error: any) {
      log.error('Ошибка обновления токена Bitrix24:', error.message);
      throw error;
    }
  }

  /**
   * Создание лида в Bitrix24
   */
  async createLead(params: BitrixLeadCreateParams): Promise<BitrixLeadResponse> {
    try {
      if (!this.isConfigured()) {
        throw new Error('Bitrix24 не настроен');
      }

      if (!this.accessToken || !this.isTokenValid()) {
        throw new Error('Отсутствует действующий токен доступа Bitrix24');
      }

      // Подготавливаем данные лида
      const leadData = {
        fields: {
          TITLE: params.title,
          NAME: params.name || '',
          LAST_NAME: params.lastName || '',
          SOURCE_ID: params.sourceId || 'CALL',
          STATUS_ID: 'NEW',
          OPENED: 'Y',
          ASSIGNED_BY_ID: params.responsibleId || null,
          COMMENTS: this.buildLeadComments(params),
          PHONE: params.phone ? [{ VALUE: params.phone, VALUE_TYPE: 'WORK' }] : [],
          EMAIL: params.email ? [{ VALUE: params.email, VALUE_TYPE: 'WORK' }] : [],
          // Добавляем кастомные поля если есть
          ...params.customFields,
        },
      };

      const response = await this.httpClient.post(
        `https://${this.config.domain}/rest/crm.lead.add.json`,
        leadData
      );

      if (!response.data.result) {
        throw new Error('Ошибка создания лида: ' + JSON.stringify(response.data.error || 'Неизвестная ошибка'));
      }

      const leadId = response.data.result;

      log.info('Лид успешно создан в Bitrix24', {
        leadId,
        phone: params.phone,
        campaign: params.campaignName,
        dtmfResponse: params.dtmfResponse,
      });

      // Получаем данные созданного лида
      return await this.getLead(leadId);
    } catch (error: any) {
      log.error('Ошибка создания лида в Bitrix24:', {
        error: error.message,
        phone: params.phone,
        campaign: params.campaignName,
      });
      throw error;
    }
  }

  /**
   * Получение лида по ID
   */
  async getLead(leadId: number): Promise<BitrixLeadResponse> {
    try {
      const response = await this.httpClient.get(
        `https://${this.config.domain}/rest/crm.lead.get.json?id=${leadId}`
      );

      if (!response.data.result) {
        throw new Error('Лид не найден');
      }

      const lead = response.data.result;
      
      return {
        id: parseInt(lead.ID),
        title: lead.TITLE || '',
        name: lead.NAME || '',
        phone: lead.PHONE?.[0]?.VALUE || '',
        email: lead.EMAIL?.[0]?.VALUE || '',
        createdTime: lead.DATE_CREATE || '',
        responsibleId: lead.ASSIGNED_BY_ID ? parseInt(lead.ASSIGNED_BY_ID) : undefined,
      };
    } catch (error: any) {
      log.error('Ошибка получения лида из Bitrix24:', error.message);
      throw error;
    }
  }

  /**
   * Получение списка лидов с фильтрацией
   */
  async getLeads(filter: Record<string, any> = {}, select: string[] = ['ID', 'TITLE', 'NAME', 'PHONE', 'EMAIL', 'DATE_CREATE']): Promise<BitrixLeadResponse[]> {
    try {
      const response = await this.httpClient.post(
        `https://${this.config.domain}/rest/crm.lead.list.json`,
        {
          filter,
          select,
          order: { DATE_CREATE: 'DESC' },
          start: 0,
        }
      );

      if (!response.data.result) {
        return [];
      }

      return response.data.result.map((lead: any) => ({
        id: parseInt(lead.ID),
        title: lead.TITLE || '',
        name: lead.NAME || '',
        phone: lead.PHONE?.[0]?.VALUE || '',
        email: lead.EMAIL?.[0]?.VALUE || '',
        createdTime: lead.DATE_CREATE || '',
        responsibleId: lead.ASSIGNED_BY_ID ? parseInt(lead.ASSIGNED_BY_ID) : undefined,
      }));
    } catch (error: any) {
      log.error('Ошибка получения списка лидов из Bitrix24:', error.message);
      throw error;
    }
  }

  /**
   * Проверка доступности API Bitrix24
   */
  async checkConnection(): Promise<boolean> {
    try {
      if (!this.isConfigured() || !this.accessToken) {
        return false;
      }

      const response = await this.httpClient.get(
        `https://${this.config.domain}/rest/profile.json`
      );

      return response.data.result !== undefined;
    } catch (error) {
      log.error('Ошибка проверки соединения с Bitrix24:', error);
      return false;
    }
  }

  /**
   * Получение информации о текущем пользователе
   */
  async getCurrentUser(): Promise<any> {
    try {
      const response = await this.httpClient.get(
        `https://${this.config.domain}/rest/profile.json`
      );

      return response.data.result;
    } catch (error: any) {
      log.error('Ошибка получения профиля пользователя Bitrix24:', error.message);
      throw error;
    }
  }

  /**
   * Установка токенов
   */
  setTokens(tokens: BitrixAuthTokens): void {
    this.accessToken = tokens.accessToken;
    this.refreshToken = tokens.refreshToken;
    this.expiresAt = tokens.expiresAt;
  }

  /**
   * Очистка токенов
   */
  clearTokens(): void {
    delete this.accessToken;
    delete this.refreshToken;
    delete this.expiresAt;
  }

  /**
   * Проверка действительности токена
   */
  private isTokenValid(): boolean {
    if (!this.expiresAt) {
      return false;
    }
    
    // Считаем токен истёкшим за 5 минут до реального истечения
    const bufferTime = 5 * 60 * 1000; // 5 минут в миллисекундах
    return new Date().getTime() < (this.expiresAt.getTime() - bufferTime);
  }

  /**
   * Проверка настройки сервиса
   */
  private isConfigured(): boolean {
    return !!(
      this.config.domain &&
      this.config.clientId &&
      this.config.clientSecret &&
      this.config.redirectUri
    );
  }

  /**
   * Построение комментария для лида
   */
  private buildLeadComments(params: BitrixLeadCreateParams): string {
    const comments = [];
    
    if (params.campaignName) {
      comments.push(`Кампания: ${params.campaignName}`);
    }
    
    if (params.dtmfResponse) {
      const responseText = params.dtmfResponse === '1' ? 'Заинтересован' : 'Не заинтересован';
      comments.push(`DTMF ответ: ${params.dtmfResponse} (${responseText})`);
    }
    
    if (params.comments) {
      comments.push(params.comments);
    }
    
    comments.push(`Создано системой автодозвона: ${new Date().toLocaleString('ru-RU')}`);
    
    return comments.join('\n');
  }

  /**
   * Получение текущей конфигурации
   */
  getConfig(): BitrixConfig {
    return { ...this.config };
  }

  /**
   * Обновление конфигурации
   */
  updateConfig(newConfig: Partial<BitrixConfig>): void {
    this.config = { ...this.config, ...newConfig };
  }

  /**
   * Получение статуса авторизации
   */
  getAuthStatus(): {
    isConfigured: boolean;
    hasTokens: boolean;
    isTokenValid: boolean;
    expiresAt?: Date | undefined;
  } {
    const result: {
      isConfigured: boolean;
      hasTokens: boolean;
      isTokenValid: boolean;
      expiresAt?: Date | undefined;
    } = {
      isConfigured: this.isConfigured(),
      hasTokens: !!(this.accessToken && this.refreshToken),
      isTokenValid: this.isTokenValid(),
    };
    
    if (this.expiresAt) {
      result.expiresAt = this.expiresAt;
    }
    
    return result;
  }
}

// Создаем singleton экземпляр сервиса
export const bitrix24Service = new Bitrix24Service();

export default bitrix24Service; 