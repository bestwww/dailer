/**
 * Абстракция для работы с VoIP провайдерами (FreeSWITCH, Asterisk, etc.)
 * Позволяет легко переключаться между разными VoIP системами
 */

import { EventEmitter } from 'events';

// 🎯 Основной интерфейс VoIP провайдера
export interface VoIPProvider extends EventEmitter {
  // === Управление подключением ===
  connect(): Promise<void>;
  disconnect(): void;
  isConnected(): boolean;
  
  // === Управление звонками ===
  makeCall(phoneNumber: string, campaignId: number, audioFilePath?: string): Promise<string>;
  hangupCall(callUuid: string): Promise<void>;
  
  // === Получение информации ===
  getConnectionStatus(): VoIPConnectionStatus;
  getStats(): Promise<VoIPStats>;
  
  // === Отправка команд ===
  sendCommand(command: string): Promise<any>;
}

// 🔧 Типы данных
export interface VoIPConnectionStatus {
  connected: boolean;
  reconnectAttempts: number;
  maxReconnectAttempts: number;
  lastError?: string;
}

export interface VoIPStats {
  activeCalls: number;
  activeChannels: number;
  uptime: number;
  connected: boolean;
}

// 🎛️ События VoIP провайдера
export interface VoIPCallCreatedEvent {
  callUuid: string;
  phoneNumber: string;
  callerIdNumber?: string;
  timestamp: Date;
}

export interface VoIPCallAnsweredEvent {
  callUuid: string;
  phoneNumber: string;
  answerTime: Date;
  timestamp: Date;
}

export interface VoIPCallHangupEvent {
  callUuid: string;
  phoneNumber: string;
  hangupCause: string;
  callDuration: number;
  billableSeconds: number;
  timestamp: Date;
}

export interface VoIPCallDTMFEvent {
  callUuid: string;
  phoneNumber: string;
  dtmfDigit: string;
  timestamp: Date;
}

export interface VoIPCallAMDEvent {
  callUuid: string;
  phoneNumber: string;
  amdResult: string;
  amdConfidence: number;
  timestamp: Date;
}

export interface VoIPLeadCreatedEvent {
  callUuid: string;
  phoneNumber: string;
  campaignId: number;
  dtmfResponse: string;
  callResult: string;
  timestamp: Date;
}

// 🏭 Тип провайдера и конфигурация
export type VoIPProviderType = 'freeswitch' | 'asterisk';

export interface VoIPConfig {
  provider: VoIPProviderType;
  freeswitch?: {
    host: string;
    port: number;
    password: string;
  };
  asterisk?: {
    host: string;
    port: number;
    username: string;
    password: string;
  };
} 