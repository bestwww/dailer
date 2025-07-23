/**
 * Asterisk адаптер для VoIPProvider интерфейса
 * Реализация для работы с Asterisk через AMI
 */

import { EventEmitter } from 'events';
import AsteriskManager from 'asterisk-manager';
import { log } from '@/utils/logger';
import { 
  VoIPProvider, 
  VoIPConnectionStatus, 
  VoIPStats,
  VoIPCallCreatedEvent,
  VoIPCallAnsweredEvent,
  VoIPCallHangupEvent,
  VoIPCallDTMFEvent,
  VoIPLeadCreatedEvent
} from '../voip-provider';

interface AsteriskEvent {
  event: string;
  uniqueid?: string;
  channel?: string;
  calleridnum?: string;
  calleridname?: string;
  context?: string;
  exten?: string;
  priority?: string;
  application?: string;
  data?: string;
  cause?: string;
  causeTxt?: string;
  duration?: string;
  billableseconds?: string;
  digit?: string;
  [key: string]: any;
}

export class AsteriskAdapter extends EventEmitter implements VoIPProvider {
  private amiClient: any = null;
  private connected: boolean = false;
  private reconnectAttempts: number = 0;
  private maxReconnectAttempts: number = 10;
  private reconnectDelay: number = 5000;
  private reconnectTimer: NodeJS.Timeout | null = null;

  constructor(private config: { host: string; port: number; username: string; password: string }) {
    super();
    log.info('🆕 AsteriskAdapter: Initializing Asterisk adapter');
    log.info(`🔧 Config: ${this.config.host}:${this.config.port} (user: ${this.config.username})`);
  }

  /**
   * Подключение к Asterisk AMI
   */
  async connect(): Promise<void> {
    try {
      if (this.connected) {
        log.warn('AsteriskAdapter: Already connected to Asterisk AMI');
        return;
      }

      log.info('🔌 AsteriskAdapter: Connecting to Asterisk AMI...');
      log.info(`📡 Host: ${this.config.host}:${this.config.port}, User: ${this.config.username}`);
      
      // Создаем AMI клиент
      this.amiClient = new AsteriskManager(
        this.config.port,
        this.config.host,
        this.config.username,
        this.config.password,
        true // События включены
      );

      // Настраиваем подключение с автоматическим переподключением
      this.amiClient.keepConnected();

      return new Promise((resolve, reject) => {
        const timeout = setTimeout(() => {
          log.error(`❌ AsteriskAdapter: Connection timeout after 10s to ${this.config.host}:${this.config.port}`);
          reject(new Error('Asterisk AMI connection timeout'));
        }, 10000);

        // Обработчик успешного подключения
        this.amiClient.on('connect', () => {
          clearTimeout(timeout);
          this.connected = true;
          this.reconnectAttempts = 0;
          
          log.info('✅ AsteriskAdapter: Connected to Asterisk AMI successfully');
          
          // Настраиваем обработчики событий
          this.setupEventHandlers();
          
          this.emit('connected');
          resolve();
        });

        // Обработчик ошибок подключения
        this.amiClient.on('error', (error: Error) => {
          clearTimeout(timeout);
          this.connected = false;
          
          log.error(`❌ AsteriskAdapter: AMI connection error: ${error.message}`);
          this.emit('error', error);
          
          // Планируем переподключение
          this.scheduleReconnect();
          
          reject(error);
        });

        // Обработчик отключения
        this.amiClient.on('disconnect', () => {
          this.connected = false;
          log.warn('🔌 AsteriskAdapter: Disconnected from Asterisk AMI');
          this.emit('disconnected');
          
          // Планируем переподключение
          this.scheduleReconnect();
        });
      });
      
    } catch (error) {
      log.error('❌ AsteriskAdapter: Failed to connect to Asterisk:', error);
      this.connected = false;
      this.emit('error', error);
      throw error;
    }
  }

  /**
   * Отключение от Asterisk
   */
  disconnect(): void {
    try {
      // Отменяем таймер переподключения
      if (this.reconnectTimer) {
        clearTimeout(this.reconnectTimer);
        this.reconnectTimer = null;
      }

      if (this.amiClient) {
        log.info('🔌 AsteriskAdapter: Disconnecting from Asterisk AMI...');
        this.amiClient.disconnect();
        this.amiClient = null;
      }
      
      this.connected = false;
      this.emit('disconnected');
      log.info('✅ AsteriskAdapter: Disconnected from Asterisk');
    } catch (error) {
      log.error('❌ AsteriskAdapter: Error during disconnect:', error);
    }
  }

  /**
   * Проверка статуса подключения
   */
  isConnected(): boolean {
    return this.connected;
  }

  /**
   * Инициация звонка через Asterisk
   */
  async makeCall(phoneNumber: string, campaignId: number, audioFilePath?: string): Promise<string> {
    if (!this.connected || !this.amiClient) {
      throw new Error('AsteriskAdapter: Not connected to Asterisk AMI');
    }

    try {
      log.info(`📞 AsteriskAdapter: Making call to ${phoneNumber} (campaign: ${campaignId})`);
      
      const callUuid = this.generateUUID();
      
      // Нормализация номера телефона
      const normalizedNumber = phoneNumber.replace(/^\+/, '');
      
      // Asterisk Originate action
      const originateAction = {
        Action: 'Originate',
        Channel: `PJSIP/${normalizedNumber}@trunk`, // Используем настроенный trunk (62.141.121.197:5070)
        Context: 'campaign-calls', // Контекст в диалплане
        Exten: campaignId.toString(), // Extension = ID кампании
        Priority: 1,
        Variables: {
          CAMPAIGN_ID: campaignId,
          PHONE_NUMBER: phoneNumber,
          CALL_UUID: callUuid,
          NORMALIZED_NUMBER: normalizedNumber,
          SIP_PROVIDER: '62.141.121.197:5070',
          ...(audioFilePath && { AUDIO_FILE: audioFilePath })
        },
        ChannelId: callUuid, // Используем наш UUID как Channel ID
        Timeout: 30000, // 30 секунд таймаут
        CallerID: process.env.SIP_CALLER_ID_NUMBER || '74951234567' // Из переменной окружения
      };

      return new Promise((resolve, reject) => {
        const timeout = setTimeout(() => {
          log.error(`❌ AsteriskAdapter: Originate timeout for ${phoneNumber}`);
          reject(new Error(`Asterisk Originate timeout for ${phoneNumber}`));
        }, 35000);

        this.amiClient.action(originateAction, (err: any, res: any) => {
          clearTimeout(timeout);
          
          if (err) {
            log.error(`❌ AsteriskAdapter: Originate failed for ${phoneNumber}:`, err);
            reject(new Error(`Asterisk Originate failed: ${err.message || err}`));
            return;
          }

          // Проверяем ответ Asterisk
          if (res && res.response === 'Success') {
            log.info(`✅ AsteriskAdapter: Originate success for ${phoneNumber}, UUID: ${callUuid}`);
            resolve(callUuid);
          } else {
            const errorMsg = res?.message || 'Unknown Asterisk error';
            log.error(`❌ AsteriskAdapter: Originate failed for ${phoneNumber}: ${errorMsg}`);
            reject(new Error(`Asterisk Originate failed: ${errorMsg}`));
          }
        });
      });
      
    } catch (error) {
      log.error(`❌ AsteriskAdapter: Failed to make call to ${phoneNumber}:`, error);
      throw error;
    }
  }

  /**
   * Завершение звонка
   */
  async hangupCall(callUuid: string): Promise<void> {
    if (!this.connected || !this.amiClient) {
      throw new Error('AsteriskAdapter: Not connected to Asterisk AMI');
    }

    try {
      log.info(`📞 AsteriskAdapter: Hanging up call ${callUuid}`);
      
      const hangupAction = {
        Action: 'Hangup',
        Channel: callUuid, // Используем UUID как Channel ID
        Cause: 16 // Normal Clearing
      };

      return new Promise((resolve, _reject) => {
        const timeout = setTimeout(() => {
          log.warn(`⚠️ AsteriskAdapter: Hangup timeout for ${callUuid}, continuing...`);
          resolve(); // Не считаем timeout критической ошибкой
        }, 10000);

        this.amiClient.action(hangupAction, (err: any, res: any) => {
          clearTimeout(timeout);
          
          if (err) {
            log.warn(`⚠️ AsteriskAdapter: Hangup warning for ${callUuid}:`, err);
            // Не считаем ошибку hangup критической - звонок может уже завершиться
            resolve();
            return;
          }

          if (res && (res.response === 'Success' || res.response === 'Error')) {
            // Error может означать что канал уже не существует - это нормально
            log.info(`✅ AsteriskAdapter: Hangup completed for ${callUuid}`);
            resolve();
          } else {
            log.warn(`⚠️ AsteriskAdapter: Unexpected hangup response for ${callUuid}:`, res);
            resolve(); // Все равно считаем успешным
          }
        });
      });
      
    } catch (error) {
      log.error(`❌ AsteriskAdapter: Failed to hangup call ${callUuid}:`, error);
      // Не пробрасываем ошибку - hangup не должен ломать систему
    }
  }

  /**
   * Получение статуса подключения
   */
  getConnectionStatus(): VoIPConnectionStatus {
    const status: VoIPConnectionStatus = {
      connected: this.connected,
      reconnectAttempts: this.reconnectAttempts,
      maxReconnectAttempts: this.maxReconnectAttempts,
    };
    
    if (!this.connected) {
      status.lastError = 'AsteriskAdapter not implemented yet';
    }
    
    return status;
  }

  /**
   * Получение статистики Asterisk
   */
  async getStats(): Promise<VoIPStats> {
    if (!this.connected || !this.amiClient) {
      throw new Error('AsteriskAdapter: Not connected to Asterisk AMI');
    }

    try {
      log.debug('📊 AsteriskAdapter: Getting Asterisk stats...');

      // Получаем информацию о каналах
      const channelsPromise = new Promise<number>((resolve) => {
        this.amiClient.action({ Action: 'CoreShowChannels' }, (err: any, res: any) => {
          if (err) {
            log.warn('⚠️ AsteriskAdapter: Failed to get channels count:', err);
            resolve(0);
            return;
          }
          
          // Подсчитываем количество активных каналов
          const channelsCount = res?.events ? res.events.length : 0;
          resolve(channelsCount);
        });
      });

      // Получаем время работы системы
      const uptimePromise = new Promise<number>((resolve) => {
        this.amiClient.action({ Action: 'CoreSettings' }, (err: any, res: any) => {
          if (err) {
            log.warn('⚠️ AsteriskAdapter: Failed to get uptime:', err);
            resolve(0);
            return;
          }
          
          // Парсим время работы из ответа
          const uptimeStr = res?.systemname || res?.uptime || '0';
          const uptime = parseInt(uptimeStr, 10) || 0;
          resolve(uptime);
        });
      });

      // Ждем результаты параллельно
      const [activeChannels, uptime] = await Promise.all([channelsPromise, uptimePromise]);
      
      // Приблизительно оцениваем количество активных звонков
      // В Asterisk один звонок = два канала (входящий и исходящий)
      const activeCalls = Math.floor(activeChannels / 2);

      const stats: VoIPStats = {
        activeCalls,
        activeChannels,
        uptime,
        connected: this.connected,
      };

      log.debug('✅ AsteriskAdapter: Stats retrieved:', stats);
      return stats;
      
    } catch (error) {
      log.error('❌ AsteriskAdapter: Failed to get stats:', error);
      throw error;
    }
  }

  /**
   * Отправка команды Asterisk
   */
  async sendCommand(command: string): Promise<any> {
    if (!this.connected || !this.amiClient) {
      throw new Error('AsteriskAdapter: Not connected to Asterisk AMI');
    }

    try {
      log.debug(`🔧 AsteriskAdapter: Sending command: ${command}`);
      
      const commandAction = {
        Action: 'Command',
        Command: command
      };

      return new Promise((resolve, reject) => {
        const timeout = setTimeout(() => {
          log.error(`❌ AsteriskAdapter: Command timeout: ${command}`);
          reject(new Error(`Asterisk command timeout: ${command}`));
        }, 30000);

        this.amiClient.action(commandAction, (err: any, res: any) => {
          clearTimeout(timeout);
          
          if (err) {
            log.error(`❌ AsteriskAdapter: Command failed: ${command}`, err);
            reject(new Error(`Asterisk command failed: ${err.message || err}`));
            return;
          }

          log.debug(`✅ AsteriskAdapter: Command executed: ${command}`);
          
          // Возвращаем результат команды
          resolve({
            success: true,
            command,
            response: res?.response || 'Success',
            output: res?.output || res?.message || '',
            data: res
          });
        });
      });
      
    } catch (error) {
      log.error(`❌ AsteriskAdapter: Failed to send command ${command}:`, error);
      throw error;
    }
  }

  /**
   * Настройка обработчиков событий Asterisk AMI
   */
  private setupEventHandlers(): void {
    if (!this.amiClient) {
      log.warn('⚠️ AsteriskAdapter: No AMI client for event handlers setup');
      return;
    }

    log.info('🎛️ AsteriskAdapter: Setting up AMI event handlers...');

    // Основной обработчик событий AMI
    this.amiClient.on('managerevent', (event: AsteriskEvent) => {
      try {
        this.handleAsteriskEvent(event);
      } catch (error) {
        log.error('❌ AsteriskAdapter: Error handling AMI event:', error);
      }
    });

    // Обработчик ошибок AMI
    this.amiClient.on('error', (error: Error) => {
      log.error('❌ AsteriskAdapter: AMI error:', error);
      this.emit('error', error);
    });

    // Обработчик переподключения AMI
    this.amiClient.on('reconnect', () => {
      log.info('🔄 AsteriskAdapter: AMI reconnected');
      this.connected = true;
      this.reconnectAttempts = 0;
      this.emit('connected');
    });

    log.info('✅ AsteriskAdapter: Event handlers setup completed');
  }

  /**
   * Обработка событий Asterisk AMI
   * Конвертирует события AMI в стандартный формат VoIP
   */
  private handleAsteriskEvent(event: AsteriskEvent): void {
    const eventName = event.event;
    
    // Логируем только важные события, чтобы не спамить логи
    if (['Newchannel', 'DialBegin', 'DialEnd', 'Hangup', 'DTMFEnd'].includes(eventName)) {
      log.debug(`🎛️ AsteriskAdapter: Received AMI event: ${eventName}`, {
        uniqueid: event.uniqueid,
        channel: event.channel,
        calleridnum: event.calleridnum
      });
    }

    try {
      switch (eventName) {
        case 'Newchannel':
          this.handleNewChannelEvent(event);
          break;
          
        case 'DialBegin':
          this.handleDialBeginEvent(event);
          break;
          
        case 'DialEnd':
          this.handleDialEndEvent(event);
          break;
          
        case 'Hangup':
          this.handleHangupEvent(event);
          break;
          
        case 'DTMFEnd':
          this.handleDTMFEvent(event);
          break;
          
        case 'VarSet':
          this.handleVarSetEvent(event);
          break;
          
        default:
          // Не логируем каждое неизвестное событие - их много
          if (eventName && !['Registry', 'PeerStatus', 'ExtensionStatus'].includes(eventName)) {
            log.debug(`🔍 AsteriskAdapter: Unhandled AMI event: ${eventName}`);
          }
          break;
      }
    } catch (error) {
      log.error(`❌ AsteriskAdapter: Error processing AMI event ${eventName}:`, error);
    }
  }

  /**
   * Обработка события создания нового канала
   */
  private handleNewChannelEvent(event: AsteriskEvent): void {
    if (!event.uniqueid || !event.channel) {
      return;
    }

    // Эмитим событие создания звонка
    const voipEvent: VoIPCallCreatedEvent = {
      callUuid: event.uniqueid,
      phoneNumber: event.calleridnum || 'unknown',
      timestamp: new Date(),
    };
    
    // Добавляем callerIdNumber только если оно есть
    if (event.calleridnum) {
      voipEvent.callerIdNumber = event.calleridnum;
    }

    log.debug('📞 AsteriskAdapter: Call created', voipEvent);
    this.emit('call:created', voipEvent);
  }

  /**
   * Обработка события начала дозвона
   */
  private handleDialBeginEvent(event: AsteriskEvent): void {
    if (!event.uniqueid) {
      return;
    }

    // В Asterisk DialBegin означает что начался дозвон, но не ответ
    log.debug(`📞 AsteriskAdapter: Dial begin for ${event.uniqueid}`);
  }

  /**
   * Обработка события завершения дозвона (ответ или неудача)
   */
  private handleDialEndEvent(event: AsteriskEvent): void {
    if (!event.uniqueid) {
      return;
    }

    // Проверяем статус дозвона
    const dialStatus = event.dialstatus;
    
    if (dialStatus === 'ANSWER') {
      // Звонок отвечен
      const voipEvent: VoIPCallAnsweredEvent = {
        callUuid: event.uniqueid,
        phoneNumber: event.calleridnum || 'unknown',
        answerTime: new Date(),
        timestamp: new Date(),
      };

      log.debug('📞 AsteriskAdapter: Call answered', voipEvent);
      this.emit('call:answered', voipEvent);
    }
  }

  /**
   * Обработка события завершения звонка
   */
  private handleHangupEvent(event: AsteriskEvent): void {
    if (!event.uniqueid) {
      return;
    }

    const voipEvent: VoIPCallHangupEvent = {
      callUuid: event.uniqueid,
      phoneNumber: event.calleridnum || 'unknown',
      hangupCause: event.causeTxt || event.cause || 'Unknown',
      callDuration: parseInt(event.duration || '0', 10),
      billableSeconds: parseInt(event.billableseconds || '0', 10),
      timestamp: new Date(),
    };

    log.debug('📞 AsteriskAdapter: Call hangup', voipEvent);
    this.emit('call:hangup', voipEvent);
  }

  /**
   * Обработка DTMF событий
   */
  private handleDTMFEvent(event: AsteriskEvent): void {
    if (!event.uniqueid || !event.digit) {
      return;
    }

    const voipEvent: VoIPCallDTMFEvent = {
      callUuid: event.uniqueid,
      phoneNumber: event.calleridnum || 'unknown',
      dtmfDigit: event.digit,
      timestamp: new Date(),
    };

    log.debug('📞 AsteriskAdapter: DTMF received', voipEvent);
    this.emit('call:dtmf', voipEvent);
  }

  /**
   * Обработка установки переменных (для пользовательских событий)
   */
  private handleVarSetEvent(event: AsteriskEvent): void {
    // Ищем пользовательские переменные связанные с диалером
    if (event.variable === 'DIALER_LEAD_CREATED' && event.value === '1') {
      // Пример обработки создания лида
      const voipEvent: VoIPLeadCreatedEvent = {
        callUuid: event.uniqueid || 'unknown',
        phoneNumber: event.calleridnum || 'unknown',
        campaignId: parseInt(event.value || '0', 10),
        dtmfResponse: '1', // TODO: Получать из переменных
        callResult: 'interested',
        timestamp: new Date(),
      };

      log.debug('📞 AsteriskAdapter: Lead created', voipEvent);
      this.emit('lead:created', voipEvent);
    }
  }

  /**
   * Планирование переподключения к AMI
   */
  private scheduleReconnect(): void {
    // Предотвращаем memory leak - не переподключаемся если уже подключены
    if (this.connected) {
      return;
    }

    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      log.error(`❌ AsteriskAdapter: Max reconnection attempts (${this.maxReconnectAttempts}) reached`);
      this.emit('error', new Error('Max AMI reconnection attempts reached'));
      return;
    }

    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
    }

    this.reconnectAttempts++;
    const delay = Math.min(this.reconnectDelay * this.reconnectAttempts, 30000); // Максимум 30 сек

    log.info(`🔄 AsteriskAdapter: Scheduling reconnect attempt ${this.reconnectAttempts}/${this.maxReconnectAttempts} in ${delay}ms`);

    this.reconnectTimer = setTimeout(async () => {
      // Двойная проверка что мы не подключены
      if (this.connected) {
        return;
      }
      
      try {
        log.info('🔄 AsteriskAdapter: Attempting to reconnect to AMI...');
        await this.connect();
      } catch (error) {
        log.warn('⚠️ AsteriskAdapter: Reconnection attempt failed:', error);
        // Только если не подключены - планируем следующую попытку
        if (!this.connected) {
          this.scheduleReconnect();
        }
      }
    }, delay);
  }

  /**
   * Генерация UUID для звонков
   */
  private generateUUID(): string {
    return require('crypto').randomUUID();
  }
} 