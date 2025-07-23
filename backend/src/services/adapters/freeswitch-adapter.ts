/**
 * FreeSWITCH адаптер для VoIPProvider интерфейса
 * Обертка для существующего FreeSWITCH кода без изменений
 */

import { EventEmitter } from 'events';
import { freeswitchClient } from '@/services/freeswitch';
import { log } from '@/utils/logger';
import { 
  VoIPProvider, 
  VoIPConnectionStatus, 
  VoIPStats,
  VoIPCallCreatedEvent,
  VoIPCallAnsweredEvent,
  VoIPCallHangupEvent,
  VoIPCallDTMFEvent,
  VoIPCallAMDEvent,
  VoIPLeadCreatedEvent
} from '../voip-provider';

export class FreeSwitchAdapter extends EventEmitter implements VoIPProvider {
  private initialized: boolean = false;

  constructor(private _config: { host: string; port: number; password: string }) {
    super();
    this.setupEventHandlers();
  }

  /**
   * Подключение к FreeSWITCH (используем существующий код)
   */
  async connect(): Promise<void> {
    try {
      log.info('🔌 FreeSwitchAdapter: Connecting to FreeSWITCH...');
      
      if (!this.initialized) {
        await freeswitchClient.connect();
        this.initialized = true;
      }
      
      if (!freeswitchClient.getConnectionStatus().connected) {
        await freeswitchClient.connect();
      }
      
      log.info('✅ FreeSwitchAdapter: Connected to FreeSWITCH');
      this.emit('connected');
    } catch (error) {
      log.error('❌ FreeSwitchAdapter: Failed to connect to FreeSWITCH:', error);
      this.emit('error', error);
      throw error;
    }
  }

  /**
   * Отключение от FreeSWITCH
   */
  disconnect(): void {
    try {
      freeswitchClient.disconnect();
      this.emit('disconnected');
      log.info('🔌 FreeSwitchAdapter: Disconnected from FreeSWITCH');
    } catch (error) {
      log.error('❌ FreeSwitchAdapter: Error during disconnect:', error);
    }
  }

  /**
   * Проверка статуса подключения
   */
  isConnected(): boolean {
    return freeswitchClient.getConnectionStatus().connected;
  }

  /**
   * Инициация звонка (прямое использование существующего кода)
   */
  async makeCall(phoneNumber: string, campaignId: number, audioFilePath?: string): Promise<string> {
    try {
      log.info(`📞 FreeSwitchAdapter: Making call to ${phoneNumber}`);
      
      // Используем существующий метод FreeSWITCH без изменений
      const callUuid = await freeswitchClient.makeCall(phoneNumber, campaignId, audioFilePath);
      
      log.info(`✅ FreeSwitchAdapter: Call initiated with UUID: ${callUuid}`);
      return callUuid;
    } catch (error) {
      log.error(`❌ FreeSwitchAdapter: Failed to make call to ${phoneNumber}:`, error);
      throw error;
    }
  }

  /**
   * Завершение звонка (прямое использование существующего кода)
   */
  async hangupCall(callUuid: string): Promise<void> {
    try {
      log.info(`📞 FreeSwitchAdapter: Hanging up call ${callUuid}`);
      await freeswitchClient.hangupCall(callUuid);
      log.info(`✅ FreeSwitchAdapter: Call ${callUuid} hung up`);
    } catch (error) {
      log.error(`❌ FreeSwitchAdapter: Failed to hangup call ${callUuid}:`, error);
      throw error;
    }
  }

  /**
   * Получение статуса подключения
   */
  getConnectionStatus(): VoIPConnectionStatus {
    const status = freeswitchClient.getConnectionStatus();
    return {
      connected: status.connected,
      reconnectAttempts: status.reconnectAttempts,
      maxReconnectAttempts: status.maxReconnectAttempts,
    };
  }

  /**
   * Получение статистики FreeSWITCH
   */
  async getStats(): Promise<VoIPStats> {
    try {
      return await freeswitchClient.getStats();
    } catch (error) {
      log.error('❌ FreeSwitchAdapter: Failed to get stats:', error);
      throw error;
    }
  }

  /**
   * Отправка команды FreeSWITCH (прямое использование существующего кода)
   */
  async sendCommand(command: string): Promise<any> {
    try {
      log.debug(`🔧 FreeSwitchAdapter: Sending command: ${command}`);
      const result = await freeswitchClient.sendCommand(command);
      log.debug(`✅ FreeSwitchAdapter: Command executed successfully`);
      return result;
    } catch (error) {
      log.error(`❌ FreeSwitchAdapter: Failed to send command ${command}:`, error);
      throw error;
    }
  }

  /**
   * Настройка обработчиков событий (перенаправление из FreeSWITCH)
   */
  private setupEventHandlers(): void {
    // Подключение/отключение
    freeswitchClient.on('connected', () => {
      log.info('🔄 FreeSwitchAdapter: FreeSWITCH connected event');
      this.emit('connected');
    });

    freeswitchClient.on('disconnected', () => {
      log.info('🔄 FreeSwitchAdapter: FreeSWITCH disconnected event');
      this.emit('disconnected');
    });

    freeswitchClient.on('error', (error: Error) => {
      log.error('🔄 FreeSwitchAdapter: FreeSWITCH error event:', error);
      this.emit('error', error);
    });

    // События звонков - преобразуем в стандартный формат
    freeswitchClient.on('call:created', (event: any) => {
      const voipEvent: VoIPCallCreatedEvent = {
        callUuid: event.callUuid,
        phoneNumber: event.phoneNumber,
        callerIdNumber: event.callerIdNumber,
        timestamp: event.timestamp || new Date(),
      };
      log.debug('🔄 FreeSwitchAdapter: Call created event:', voipEvent);
      this.emit('call:created', voipEvent);
    });

    freeswitchClient.on('call:answered', (event: any) => {
      const voipEvent: VoIPCallAnsweredEvent = {
        callUuid: event.callUuid,
        phoneNumber: event.phoneNumber,
        answerTime: event.answerTime || new Date(),
        timestamp: event.timestamp || new Date(),
      };
      log.debug('🔄 FreeSwitchAdapter: Call answered event:', voipEvent);
      this.emit('call:answered', voipEvent);
    });

    freeswitchClient.on('call:hangup', (event: any) => {
      const voipEvent: VoIPCallHangupEvent = {
        callUuid: event.callUuid,
        phoneNumber: event.phoneNumber,
        hangupCause: event.hangupCause,
        callDuration: event.callDuration || 0,
        billableSeconds: event.billableSeconds || 0,
        timestamp: event.timestamp || new Date(),
      };
      log.debug('🔄 FreeSwitchAdapter: Call hangup event:', voipEvent);
      this.emit('call:hangup', voipEvent);
    });

    freeswitchClient.on('call:dtmf', (event: any) => {
      const voipEvent: VoIPCallDTMFEvent = {
        callUuid: event.callUuid,
        phoneNumber: event.phoneNumber,
        dtmfDigit: event.dtmfDigit,
        timestamp: event.timestamp || new Date(),
      };
      log.debug('🔄 FreeSwitchAdapter: DTMF event:', voipEvent);
      this.emit('call:dtmf', voipEvent);
    });

    freeswitchClient.on('call:amd_result', (event: any) => {
      const voipEvent: VoIPCallAMDEvent = {
        callUuid: event.callUuid,
        phoneNumber: event.phoneNumber,
        amdResult: event.amdResult,
        amdConfidence: event.amdConfidence || 0,
        timestamp: event.timestamp || new Date(),
      };
      log.debug('🔄 FreeSwitchAdapter: AMD result event:', voipEvent);
      this.emit('call:amd_result', voipEvent);
    });

    freeswitchClient.on('lead:created', (event: any) => {
      const voipEvent: VoIPLeadCreatedEvent = {
        callUuid: event.callUuid,
        phoneNumber: event.phoneNumber,
        campaignId: event.campaignId,
        dtmfResponse: event.dtmfResponse,
        callResult: event.callResult,
        timestamp: event.timestamp || new Date(),
      };
      log.debug('🔄 FreeSwitchAdapter: Lead created event:', voipEvent);
      this.emit('lead:created', voipEvent);
    });

    log.info('✅ FreeSwitchAdapter: Event handlers setup completed');
  }
} 