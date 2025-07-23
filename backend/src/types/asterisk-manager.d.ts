// Типы для модуля asterisk-manager
declare module 'asterisk-manager' {
  import { EventEmitter } from 'events';

  export interface AsteriskManagerOptions {
    host?: string;
    port?: number;
    username: string;
    password: string;
    events?: boolean;
    ami_version?: string;
  }

  export interface AsteriskAction {
    action: string;
    [key: string]: any;
  }

  export interface AsteriskEvent {
    event?: string;
    uniqueid?: string;
    channel?: string;
    calleridnum?: string;
    calleridname?: string;
    state?: string;
    [key: string]: any;
  }

  export interface AsteriskResponse {
    response: string;
    message?: string;
    [key: string]: any;
  }

  export default class AsteriskManager extends EventEmitter {
    constructor(
      port?: number,
      host?: string,
      username?: string,
      password?: string,
      events?: boolean
    );

    constructor(options: AsteriskManagerOptions);

    open(): void;
    close(): void;
    isConnected(): boolean;
    action(action: AsteriskAction): Promise<AsteriskResponse>;

    on(event: 'connect', listener: () => void): this;
    on(event: 'close', listener: () => void): this;
    on(event: 'error', listener: (error: Error) => void): this;
    on(event: 'managerevent', listener: (event: AsteriskEvent) => void): this;
    on(event: string, listener: (...args: any[]) => void): this;

    emit(event: 'connect'): boolean;
    emit(event: 'close'): boolean;
    emit(event: 'error', error: Error): boolean;
    emit(event: 'managerevent', event: AsteriskEvent): boolean;
    emit(event: string, ...args: any[]): boolean;
  }
} 