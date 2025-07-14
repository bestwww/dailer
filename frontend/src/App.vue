<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { 
  Phone, 
  Close, 
  Menu, 
  Bell, 
  Setting, 
  InfoFilled,
  DataAnalysis,
  Document,
  User,
  Histogram
} from '@element-plus/icons-vue'
import { wsService } from '@/services/websocket'

// Auth store
const authStore = useAuthStore()

// Состояние бокового меню
const sidebarOpen = ref(false)

// Статус подключения WebSocket
const connectionStatus = ref<'connected' | 'disconnected'>('disconnected')

// Счетчик уведомлений
const notificationCount = ref(0)

// Текущий маршрут
const route = useRoute()

// Проверка авторизации
const isAuthenticated = computed(() => authStore.isAuthenticated)

// Элементы навигации
const navigationItems = [
  {
    name: 'Дашборд',
    path: '/',
    icon: DataAnalysis
  },
  {
    name: 'Кампании',
    path: '/campaigns',
    icon: Document
  },
  {
    name: 'Контакты',
    path: '/contacts',
    icon: User
  },
  {
    name: 'Статистика',
    path: '/statistics',
    icon: Histogram
  },
  {
    name: 'Настройки',
    path: '/settings',
    icon: Setting
  }
]

// Методы управления боковым меню
function toggleSidebar(): void {
  sidebarOpen.value = !sidebarOpen.value
}

function closeSidebar(): void {
  sidebarOpen.value = false
}

// Определение активного элемента навигации
function getNavItemClass(path: string): string {
  const isActive = route.path === path || (path !== '/' && route.path.startsWith(path))
  return isActive 
    ? 'bg-primary-50 text-primary-700 border-primary-200' 
    : 'text-gray-700 hover:bg-gray-100'
}

// Получение заголовка текущей страницы
function getCurrentPageTitle(): string {
  const currentItem = navigationItems.find(item => 
    route.path === item.path || (item.path !== '/' && route.path.startsWith(item.path))
  )
  return currentItem?.name || 'Диалер Система'
}

// Обработчики действий
function openSettings(): void {
  // TODO: Открыть модальное окно настроек
  console.log('Открыть настройки')
}

function showAbout(): void {
  // TODO: Показать информацию о системе
  console.log('О системе')
}

/**
 * Выход из системы
 */
async function handleLogout(): Promise<void> {
  try {
    await authStore.logout()
    // Роутер автоматически перенаправит на страницу входа
  } catch (error) {
    console.error('Ошибка выхода:', error)
  }
}

// Обработка WebSocket событий
function handleConnectionChange(data: any): void {
  connectionStatus.value = data.status
}

// Жизненный цикл компонента
onMounted(() => {
  // Подписываемся на события WebSocket
  wsService.on('connection', handleConnectionChange)
  
  // Закрытие бокового меню только на мобильных устройствах при изменении размера
  const handleResize = () => {
    if (window.innerWidth < 1024) {
      // На мобильных устройствах сайдбар может быть открыт/закрыт
      // Но мы не закрываем его автоматически
    } else {
      // На больших экранах закрываем overlay если он был открыт
      sidebarOpen.value = false
    }
  }
  
  window.addEventListener('resize', handleResize)
  
  // Проверяем начальное состояние подключения
  connectionStatus.value = wsService.isConnected ? 'connected' : 'disconnected'
  
  // Инициализируем состояние сайдбара в зависимости от размера экрана
  if (window.innerWidth < 1024) {
    sidebarOpen.value = false
  }
})

onUnmounted(() => {
  // Отписываемся от событий
  wsService.off('connection', handleConnectionChange)
  window.removeEventListener('resize', () => {})
})
</script>

<template>
  <!-- Показываем интерфейс только для авторизованных пользователей -->
  <div v-if="true" class="min-h-screen bg-gray-50">
    <!-- Боковое меню -->
    <div 
      class="fixed inset-y-0 left-0 z-50 w-64 bg-white shadow-lg transform transition-transform duration-300 ease-in-out lg:translate-x-0"
      :class="{ '-translate-x-full': !sidebarOpen, 'translate-x-0': sidebarOpen }"
    >
      <div class="flex flex-col h-full">
        <!-- Логотип -->
        <div class="flex items-center justify-between h-16 px-6 border-b border-gray-200">
          <div class="flex items-center">
            <el-icon size="32" class="text-primary-600">
              <Phone />
            </el-icon>
            <h1 class="ml-3 text-xl font-bold text-gray-900">Dialer System</h1>
          </div>
          <button 
            @click="toggleSidebar" 
            class="lg:hidden p-2 rounded-md text-gray-500 hover:text-gray-700"
          >
            <el-icon><Close /></el-icon>
          </button>
        </div>

        <!-- Навигация -->
        <nav class="flex-1 px-4 py-6 space-y-2">
          <router-link 
            v-for="item in navigationItems" 
            :key="item.name"
            :to="item.path"
            class="flex items-center px-4 py-3 text-sm font-medium rounded-lg transition-colors"
            :class="getNavItemClass(item.path)"
          >
            <el-icon size="20" class="mr-3">
              <component :is="item.icon" />
            </el-icon>
            {{ item.name }}
          </router-link>
        </nav>

        <!-- Статус подключения -->
        <div class="px-6 py-4 border-t border-gray-200">
          <div class="flex items-center text-sm">
            <div 
              class="w-2 h-2 rounded-full mr-2"
              :class="connectionStatus === 'connected' ? 'bg-green-400' : 'bg-red-400'"
            ></div>
            <span class="text-gray-600">
              {{ connectionStatus === 'connected' ? 'Подключено' : 'Отключено' }}
            </span>
          </div>
        </div>
      </div>
    </div>

    <!-- Основной контент -->
    <div class="lg:pl-64">
      <!-- Header -->
      <header class="bg-white shadow-sm border-b border-gray-200">
        <div class="flex items-center justify-between h-16 px-6">
          <!-- Кнопка мобильного меню -->
          <button 
            @click="toggleSidebar"
            class="lg:hidden p-2 rounded-md text-gray-500 hover:text-gray-700"
          >
            <el-icon><Menu /></el-icon>
          </button>

          <!-- Breadcrumb -->
          <div class="flex items-center space-x-2 text-sm text-gray-600">
            <span>{{ getCurrentPageTitle() }}</span>
          </div>

          <!-- Header actions -->
          <div class="flex items-center space-x-4">
            <!-- Уведомления -->
            <el-badge :value="notificationCount" :hidden="notificationCount === 0">
              <el-button :icon="Bell" circle />
            </el-badge>

            <!-- Настройки -->
            <el-dropdown>
              <el-button :icon="Setting" circle />
              <template #dropdown>
                <el-dropdown-menu>
                  <el-dropdown-item @click="openSettings">
                    <el-icon><Setting /></el-icon>
                    Настройки
                  </el-dropdown-item>
                  <el-dropdown-item divided @click="showAbout">
                    <el-icon><InfoFilled /></el-icon>
                    О системе
                  </el-dropdown-item>
                  <el-dropdown-item @click="handleLogout">
                    <el-icon><Close /></el-icon>
                    Выйти
                  </el-dropdown-item>
                </el-dropdown-menu>
              </template>
            </el-dropdown>
          </div>
        </div>
      </header>

      <!-- Основной контент -->
      <main class="p-6">
        <router-view />
      </main>
    </div>

    <!-- Overlay для мобильного меню -->
    <div 
      v-show="sidebarOpen" 
      @click="closeSidebar"
      class="fixed inset-0 z-40 bg-black bg-opacity-50 lg:hidden"
    ></div>
  </div>
  
  <!-- Экран загрузки для неавторизованных пользователей -->
  <div v-if="false" class="min-h-screen bg-gray-50 flex items-center justify-center">
    <div class="text-center">
      <el-icon size="48" class="text-primary-600 mb-4">
        <Phone />
      </el-icon>
      <h2 class="text-2xl font-bold text-gray-900 mb-2">Dialer System</h2>
      <p class="text-gray-600">Загрузка...</p>
    </div>
  </div>
</template>

<style scoped>
/* Дополнительные стили при необходимости */
</style>
