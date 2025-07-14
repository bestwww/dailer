import { io, type Socket } from 'socket.io-client'
import type { RealTimeEvent } from '@/types'

// WebSocket сервис для real-time обновлений
class WebSocketService {
  private socket: Socket | null = null
  private eventListeners: Map<string, Function[]> = new Map()
  private reconnectAttempts = 0
  private maxReconnectAttempts = 5
  private reconnectDelay = 1000

  constructor() {
    this.connect()
  }

  /**
   * Подключение к WebSocket серверу
   */
  connect(): void {
    const url = import.meta.env.VITE_WS_URL || 'http://localhost:3000'
    
    this.socket = io(url, {
      autoConnect: true,
      reconnection: true,
      reconnectionAttempts: this.maxReconnectAttempts,
      reconnectionDelay: this.reconnectDelay,
      transports: ['websocket', 'polling']
    })

    this.setupEventHandlers()
  }

  /**
   * Настройка базовых обработчиков событий
   */
  private setupEventHandlers(): void {
    if (!this.socket) return

    // Успешное подключение
    this.socket.on('connect', () => {
      console.log('✅ WebSocket подключен')
      this.reconnectAttempts = 0
      this.emit('connection', { status: 'connected' })
    })

    // Ошибка подключения
    this.socket.on('connect_error', (error: Error) => {
      console.error('❌ WebSocket ошибка подключения:', error)
      this.handleReconnect()
    })

    // Отключение
    this.socket.on('disconnect', (reason: string) => {
      console.warn('⚠️ WebSocket отключен:', reason)
      this.emit('connection', { status: 'disconnected', reason })
    })

    // Real-time события диалер системы
    this.socket.on('call_started', (data: any) => {
      console.log('🔔 WebSocket событие call_started:', data)
      this.emit('call_started', data)
    })

    this.socket.on('call_completed', (data: any) => {
      console.log('🔔 WebSocket событие call_completed:', data)
      this.emit('call_completed', data)
    })

    this.socket.on('call_failed', (data: any) => {
      console.log('🔔 WebSocket событие call_failed:', data)
      this.emit('call_failed', data)
    })

    this.socket.on('campaign_updated', (data: any) => {
      console.log('🔔 WebSocket событие campaign_updated получено:', data)
      this.emit('campaign_updated', data)
    })

    this.socket.on('system_stats', (data: any) => {
      console.log('🔔 WebSocket событие system_stats:', data)
      this.emit('system_stats', data)
    })
  }

  /**
   * Обработка переподключения
   */
  private handleReconnect(): void {
    if (this.reconnectAttempts < this.maxReconnectAttempts) {
      this.reconnectAttempts++
      console.log(`🔄 Попытка переподключения ${this.reconnectAttempts}/${this.maxReconnectAttempts}`)
      
      setTimeout(() => {
        if (this.socket) {
          this.socket.connect()
        }
      }, this.reconnectDelay * this.reconnectAttempts)
    } else {
      console.error('❌ Превышено максимальное количество попыток переподключения')
      this.emit('connection', { status: 'failed' })
    }
  }

  /**
   * Подписка на события
   */
  on(event: string, callback: Function): void {
    if (!this.eventListeners.has(event)) {
      this.eventListeners.set(event, [])
    }
    this.eventListeners.get(event)!.push(callback)
  }

  /**
   * Отписка от событий
   */
  off(event: string, callback?: Function): void {
    if (!this.eventListeners.has(event)) return

    if (callback) {
      const listeners = this.eventListeners.get(event)!
      const index = listeners.indexOf(callback)
      if (index !== -1) {
        listeners.splice(index, 1)
      }
    } else {
      this.eventListeners.delete(event)
    }
  }

  /**
   * Эмит событий для внутренних слушателей
   */
  private emit(event: string, data: any): void {
    const listeners = this.eventListeners.get(event) || []
    listeners.forEach(callback => {
      try {
        callback(data)
      } catch (error) {
        console.error(`Ошибка в обработчике события ${event}:`, error)
      }
    })
  }

  /**
   * Отправка событий на сервер
   */
  send(event: string, data?: any): void {
    if (this.socket && this.socket.connected) {
      this.socket.emit(event, data)
    } else {
      console.warn('WebSocket не подключен, сообщение не отправлено:', event, data)
    }
  }

  /**
   * Присоединение к комнате кампании для получения обновлений
   */
  joinCampaignRoom(campaignId: number): void {
    this.send('join_campaign', { campaignId })
  }

  /**
   * Покидание комнаты кампании
   */
  leaveCampaignRoom(campaignId: number): void {
    this.send('leave_campaign', { campaignId })
  }

  /**
   * Запрос текущих статистик
   */
  requestStats(): void {
    this.send('get_stats')
  }

  /**
   * Проверка состояния подключения
   */
  get isConnected(): boolean {
    return this.socket?.connected || false
  }

  /**
   * Отключение WebSocket
   */
  disconnect(): void {
    if (this.socket) {
      this.socket.disconnect()
      this.socket = null
    }
    this.eventListeners.clear()
  }

  /**
   * Переподключение
   */
  reconnect(): void {
    this.disconnect()
    this.reconnectAttempts = 0
    this.connect()
  }
}

// Экспортируем единственный экземпляр
export const wsService = new WebSocketService()
export default wsService 