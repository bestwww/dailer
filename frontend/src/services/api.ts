import axios, { type AxiosInstance, type AxiosResponse } from 'axios'
import type {
  Campaign,
  Contact,
  CallResult,
  CampaignStats,
  SystemSettings,
  ApiResponse,
  PaginatedResponse,
  PaginatedRequest,
  ContactImport,
  CreateContactRequest,
  UpdateContactRequest
} from '@/types'

// Интерфейсы для статистики
export interface CampaignStatsOverview {
  campaigns: {
    total: number;
    active: number;
    completed: number;
    totalCalls: number;
    totalContacts: number;
  };
  callsLast30Days: {
    totalCalls: number;
    answeredCalls: number;
    busyCalls: number;
    noAnswerCalls: number;
    failedCalls: number;
    interestedResponses: number;
    machineAnswers: number;
    leadsCreated: number;
    answerRate: number;
    conversionRate: number;
    avgCallDuration: number;
    avgRingDuration: number;
  };
}

export interface CampaignDetailedStats {
  campaign: {
    id: number;
    name: string;
    status: string;
    createdAt: string;
  };
  callStats: {
    totalCalls: number;
    answeredCalls: number;
    busyCalls: number;
    noAnswerCalls: number;
    failedCalls: number;
    averageCallDuration: number;
    averageRingDuration: number;
    interestedResponses: number;
    humanAnswers: number;
    machineAnswers: number;
    answerRate: number;
    conversionRate: number;
  };
  timeseries: Array<{
    timestamp: Date;
    totalCalls: number;
    answeredCalls: number;
    failedCalls: number;
    averageDuration: number;
  }>;
  topNumbers: Array<{
    phoneNumber: string;
    totalCalls: number;
    answeredCalls: number;
    lastCallAt: Date;
    lastCallStatus: string;
  }>;
  weekdayStats: Array<{
    dayOfWeek: number;
    totalCalls: number;
    answeredCalls: number;
    avgDuration: number;
  }>;
  hourlyStats: Array<{
    hour: number;
    totalCalls: number;
    answeredCalls: number;
    avgDuration: number;
  }>;
}

export interface RealtimeStats {
  callsLastHour: number;
  answeredLastHour: number;
  interestedLastHour: number;
  callsLast10Min: number;
  activeCampaigns: number;
  timestamp: string;
}

// Базовая конфигурация API
class ApiService {
  private api: AxiosInstance

  constructor() {
    const baseUrl = import.meta.env.VITE_API_URL || 'http://localhost:3000'
    this.api = axios.create({
      baseURL: `${baseUrl}/api`,
      timeout: 10000,
      headers: {
        'Content-Type': 'application/json'
      }
    })

    // Настройка авторизации из localStorage
    const token = localStorage.getItem('auth_token')
    if (token) {
      this.setAuthToken(token)
    }

    // Перехватчик ошибок
    this.api.interceptors.response.use(
      (response: AxiosResponse) => response,
      (error) => {
        console.error('API Error:', error)
        return Promise.reject(error)
      }
    )
  }

  /**
   * Установка токена авторизации
   */
  setAuthToken(token: string | null): void {
    if (token) {
      this.api.defaults.headers.common['Authorization'] = `Bearer ${token}`
    } else {
      delete this.api.defaults.headers.common['Authorization']
    }
  }

  /**
   * Базовый GET запрос
   */
  async get<T = any>(url: string, params?: any): Promise<T> {
    const response = await this.api.get(url, { params })
    return response.data
  }

  /**
   * Базовый POST запрос
   */
  async post<T = any>(url: string, data?: any): Promise<T> {
    const response = await this.api.post(url, data)
    return response.data
  }

  /**
   * Базовый PUT запрос
   */
  async put<T = any>(url: string, data?: any): Promise<T> {
    const response = await this.api.put(url, data)
    return response.data
  }

  /**
   * Базовый DELETE запрос
   */
  async delete<T = any>(url: string): Promise<T> {
    const response = await this.api.delete(url)
    return response.data
  }

  // Методы для работы с кампаниями
  async getCampaigns(params?: PaginatedRequest): Promise<PaginatedResponse<Campaign>> {
    const response = await this.api.get('/campaigns', { params })
    return response.data
  }

  async getCampaign(id: number): Promise<Campaign> {
    const response = await this.api.get(`/campaigns/${id}`)
    return response.data.data
  }

  async createCampaign(data: Partial<Campaign>): Promise<Campaign> {
    const response = await this.api.post('/campaigns', data)
    return response.data.data
  }

  async updateCampaign(id: number, data: Partial<Campaign>): Promise<Campaign> {
    console.log('Отправляем данные для обновления кампании:', id, data)
    const response = await this.api.put(`/campaigns/${id}`, data)
    console.log('Ответ от API на обновление кампании:', response.data)
    return response.data.data
  }

  async deleteCampaign(id: number): Promise<void> {
    await this.api.delete(`/campaigns/${id}`)
  }

  async startCampaign(id: number): Promise<ApiResponse<Campaign>> {
    const response = await this.api.post(`/campaigns/${id}/start`)
    return response.data
  }

  async pauseCampaign(id: number): Promise<ApiResponse<Campaign>> {
    const response = await this.api.post(`/campaigns/${id}/pause`)
    return response.data
  }

  async stopCampaign(id: number): Promise<ApiResponse<Campaign>> {
    const response = await this.api.post(`/campaigns/${id}/stop`)
    return response.data
  }

  // Методы для работы с контактами
  async getContacts(campaignId?: number, params?: PaginatedRequest): Promise<PaginatedResponse<Contact>> {
    const response = await this.api.get('/contacts', {
      params: { campaignId, ...params }
    })
    return response.data
  }

  async getContact(id: number): Promise<Contact> {
    const response = await this.api.get(`/contacts/${id}`)
    return response.data.data
  }

  async createContact(data: CreateContactRequest): Promise<Contact> {
    const response = await this.api.post('/contacts', data)
    return response.data.data
  }

  async updateContact(id: number, data: UpdateContactRequest): Promise<Contact> {
    const response = await this.api.put(`/contacts/${id}`, data)
    return response.data.data
  }

  async deleteContact(id: number): Promise<void> {
    await this.api.delete(`/contacts/${id}`)
  }

  async importContacts(campaignId: number, contacts: CreateContactRequest[]): Promise<ApiResponse> {
    const response = await this.api.post('/contacts/import', {
      campaignId,
      contacts
    })
    return response.data
  }

  async getContactsStats(campaignId: number): Promise<ApiResponse> {
    const response = await this.api.get(`/contacts/stats/${campaignId}`)
    return response.data
  }

  async getNextContactsForCalling(campaignId: number, limit: number = 10, timezone?: string): Promise<ApiResponse> {
    const response = await this.api.get(`/contacts/next-for-calling/${campaignId}`, {
      params: { limit, timezone }
    })
    return response.data
  }

  // Методы для работы с результатами звонков
  async getCallResults(campaignId?: number, params?: PaginatedRequest): Promise<PaginatedResponse<CallResult>> {
    const response = await this.api.get('/call-results', {
      params: { campaignId, ...params }
    })
    return response.data
  }

  async getCallResult(id: number): Promise<CallResult> {
    const response = await this.api.get(`/call-results/${id}`)
    return response.data.data
  }

  // Статистика
  async getCampaignStats(campaignId: number): Promise<CampaignStats> {
    const response = await this.api.get(`/campaigns/${campaignId}/stats`)
    return response.data.data
  }

  async getSystemStats(): Promise<any> {
    const response = await this.api.get('/stats/system')
    return response.data.data
  }

  // Настройки
  async getSettings(): Promise<SystemSettings> {
    const response = await this.api.get('/settings')
    return response.data.data
  }

  async updateSettings(data: Partial<SystemSettings>): Promise<SystemSettings> {
    const response = await this.api.put('/settings', data)
    return response.data.data
  }

  // Загрузка аудиофайлов
  async uploadAudioFile(file: File): Promise<{ filePath: string }> {
    const formData = new FormData()
    formData.append('audio', file)

    const response = await this.api.post('/audio/upload', formData, {
      headers: {
        'Content-Type': 'multipart/form-data'
      }
    })
    return response.data.data
  }

  // Загрузка аудиофайла для кампании
  async uploadCampaignAudio(campaignId: number, file: File, retryCount = 0): Promise<Campaign> {
    const maxRetries = 3
    const retryDelay = 2000 // 2 секунды
    
    console.log('🔍 DEBUG: Загрузка аудиофайла для кампании')
    console.log('🆔 ID кампании:', campaignId)
    console.log('📁 Файл:', file)
    console.log('📂 Имя файла:', file.name)
    console.log('📊 Размер файла:', file.size)
    console.log('🎵 Тип файла:', file.type)
    if (retryCount > 0) {
      console.log(`🔄 Попытка ${retryCount + 1} из ${maxRetries + 1}`)
    }
    
    const formData = new FormData()
    formData.append('audio', file)

    console.log('📤 Отправляем запрос на:', `/campaigns/${campaignId}/audio`)
    
    try {
      const response = await this.api.post(`/campaigns/${campaignId}/audio`, formData, {
        headers: {
          'Content-Type': 'multipart/form-data'
        },
        timeout: 300000, // 5 минут таймаут для загрузки файлов
        onUploadProgress: (progressEvent) => {
          if (progressEvent.total) {
            const percentCompleted = Math.round((progressEvent.loaded * 100) / progressEvent.total)
            console.log(`📈 Прогресс загрузки: ${percentCompleted}%`)
          }
        }
      })
      
      console.log('✅ Ответ сервера - статус:', response.status)
      console.log('✅ Ответ сервера - заголовки:', response.headers)
      console.log('✅ Ответ сервера - данные:', response.data)
      
      if (!response.data) {
        throw new Error('Пустой ответ от сервера')
      }
      
      if (!response.data.success) {
        throw new Error(response.data.error || 'Неизвестная ошибка сервера')
      }
      
      return response.data.data
      
    } catch (error: any) {
      console.error('❌ Ошибка загрузки аудиофайла:', error)
      
      // Проверяем, можно ли повторить попытку
      const isRetryableError = (
        error.code === 'ECONNABORTED' || // Таймаут
        error.code === 'NETWORK_ERROR' ||
        error.code === 'ECONNRESET' ||
        (error.response && error.response.status >= 500) || // Ошибки сервера
        (!error.response && error.request) // Нет ответа
      )
      
      if (isRetryableError && retryCount < maxRetries) {
        console.log(`🔄 Повторная попытка через ${retryDelay}ms...`)
        await new Promise(resolve => setTimeout(resolve, retryDelay))
        return this.uploadCampaignAudio(campaignId, file, retryCount + 1)
      }
      
      if (error.response) {
        // Сервер ответил с кодом ошибки
        console.error('❌ Статус ответа:', error.response.status)
        console.error('❌ Заголовки ответа:', error.response.headers)
        console.error('❌ Данные ответа:', error.response.data)
        
        const errorMessage = error.response.data?.error || 
                           error.response.data?.message || 
                           `Ошибка сервера (${error.response.status})`
        throw new Error(errorMessage)
        
      } else if (error.request) {
        // Запрос был отправлен, но ответа не получено
        console.error('❌ Запрос отправлен, но ответа нет:', error.request)
        console.error('❌ URL запроса:', error.config?.url)
        console.error('❌ Таймаут:', error.config?.timeout)
        const message = retryCount >= maxRetries 
          ? `Не удалось загрузить файл после ${maxRetries + 1} попыток. Проверьте подключение к интернету.`
          : 'Сервер не отвечает. Проверьте подключение к серверу.'
        throw new Error(message)
        
      } else {
        // Ошибка при настройке запроса
        console.error('❌ Ошибка настройки запроса:', error.message)
        throw new Error(`Ошибка запроса: ${error.message}`)
      }
    }
  }

  // Проверка состояния системы
  async getSystemHealth(): Promise<{ status: string; uptime: number }> {
    const response = await this.api.get('/health')
    return response.data.data
  }

  // Bitrix24 методы
  async getBitrixStatus(): Promise<ApiResponse> {
    const response = await this.api.get('/bitrix/status')
    return response.data
  }

  async testBitrixConnection(): Promise<ApiResponse> {
    const response = await this.api.post('/bitrix/test-connection')
    return response.data
  }

  async getBitrixAuthUrl(state?: string): Promise<ApiResponse> {
    const response = await this.api.get('/bitrix/auth', { params: { state } })
    return response.data
  }

  async updateBitrixConfig(config: {
    domain: string
    clientId: string
    clientSecret: string
    redirectUri: string
  }): Promise<ApiResponse> {
    const response = await this.api.post('/bitrix/config', config)
    return response.data
  }

  async disconnectBitrix(): Promise<ApiResponse> {
    const response = await this.api.post('/bitrix/disconnect')
    return response.data
  }

  async getBitrixLeads(params?: {
    phone?: string
    campaignName?: string
    startDate?: string
    endDate?: string
    limit?: number
  }): Promise<ApiResponse> {
    const response = await this.api.get('/bitrix/leads', { params })
    return response.data
  }

  async createBitrixLead(leadData: {
    title: string
    name?: string
    lastName?: string
    phone: string
    email?: string
    sourceId?: string
    responsibleId?: number
    comments?: string
    campaignName?: string
    dtmfResponse?: string
  }): Promise<ApiResponse> {
    const response = await this.api.post('/bitrix/lead', leadData)
    return response.data
  }

  async getBitrixLead(leadId: number): Promise<ApiResponse> {
    const response = await this.api.get(`/bitrix/lead/${leadId}`)
    return response.data
  }

  async getBitrixProfile(): Promise<ApiResponse> {
    const response = await this.api.get('/bitrix/profile')
    return response.data
  }

  /**
   * Статистика
   */
  stats = {
    /**
     * Получение общей статистики
     */
    getOverview: async (): Promise<CampaignStatsOverview> => {
      const response = await this.api.get('/stats/overview');
      // Если данные в обёрточной структуре, извлекаем их
      if (response.data.success && response.data.data) {
        return response.data.data;
      }
      return response.data;
    },

    /**
     * Получение детальной статистики по кампании
     */
    getCampaignStats: async (campaignId: number): Promise<CampaignDetailedStats> => {
      const response = await this.api.get(`/stats/campaign/${campaignId}`);
      // Если данные в обёрточной структуре, извлекаем их
      if (response.data.success && response.data.data) {
        return response.data.data;
      }
      return response.data;
    },

    /**
     * Сравнение кампаний
     */
    compareCampaigns: async (campaignIds: number[]): Promise<{
      comparisons: Array<{
        campaign: {
          id: number;
          name: string;
          status: string;
          createdAt: string;
        };
        stats: any;
      }>;
      totalCampaigns: number;
    }> => {
      const response = await this.api.post('/stats/compare', { campaignIds });
      return response.data;
    },

         /**
      * Экспорт статистики кампании
      */
     exportCampaignStats: async (campaignId: number, format: 'csv' | 'json' = 'csv'): Promise<void> => {
       const url = `/stats/export/campaign/${campaignId}?format=${format}`;
       
       if (format === 'csv') {
         // Для CSV скачиваем файл
         const token = localStorage.getItem('auth_token');
         const headers: Record<string, string> = {
           'Content-Type': 'application/json',
         };
         if (token) {
           headers['Authorization'] = `Bearer ${token}`;
         }
         
         const response = await fetch(`${this.api.defaults.baseURL}${url}`, {
           headers
         });
         
         if (!response.ok) {
           throw new Error(`HTTP error! status: ${response.status}`);
         }
         
         const blob = await response.blob();
         const downloadUrl = window.URL.createObjectURL(blob);
         const link = document.createElement('a');
         link.href = downloadUrl;
         link.download = `campaign_${campaignId}_stats.csv`;
         document.body.appendChild(link);
         link.click();
         document.body.removeChild(link);
         window.URL.revokeObjectURL(downloadUrl);
       } else {
         const response = await this.api.get(url);
         return response.data;
       }
     },

    /**
     * Получение real-time статистики
     */
    getRealtimeStats: async (): Promise<RealtimeStats> => {
      const response = await this.api.get('/stats/realtime');
      // Если данные в обёрточной структуре, извлекаем их
      if (response.data.success && response.data.data) {
        return response.data.data;
      }
      return response.data;
    }
  };
}

// Экспортируем единственный экземпляр
export const apiService = new ApiService()
export default apiService 