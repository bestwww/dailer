/**
 * FreeSWITCH ESL (Event Socket Library) клиент
 * Управление звонками и обработка событий FreeSWITCH
 */

import { EventEmitter } from 'events';
import { config } from '@/config';
import { log } from '@/utils/logger';
// import { FreeSwitchEvent, CallStatus } from '@/types'; // Временно отключено

const modesl = require('modesl');

/**
 * Интерфейс для ESL соединения
 */
/*
interface ESLConnection {
  connect(): Promise<void>;
  disconnect(): void;
  send(command: string): Promise<any>;
  on(event: string, callback: Function): void;
  connected: boolean;
}
*/

/**
 * FreeSWITCH ESL клиент
 */
export class FreeSwitchClient extends EventEmitter {
  private connection: any = null;
  private isConnected: boolean = false;
  private reconnectAttempts: number = 0;
  private maxReconnectAttempts: number = 10;
  private reconnectDelay: number = 5000; // 5 секунд
  private heartbeatInterval: NodeJS.Timeout | null = null;

  constructor() {
    super();
    this.setupEventHandlers();
  }

  /**
   * Подключение к FreeSWITCH ESL
   */
  async connect(): Promise<void> {
    try {
      if (this.isConnected) {
        log.freeswitch('Already connected to FreeSWITCH');
        return;
      }

      log.freeswitch(`Connecting to FreeSWITCH at ${config.freeswitchHost}:${config.freeswitchPort}`);

      this.connection = new modesl.Connection(
        config.freeswitchHost,
        config.freeswitchPort,
        config.freeswitchPassword
      );

      // Ожидание подключения
      await new Promise((resolve, reject) => {
        const timeout = setTimeout(() => {
          reject(new Error('Connection timeout'));
        }, 10000);

        this.connection.on('error', (error: Error) => {
          clearTimeout(timeout);
          reject(error);
        });

        this.connection.on('esl::connect', () => {
          clearTimeout(timeout);
          resolve(void 0);
        });
      });

      this.isConnected = true;
      this.reconnectAttempts = 0;

      // Подписка на события
      await this.subscribeToEvents();
      
      // Запуск heartbeat
      this.startHeartbeat();

      log.freeswitch('✅ Connected to FreeSWITCH successfully');
      this.emit('connected');

    } catch (error) {
      log.error('❌ Failed to connect to FreeSWITCH:', error);
      this.isConnected = false;
      this.emit('error', error);
      
      // Попытка переподключения
      if (this.reconnectAttempts < this.maxReconnectAttempts) {
        await this.scheduleReconnect();
      }
      
      throw error;
    }
  }

  /**
   * Отключение от FreeSWITCH
   */
  disconnect(): void {
    try {
      if (this.heartbeatInterval) {
        clearInterval(this.heartbeatInterval);
        this.heartbeatInterval = null;
      }

      if (this.connection) {
        this.connection.disconnect();
        this.connection = null;
      }

      this.isConnected = false;
      log.freeswitch('Disconnected from FreeSWITCH');
      this.emit('disconnected');

    } catch (error) {
      log.error('Error during FreeSWITCH disconnect:', error);
    }
  }

  /**
   * Подписка на события FreeSWITCH
   */
  private async subscribeToEvents(): Promise<void> {
    if (!this.connection) {
      throw new Error('No FreeSWITCH connection');
    }

    try {
      // Подписка на основные события
      const events = [
        'CHANNEL_CREATE',
        'CHANNEL_ANSWER', 
        'CHANNEL_HANGUP',
        'DTMF',
        'CUSTOM dialer::amd_result',
        'CUSTOM dialer::call_result',
        'HEARTBEAT'
      ];

      for (const event of events) {
        await this.sendCommand(`event plain ${event}`);
      }

      log.freeswitch(`Subscribed to ${events.length} FreeSWITCH events`);

    } catch (error) {
      log.error('Failed to subscribe to FreeSWITCH events:', error);
      throw error;
    }
  }

  /**
   * Настройка обработчиков событий
   */
  private setupEventHandlers(): void {
    this.on('esl::event', (event: any) => {
      this.handleFreeSwitchEvent(event);
    });
  }

  /**
   * Обработка событий FreeSWITCH
   */
  private handleFreeSwitchEvent(event: any): void {
    try {
      const eventName = event.getHeader('Event-Name');
      const eventSubclass = event.getHeader('Event-Subclass');
      
      log.freeswitch(`Received event: ${eventName}${eventSubclass ? ` (${eventSubclass})` : ''}`);

      switch (eventName) {
        case 'CHANNEL_CREATE':
          this.handleChannelCreate(event);
          break;
          
        case 'CHANNEL_ANSWER':
          this.handleChannelAnswer(event);
          break;
          
        case 'CHANNEL_HANGUP':
          this.handleChannelHangup(event);
          break;
          
        case 'DTMF':
          this.handleDTMF(event);
          break;
          
        case 'CUSTOM':
          this.handleCustomEvent(event, eventSubclass);
          break;
          
        case 'HEARTBEAT':
          this.handleHeartbeat(event);
          break;
          
        default:
          log.debug(`Unhandled FreeSWITCH event: ${eventName}`);
      }

    } catch (error) {
      log.error('Error handling FreeSWITCH event:', error);
    }
  }

  /**
   * Обработка создания канала
   */
  private handleChannelCreate(event: any): void {
    const callUuid = event.getHeader('Unique-ID');
    const callerIdNumber = event.getHeader('Caller-Caller-ID-Number');
    const destinationNumber = event.getHeader('Caller-Destination-Number');

    log.call.started(destinationNumber || 'unknown', 0, {
      callUuid,
      callerIdNumber,
    });

    this.emit('call:created', {
      callUuid,
      phoneNumber: destinationNumber,
      callerIdNumber,
      timestamp: new Date(),
    });
  }

  /**
   * Обработка ответа на звонок
   */
  private handleChannelAnswer(event: any): void {
    const callUuid = event.getHeader('Unique-ID');
    const phoneNumber = event.getHeader('Caller-Destination-Number');
    const answerTime = new Date(event.getHeader('Event-Date-Timestamp') / 1000);

    log.call.answered(phoneNumber || 'unknown', 0, {
      callUuid,
      answerTime,
    });

    this.emit('call:answered', {
      callUuid,
      phoneNumber,
      answerTime,
      timestamp: new Date(),
    });
  }

  /**
   * Обработка завершения звонка
   */
  private handleChannelHangup(event: any): void {
    const callUuid = event.getHeader('Unique-ID');
    const phoneNumber = event.getHeader('Caller-Destination-Number');
    const hangupCause = event.getHeader('Hangup-Cause');
    const callDuration = parseInt(event.getHeader('variable_duration') || '0', 10);
    const billableSeconds = parseInt(event.getHeader('variable_billsec') || '0', 10);

    log.call.failed(phoneNumber || 'unknown', hangupCause || 'unknown', {
      callUuid,
      callDuration,
      billableSeconds,
    });

    this.emit('call:hangup', {
      callUuid,
      phoneNumber,
      hangupCause,
      callDuration,
      billableSeconds,
      timestamp: new Date(),
    });
  }

  /**
   * Обработка DTMF сигналов
   */
  private handleDTMF(event: any): void {
    const callUuid = event.getHeader('Unique-ID');
    const dtmfDigit = event.getHeader('DTMF-Digit');
    const phoneNumber = event.getHeader('Caller-Destination-Number');

    log.call.dtmf(phoneNumber || 'unknown', dtmfDigit || 'unknown', {
      callUuid,
    });

    this.emit('call:dtmf', {
      callUuid,
      phoneNumber,
      dtmfDigit,
      timestamp: new Date(),
    });
  }

  /**
   * Обработка пользовательских событий
   */
  private handleCustomEvent(event: any, eventSubclass: string): void {
    switch (eventSubclass) {
      case 'dialer::amd_result':
        this.handleAMDResult(event);
        break;
        
      case 'dialer::call_result':
        this.handleCallResult(event);
        break;
        
      case 'dialer::lead_created':
        this.handleLeadCreated(event);
        break;
        
      default:
        log.debug(`Unhandled custom event: ${eventSubclass}`);
    }
  }

  /**
   * Обработка результата AMD (Answering Machine Detection)
   */
  private handleAMDResult(event: any): void {
    const callUuid = event.getHeader('Unique-ID');
    const phoneNumber = event.getHeader('Caller-Destination-Number');
    const amdResult = event.getHeader('AMD-Result'); // HUMAN, MACHINE, NOTSURE
    const amdConfidence = parseFloat(event.getHeader('AMD-Confidence') || '0');

    log.call.amd(phoneNumber || 'unknown', amdResult || 'unknown', amdConfidence * 100, {
      callUuid,
    });

    this.emit('call:amd_result', {
      callUuid,
      phoneNumber,
      amdResult,
      amdConfidence,
      timestamp: new Date(),
    });
  }

  /**
   * Обработка результата звонка
   */
  private handleCallResult(event: any): void {
    const callUuid = event.getHeader('Unique-ID');
    const phoneNumber = event.getHeader('Phone-Number');
    const campaignId = parseInt(event.getHeader('Campaign-ID') || '0', 10);
    const callResult = event.getHeader('Call-Result');

    this.emit('call:result', {
      callUuid,
      phoneNumber,
      campaignId,
      callResult,
      timestamp: new Date(),
    });
  }

  /**
   * Обработка события создания лида
   */
  private handleLeadCreated(event: any): void {
    const callUuid = event.getHeader('Unique-ID');
    const phoneNumber = event.getHeader('Phone-Number');
    const campaignId = parseInt(event.getHeader('Campaign-ID') || '0', 10);
    const dtmfResponse = event.getHeader('DTMF-Response');
    const callResult = event.getHeader('Call-Result');

    log.info(`Lead creation event: ${phoneNumber} pressed ${dtmfResponse} for campaign ${campaignId}`);

    this.emit('lead:created', {
      callUuid,
      phoneNumber,
      campaignId,
      dtmfResponse,
      callResult,
      timestamp: new Date(),
    });
  }

  /**
   * Обработка heartbeat
   */
  private handleHeartbeat(event: any): void {
    const uptime = event.getHeader('FreeSWITCH-Uptime-Seconds');
    log.debug(`FreeSWITCH heartbeat - uptime: ${uptime}s`);
  }

  /**
   * Отправка команды FreeSWITCH
   */
  async sendCommand(command: string): Promise<any> {
    if (!this.connection || !this.isConnected) {
      throw new Error('No active FreeSWITCH connection');
    }

    try {
      log.debug(`Sending FreeSWITCH command: ${command}`);
      
      return new Promise((resolve, reject) => {
        this.connection.api(command, (response: any) => {
          if (response.getHeader('Reply-Text')?.includes('-ERR')) {
            reject(new Error(response.getHeader('Reply-Text')));
          } else {
            resolve(response);
          }
        });
      });

    } catch (error) {
      log.error(`Failed to send FreeSWITCH command: ${command}`, error);
      throw error;
    }
  }

  /**
   * Инициация исходящего звонка
   */
  async makeCall(phoneNumber: string, campaignId: number, audioFilePath?: string): Promise<string> {
    if (!this.isConnected) {
      throw new Error('FreeSWITCH not connected');
    }

    try {
      // Генерация UUID для звонка
      const callUuid = await this.generateUUID();
      
      // Построение dialstring
      const dialstring = this.buildDialstring(phoneNumber, campaignId, audioFilePath, callUuid);
      
      // Инициация звонка
      const command = `originate ${dialstring}`;
      await this.sendCommand(command);

      log.call.started(phoneNumber, campaignId, {
        callUuid,
        audioFilePath,
      });

      return callUuid;

    } catch (error) {
      log.error(`Failed to make call to ${phoneNumber}:`, error);
      throw error;
    }
  }

  /**
   * Построение dialstring для звонка
   */
  private buildDialstring(phoneNumber: string, campaignId: number, audioFilePath?: string, callUuid?: string): string {
    const variables = [
      `campaign_id=${campaignId}`,
      `phone_number=${phoneNumber}`,
      ...(callUuid ? [`call_uuid=${callUuid}`] : []),
      ...(audioFilePath ? [`audio_file=${audioFilePath}`] : []),
      'ignore_early_media=true',
      'origination_caller_id_number=74951234567', // TODO: настраиваемый CallerID
    ];

    const variableString = `{${variables.join(',')}}`;
    const gateway = 'sofia/gateway/provider'; // TODO: настраиваемый gateway
    const extension = '&bridge'; // TODO: настраиваемый extension/dialplan

    return `${variableString}${gateway}/${phoneNumber} ${extension}`;
  }

  /**
   * Генерация UUID для звонка
   */
  private async generateUUID(): Promise<string> {
    const response = await this.sendCommand('create_uuid');
    return response.getBody().trim();
  }

  /**
   * Завершение звонка
   */
  async hangupCall(callUuid: string): Promise<void> {
    try {
      await this.sendCommand(`uuid_kill ${callUuid}`);
      log.freeswitch(`Hung up call: ${callUuid}`);
    } catch (error) {
      log.error(`Failed to hangup call ${callUuid}:`, error);
      throw error;
    }
  }

  /**
   * Запуск heartbeat
   */
  private startHeartbeat(): void {
    this.heartbeatInterval = setInterval(() => {
      if (this.isConnected && this.connection) {
        this.sendCommand('status').catch((error) => {
          log.warn('Heartbeat failed:', error);
          this.handleConnectionLoss();
        });
      }
    }, 30000); // каждые 30 секунд
  }

  /**
   * Обработка потери соединения
   */
  private handleConnectionLoss(): void {
    log.warn('FreeSWITCH connection lost');
    this.isConnected = false;
    this.emit('disconnected');
    
    // Попытка переподключения
    this.scheduleReconnect();
  }

  /**
   * Планирование переподключения
   */
  private async scheduleReconnect(): Promise<void> {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      log.error('Max reconnection attempts reached');
      this.emit('max_reconnects_reached');
      return;
    }

    this.reconnectAttempts++;
    const delay = this.reconnectDelay * this.reconnectAttempts;

    log.freeswitch(`Scheduling reconnect attempt ${this.reconnectAttempts} in ${delay}ms`);

    setTimeout(async () => {
      try {
        await this.connect();
      } catch (error) {
        log.error(`Reconnect attempt ${this.reconnectAttempts} failed:`, error);
      }
    }, delay);
  }

  /**
   * Получение статуса соединения
   */
  getConnectionStatus(): {
    connected: boolean;
    reconnectAttempts: number;
    maxReconnectAttempts: number;
  } {
    return {
      connected: this.isConnected,
      reconnectAttempts: this.reconnectAttempts,
      maxReconnectAttempts: this.maxReconnectAttempts,
    };
  }

  /**
   * Получение статистики FreeSWITCH
   */
  async getStats(): Promise<any> {
    if (!this.isConnected) {
      throw new Error('FreeSWITCH not connected');
    }

    try {
      const response = await this.sendCommand('show calls count');
      const callsCount = parseInt(response.getBody().trim(), 10);

      const channelsResponse = await this.sendCommand('show channels count');
      const channelsCount = parseInt(channelsResponse.getBody().trim(), 10);

      return {
        activeCalls: callsCount,
        activeChannels: channelsCount,
        connected: this.isConnected,
        uptime: await this.getUptime(),
      };

    } catch (error) {
      log.error('Failed to get FreeSWITCH stats:', error);
      throw error;
    }
  }

  /**
   * Получение uptime FreeSWITCH
   */
  private async getUptime(): Promise<number> {
    try {
      const response = await this.sendCommand('status');
      const body = response.getBody();
      const uptimeMatch = body.match(/UP (\d+) years?, (\d+) days?, (\d+) hours?, (\d+) minutes?, (\d+) seconds?/);
      
      if (uptimeMatch) {
        const [, years, days, hours, minutes, seconds] = uptimeMatch.map(Number);
        return (years * 365 * 24 * 3600) + (days * 24 * 3600) + (hours * 3600) + (minutes * 60) + seconds;
      }
      
      return 0;
    } catch (error) {
      return 0;
    }
  }
}

/**
 * Singleton экземпляр FreeSWITCH клиента
 */
export const freeswitchClient = new FreeSwitchClient();

/**
 * Автоматическое подключение при импорте (если не в тестах)
 */
if (process.env.NODE_ENV !== 'test') {
  freeswitchClient.connect().catch((error) => {
    log.error('Failed to auto-connect to FreeSWITCH:', error);
  });
} 