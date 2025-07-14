import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { apiService } from '@/services/api'
import type { ApiResponse } from '@/types'

/**
 * Интерфейс пользователя
 */
interface User {
  id: number
  username: string
  email: string
  role: 'admin' | 'manager' | 'user' | 'viewer'
  permissions: Record<string, boolean>
  firstName?: string
  lastName?: string
  isActive: boolean
  lastLoginAt?: string
  timezone: string
  language: string
  createdAt: string
  updatedAt: string
}

/**
 * Store для управления аутентификацией
 */
export const useAuthStore = defineStore('auth', () => {
  // Состояние
  const user = ref<User | null>(null)
  const token = ref<string | null>(localStorage.getItem('auth_token'))
  const loading = ref(false)
  const error = ref<string | null>(null)

  // Геттеры
  const isAuthenticated = computed(() => !!token.value && !!user.value)
  const userRole = computed(() => user.value?.role || null)
  const userName = computed(() => {
    if (!user.value) return null
    return `${user.value.firstName || ''} ${user.value.lastName || ''}`.trim() || user.value.username
  })

  // Действия

  /**
   * Авторизация пользователя
   */
  async function login(identifier: string, password: string): Promise<boolean> {
    try {
      loading.value = true
      error.value = null

      const response = await apiService.post<ApiResponse<{ token: string; user: User }>>('/auth/login', {
        identifier,
        password
      })

      if (response.success && response.data) {
        token.value = response.data.token
        user.value = response.data.user
        
        // Сохранение токена в localStorage
        localStorage.setItem('auth_token', response.data.token)
        
        // Настройка заголовка авторизации для API
        apiService.setAuthToken(response.data.token)
        
        return true
      } else {
        error.value = response.error || 'Неверные учетные данные'
        return false
      }
    } catch (err: any) {
      error.value = err.response?.data?.error || 'Ошибка при входе в систему'
      return false
    } finally {
      loading.value = false
    }
  }

  /**
   * Выход из системы
   */
  async function logout(): Promise<void> {
    try {
      loading.value = true
      
      // Отправляем запрос на выход
      await apiService.post('/auth/logout')
    } catch (err) {
      console.error('Ошибка при выходе:', err)
    } finally {
      // Очищаем данные независимо от результата
      clearAuth()
      loading.value = false
    }
  }

  /**
   * Получение информации о текущем пользователе
   */
  async function fetchUser(): Promise<boolean> {
    try {
      if (!token.value) return false

      loading.value = true
      error.value = null

      const response = await apiService.get<ApiResponse<User>>('/auth/me')

      if (response.success && response.data) {
        user.value = response.data
        return true
      } else {
        clearAuth()
        return false
      }
    } catch (err: any) {
      error.value = err.response?.data?.error || 'Ошибка получения данных пользователя'
      clearAuth()
      return false
    } finally {
      loading.value = false
    }
  }

  /**
   * Обновление токена
   */
  async function refreshToken(): Promise<boolean> {
    try {
      if (!token.value) return false

      const response = await apiService.post<ApiResponse<{ token: string }>>('/auth/refresh')

      if (response.success && response.data) {
        token.value = response.data.token
        localStorage.setItem('auth_token', response.data.token)
        apiService.setAuthToken(response.data.token)
        return true
      } else {
        clearAuth()
        return false
      }
    } catch (err) {
      clearAuth()
      return false
    }
  }

  /**
   * Смена пароля
   */
  async function changePassword(currentPassword: string, newPassword: string): Promise<boolean> {
    try {
      loading.value = true
      error.value = null

      const response = await apiService.post<ApiResponse>('/auth/change-password', {
        currentPassword,
        newPassword
      })

      if (response.success) {
        return true
      } else {
        error.value = response.error || 'Ошибка смены пароля'
        return false
      }
    } catch (err: any) {
      error.value = err.response?.data?.error || 'Ошибка смены пароля'
      return false
    } finally {
      loading.value = false
    }
  }

  /**
   * Проверка разрешения пользователя
   */
  function hasPermission(permission: string): boolean {
    return user.value?.permissions?.[permission] ?? false
  }

  /**
   * Проверка роли пользователя
   */
  function hasRole(role: string | string[]): boolean {
    if (!user.value) return false
    
    if (Array.isArray(role)) {
      return role.includes(user.value.role)
    }
    
    return user.value.role === role
  }

  /**
   * Очистка данных аутентификации
   */
  function clearAuth(): void {
    user.value = null
    token.value = null
    error.value = null
    localStorage.removeItem('auth_token')
    apiService.setAuthToken(null)
  }

  /**
   * Инициализация store
   */
  function initialize(): void {
    const savedToken = localStorage.getItem('auth_token')
    if (savedToken) {
      token.value = savedToken
      apiService.setAuthToken(savedToken)
      // Получаем данные пользователя асинхронно
      fetchUser().catch(error => {
        console.error('Ошибка инициализации пользователя:', error)
        // Если не удалось получить пользователя, очищаем токен
        clearAuth()
      })
    }
  }

  return {
    // Состояние
    user,
    token,
    loading,
    error,
    
    // Геттеры
    isAuthenticated,
    userRole,
    userName,
    
    // Действия
    login,
    logout,
    fetchUser,
    refreshToken,
    changePassword,
    hasPermission,
    hasRole,
    clearAuth,
    initialize
  }
}) 