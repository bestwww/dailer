/**
 * Сервис для работы с часовыми поясами
 * Этап 6.2.4: Настройки времени обзвона и часовые пояса
 */

import { log } from '@/utils/logger';
import { Campaign, Contact } from '@/types';

export interface TimeZoneInfo {
  timezone: string;
  offset: number; // в минутах от UTC
  isDST: boolean;
  name: string;
  abbreviation: string;
}

export interface WorkingHoursConfig {
  startTime: string; // HH:mm формат
  endTime: string;   // HH:mm формат
  workDays: number[]; // дни недели (1=понедельник, 7=воскресенье)
  timezone: string;
}

export interface TimeSlot {
  hour: number;
  minute: number;
}

export class TimezoneService {
  private static instance: TimezoneService;
  
  // Кэш часовых поясов
  private timezoneCache = new Map<string, TimeZoneInfo>();
  
  // Поддерживаемые часовые пояса
  private supportedTimezones = [
    'UTC',
    'Europe/Moscow',
    'Europe/London',
    'Europe/Berlin',
    'Europe/Paris',
    'Europe/Kiev',
    'Europe/Minsk',
    'Asia/Yekaterinburg',
    'Asia/Omsk',
    'Asia/Novosibirsk',
    'Asia/Krasnoyarsk',
    'Asia/Irkutsk',
    'Asia/Yakutsk',
    'Asia/Vladivostok',
    'Asia/Magadan',
    'Asia/Kamchatka',
    'America/New_York',
    'America/Los_Angeles',
    'America/Chicago',
    'America/Denver',
    'America/Toronto',
    'America/Vancouver',
    'Asia/Shanghai',
    'Asia/Tokyo',
    'Asia/Seoul',
    'Asia/Singapore',
    'Asia/Dubai',
    'Asia/Tashkent',
    'Asia/Almaty',
    'Asia/Bishkek',
    'Asia/Dushanbe',
    'Asia/Ashgabat',
    'Asia/Baku',
    'Asia/Yerevan',
    'Asia/Tbilisi',
    'Australia/Sydney',
    'Australia/Melbourne',
    'Australia/Perth'
  ];

  private constructor() {}

  static getInstance(): TimezoneService {
    if (!TimezoneService.instance) {
      TimezoneService.instance = new TimezoneService();
    }
    return TimezoneService.instance;
  }

  /**
   * Получение информации о часовом поясе
   */
  getTimezoneInfo(timezone: string): TimeZoneInfo {
    if (this.timezoneCache.has(timezone)) {
      return this.timezoneCache.get(timezone)!;
    }

    try {
      const now = new Date();
      const utcTime = new Date(now.getTime() + now.getTimezoneOffset() * 60000);
      
      // Создаем дату в указанном часовом поясе
      const localTime = new Date(utcTime.toLocaleString('en-US', { timeZone: timezone }));
      
      // Вычисляем смещение
      const offset = (localTime.getTime() - utcTime.getTime()) / (60 * 1000);
      
      // Проверяем DST
      const jan = new Date(now.getFullYear(), 0, 1);
      const jul = new Date(now.getFullYear(), 6, 1);
      const janOffset = this.getOffsetForDate(jan, timezone);
      const julOffset = this.getOffsetForDate(jul, timezone);
      const isDST = offset !== Math.max(janOffset, julOffset);
      
      // Получаем название и аббревиатуру
      const formatter = new Intl.DateTimeFormat('en', {
        timeZone: timezone,
        timeZoneName: 'long'
      });
      
      const parts = formatter.formatToParts(now);
      const timeZoneName = parts.find(part => part.type === 'timeZoneName')?.value || timezone;
      
      const shortFormatter = new Intl.DateTimeFormat('en', {
        timeZone: timezone,
        timeZoneName: 'short'
      });
      
      const shortParts = shortFormatter.formatToParts(now);
      const abbreviation = shortParts.find(part => part.type === 'timeZoneName')?.value || timezone;

      const info: TimeZoneInfo = {
        timezone,
        offset,
        isDST,
        name: timeZoneName || timezone,
        abbreviation: abbreviation || timezone
      };

      this.timezoneCache.set(timezone, info);
      return info;

    } catch (error) {
      log.error(`Ошибка получения информации о часовом поясе ${timezone}:`, error);
      
      // Возвращаем UTC по умолчанию
      const defaultInfo: TimeZoneInfo = {
        timezone: 'UTC',
        offset: 0,
        isDST: false,
        name: 'Coordinated Universal Time',
        abbreviation: 'UTC'
      };
      
      return defaultInfo;
    }
  }

  /**
   * Получение смещения для конкретной даты
   */
  private getOffsetForDate(date: Date, timezone: string): number {
    const utcTime = new Date(date.getTime() + date.getTimezoneOffset() * 60000);
    const localTime = new Date(utcTime.toLocaleString('en-US', { timeZone: timezone }));
    return (localTime.getTime() - utcTime.getTime()) / (60 * 1000);
  }

  /**
   * Конвертация времени из одного часового пояса в другой
   */
  convertTime(date: Date, fromTimezone: string, toTimezone: string): Date {
    try {
      // Получаем время в исходном часовом поясе
      const utcTime = new Date(date.toLocaleString('en-US', { timeZone: 'UTC' }));
      
      // Конвертируем в целевой часовой пояс
      const targetTime = new Date(utcTime.toLocaleString('en-US', { timeZone: toTimezone }));
      
      return targetTime;
    } catch (error) {
      log.error(`Ошибка конвертации времени из ${fromTimezone} в ${toTimezone}:`, error);
      return date;
    }
  }

  /**
   * Получение текущего времени в указанном часовом поясе
   */
  getCurrentTimeInTimezone(timezone: string): Date {
    try {
      const now = new Date();
      const utcTime = new Date(now.getTime() + now.getTimezoneOffset() * 60000);
      return new Date(utcTime.toLocaleString('en-US', { timeZone: timezone }));
    } catch (error) {
      log.error(`Ошибка получения текущего времени в ${timezone}:`, error);
      return new Date();
    }
  }

  /**
   * Парсинг времени из строки HH:mm в объект TimeSlot
   */
  parseTimeSlot(timeString: string): TimeSlot {
    const match = timeString.match(/^(\d{1,2}):(\d{2})$/);
    if (!match) {
      throw new Error(`Некорректный формат времени: ${timeString}`);
    }
    
    const hour = parseInt(match[1] || '0');
    const minute = parseInt(match[2] || '0');
    
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw new Error(`Некорректное время: ${timeString}`);
    }
    
    return { hour, minute };
  }

  /**
   * Проверка, находится ли время в рабочих часах
   */
  isWorkingTime(config: WorkingHoursConfig, checkDate?: Date): boolean {
    try {
      const currentTime = checkDate || this.getCurrentTimeInTimezone(config.timezone);
      const currentDay = currentTime.getDay() === 0 ? 7 : currentTime.getDay(); // Воскресенье = 7
      
      // Проверяем рабочие дни
      if (!config.workDays.includes(currentDay)) {
        return false;
      }
      
      // Парсим время
      const startTime = this.parseTimeSlot(config.startTime);
      const endTime = this.parseTimeSlot(config.endTime);
      
      const currentHour = currentTime.getHours();
      const currentMinute = currentTime.getMinutes();
      
      // Конвертируем время в минуты для сравнения
      const currentMinutes = currentHour * 60 + currentMinute;
      const startMinutes = startTime.hour * 60 + startTime.minute;
      const endMinutes = endTime.hour * 60 + endTime.minute;
      
      // Проверяем, если рабочее время переходит через полночь
      if (startMinutes > endMinutes) {
        return currentMinutes >= startMinutes || currentMinutes < endMinutes;
      }
      
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
      
    } catch (error) {
      log.error('Ошибка проверки рабочего времени:', error);
      return false;
    }
  }

  /**
   * Проверка рабочего времени для кампании
   */
  isCampaignWorkingTime(campaign: Campaign, checkDate?: Date): boolean {
    const config: WorkingHoursConfig = {
      startTime: campaign.workTimeStart,
      endTime: campaign.workTimeEnd,
      workDays: campaign.workDays,
      timezone: campaign.timezone
    };
    
    return this.isWorkingTime(config, checkDate);
  }

  /**
   * Проверка рабочего времени для контакта с учетом его часового пояса
   */
  isContactWorkingTime(
    campaign: Campaign, 
    contact: Contact, 
    checkDate?: Date
  ): boolean {
    try {
      // Получаем текущее время в часовом поясе контакта
      const contactTime = checkDate || this.getCurrentTimeInTimezone(contact.timezone);
      
      // Создаем конфигурацию для часового пояса контакта
      const contactConfig: WorkingHoursConfig = {
        startTime: campaign.workTimeStart,
        endTime: campaign.workTimeEnd,
        workDays: campaign.workDays,
        timezone: contact.timezone
      };
      
      return this.isWorkingTime(contactConfig, contactTime);
      
    } catch (error) {
      log.error(`Ошибка проверки рабочего времени для контакта ${contact.id}:`, error);
      return false;
    }
  }

  /**
   * Получение следующего рабочего времени для кампании
   */
  getNextWorkingTime(campaign: Campaign, fromDate?: Date): Date {
    const startDate = fromDate || new Date();
    const maxDays = 14; // Максимум 14 дней поиска
    
    for (let dayOffset = 0; dayOffset < maxDays; dayOffset++) {
      const checkDate = new Date(startDate);
      checkDate.setDate(startDate.getDate() + dayOffset);
      
      // Устанавливаем время начала работы
      const startTime = this.parseTimeSlot(campaign.workTimeStart);
      checkDate.setHours(startTime.hour, startTime.minute, 0, 0);
      
      // Конвертируем в часовой пояс кампании
      const targetTime = new Date(checkDate.toLocaleString('en-US', { timeZone: campaign.timezone }));
      
      if (this.isCampaignWorkingTime(campaign, targetTime)) {
        return targetTime;
      }
    }
    
    // Если не найдено рабочее время, возвращаем завтра в начале рабочего дня
    const tomorrow = new Date(startDate);
    tomorrow.setDate(startDate.getDate() + 1);
    const startTime = this.parseTimeSlot(campaign.workTimeStart);
    tomorrow.setHours(startTime.hour, startTime.minute, 0, 0);
    
    return tomorrow;
  }

  /**
   * Получение следующего рабочего времени для контакта
   */
  getNextWorkingTimeForContact(
    campaign: Campaign, 
    contact: Contact, 
    fromDate?: Date
  ): Date {
    const startDate = fromDate || new Date();
    const maxDays = 14; // Максимум 14 дней поиска
    
    for (let dayOffset = 0; dayOffset < maxDays; dayOffset++) {
      const checkDate = new Date(startDate);
      checkDate.setDate(startDate.getDate() + dayOffset);
      
      // Устанавливаем время начала работы в часовом поясе контакта
      const startTime = this.parseTimeSlot(campaign.workTimeStart);
      const contactTime = this.getCurrentTimeInTimezone(contact.timezone);
      const targetTime = new Date(contactTime);
      targetTime.setHours(startTime.hour, startTime.minute, 0, 0);
      
      if (this.isContactWorkingTime(campaign, contact, targetTime)) {
        return targetTime;
      }
    }
    
    // Если не найдено рабочее время, возвращаем завтра в начале рабочего дня
    const tomorrow = new Date(startDate);
    tomorrow.setDate(startDate.getDate() + 1);
    const startTime = this.parseTimeSlot(campaign.workTimeStart);
    tomorrow.setHours(startTime.hour, startTime.minute, 0, 0);
    
    return tomorrow;
  }

  /**
   * Получение списка поддерживаемых часовых поясов
   */
  getSupportedTimezones(): string[] {
    return [...this.supportedTimezones];
  }

  /**
   * Валидация часового пояса
   */
  isValidTimezone(timezone: string): boolean {
    try {
      Intl.DateTimeFormat(undefined, { timeZone: timezone });
      return true;
    } catch (error) {
      return false;
    }
  }

  /**
   * Получение часового пояса по умолчанию
   */
  getDefaultTimezone(): string {
    return 'Europe/Moscow';
  }

  /**
   * Получение информации о всех поддерживаемых часовых поясах
   */
  getAllTimezoneInfo(): TimeZoneInfo[] {
    return this.supportedTimezones.map(tz => this.getTimezoneInfo(tz));
  }

  /**
   * Форматирование времени для отображения
   */
  formatTimeForDisplay(date: Date, timezone: string, locale: string = 'ru-RU'): string {
    try {
      return date.toLocaleString(locale, {
        timeZone: timezone,
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
      });
    } catch (error) {
      log.error(`Ошибка форматирования времени для ${timezone}:`, error);
      return date.toLocaleString(locale);
    }
  }

  /**
   * Получение смещения часового пояса в человекочитаемом формате
   */
  getTimezoneOffsetString(timezone: string): string {
    const info = this.getTimezoneInfo(timezone);
    const hours = Math.floor(Math.abs(info.offset) / 60);
    const minutes = Math.abs(info.offset) % 60;
    const sign = info.offset >= 0 ? '+' : '-';
    
    return `UTC${sign}${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}`;
  }
}

// Экспорт singleton instance
export const timezoneService = TimezoneService.getInstance(); 