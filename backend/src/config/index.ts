/**
 * Конфигурация приложения
 * Загружает и валидирует переменные окружения
 */

import dotenv from 'dotenv';
import { AppConfig } from '@/types';

const Joi = require('joi');

// Загружаем переменные окружения
dotenv.config();

/**
 * Схема валидации переменных окружения
 */
const configSchema = Joi.object({
  // Основные настройки
  NODE_ENV: Joi.string()
    .valid('development', 'production', 'test')
    .default('development'),
  PORT: Joi.number().default(3000),

  // База данных PostgreSQL
  DATABASE_URL: Joi.string().required()
    .description('PostgreSQL connection string'),

  // Redis
  REDIS_URL: Joi.string().required()
    .description('Redis connection string'),

  // FreeSWITCH
  FREESWITCH_HOST: Joi.string().default('localhost')
    .description('FreeSWITCH server hostname'),
  FREESWITCH_PORT: Joi.number().default(8021)
    .description('FreeSWITCH ESL port'),
  FREESWITCH_PASSWORD: Joi.string().default('ClueCon')
    .description('FreeSWITCH ESL password'),

  // JWT
  JWT_SECRET: Joi.string().min(32).required()
    .description('JWT signing secret (min 32 chars)'),
  JWT_EXPIRES_IN: Joi.string().default('24h')
    .description('JWT expiration time'),

  // Файлы
  AUDIO_UPLOAD_PATH: Joi.string().default('./audio')
    .description('Path for audio file uploads'),
  AUDIO_MAX_SIZE: Joi.number().default(10485760)
    .description('Max audio file size in bytes (10MB)'),
  SUPPORTED_AUDIO_FORMATS: Joi.string().default('wav,mp3,aiff')
    .description('Supported audio formats (comma separated)'),

  // Настройки диалера
  MAX_CONCURRENT_CALLS: Joi.number().min(1).max(100).default(10)
    .description('Maximum concurrent calls'),
  CALLS_PER_MINUTE: Joi.number().min(1).max(1000).default(30)
    .description('Calls per minute limit'),
  DEFAULT_RETRY_ATTEMPTS: Joi.number().min(0).max(10).default(3)
    .description('Default retry attempts for failed calls'),
  DEFAULT_RETRY_DELAY: Joi.number().min(60).default(300)
    .description('Default retry delay in seconds'),

  // AMD настройки
  AMD_ENABLED: Joi.boolean().default(true)
    .description('Enable Answering Machine Detection'),
  AMD_TIMEOUT: Joi.number().default(5000)
    .description('AMD timeout in milliseconds'),
  AMD_SILENCE_TIMEOUT: Joi.number().default(1000)
    .description('AMD silence timeout in milliseconds'),

  // Битрикс24 интеграция (опционально)
  BITRIX24_DOMAIN: Joi.string().allow('').optional()
    .description('Bitrix24 domain (without https://)'),
  BITRIX24_CLIENT_ID: Joi.string().allow('').optional()
    .description('Bitrix24 OAuth client ID'),
  BITRIX24_CLIENT_SECRET: Joi.string().allow('').optional()
    .description('Bitrix24 OAuth client secret'),
  BITRIX24_REDIRECT_URI: Joi.string().allow('').optional()
    .description('Bitrix24 OAuth redirect URI'),

  // Логирование
  LOG_LEVEL: Joi.string()
    .valid('error', 'warn', 'info', 'http', 'verbose', 'debug', 'silly')
    .default('info'),
  LOG_FILE_PATH: Joi.string().default('./logs/app.log')
    .description('Log file path'),

  // CORS настройки (для development)
  ENABLE_CORS: Joi.boolean().default(true)
    .description('Enable CORS for development'),

}).unknown().required();

/**
 * Валидация переменных окружения
 */
const { error, value: envVars } = configSchema.validate(process.env);

if (error) {
  throw new Error(`Config validation error: ${error.message}`);
}

/**
 * Конфигурация приложения
 */
export const config: AppConfig = {
  // Сервер
  port: envVars.PORT,
  nodeEnv: envVars.NODE_ENV,

  // База данных
  databaseUrl: envVars.DATABASE_URL,

  // Redis
  redisUrl: envVars.REDIS_URL,

  // FreeSWITCH
  freeswitchHost: envVars.FREESWITCH_HOST,
  freeswitchPort: envVars.FREESWITCH_PORT,
  freeswitchPassword: envVars.FREESWITCH_PASSWORD,

  // JWT
  jwtSecret: envVars.JWT_SECRET,
  jwtExpiresIn: envVars.JWT_EXPIRES_IN,

  // Файлы
  audioUploadPath: envVars.AUDIO_UPLOAD_PATH,
  audioMaxSize: envVars.AUDIO_MAX_SIZE,
  supportedAudioFormats: envVars.SUPPORTED_AUDIO_FORMATS.split(','),

  // Диалер
  maxConcurrentCalls: envVars.MAX_CONCURRENT_CALLS,
  callsPerMinute: envVars.CALLS_PER_MINUTE,
  defaultRetryAttempts: envVars.DEFAULT_RETRY_ATTEMPTS,
  defaultRetryDelay: envVars.DEFAULT_RETRY_DELAY,

  // AMD
  amdEnabled: envVars.AMD_ENABLED,
  amdTimeout: envVars.AMD_TIMEOUT,
  amdSilenceTimeout: envVars.AMD_SILENCE_TIMEOUT,

  // Битрикс24
  bitrix24Domain: envVars.BITRIX24_DOMAIN || undefined,
  bitrix24ClientId: envVars.BITRIX24_CLIENT_ID || undefined,
  bitrix24ClientSecret: envVars.BITRIX24_CLIENT_SECRET || undefined,
  bitrix24RedirectUri: envVars.BITRIX24_REDIRECT_URI || undefined,

  // Логирование
  logLevel: envVars.LOG_LEVEL,
  logFilePath: envVars.LOG_FILE_PATH,
};

/**
 * Экспорт отдельных настроек для удобства
 */
export const {
  port,
  nodeEnv,
  databaseUrl,
  redisUrl,
  freeswitchHost,
  freeswitchPort,
  freeswitchPassword,
  jwtSecret,
  audioUploadPath,
  maxConcurrentCalls,
  logLevel,
} = config;

/**
 * Проверка, что мы в production окружении
 */
export const isProduction = nodeEnv === 'production';

/**
 * Проверка, что мы в development окружении
 */
export const isDevelopment = nodeEnv === 'development';

/**
 * Проверка, что мы в test окружении
 */
export const isTest = nodeEnv === 'test';

/**
 * Валидация критически важных настроек
 */
export function validateCriticalConfig(): void {
  const criticalSettings = [
    { name: 'DATABASE_URL', value: databaseUrl },
    { name: 'REDIS_URL', value: redisUrl },
    { name: 'JWT_SECRET', value: jwtSecret },
    { name: 'FREESWITCH_HOST', value: freeswitchHost },
  ];

  const missing = criticalSettings.filter(setting => !setting.value);
  
  if (missing.length > 0) {
    const missingNames = missing.map(s => s.name).join(', ');
    throw new Error(`Missing critical configuration: ${missingNames}`);
  }

  console.log('✅ All critical configuration settings are present');
}

/**
 * Вывод информации о конфигурации (без секретов)
 */
export function logConfigInfo(): void {
  console.log('\n🔧 Application Configuration:');
  console.log(`   Environment: ${nodeEnv}`);
  console.log(`   Port: ${port}`);
  console.log(`   FreeSWITCH: ${freeswitchHost}:${freeswitchPort}`);
  console.log(`   Max Concurrent Calls: ${maxConcurrentCalls}`);
  console.log(`   Calls Per Minute: ${config.callsPerMinute}`);
  console.log(`   AMD Enabled: ${config.amdEnabled ? '✅' : '❌'}`);
  console.log(`   Bitrix24 Integration: ${config.bitrix24Domain ? '✅' : '❌'}`);
  console.log(`   Log Level: ${logLevel}`);
  console.log('');
} 