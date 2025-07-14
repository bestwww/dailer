<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { 
  Refresh, 
  Document, 
  Phone, 
  CircleCheck, 
  TrendCharts 
} from '@element-plus/icons-vue'
import { useCampaignsStore } from '@/stores/campaigns'
import { wsService } from '@/services/websocket'
import { apiService } from '@/services/api'
import type { Campaign, CallResult, CallStatus } from '@/types'

// Stores
const campaignsStore = useCampaignsStore()

// Реактивные данные
const loading = ref(false)
const wsConnected = ref(false)

// Статистика
const stats = ref({
  activeCampaigns: 0,
  callsToday: 0,
  successfulCalls: 0,
  conversionRate: 0
})

// Информация о системе
const systemInfo = ref({
  activeCalls: 0,
  queueSize: 0,
  cpuUsage: 0,
  memoryUsage: 0
})

// Последние звонки
const recentCalls = ref<any[]>([])

// Computed свойства
const activeCampaigns = computed(() => campaignsStore.activeCampaigns.slice(0, 5))

// Методы
async function refreshData(): Promise<void> {
  try {
    loading.value = true
    
    // Загружаем данные параллельно, но не блокируем выполнение при ошибках
    await Promise.allSettled([
      loadStats(),
      loadSystemInfo(),
      loadRecentCalls(),
      campaignsStore.fetchCampaigns({ limit: 10 })
    ])
  } catch (error) {
    console.error('Ошибка обновления данных:', error)
  } finally {
    loading.value = false
  }
}

async function loadStats(): Promise<void> {
  try {
    const data = await apiService.getSystemStats()
    stats.value = data
  } catch (error) {
    console.error('Ошибка загрузки статистики:', error)
    // Устанавливаем значения по умолчанию при ошибке
    stats.value = {
      activeCampaigns: 0,
      callsToday: 0,
      successfulCalls: 0,
      conversionRate: 0
    }
  }
}

async function loadSystemInfo(): Promise<void> {
  try {
    const healthData = await apiService.getSystemHealth()
    // Пока используем заглушки для демонстрации
    systemInfo.value = {
      activeCalls: Math.floor(Math.random() * 10),
      queueSize: Math.floor(Math.random() * 50),
      cpuUsage: Math.floor(Math.random() * 80),
      memoryUsage: Math.floor(Math.random() * 70)
    }
  } catch (error) {
    console.error('Ошибка загрузки информации о системе:', error)
    // Устанавливаем значения по умолчанию при ошибке
    systemInfo.value = {
      activeCalls: 0,
      queueSize: 0,
      cpuUsage: 0,
      memoryUsage: 0
    }
  }
}

async function loadRecentCalls(): Promise<void> {
  try {
    const response = await apiService.getCallResults(undefined, { limit: 10 })
    console.log('Recent calls response:', response) // Для отладки
    
    // Проверяем различные форматы данных
    let callsData: any[] = []
    const responseAny = response as any
    
    if (Array.isArray(responseAny)) {
      // Если response - это массив
      callsData = responseAny
    } else if (responseAny && typeof responseAny === 'object') {
      // Если response - это объект
      if (Array.isArray(responseAny.data)) {
        // Если response.data - это массив (формат PaginatedResponse)
        callsData = responseAny.data
      } else if (responseAny.data && Array.isArray(responseAny.data.data)) {
        // Если response.data.data - это массив (формат ApiResponse<PaginatedResponse>)
        callsData = responseAny.data.data
      }
    }
    
    recentCalls.value = callsData.map(call => ({
      ...call,
      phone: '+7-XXX-XXX-XXXX', // Замените на реальный номер
      campaignName: 'Кампания ' + call.campaignId // Замените на реальное название
    }))
  } catch (error) {
    console.error('Ошибка загрузки последних звонков:', error)
    // Устанавливаем пустой массив при ошибке
    recentCalls.value = []
  }
}

function getProgressPercentage(campaign: Campaign): number {
  if (!campaign.totalContacts || campaign.totalContacts === 0) return 0
  return Math.round(((campaign.completedContacts || 0) / campaign.totalContacts) * 100)
}

function getCpuColor(usage: number): string {
  if (usage < 50) return '#22c55e'
  if (usage < 80) return '#f59e0b'
  return '#ef4444'
}

function getMemoryColor(usage: number): string {
  if (usage < 70) return '#22c55e'
  if (usage < 90) return '#f59e0b'
  return '#ef4444'
}

function getCallStatusClass(status: CallStatus): string {
  const classes = {
    'answered': 'bg-success-100 text-success-800',
    'busy': 'bg-warning-100 text-warning-800',
    'no_answer': 'bg-gray-100 text-gray-800',
    'failed': 'bg-error-100 text-error-800'
  }
  return classes[status] || 'bg-gray-100 text-gray-800'
}

function getCallStatusText(status: CallStatus): string {
  const texts = {
    'answered': 'Отвечен',
    'busy': 'Занято',
    'no_answer': 'Не отвечен',
    'failed': 'Ошибка'
  }
  return texts[status] || 'Неизвестно'
}

function formatTime(dateString: string): string {
  return new Date(dateString).toLocaleTimeString('ru-RU', {
    hour: '2-digit',
    minute: '2-digit'
  })
}

// WebSocket обработчики
function handleConnection(data: any): void {
  wsConnected.value = data.status === 'connected'
}

function handleSystemStats(data: any): void {
  systemInfo.value = { ...systemInfo.value, ...data }
}

function handleCallUpdate(): void {
  // Обновляем статистику при изменении звонков
  loadStats()
  loadRecentCalls()
}

// Жизненный цикл
onMounted(() => {
  // Подписываемся на WebSocket события
  wsService.on('connection', handleConnection)
  wsService.on('system_stats', handleSystemStats)
  wsService.on('call_completed', handleCallUpdate)
  wsService.on('call_failed', handleCallUpdate)
  
  // Загружаем начальные данные
  refreshData()
  
  // Проверяем состояние WebSocket
  wsConnected.value = wsService.isConnected
})

onUnmounted(() => {
  // Отписываемся от событий
  wsService.off('connection', handleConnection)
  wsService.off('system_stats', handleSystemStats)
  wsService.off('call_completed', handleCallUpdate)
  wsService.off('call_failed', handleCallUpdate)
})
</script>

<template>
  <div class="space-y-6">
    <!-- Заголовок страницы -->
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-2xl font-bold text-gray-900">Дашборд</h1>
        <p class="mt-1 text-sm text-gray-500">
          Общая статистика системы автодозвона
        </p>
      </div>
      <div class="flex items-center space-x-3">
        <el-button 
          type="primary" 
          :icon="Refresh" 
          @click="refreshData"
          :loading="loading"
        >
          Обновить
        </el-button>
      </div>
    </div>

    <!-- Основные метрики -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
      <!-- Активные кампании -->
      <div class="card">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-12 h-12 bg-primary-100 rounded-lg flex items-center justify-center">
              <el-icon size="24" class="text-primary-600">
                <Document />
              </el-icon>
            </div>
          </div>
          <div class="ml-4">
            <p class="text-sm font-medium text-gray-500">Активные кампании</p>
            <p class="text-2xl font-bold text-gray-900">{{ stats.activeCampaigns }}</p>
          </div>
        </div>
      </div>

      <!-- Звонки сегодня -->
      <div class="card">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-12 h-12 bg-success-100 rounded-lg flex items-center justify-center">
              <el-icon size="24" class="text-success-600">
                <Phone />
              </el-icon>
            </div>
          </div>
          <div class="ml-4">
            <p class="text-sm font-medium text-gray-500">Звонки сегодня</p>
            <p class="text-2xl font-bold text-gray-900">{{ stats.callsToday }}</p>
          </div>
        </div>
      </div>

      <!-- Успешные соединения -->
      <div class="card">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-12 h-12 bg-warning-100 rounded-lg flex items-center justify-center">
              <el-icon size="24" class="text-warning-600">
                <CircleCheck />
              </el-icon>
            </div>
          </div>
          <div class="ml-4">
            <p class="text-sm font-medium text-gray-500">Успешные</p>
            <p class="text-2xl font-bold text-gray-900">{{ stats.successfulCalls }}</p>
          </div>
        </div>
      </div>

      <!-- Конверсия -->
      <div class="card">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-12 h-12 bg-error-100 rounded-lg flex items-center justify-center">
              <el-icon size="24" class="text-error-600">
                <TrendCharts />
              </el-icon>
            </div>
          </div>
          <div class="ml-4">
            <p class="text-sm font-medium text-gray-500">Конверсия</p>
            <p class="text-2xl font-bold text-gray-900">{{ stats.conversionRate }}%</p>
          </div>
        </div>
      </div>
    </div>

    <!-- Активные кампании и система -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <!-- Список активных кампаний -->
      <div class="card">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-lg font-semibold text-gray-900">Активные кампании</h2>
          <router-link to="/campaigns" class="text-primary-600 hover:text-primary-500 text-sm">
            Смотреть все
          </router-link>
        </div>
        
        <div v-if="loading" class="flex justify-center py-4">
          <el-skeleton :rows="3" animated />
        </div>
        
        <div v-else-if="activeCampaigns.length === 0" class="text-center py-8 text-gray-500">
          Нет активных кампаний
        </div>
        
        <div v-else class="space-y-3">
          <div 
            v-for="campaign in activeCampaigns" 
            :key="campaign.id"
            class="flex items-center justify-between p-3 bg-gray-50 rounded-lg"
          >
            <div class="flex-1">
              <h3 class="font-medium text-gray-900">{{ campaign.name }}</h3>
              <p class="text-sm text-gray-500">
                {{ campaign.completedContacts }}/{{ campaign.totalContacts }} контактов
              </p>
            </div>
            <div class="flex items-center space-x-2">
              <span 
                class="status-active"
                v-if="campaign.status === 'active'"
              >
                Активна
              </span>
              <el-progress 
                :percentage="getProgressPercentage(campaign)"
                :stroke-width="6"
                :show-text="false"
                class="w-16"
              />
            </div>
          </div>
        </div>
      </div>

      <!-- Статус системы -->
      <div class="card">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-lg font-semibold text-gray-900">Статус системы</h2>
          <div 
            class="flex items-center space-x-2"
            :class="wsConnected ? 'text-success-600' : 'text-error-600'"
          >
            <div 
              class="w-2 h-2 rounded-full"
              :class="wsConnected ? 'bg-success-400' : 'bg-error-400'"
            ></div>
            <span class="text-sm font-medium">
              {{ wsConnected ? 'Онлайн' : 'Офлайн' }}
            </span>
          </div>
        </div>

        <div class="space-y-4">
          <!-- Параметры системы -->
          <div class="grid grid-cols-2 gap-4">
            <div class="text-center p-3 bg-gray-50 rounded-lg">
              <p class="text-2xl font-bold text-gray-900">{{ systemInfo.activeCalls }}</p>
              <p class="text-sm text-gray-500">Активных звонков</p>
            </div>
            <div class="text-center p-3 bg-gray-50 rounded-lg">
              <p class="text-2xl font-bold text-gray-900">{{ systemInfo.queueSize }}</p>
              <p class="text-sm text-gray-500">В очереди</p>
            </div>
          </div>

          <!-- Загрузка системы -->
          <div>
            <div class="flex justify-between text-sm mb-1">
              <span class="text-gray-600">Загрузка CPU</span>
              <span class="font-medium">{{ systemInfo.cpuUsage }}%</span>
            </div>
            <el-progress 
              :percentage="systemInfo.cpuUsage" 
              :stroke-width="8"
              :show-text="false"
              :color="getCpuColor(systemInfo.cpuUsage)"
            />
          </div>

          <div>
            <div class="flex justify-between text-sm mb-1">
              <span class="text-gray-600">Использование памяти</span>
              <span class="font-medium">{{ systemInfo.memoryUsage }}%</span>
            </div>
            <el-progress 
              :percentage="systemInfo.memoryUsage" 
              :stroke-width="8"
              :show-text="false"
              :color="getMemoryColor(systemInfo.memoryUsage)"
            />
          </div>
        </div>
      </div>
    </div>

    <!-- Последние звонки -->
    <div class="card">
      <div class="flex items-center justify-between mb-4">
        <h2 class="text-lg font-semibold text-gray-900">Последние звонки</h2>
        <router-link to="/statistics" class="text-primary-600 hover:text-primary-500 text-sm">
          Подробная статистика
        </router-link>
      </div>

      <div v-if="loading" class="flex justify-center py-4">
        <el-skeleton :rows="5" animated />
      </div>

      <div v-else-if="recentCalls.length === 0" class="text-center py-8 text-gray-500">
        Нет данных о звонках
      </div>

      <div v-else class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Время
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Номер
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Кампания
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Статус
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Ответ DTMF
              </th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <tr v-for="call in recentCalls" :key="call.id">
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                {{ formatTime(call.createdAt) }}
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                {{ call.phone }}
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                {{ call.campaignName }}
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span 
                  class="inline-flex px-2 py-1 text-xs font-semibold rounded-full"
                  :class="getCallStatusClass(call.callStatus)"
                >
                  {{ getCallStatusText(call.callStatus) }}
                </span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                {{ call.dtmfResponse || '-' }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>
