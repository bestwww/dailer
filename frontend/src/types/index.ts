// Основные интерфейсы для диалер системы

// Статусы кампании
export type CampaignStatus = 'draft' | 'active' | 'paused' | 'completed' | 'cancelled'

// Статусы контакта
export type ContactStatus = 'pending' | 'calling' | 'completed' | 'failed' | 'blacklisted' | 'do_not_call'

// Статусы звонка
export type CallStatus = 'answered' | 'busy' | 'no_answer' | 'failed'

// Интерфейс кампании
export interface Campaign {
  id: number
  name: string
  description?: string
  audioFilePath?: string
  audioFileName?: string // Оригинальное имя загруженного файла
  status: CampaignStatus
  totalContacts?: number
  completedContacts?: number
  successfulCalls?: number
  // Настройки кампании
  maxConcurrentCalls?: number
  callsPerMinute?: number
  retryAttempts?: number
  retryDelay?: number
  amdEnabled?: boolean
  bitrixIntegrationEnabled?: boolean
  bitrixCreateLeads?: boolean
  // Поля времени работы (для совместимости с backend)
  workTimeStart?: string
  workTimeEnd?: string
  workingHoursStart?: string
  workingHoursEnd?: string
  // Временная зона кампании
  timezone?: string
  createdAt: string
  updatedAt: string
}

// Интерфейс контакта
export interface Contact {
  id: number
  campaignId: number
  // Контактная информация
  phoneNumber: string
  firstName?: string
  lastName?: string
  email?: string
  company?: string
  // Статус обработки
  status: ContactStatus
  // Попытки звонков
  callAttempts: number
  lastCallAt?: string
  nextCallAt?: string
  // Битрикс24 интеграция
  bitrixContactId?: number
  bitrixLeadId?: number
  // Метаданные
  customFields?: Record<string, any>
  notes?: string
  // Временная зона
  timezone?: string
  createdAt: string
  updatedAt: string
}

// Типы для создания и обновления контактов
export interface CreateContactRequest {
  campaignId: number
  phoneNumber: string
  firstName?: string
  lastName?: string
  email?: string
  company?: string
  customFields?: Record<string, any>
  notes?: string
  timezone?: string
  bitrixContactId?: number
  bitrixLeadId?: number
}

export interface UpdateContactRequest {
  firstName?: string
  lastName?: string
  email?: string
  company?: string
  status?: ContactStatus
  customFields?: Record<string, any>
  notes?: string
  timezone?: string
  bitrixContactId?: number
  bitrixLeadId?: number
}

// Интерфейс результата звонка
export interface CallResult {
  id: number
  contactId: number
  campaignId: number
  callStatus: CallStatus
  dtmfResponse?: string
  callDuration?: number
  isAnsweringMachine: boolean
  bitrixLeadId?: number
  createdAt: string
}

// Статистика кампании
export interface CampaignStats {
  campaignId: number
  totalContacts: number
  completedCalls: number
  successfulCalls: number
  failedCalls: number
  interestedResponses: number
  notInterestedResponses: number
  answeringMachineDetected: number
  averageCallDuration: number
  conversionRate: number
}

// Настройки системы
export interface SystemSettings {
  maxConcurrentCalls: number
  callsPerMinute: number
  retryAttempts: number
  retryDelay: number
  amdEnabled: boolean
  bitrixIntegrationEnabled: boolean
  workingHoursStart: string
  workingHoursEnd: string
}

// Real-time события
export interface RealTimeEvent {
  type: 'call_started' | 'call_completed' | 'call_failed' | 'campaign_updated'
  data: any
  timestamp: string
}

// Загрузка файла контактов
export interface ContactImport {
  file: File
  campaignId: number
  mapping: {
    phoneColumn: string
    nameColumn?: string
  }
}

// Ответ от API
export interface ApiResponse<T = any> {
  success: boolean
  data?: T
  message?: string
  error?: string
}

// Пагинация
export interface Pagination {
  page: number
  limit: number
  total: number
  totalPages: number
}

// Запрос с пагинацией
export interface PaginatedRequest {
  page?: number
  limit?: number
  search?: string
  sortBy?: string
  sortOrder?: 'asc' | 'desc'
}

// Ответ с пагинацией
export interface PaginatedResponse<T> {
  data: T[]
  pagination: Pagination
} 