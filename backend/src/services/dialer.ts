/**
 * Основной сервис диалера - управление процессом автодозвона
 */

import { EventEmitter } from 'events';
import { getVoIPProvider } from '@/services/voip-provider-factory';
import { VoIPProvider } from '@/services/voip-provider';
import { campaignModel } from '@/models/campaign';
import { contactModel } from '@/models/contact';
import { callResultModel } from '@/models/call-result';
import { blacklistModel } from '@/models/blacklist';
import bitrix24Service from '@/services/bitrix24';
import { webhookService } from '@/services/webhook';
import { timezoneService } from '@/services/timezone';
import { monitoringService } from '@/services/monitoring';
import { config } from '@/config';
import { log } from '@/utils/logger';
import { Campaign, Contact, CallStatus, ContactStatus } from '@/types';

interface ActiveCall {
  callUuid: string;
  campaignId: number;
  contactId: number;
  phoneNumber: string;
  startTime: Date;
  status: CallStatus;
}

interface DialerStats {
  activeCalls: number;
  totalCallsToday: number;
  successfulCallsToday: number;
  failedCallsToday: number;
  callsPerMinute: number;
  activeCampaigns: number;
}

/**
 * Сервис диалера
 */
export class DialerService extends EventEmitter {
  private activeCalls: Map<string, ActiveCall> = new Map();
  private campaignIntervals: Map<number, NodeJS.Timeout> = new Map();
  private isRunning: boolean = false;
  private callsInLastMinute: Date[] = [];
  private voipProvider: VoIPProvider;

  constructor() {
    super();
    // Инициализация VoIP провайдера (FreeSWITCH или Asterisk)
    this.voipProvider = getVoIPProvider();
    this.setupVoIPEventHandlers();
    
    log.info(`🎯 DialerService: Initialized with ${config.voipProvider.toUpperCase()} provider`);
  }

  /**
   * Запуск диалера
   */
  async start(): Promise<void> {
    try {
      if (this.isRunning) {
        log.warn('Dialer is already running');
        return;
      }

      log.info('🚀 Starting dialer service...');

      // Проверка подключения к VoIP провайдеру
      if (!this.voipProvider.isConnected()) {
        log.info(`🔌 Connecting to ${config.voipProvider.toUpperCase()} provider...`);
        await this.voipProvider.connect();
      }

      this.isRunning = true;
      
      // Запуск активных кампаний
      await this.startActiveCampaigns();
      
      // Запуск мониторинга
      this.startMonitoring();

      // Регистрация health checks
      this.registerHealthChecks();

      log.info('✅ Dialer service started successfully');
      this.emit('started');

    } catch (error) {
      log.error('❌ Failed to start dialer service:', error);
      this.isRunning = false;
      throw error;
    }
  }

  /**
   * Остановка диалера
   */
  async stop(): Promise<void> {
    try {
      log.info('🛑 Stopping dialer service...');

      this.isRunning = false;

      // Остановка всех кампаний
      await this.stopAllCampaigns();

      // Завершение активных звонков
      await this.hangupAllActiveCalls();

      log.info('✅ Dialer service stopped');
      this.emit('stopped');

    } catch (error) {
      log.error('❌ Failed to stop dialer service:', error);
      throw error;
    }
  }

  /**
   * Запуск кампании
   */
  async startCampaign(campaignId: number): Promise<void> {
    try {
      const campaign = await campaignModel.getCampaignById(campaignId);
      
      if (!campaign) {
        throw new Error(`Campaign ${campaignId} not found`);
      }

      // Проверка возможности запуска
      const canStart = await campaignModel.canStartCampaign(campaignId);
      if (!canStart.canStart) {
        throw new Error(`Cannot start campaign: ${canStart.reason}`);
      }

      // Очистка "зависших" контактов в статусе calling
      await this.resetStuckContacts(campaignId);

      // Обновление статуса кампании
      await campaignModel.updateCampaign(campaignId, { status: 'active' });

      // Запуск процесса обзвона
      const callInterval = this.calculateCallInterval(campaign.callsPerMinute);
      log.info(`📞 Setting up dialer interval for campaign ${campaignId}: ${callInterval}ms (${campaign.callsPerMinute} calls/min)`);
      
      const interval = setInterval(async () => {
        log.debug(`🔄 Processing campaign ${campaignId} calls...`);
        await this.processCampaignCalls(campaignId);
      }, callInterval);

      this.campaignIntervals.set(campaignId, interval);

      log.info(`📞 Started campaign: ${campaign.name} (ID: ${campaignId})`);
      this.emit('campaign:started', { campaignId, campaign });

      // Отправка webhook уведомления о запуске кампании
      await webhookService.sendCampaignEvent('campaign.started', {
        campaignId: campaign.id,
        campaignName: campaign.name,
        status: campaign.status,
        totalContacts: campaign.totalContacts,
        completedCalls: campaign.completedCalls,
        timestamp: new Date().toISOString()
      });

    } catch (error) {
      log.error(`Failed to start campaign ${campaignId}:`, error);
      throw error;
    }
  }

  /**
   * Остановка кампании
   */
  async stopCampaign(campaignId: number): Promise<void> {
    try {
      const interval = this.campaignIntervals.get(campaignId);
      
      if (interval) {
        clearInterval(interval);
        this.campaignIntervals.delete(campaignId);
      }

      // Обновление статуса кампании
      await campaignModel.updateCampaign(campaignId, { status: 'cancelled' });

      // Завершение активных звонков кампании
      await this.hangupCampaignCalls(campaignId);

      log.info(`⏸️ Stopped campaign: ${campaignId}`);
      this.emit('campaign:stopped', { campaignId });

      // Отправка webhook уведомления об остановке кампании
      const campaign = await campaignModel.getCampaignById(campaignId);
      if (campaign) {
        await webhookService.sendCampaignEvent('campaign.stopped', {
          campaignId: campaign.id,
          campaignName: campaign.name,
          status: campaign.status,
          totalContacts: campaign.totalContacts,
          completedCalls: campaign.completedCalls,
          timestamp: new Date().toISOString()
        });
      }

    } catch (error) {
      log.error(`Failed to stop campaign ${campaignId}:`, error);
      throw error;
    }
  }

  /**
   * Приостановка кампании (пауза)
   */
  async pauseCampaign(campaignId: number): Promise<void> {
    try {
      const interval = this.campaignIntervals.get(campaignId);
      
      if (interval) {
        clearInterval(interval);
        this.campaignIntervals.delete(campaignId);
      }

      // Обновление статуса кампании на paused
      await campaignModel.updateCampaign(campaignId, { status: 'paused' });

      // Завершение активных звонков кампании
      await this.hangupCampaignCalls(campaignId);

      log.info(`⏸️ Paused campaign: ${campaignId}`);
      this.emit('campaign:paused', { campaignId });

      // Отправка webhook уведомления о паузе кампании
      const campaign = await campaignModel.getCampaignById(campaignId);
      if (campaign) {
        await webhookService.sendCampaignEvent('campaign.stopped', {
          campaignId: campaign.id,
          campaignName: campaign.name,
          status: campaign.status,
          totalContacts: campaign.totalContacts,
          completedCalls: campaign.completedCalls,
          timestamp: new Date().toISOString()
        });
      }

    } catch (error) {
      log.error(`Failed to pause campaign ${campaignId}:`, error);
      throw error;
    }
  }

  /**
   * Обработка звонков кампании
   */
  private async processCampaignCalls(campaignId: number): Promise<void> {
    try {
      log.debug(`🔍 processCampaignCalls start for campaign ${campaignId}`);
      
      if (!this.isRunning) {
        log.debug(`❌ Dialer not running, skipping campaign ${campaignId}`);
        return;
      }

      const campaign = await campaignModel.getCampaignById(campaignId);
      
      if (!campaign || campaign.status !== 'active') {
        log.warn(`❌ Campaign ${campaignId} not active or not found, stopping`);
        await this.stopCampaign(campaignId);
        return;
      }

      // Проверка лимитов времени работы
      if (!this.isWorkingTime(campaign)) {
        log.debug(`Campaign ${campaignId} outside working hours`);
        return;
      }

      // Проверка лимита одновременных звонков
      const currentCampaignCalls = this.getActiveCampaignCallsCount(campaignId);
      
      if (currentCampaignCalls >= campaign.maxConcurrentCalls) {
        log.debug(`Campaign ${campaignId} reached max concurrent calls limit`);
        return;
      }

      // Проверка лимита звонков в минуту
      if (!this.canMakeCall(campaign.callsPerMinute)) {
        log.debug(`Campaign ${campaignId} reached calls per minute limit`);
        return;
      }

      // Получение следующих контактов для звонков
      const contactsNeeded = Math.min(campaign.maxConcurrentCalls - currentCampaignCalls, 50);
      log.debug(`🔍 Looking for ${contactsNeeded} contacts for campaign ${campaignId}`);
      
      const allContacts = await contactModel.getNextContactsForCalling(
        campaignId,
        contactsNeeded // Получаем больше контактов для фильтрации
      );

      log.info(`📋 Found ${allContacts.length} available contacts for campaign ${campaignId}`);
      if (allContacts.length > 0) {
        log.info(`📞 Contact statuses: ${allContacts.map(c => `${c.phoneNumber}(${c.status})`).join(', ')}`);
      }

      // Фильтрация контактов по рабочему времени их часовых поясов
      const contactsToCall = allContacts.filter(contact => 
        this.isContactInWorkingTime(campaign, contact)
      ).slice(0, campaign.maxConcurrentCalls - currentCampaignCalls);

      log.info(`📞 Contacts to call after filtering: ${contactsToCall.length}`);

      // Совершение звонков
      for (const contact of contactsToCall) {
        log.info(`📞 Making call to ${contact.phoneNumber} (ID: ${contact.id})`);
        await this.makeCall(campaign, contact);
      }

    } catch (error) {
      log.error(`Error processing campaign ${campaignId} calls:`, error);
    }
  }

  /**
   * Совершение звонка
   */
  private async makeCall(campaign: Campaign, contact: Contact): Promise<void> {
    try {
      log.info(`🔄 Starting makeCall for contact ${contact.id} (${contact.phoneNumber})`);
      
      // Проверка черного списка
      log.info(`🔍 Checking blacklist for ${contact.phoneNumber}`);
      const blacklistCheck = await blacklistModel.isBlacklisted(contact.phoneNumber);
      log.info(`✅ Blacklist check completed for ${contact.phoneNumber}, isBlacklisted: ${blacklistCheck.isBlacklisted}`);
      
      if (blacklistCheck.isBlacklisted) {
        log.warn(`Blocked call to blacklisted number: ${contact.phoneNumber}`, {
          reason: blacklistCheck.reason,
          campaignId: campaign.id,
          contactId: contact.id
        });

        // Увеличиваем счетчик попыток для заблокированного номера
        await blacklistModel.incrementAttemptCount(contact.phoneNumber);

        // Обновляем статус контакта как заблокированный
        await contactModel.updateContactCallStats(
          contact.id,
          'blacklisted',
          new Date()
        );

        // Создаем запись результата звонка
        await callResultModel.createCallResult({
          contactId: contact.id,
          campaignId: campaign.id,
          phoneNumber: contact.phoneNumber,
          callStatus: 'blacklisted',
          callDuration: 0,
          ringDuration: 0,
          isAnsweringMachine: false,
          bitrixLeadCreated: false,
          additionalData: {
            blacklistReason: blacklistCheck.reason,
            blockedAt: new Date().toISOString()
          }
        });

        this.emit('call:blocked', {
          campaignId: campaign.id,
          contactId: contact.id,
          phoneNumber: contact.phoneNumber,
          reason: blacklistCheck.reason
        });

        // Отслеживание блокировки в мониторинге
        monitoringService.trackBlacklistBlock();

        return; // Прерываем выполнение звонка
      }

      log.info(`✅ Blacklist check passed for ${contact.phoneNumber}`);

      // Обновление статуса контакта
      log.info(`📝 Updating contact ${contact.id} status to 'calling'`);
      await contactModel.updateContactCallStats(
        contact.id,
        'calling',
        new Date()
      );
      log.info(`✅ Contact ${contact.id} status updated to 'calling'`);

      // Инициация звонка через VoIP провайдер (FreeSWITCH или Asterisk)
      log.info(`📞 Calling ${config.voipProvider}.makeCall for ${contact.phoneNumber}`);
      const callUuid = await this.voipProvider.makeCall(
        contact.phoneNumber,
        campaign.id,
        campaign.audioFilePath
      );
      log.info(`✅ ${config.voipProvider}.makeCall returned UUID: ${callUuid}`);

      // Сохранение активного звонка
      log.info(`💾 Saving active call with UUID: ${callUuid}`);
      const activeCall: ActiveCall = {
        callUuid,
        campaignId: campaign.id,
        contactId: contact.id,
        phoneNumber: contact.phoneNumber,
        startTime: new Date(),
        status: 'answered', // Изначально неизвестно, будет обновлено по событиям
      };

      this.activeCalls.set(callUuid, activeCall);
      this.trackCallForRateLimit();

      log.call.started(contact.phoneNumber, campaign.id, {
        callUuid,
        contactId: contact.id,
      });

      log.info(`📡 Emitting call:initiated event for ${contact.phoneNumber}`);
      this.emit('call:initiated', {
        callUuid,
        campaignId: campaign.id,
        contactId: contact.id,
        phoneNumber: contact.phoneNumber,
      });

      log.info(`✅ makeCall completed successfully for contact ${contact.id} (${contact.phoneNumber})`);

    } catch (error) {
      log.error(`❌ ERROR in makeCall for ${contact.phoneNumber} (contact ID: ${contact.id}):`, error);
      log.error(`❌ Error type: ${error.constructor.name}, message: ${error.message}`);
      
      try {
        // Обновление статуса контакта при ошибке
        log.debug(`📝 Updating contact ${contact.id} status to 'failed' due to error`);
        await contactModel.updateContactCallStats(
          contact.id,
          'failed',
          new Date(),
          this.calculateNextCallTime(contact.callAttempts + 1, campaign.retryDelay, campaign, contact)
        );
        log.debug(`✅ Contact ${contact.id} status updated to 'failed'`);
      } catch (updateError) {
        log.error(`❌ Failed to update contact status after call error:`, updateError);
      }
    }
  }

  /**
   * Настройка обработчиков событий VoIP провайдера (FreeSWITCH или Asterisk)
   */
  private setupVoIPEventHandlers(): void {
    this.voipProvider.on('call:created', this.handleCallCreated.bind(this));
    this.voipProvider.on('call:answered', this.handleCallAnswered.bind(this));
    this.voipProvider.on('call:hangup', this.handleCallHangup.bind(this));
    this.voipProvider.on('call:dtmf', this.handleCallDTMF.bind(this));
    this.voipProvider.on('call:amd_result', this.handleAMDResult.bind(this));
    this.voipProvider.on('lead:created', this.handleLeadCreatedEvent.bind(this));
    
    log.info(`✅ DialerService: VoIP event handlers setup for ${config.voipProvider}`);
  }

  /**
   * Обработка создания звонка
   */
  private async handleCallCreated(event: any): Promise<void> {
    try {
      const { callUuid, phoneNumber } = event;
      
      const activeCall = this.activeCalls.get(callUuid);
      if (!activeCall) {
        log.warn(`Received call created event for unknown call: ${callUuid}`);
        return;
      }

      log.debug(`Call created: ${phoneNumber} (${callUuid})`);

      // Отправка webhook уведомления о начале звонка
      await webhookService.sendCallEvent('call.started', {
        callId: callUuid,
        campaignId: activeCall.campaignId,
        contactId: activeCall.contactId,
        phoneNumber: activeCall.phoneNumber,
        callStatus: activeCall.status,
        timestamp: new Date().toISOString()
      });

    } catch (error) {
      log.error('Error handling call created event:', error);
    }
  }

  /**
   * Обработка ответа на звонок
   */
  private async handleCallAnswered(event: any): Promise<void> {
    try {
      const { callUuid, phoneNumber, answerTime } = event;
      
      const activeCall = this.activeCalls.get(callUuid);
      if (!activeCall) {
        log.warn(`Received call answered event for unknown call: ${callUuid}`);
        return;
      }

      activeCall.status = 'answered';

      // Обновление статуса контакта
      await contactModel.updateContactCallStats(
        activeCall.contactId,
        'calling',
        new Date()
      );

      log.call.answered(phoneNumber, 0, {
        callUuid,
        contactId: activeCall.contactId,
        answerTime,
      });

      this.emit('call:answered', {
        callUuid,
        campaignId: activeCall.campaignId,
        contactId: activeCall.contactId,
        phoneNumber,
        answerTime,
      });

      // Отправка webhook уведомления об ответе на звонок
      await webhookService.sendCallEvent('call.answered', {
        callId: callUuid,
        campaignId: activeCall.campaignId,
        contactId: activeCall.contactId,
        phoneNumber: activeCall.phoneNumber,
        callStatus: activeCall.status,
        timestamp: new Date().toISOString()
      });

    } catch (error) {
      log.error('Error handling call answered event:', error);
    }
  }

  /**
   * Обработка завершения звонка
   */
  private async handleCallHangup(event: any): Promise<void> {
    try {
      const { callUuid, phoneNumber, hangupCause, callDuration, billableSeconds } = event;
      
      const activeCall = this.activeCalls.get(callUuid);
      if (!activeCall) {
        log.warn(`Received call hangup event for unknown call: ${callUuid}`);
        return;
      }

      // Определение статуса звонка
      const callStatus = this.mapHangupCauseToCallStatus(hangupCause);
      const contactStatus = this.mapCallStatusToContactStatus(callStatus);

      // Сохранение результата звонка
      await callResultModel.createCallResult({
        contactId: activeCall.contactId,
        campaignId: activeCall.campaignId,
        callUuid,
        phoneNumber,
        callStatus,
        callDuration: callDuration || 0,
        ringDuration: Math.max(0, (callDuration || 0) - (billableSeconds || 0)),
        isAnsweringMachine: false, // Будет обновлено из AMD события
        callStartedAt: activeCall.startTime,
        callEndedAt: new Date(),
        hangupCause,
      });

      // Отслеживание звонка в мониторинге
      const isSuccessful = callStatus === 'answered';
      monitoringService.trackCall(callDuration || 0, isSuccessful ? 'successful' : 'failed');

      // Обновление статуса контакта
      const contact = await contactModel.getContactById(activeCall.contactId);
      const campaign = await campaignModel.getCampaignById(activeCall.campaignId);
      
      if (contact && campaign) {
        const nextCallTime = this.shouldRetryCall(contact, campaign, callStatus) 
          ? this.calculateNextCallTime(contact.callAttempts + 1, campaign.retryDelay, campaign, contact)
          : undefined;

        await contactModel.updateContactCallStats(
          activeCall.contactId,
          contactStatus,
          new Date(),
          nextCallTime
        );
      }

      // Удаление из активных звонков
      this.activeCalls.delete(callUuid);

      log.call.failed(phoneNumber, hangupCause, {
        callUuid,
        contactId: activeCall.contactId,
        callDuration,
        billableSeconds,
      });

      this.emit('call:hangup', {
        callUuid,
        campaignId: activeCall.campaignId,
        contactId: activeCall.contactId,
        phoneNumber,
        hangupCause,
        callDuration,
        callStatus,
      });

      // Отправка webhook уведомления о завершении звонка
      const eventType = (callStatus === 'answered') ? 'call.completed' : 'call.failed';
      await webhookService.sendCallEvent(eventType, {
        callId: callUuid,
        campaignId: activeCall.campaignId,
        contactId: activeCall.contactId,
        phoneNumber: activeCall.phoneNumber,
        callStatus,
        duration: callDuration,
        hangupCause,
        timestamp: new Date().toISOString()
      });

    } catch (error) {
      log.error('Error handling call hangup event:', error);
    }
  }

  /**
   * Обработка DTMF сигналов
   */
  private async handleCallDTMF(event: any): Promise<void> {
    try {
      const { callUuid, phoneNumber, dtmfDigit } = event;
      
      const activeCall = this.activeCalls.get(callUuid);
      if (!activeCall) {
        log.warn(`Received DTMF event for unknown call: ${callUuid}`);
        return;
      }

      // Обработка DTMF ответа (1 = заинтересован, 2 = не заинтересован)
      let contactStatus: ContactStatus = 'completed';
      
      if (dtmfDigit === '1') {
        contactStatus = 'interested';
      } else if (dtmfDigit === '2') {
        contactStatus = 'not_interested';
      }

      // Обновление статуса контакта
      await contactModel.updateContactCallStats(
        activeCall.contactId,
        contactStatus,
        new Date()
      );

      // Создание лида теперь обрабатывается через FreeSWITCH событие lead:created

      log.call.dtmf(phoneNumber, dtmfDigit, {
        callUuid,
        contactId: activeCall.contactId,
      });

      this.emit('call:dtmf', {
        callUuid,
        campaignId: activeCall.campaignId,
        contactId: activeCall.contactId,
        phoneNumber,
        dtmfDigit,
        contactStatus,
      });

    } catch (error) {
      log.error('Error handling DTMF event:', error);
    }
  }

  /**
   * Обработка результата AMD
   */
  private async handleAMDResult(event: any): Promise<void> {
    try {
      const { callUuid, phoneNumber, amdResult, amdConfidence } = event;
      
      const activeCall = this.activeCalls.get(callUuid);
      if (!activeCall) {
        log.warn(`Received AMD result for unknown call: ${callUuid}`);
        return;
      }

      const isAnsweringMachine = amdResult === 'MACHINE';

      log.call.amd(phoneNumber, amdResult, amdConfidence * 100, {
        callUuid,
        contactId: activeCall.contactId,
      });

      this.emit('call:amd_result', {
        callUuid,
        campaignId: activeCall.campaignId,
        contactId: activeCall.contactId,
        phoneNumber,
        amdResult,
        amdConfidence,
        isAnsweringMachine,
      });

      // Если обнаружен автоответчик, можно завершить звонок
      if (isAnsweringMachine && config.amdEnabled) {
        await this.voipProvider.hangupCall(callUuid);
      }

    } catch (error) {
      log.error('Error handling AMD result event:', error);
    }
  }

  /**
   * Обработка события создания лида от FreeSWITCH
   */
  private async handleLeadCreatedEvent(event: any): Promise<void> {
    try {
      const { callUuid, phoneNumber, campaignId, dtmfResponse } = event;
      
      const activeCall = this.activeCalls.get(callUuid);
      if (!activeCall) {
        log.warn(`Received lead creation event for unknown call: ${callUuid}, phone: ${phoneNumber}`);
        return;
      }

      // Создание лида в Bitrix24
      await this.createBitrixLead(activeCall, dtmfResponse);

      log.info(`✅ Лид создан через FreeSWITCH событие для кампании ${campaignId}, телефон ${phoneNumber}, DTMF: ${dtmfResponse}`, {
        callUuid,
        campaignId: activeCall.campaignId,
        contactId: activeCall.contactId,
      });

    } catch (error) {
      log.error('Error handling lead creation event:', error);
    }
  }

  /**
   * Запуск активных кампаний при старте диалера
   */
  private async startActiveCampaigns(): Promise<void> {
    try {
      const activeCampaigns = await campaignModel.getActiveCampaigns();
      
      for (const campaign of activeCampaigns) {
        await this.startCampaign(campaign.id);
      }

      log.info(`Started ${activeCampaigns.length} active campaigns`);

    } catch (error) {
      log.error('Failed to start active campaigns:', error);
    }
  }

  /**
   * Остановка всех кампаний
   */
  private async stopAllCampaigns(): Promise<void> {
    const campaignIds = Array.from(this.campaignIntervals.keys());
    
    for (const campaignId of campaignIds) {
      await this.stopCampaign(campaignId);
    }
  }

  /**
   * Завершение всех активных звонков
   */
  private async hangupAllActiveCalls(): Promise<void> {
    const callUuids = Array.from(this.activeCalls.keys());
    
    for (const callUuid of callUuids) {
      try {
        await this.voipProvider.hangupCall(callUuid);
      } catch (error) {
        log.warn(`Failed to hangup call ${callUuid}:`, error);
      }
    }

    this.activeCalls.clear();
  }

  /**
   * Завершение звонков кампании
   */
  private async hangupCampaignCalls(campaignId: number): Promise<void> {
    const campaignCalls = Array.from(this.activeCalls.entries())
      .filter(([, call]) => call.campaignId === campaignId);
    
    for (const [callUuid] of campaignCalls) {
      try {
        await this.voipProvider.hangupCall(callUuid);
      } catch (error) {
        log.warn(`Failed to hangup campaign call ${callUuid}:`, error);
      }
    }
  }

  /**
   * Проверка рабочего времени кампании
   */
  private isWorkingTime(campaign: Campaign): boolean {
    return timezoneService.isCampaignWorkingTime(campaign);
  }

  /**
   * Проверка рабочего времени для контакта с учетом его часового пояса
   */
  private isContactInWorkingTime(campaign: Campaign, contact: Contact): boolean {
    return timezoneService.isContactWorkingTime(campaign, contact);
  }

  /**
   * Проверка возможности совершения звонка (лимит в минуту)
   */
  private canMakeCall(callsPerMinute: number): boolean {
    const now = new Date();
    const oneMinuteAgo = new Date(now.getTime() - 60000);

    // Очистка старых записей
    this.callsInLastMinute = this.callsInLastMinute.filter(time => time > oneMinuteAgo);

    return this.callsInLastMinute.length < callsPerMinute;
  }

  /**
   * Отслеживание звонка для лимита в минуту
   */
  private trackCallForRateLimit(): void {
    this.callsInLastMinute.push(new Date());
  }

  /**
   * Расчет интервала между звонками
   */
  private calculateCallInterval(callsPerMinute: number): number {
    return Math.max(1000, Math.floor(60000 / callsPerMinute));
  }

  /**
   * Получение количества активных звонков кампании
   */
  private getActiveCampaignCallsCount(campaignId: number): number {
    return Array.from(this.activeCalls.values())
      .filter(call => call.campaignId === campaignId).length;
  }

  /**
   * Маппинг причины завершения звонка в статус звонка
   */
  private mapHangupCauseToCallStatus(hangupCause: string): CallStatus {
    switch (hangupCause) {
      case 'NORMAL_CLEARING':
      case 'SUCCESS':
        return 'answered';
      case 'USER_BUSY':
      case 'CALL_REJECTED':
        return 'busy';
      case 'NO_ANSWER':
      case 'ORIGINATOR_CANCEL':
        return 'no_answer';
      case 'BLACKLISTED':
        return 'blacklisted';
      default:
        return 'failed';
    }
  }

  /**
   * Маппинг статуса звонка в статус контакта
   */
  private mapCallStatusToContactStatus(callStatus: CallStatus): ContactStatus {
    switch (callStatus) {
      case 'answered':
        return 'completed';
      case 'busy':
      case 'no_answer':
        return 'retry';
      case 'blacklisted':
        return 'blacklisted';
      case 'failed':
      default:
        return 'failed';
    }
  }

  /**
   * Проверка необходимости повторного звонка
   */
  private shouldRetryCall(contact: Contact, campaign: Campaign, callStatus: CallStatus): boolean {
    if (callStatus === 'answered' || callStatus === 'blacklisted') {
      return false;
    }

    return contact.callAttempts < campaign.retryAttempts;
  }

  /**
   * Расчет времени следующего звонка с учетом часовых поясов
   */
  private calculateNextCallTime(
    attempt: number, 
    retryDelay: number, 
    campaign?: Campaign, 
    contact?: Contact
  ): Date {
    const baseDelay = retryDelay * attempt * 1000; // в миллисекундах
    const nextAttemptTime = new Date(Date.now() + baseDelay);
    
    // Если есть информация о кампании и контакте, учитываем рабочее время
    if (campaign && contact) {
      const nextWorkingTime = timezoneService.getNextWorkingTimeForContact(
        campaign, 
        contact, 
        nextAttemptTime
      );
      
      // Если расчетное время попадает в рабочие часы, используем его
      if (timezoneService.isContactWorkingTime(campaign, contact, nextAttemptTime)) {
        return nextAttemptTime;
      }
      
      // Иначе используем следующее рабочее время
      return nextWorkingTime;
    }
    
    // Fallback для обратной совместимости
    return nextAttemptTime;
  }

  /**
   * Запуск мониторинга
   */
  private startMonitoring(): void {
    setInterval(() => {
      this.emitStats();
      this.updateMonitoringMetrics();
    }, 30000); // каждые 30 секунд
  }

  /**
   * Обновление метрик мониторинга
   */
  private updateMonitoringMetrics(): void {
    const stats = this.getStats();
    
    // Обновляем gauge метрики
    monitoringService.getGauge('active_calls')?.set(stats.activeCalls);
    monitoringService.getGauge('active_campaigns')?.set(stats.activeCampaigns);
    
    // Записываем метрики производительности
    monitoringService.recordMetric({
      name: 'dialer_calls_per_minute',
      value: stats.callsPerMinute,
      type: 'gauge'
    });
  }

  /**
   * Регистрация health checks
   */
  private registerHealthChecks(): void {
    // Health check для диалера
    monitoringService.registerHealthCheck('dialer', async () => {
      const start = Date.now();
      const status = this.getStatus();
      
      const isHealthy = status.isRunning && status.voipConnected;
      
      return {
        name: 'dialer',
        status: isHealthy ? 'healthy' : 'unhealthy',
        message: isHealthy ? 'Диалер работает нормально' : `Проблемы с диалером или ${config.voipProvider.toUpperCase()}`,
        duration: Date.now() - start,
        timestamp: new Date(),
        details: {
          isRunning: status.isRunning,
          voipConnected: status.voipConnected,
          voipProvider: config.voipProvider,
          activeCalls: status.activeCalls,
          activeCampaigns: status.activeCampaigns
        }
      };
    });

    // Health check для VoIP провайдера (FreeSWITCH или Asterisk)
    monitoringService.registerHealthCheck('voip_provider', async () => {
      const start = Date.now();
      const connectionStatus = this.voipProvider.getConnectionStatus();
      
      return {
        name: 'voip_provider',
        status: connectionStatus.connected ? 'healthy' : 'unhealthy',
        message: connectionStatus.connected 
          ? `${config.voipProvider.toUpperCase()} подключен` 
          : `${config.voipProvider.toUpperCase()} недоступен`,
        duration: Date.now() - start,
        timestamp: new Date(),
        details: {
          ...connectionStatus,
          provider: config.voipProvider
        }
      };
    });
  }

  /**
   * Отправка статистики
   */
  private emitStats(): void {
    const stats: DialerStats = {
      activeCalls: this.activeCalls.size,
      totalCallsToday: 0, // TODO: Получать из БД
      successfulCallsToday: 0, // TODO: Получать из БД  
      failedCallsToday: 0, // TODO: Получать из БД
      callsPerMinute: this.callsInLastMinute.length,
      activeCampaigns: this.campaignIntervals.size,
    };

    this.emit('stats', stats);
  }

  /**
   * Получение статистики диалера
   */
  getStats(): DialerStats {
    return {
      activeCalls: this.activeCalls.size,
      totalCallsToday: 0,
      successfulCallsToday: 0,
      failedCallsToday: 0,
      callsPerMinute: this.callsInLastMinute.length,
      activeCampaigns: this.campaignIntervals.size,
    };
  }

  /**
   * Получение активных звонков
   */
  getActiveCalls(): ActiveCall[] {
    return Array.from(this.activeCalls.values());
  }

  /**
   * Получение статуса диалера
   */
  getStatus(): {
    isRunning: boolean;
    activeCalls: number;
    activeCampaigns: number;
    voipConnected: boolean;
    voipProvider: string;
  } {
    return {
      isRunning: this.isRunning,
      activeCalls: this.activeCalls.size,
      activeCampaigns: this.campaignIntervals.size,
      voipConnected: this.voipProvider.isConnected(),
      voipProvider: config.voipProvider,
    };
  }

  /**
   * Сброс "зависших" контактов в статусе calling
   */
  private async resetStuckContacts(campaignId: number): Promise<void> {
    try {
      // Находим контакты, которые более 5 минут находятся в статусе calling
      const stuckContactsQuery = `
        UPDATE contacts 
        SET status = 'retry', last_call_at = NULL, next_call_at = NOW() + INTERVAL '1 minute'
        WHERE campaign_id = $1 
          AND status = 'calling' 
          AND (last_call_at IS NULL OR last_call_at < NOW() - INTERVAL '5 minutes')
        RETURNING id, phone, status;
      `;
      
      const result = await contactModel.query<any>(stuckContactsQuery, [campaignId]);
      
      if (result.rowCount && result.rowCount > 0) {
        log.info(`🔄 Reset ${result.rowCount} stuck contacts for campaign ${campaignId}`);
        result.rows.forEach(contact => {
          log.info(`📞 Reset contact: ${contact.phone} (ID: ${contact.id}) → ${contact.status}`);
        });
      }
      
    } catch (error) {
      log.error(`Failed to reset stuck contacts for campaign ${campaignId}:`, error);
    }
  }

  /**
   * Создание лида в Bitrix24 для клиента с DTMF ответом
   */
  private async createBitrixLead(activeCall: ActiveCall, dtmfResponse: string): Promise<void> {
    try {
      // Получаем информацию о кампании и контакте
      const [campaign, contact] = await Promise.all([
        campaignModel.getCampaignById(activeCall.campaignId),
        contactModel.getContactById(activeCall.contactId)
      ]);

      if (!campaign || !contact) {
        log.warn(`Cannot create Bitrix lead: campaign or contact not found`, {
          campaignId: activeCall.campaignId,
          contactId: activeCall.contactId,
        });
        return;
      }

      // Проверяем, включена ли интеграция с Bitrix24 для кампании
      if (!campaign.bitrixCreateLeads) {
        log.debug(`Bitrix24 integration disabled for campaign ${campaign.name}`);
        return;
      }

      // Проверяем статус подключения к Bitrix24
      const authStatus = bitrix24Service.getAuthStatus();
      if (!authStatus.isConfigured || !authStatus.hasTokens || !authStatus.isTokenValid) {
        log.warn('Bitrix24 not configured or tokens invalid, skipping lead creation');
        return;
      }

      // Подготавливаем данные лида
      const leadParams: any = {
        title: `Лид из кампании: ${campaign.name}`,
        name: contact.firstName || '',
        lastName: contact.lastName || '',
        phone: contact.phoneNumber,
        email: contact.email || '',
        sourceId: campaign.bitrixSourceId || 'CALL',
        campaignName: campaign.name,
        dtmfResponse,
        comments: `Телефон: ${contact.phoneNumber}\nВремя звонка: ${new Date().toLocaleString('ru-RU')}`,
      };

      // Добавляем responsibleId только если он определен  
      if (campaign.bitrixResponsibleId && typeof campaign.bitrixResponsibleId === 'number') {
        leadParams.responsibleId = campaign.bitrixResponsibleId;
      }

      // Создаем лид в Bitrix24
      const bitrixLead = await bitrix24Service.createLead(leadParams);

      // Обновляем контакт с ID созданного лида
      await contactModel.updateContact(contact.id, {
        bitrixLeadId: bitrixLead.id,
      });

      log.info(`✅ Bitrix24 лид создан успешно`, {
        leadId: bitrixLead.id,
        campaignName: campaign.name,
        phone: contact.phoneNumber,
        dtmfResponse,
      });

      // Отслеживание создания лида в мониторинге
      monitoringService.trackLeadCreated();

      // Эмитим событие успешного создания лида
      this.emit('bitrix:lead_created', {
        campaignId: activeCall.campaignId,
        contactId: activeCall.contactId,
        leadId: bitrixLead.id,
        phone: contact.phoneNumber,
        dtmfResponse,
      });

    } catch (error: any) {
      log.error('❌ Ошибка создания лида в Bitrix24:', {
        error: error.message,
        campaignId: activeCall.campaignId,
        contactId: activeCall.contactId,
        phone: activeCall.phoneNumber,
        dtmfResponse,
      });

      // Эмитим событие ошибки создания лида
      this.emit('bitrix:lead_error', {
        campaignId: activeCall.campaignId,
        contactId: activeCall.contactId,
        phone: activeCall.phoneNumber,
        error: error.message,
        dtmfResponse,
      });
    }
  }
}

/**
 * Singleton экземпляр сервиса диалера
 */
export const dialerService = new DialerService(); 