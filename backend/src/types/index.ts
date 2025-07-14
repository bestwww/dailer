/**
 * Основные типы данных для системы автодозвона
 */

// === Базовые типы ===

export interface BaseEntity {
  id: number;
  createdAt: Date;
  updatedAt: Date;
}

export interface User extends BaseEntity {
  username: string;
  email: string;
  passwordHash: string;
  role: 'admin' | 'manager' | 'user' | 'viewer';
  permissions: Record<string, boolean>;
  firstName?: string;
  lastName?: string;
  phone?: string;
  isActive: boolean;
  isVerified: boolean;
  lastLoginAt?: Date;
  timezone: string;
  language: string;
}

// === Кампании ===

export type CampaignStatus = 'draft' | 'active' | 'paused' | 'completed' | 'cancelled';

export interface Campaign extends BaseEntity {
  name: string;
  description?: string;
  
  // Настройки аудио
  audioFilePath?: string;
  audioFileName?: string;
  audioDuration: number; // в секундах
  
  // Статус кампании
  status: CampaignStatus;
  
  // Настройки обзвона
  maxConcurrentCalls: number;
  callsPerMinute: number;
  retryAttempts: number;
  retryDelay: number; // в секундах
  
  // Настройки времени работы
  workTimeStart: string; // HH:mm формат
  workTimeEnd: string;   // HH:mm формат
  workDays: number[];    // дни недели (1=понедельник)
  timezone: string;
  
  // Планировщик кампаний
  isScheduled: boolean;
  scheduledStart?: Date; // планируемое время запуска
  scheduledStop?: Date;  // планируемое время остановки
  isRecurring: boolean;  // повторяющееся расписание
  cronExpression?: string; // cron выражение для повторяющихся запусков
  
  // Битрикс24 интеграция
  bitrixCreateLeads: boolean;
  bitrixResponsibleId?: number;
  bitrixSourceId: string;
  
  // Метаданные
  createdBy?: number;
  
  // Статистика
  totalContacts: number;
  completedCalls: number;
  successfulCalls: number;
  failedCalls: number;
  interestedResponses: number;
}

// === Контакты ===

export type ContactStatus = 'pending' | 'calling' | 'completed' | 'failed' | 'blacklisted' | 'do_not_call' | 'interested' | 'not_interested' | 'retry' | 'new' | 'callback';

export interface Contact extends BaseEntity {
  campaignId: number;
  
  // Контактная информация
  phoneNumber: string;
  firstName?: string;
  lastName?: string;
  email?: string;
  company?: string;
  
  // Статус обработки
  status: ContactStatus;
  
  // Попытки звонков
  callAttempts: number;
  lastCallAt?: Date;
  nextCallAt?: Date;
  
  // Битрикс24 интеграция
  bitrixContactId?: number;
  bitrixLeadId?: number;
  
  // Метаданные
  customFields: Record<string, any>;
  notes?: string;
  
  // Временная зона
  timezone: string;
}

// === Результаты звонков ===

export type CallStatus = 'answered' | 'busy' | 'no_answer' | 'failed' | 'cancelled' | 'blacklisted';

export interface CallResult extends BaseEntity {
  contactId: number;
  campaignId: number;
  
  // Информация о звонке
  callUuid?: string; // UUID звонка от FreeSWITCH
  phoneNumber: string;
  
  // Результаты звонка
  callStatus: CallStatus;
  callDuration: number; // в секундах
  ringDuration: number; // время до ответа
  
  // DTMF ответ пользователя
  dtmfResponse?: string;
  dtmfTimestamp?: Date;
  
  // AMD результаты
  isAnsweringMachine: boolean;
  amdConfidence?: number; // уверенность AMD (0.00-1.00)
  amdDetectionTime?: number; // время обнаружения в мс
  
  // Битрикс24 интеграция
  bitrixLeadId?: number;
  bitrixLeadCreated: boolean;
  bitrixError?: string;
  
  // Аудио записи
  recordingFilePath?: string;
  recordingDuration?: number;
  
  // Технические данные
  callerIdName?: string;
  callerIdNumber?: string;
  hangupCause?: string;
  
  // Качество звонка
  audioQualityScore?: number;
  networkQuality?: string;
  
  // Дополнительные данные
  additionalData: Record<string, any>;
  
  // Времена звонка
  callStartedAt?: Date;
  callAnsweredAt?: Date;
  callEndedAt?: Date;
}

// === Черный список ===

export type BlacklistReason = 
  | 'user_request'           // Запрос пользователя
  | 'complaint'              // Жалоба
  | 'invalid_number'         // Некорректный номер
  | 'do_not_call_registry'   // Реестр "не звонить"
  | 'fraud_suspected'        // Подозрение на мошенничество
  | 'repeated_no_answer'     // Многократное отсутствие ответа
  | 'operator_decision'      // Решение оператора
  | 'auto_detected'          // Автоматически обнаружен
  | 'other';                 // Другая причина

export interface BlacklistEntry extends BaseEntity {
  phone: string;              // Номер телефона
  reason?: string;            // Описание причины
  reasonType: BlacklistReason; // Тип причины
  addedBy?: number;           // Кто добавил (ID пользователя)
  addedByName?: string;       // Имя добавившего
  source?: string;            // Источник (campaign_id, manual, import, etc.)
  isActive: boolean;          // Активна ли запись
  expiresAt?: Date;           // Дата истечения (для временной блокировки)
  lastAttemptAt?: Date;       // Последняя попытка звонка
  attemptCount: number;       // Количество попыток звонков
  notes?: string;             // Дополнительные заметки
}

export interface CreateBlacklistRequest {
  phone: string;
  reason?: string;
  reasonType: BlacklistReason;
  source?: string;
  expiresAt?: Date;
  notes?: string;
}

export interface UpdateBlacklistRequest {
  reason?: string;
  reasonType?: BlacklistReason;
  isActive?: boolean;
  expiresAt?: Date;
  notes?: string;
}

export interface BulkBlacklistRequest {
  phones: string[];
  reason?: string;
  reasonType: BlacklistReason;
  source?: string;
  notes?: string;
}

export interface BlacklistStats {
  totalEntries: number;
  activeEntries: number;
  expiredEntries: number;
  blockedCallsToday: number;
  blockedCallsTotal: number;
  topReasons: Array<{
    reasonType: BlacklistReason;
    count: number;
  }>;
}

// === Настройки системы ===

export type SettingType = 'string' | 'number' | 'boolean' | 'json';

export interface SystemSetting extends BaseEntity {
  settingKey: string;
  settingValue?: string;
  settingType: SettingType;
  description?: string;
  isPublic: boolean;
  updatedBy?: number;
}

// === FreeSWITCH события ===

export interface FreeSwitchEvent {
  eventName: string;
  eventSubclass?: string;
  campaignId?: number;
  phoneNumber?: string;
  callUuid?: string;
  dtmfResponse?: string;
  callResult?: string;
  amdResult?: string;
  hangupCause?: string;
  callDuration?: number;
  [key: string]: any;
}

// === API типы ===

export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  message?: string;
  error?: string;
  timestamp: string;
}

export interface PaginatedResponse<T> extends ApiResponse<T[]> {
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}

export interface ApiError {
  code: string;
  message: string;
  details?: any;
}

// === Запросы создания/обновления ===

export interface CreateCampaignRequest {
  name: string;
  description?: string;
  // Аудио файлы
  audioFilePath?: string;
  audioFileName?: string;
  maxConcurrentCalls?: number;
  callsPerMinute?: number;
  retryAttempts?: number;
  retryDelay?: number;
  workTimeStart?: string;
  workTimeEnd?: string;
  workDays?: number[];
  timezone?: string;
  // Планировщик
  isScheduled?: boolean;
  scheduledStart?: Date;
  scheduledStop?: Date;
  isRecurring?: boolean;
  cronExpression?: string;
  bitrixCreateLeads?: boolean;
  bitrixResponsibleId?: number;
  bitrixSourceId?: string;
}

export interface UpdateCampaignRequest extends Partial<CreateCampaignRequest> {
  status?: CampaignStatus;
}

export interface CreateContactRequest {
  campaignId: number;
  phoneNumber: string;
  firstName?: string;
  lastName?: string;
  email?: string;
  company?: string;
  customFields?: Record<string, any>;
  notes?: string;
  timezone?: string;
  bitrixContactId?: number;
  bitrixLeadId?: number;
}

export interface UpdateContactRequest {
  firstName?: string;
  lastName?: string;
  email?: string;
  company?: string;
  status?: ContactStatus;
  customFields?: Record<string, any>;
  notes?: string;
  timezone?: string;
  bitrixContactId?: number;
  bitrixLeadId?: number;
}

export interface BulkCreateContactsRequest {
  contacts: CreateContactRequest[];
  campaignId: number;
}

// === Битрикс24 типы ===

export interface BitrixConfig {
  domain: string;
  clientId: string;
  clientSecret: string;
  redirectUri: string;
  accessToken?: string;
  refreshToken?: string;
  expiresAt?: Date;
}

export interface BitrixLead {
  title: string;
  name?: string;
  phone?: string;
  email?: string;
  sourceId: string;
  responsibleId?: number;
  comments?: string;
  additionalFields?: Record<string, any>;
}

// === Статистика ===

export interface CampaignStats {
  campaignId: number;
  campaignName: string;
  status: CampaignStatus;
  
  // Общие метрики
  totalContacts: number;
  completedCalls: number;
  successfulCalls: number;
  failedCalls: number;
  
  // DTMF ответы
  interestedResponses: number;
  notInterestedResponses: number;
  noResponses: number;
  
  // AMD статистика
  humanAnswers: number;
  machineAnswers: number;
  unknownAnswers: number;
  
  // Конверсия
  conversionRate: number; // процент заинтересованных
  answerRate: number;     // процент отвеченных звонков
  
  // Битрикс24
  leadsCreated: number;
  leadsErrors: number;
  
  // Временные метрики
  averageCallDuration: number;
  averageRingDuration: number;
  
  // Период статистики
  startDate: Date;
  endDate: Date;
  lastUpdated: Date;
}

// === Конфигурация приложения ===

export interface AppConfig {
  // Сервер
  port: number;
  nodeEnv: string;
  
  // База данных
  databaseUrl: string;
  
  // Redis
  redisUrl: string;
  
  // FreeSWITCH
  freeswitchHost: string;
  freeswitchPort: number;
  freeswitchPassword: string;
  
  // JWT
  jwtSecret: string;
  jwtExpiresIn: string;
  
  // Файлы
  audioUploadPath: string;
  audioMaxSize: number;
  supportedAudioFormats: string[];
  
  // Диалер
  maxConcurrentCalls: number;
  callsPerMinute: number;
  defaultRetryAttempts: number;
  defaultRetryDelay: number;
  
  // AMD
  amdEnabled: boolean;
  amdTimeout: number;
  amdSilenceTimeout: number;
  
  // Битрикс24
  bitrix24Domain?: string;
  bitrix24ClientId?: string;
  bitrix24ClientSecret?: string;
  bitrix24RedirectUri?: string;
  
  // Логирование
  logLevel: string;
  logFilePath: string;
}

// === WebSocket события ===

export interface WebSocketEvent {
  type: string;
  data: any;
  timestamp: string;
}

export interface CallStatusUpdate extends WebSocketEvent {
  type: 'call_status_update';
  data: {
    campaignId: number;
    contactId: number;
    phone: string;
    status: CallStatus;
    duration?: number;
    dtmfResponse?: string;
  };
}

export interface CampaignStatsUpdate extends WebSocketEvent {
  type: 'campaign_stats_update';
  data: CampaignStats;
} 

// === Webhook Types ===

export type WebhookEventType = 
  | 'call.started'         // Звонок начат
  | 'call.answered'        // Звонок отвечен
  | 'call.completed'       // Звонок завершен
  | 'call.failed'          // Звонок неудачен
  | 'call.dtmf'            // DTMF ответ получен
  | 'call.amd_detected'    // AMD обнаружен
  | 'call.blocked'         // Звонок заблокирован
  | 'campaign.started'     // Кампания запущена
  | 'campaign.stopped'     // Кампания остановлена
  | 'campaign.completed'   // Кампания завершена
  | 'lead.created'         // Лид создан в CRM
  | 'lead.failed'          // Ошибка создания лида
  | 'system.error'         // Системная ошибка
  | 'blacklist.added';     // Номер добавлен в черный список

export interface WebhookEvent {
  id: string;              // UUID события
  eventType: WebhookEventType;
  data: any;               // Данные события
  timestamp: string;       // ISO timestamp
  campaignId?: number;     // ID кампании (если применимо)
  contactId?: number;      // ID контакта (если применимо)
  metadata?: Record<string, any>; // Дополнительные метаданные
}

export interface WebhookEndpoint extends BaseEntity {
  url: string;             // URL для отправки webhook
  name: string;            // Название endpoint'а
  description?: string;    // Описание
  isActive: boolean;       // Активен ли endpoint
  secret?: string;         // Секретный ключ для подписи
  
  // Настройки фильтрации
  eventTypes: WebhookEventType[]; // Типы событий для отправки
  campaignIds?: number[];  // Фильтр по кампаниям (если пусто - все)
  
  // Настройки retry
  maxRetries: number;      // Максимум попыток
  retryDelay: number;      // Задержка между попытками (мс)
  timeout: number;         // Таймаут запроса (мс)
  
  // Статистика
  totalSent: number;       // Всего отправлено
  totalFailed: number;     // Всего неудачных
  lastSentAt?: Date;       // Время последней отправки
  lastFailedAt?: Date;     // Время последней неудачи
  lastError?: string;      // Последняя ошибка
  
  // Безопасность
  allowedIPs?: string[];   // Разрешенные IP (если нужно)
  httpMethod: 'POST' | 'PUT' | 'PATCH'; // HTTP метод
  customHeaders?: Record<string, string>; // Кастомные заголовки
  
  createdBy?: number;      // Кто создал
}

export interface WebhookDelivery extends BaseEntity {
  webhookEndpointId: number;
  eventId: string;         // ID события
  eventType: WebhookEventType;
  
  // Данные запроса
  requestUrl: string;
  requestMethod: string;
  requestHeaders: Record<string, string>;
  requestBody: string;
  
  // Результат
  statusCode?: number;
  responseBody?: string;
  responseHeaders?: Record<string, string>;
  
  // Метрики
  attemptNumber: number;   // Номер попытки
  processingTime: number;  // Время обработки (мс)
  
  // Статус
  status: 'pending' | 'delivered' | 'failed';
  error?: string;
  
  // Времена
  sentAt?: Date;
  deliveredAt?: Date;
  failedAt?: Date;
  nextRetryAt?: Date;
}

export interface CreateWebhookEndpointRequest {
  url: string;
  name: string;
  description?: string;
  isActive?: boolean;
  secret?: string;
  eventTypes: WebhookEventType[];
  campaignIds?: number[];
  maxRetries?: number;
  retryDelay?: number;
  timeout?: number;
  allowedIPs?: string[];
  httpMethod?: 'POST' | 'PUT' | 'PATCH';
  customHeaders?: Record<string, string>;
}

export interface UpdateWebhookEndpointRequest {
  url?: string;
  name?: string;
  description?: string;
  isActive?: boolean;
  secret?: string;
  eventTypes?: WebhookEventType[];
  campaignIds?: number[];
  maxRetries?: number;
  retryDelay?: number;
  timeout?: number;
  allowedIPs?: string[];
  httpMethod?: 'POST' | 'PUT' | 'PATCH';
  customHeaders?: Record<string, string>;
}

export interface WebhookStats {
  totalEndpoints: number;
  activeEndpoints: number;
  totalDeliveries: number;
  successfulDeliveries: number;
  failedDeliveries: number;
  pendingDeliveries: number;
  averageDeliveryTime: number;
  
  // Статистика по типам событий
  eventTypeStats: Array<{
    eventType: WebhookEventType;
    count: number;
    successRate: number;
  }>;
  
  // Статистика по endpoint'ам
  endpointStats: Array<{
    endpointId: number;
    endpointName: string;
    totalSent: number;
    successRate: number;
    averageResponseTime: number;
    lastSentAt?: Date;
  }>;
}

// Webhook события для конкретных случаев
export interface WebhookCallEvent {
  callId: string;
  campaignId: number;
  contactId: number;
  phoneNumber: string;
  callStatus: CallStatus;
  duration?: number;
  dtmfResponse?: string;
  amdResult?: string;
  hangupCause?: string;
  timestamp: string;
}

export interface WebhookCampaignEvent {
  campaignId: number;
  campaignName: string;
  status: CampaignStatus;
  totalContacts: number;
  completedCalls: number;
  timestamp: string;
}

export interface WebhookLeadEvent {
  leadId?: number;
  campaignId: number;
  contactId: number;
  phoneNumber: string;
  dtmfResponse: string;
  bitrixLeadId?: number;
  error?: string;
  timestamp: string;
}

export interface WebhookBlacklistEvent {
  phone: string;
  reason: string;
  reasonType: BlacklistReason;
  addedBy?: string;
  source?: string;
  timestamp: string;
}

export interface WebhookSystemEvent {
  errorCode: string;
  message: string;
  details?: any;
  severity: 'low' | 'medium' | 'high' | 'critical';
  component: string;
  timestamp: string;
} 