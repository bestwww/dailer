<template>
  <div class="statistics-view">
    <!-- Заголовок страницы -->
    <div class="page-header">
      <div class="flex justify-between items-start">
        <div>
          <h1 class="text-2xl font-bold text-gray-900">Статистика и аналитика</h1>
          <p class="mt-1 text-sm text-gray-500">
            Детальная аналитика по кампаниям и звонкам
          </p>
        </div>
        
        <!-- Элементы управления -->
        <div class="flex gap-3">
          <!-- Переключатель периода -->
          <el-select
            v-model="selectedPeriod"
            @change="onPeriodChange"
            class="!w-52 !min-w-52"
            placeholder="Выберите период"
          >
            <el-option label="Последние 24 часа" value="24h" />
            <el-option label="Последние 7 дней" value="7d" />
            <el-option label="Последние 30 дней" value="30d" />
            <el-option label="Последние 90 дней" value="90d" />
          </el-select>
          
          <!-- Выбор кампании для сравнения -->
          <el-select
            v-model="selectedCampaignId"
            @change="onCampaignChange"
            class="!w-80 !min-w-80"
            placeholder="Выберите кампанию"
            clearable
            filterable
            :loading="isLoading"
          >
            <el-option
              v-for="campaign in campaigns"
              :key="campaign.id"
              :label="campaign.name"
              :value="campaign.id"
            />
          </el-select>
          
          <!-- Экспорт данных -->
          <el-dropdown @command="handleExport">
            <el-button type="primary">
              Экспорт
              <el-icon class="ml-1"><ArrowDown /></el-icon>
            </el-button>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="csv">Экспорт в CSV</el-dropdown-item>
                <el-dropdown-item command="json">Экспорт в JSON</el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
          
          <!-- Кнопка обновления -->
          <el-button 
            @click="refreshData"
            :loading="isLoading"
          >
            <el-icon><Refresh /></el-icon>
            Обновить
          </el-button>
        </div>
      </div>
    </div>



    <!-- Вкладки для разных типов статистики -->
    <el-tabs v-model="activeTab" @tab-click="onTabChange">
      <el-tab-pane label="Общая статистика" name="overview">
        <!-- Загрузка -->
        <div v-if="isLoading && !overviewStats" class="loading-state">
          <el-skeleton :rows="5" animated />
        </div>

        <!-- Основной контент -->
        <div v-else-if="overviewStats && !isLoading" class="statistics-content">
          <!-- Карточки с ключевыми метриками -->
          <div v-if="formattedOverviewStats" class="mb-8">
            <StatsCards :stats="formattedOverviewStats" />
          </div>

          <!-- Графики -->
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
            <!-- Круговая диаграмма статуса звонков -->
            <CallsStatsChart
              v-if="overviewStats?.callsLast30Days && !isLoading"
              title="Статистика звонков"
              :subtitle="`За ${getPeriodLabel()}`"
              :stats="overviewStats.callsLast30Days"
            />
            
            <!-- Заглушка для графика когда нет данных -->
            <div v-else class="timeseries-placeholder">
              <div class="placeholder-content">
                <el-icon size="48" class="text-gray-400 mb-4">
                  <DataAnalysis />
                </el-icon>
                <h3 class="text-lg font-medium text-gray-900 mb-2">Статистика звонков</h3>
                <p class="text-gray-500">Загрузка данных...</p>
              </div>
            </div>

            <!-- Временная динамика -->
            <TimeseriesChart
              v-if="timeseriesData.length > 0"
              title="Динамика звонков"
              :subtitle="`По часам за ${getPeriodLabel()}`"
              :data="timeseriesData"
              :height="300"
            />
            
            <!-- Заглушка если нет данных по времени -->
            <div v-else class="timeseries-placeholder">
              <div class="placeholder-content">
                <el-icon size="48" class="text-gray-400 mb-4">
                  <DataAnalysis />
                </el-icon>
                <h3 class="text-lg font-medium text-gray-900 mb-2">Данные по времени</h3>
                <p class="text-gray-500">Выберите кампанию для просмотра детальной временной динамики</p>
              </div>
            </div>
          </div>

          <!-- Дополнительные графики -->
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
            <!-- График производительности по часам -->
            <!-- <HourlyPerformanceChart
              v-if="hourlyData.length > 0"
              title="Производительность по часам"
              :data="hourlyData"
              :height="300"
            /> -->

            <!-- График по дням недели -->
            <!-- <WeekdayPerformanceChart
              v-if="weekdayData.length > 0"
              title="Производительность по дням недели"
              :data="weekdayData"
              :height="300"
            /> -->
          </div>

          <!-- Real-time статистика -->
          <div class="realtime-stats mt-8">
            <div class="realtime-header">
              <h2 class="text-lg font-semibold text-gray-900">Активность в реальном времени</h2>
              <span class="text-sm text-gray-500">
                Обновлено: {{ formatLastUpdate() }}
              </span>
            </div>
            
            <div class="grid grid-cols-1 md:grid-cols-5 gap-4 mt-4">
              <div class="realtime-metric">
                <span class="metric-label">За последний час</span>
                <span class="metric-value">{{ realtimeStats?.callsLastHour || 0 }}</span>
              </div>
              
              <div class="realtime-metric">
                <span class="metric-label">Отвечены за час</span>
                <span class="metric-value">{{ realtimeStats?.answeredLastHour || 0 }}</span>
              </div>
              
              <div class="realtime-metric">
                <span class="metric-label">Заинтересованы</span>
                <span class="metric-value">{{ realtimeStats?.interestedLastHour || 0 }}</span>
              </div>
              
              <div class="realtime-metric">
                <span class="metric-label">За 10 минут</span>
                <span class="metric-value">{{ realtimeStats?.callsLast10Min || 0 }}</span>
              </div>
              
              <div class="realtime-metric">
                <span class="metric-label">Активные кампании</span>
                <span class="metric-value">{{ realtimeStats?.activeCampaigns || 0 }}</span>
              </div>
            </div>
          </div>
        </div>
      </el-tab-pane>

      <el-tab-pane label="Детальная статистика" name="detailed">
        <!-- Детальная статистика по выбранной кампании -->
        <div v-if="selectedCampaignId && campaignStats && campaignStats.campaign" class="campaign-details">
          <div class="campaign-header mb-6">
            <h2 class="text-xl font-semibold text-gray-900">
              {{ campaignStats?.campaign?.name || 'Загрузка...' }}
            </h2>
            <p class="text-sm text-gray-500">
              Создана: {{ campaignStats?.campaign?.createdAt ? formatDate(campaignStats.campaign.createdAt) : 'Загрузка...' }}
              • Статус: <span class="capitalize">{{ campaignStats?.campaign?.status || 'Загрузка...' }}</span>
            </p>
          </div>

          <!-- Детальные карточки -->
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
            <div class="detail-card">
              <div class="detail-value">{{ campaignStats?.callStats?.totalCalls || 0 }}</div>
              <div class="detail-label">Всего звонков</div>
            </div>
            <div class="detail-card">
              <div class="detail-value">{{ formatPercentage(campaignStats?.callStats?.answerRate || 0) }}%</div>
              <div class="detail-label">Процент ответов</div>
            </div>
            <div class="detail-card">
              <div class="detail-value">{{ formatPercentage(campaignStats?.callStats?.conversionRate || 0) }}%</div>
              <div class="detail-label">Конверсия</div>
            </div>
            <div class="detail-card">
              <div class="detail-value">{{ formatDuration(campaignStats?.callStats?.averageCallDuration || 0) }}</div>
              <div class="detail-label">Ср. длительность</div>
            </div>
          </div>

          <!-- Графики для детальной статистики -->
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
            <!-- Временная динамика кампании -->
            <TimeseriesChart
              v-if="campaignStats?.timeseries && campaignStats.timeseries.length > 0"
              title="Динамика звонков кампании"
              :data="campaignStats?.timeseries || []"
              :height="350"
              :show-duration="true"
            />
            
            <!-- Заглушка для временной динамики -->
            <div v-else class="timeseries-placeholder">
              <div class="placeholder-content">
                <el-icon size="48" class="text-gray-400 mb-4">
                  <DataAnalysis />
                </el-icon>
                <h3 class="text-lg font-medium text-gray-900 mb-2">Динамика звонков</h3>
                <p class="text-gray-500">Нет данных для отображения временной динамики</p>
              </div>
            </div>

            <!-- Топ номеров -->
            <!-- <TopNumbersChart
              v-if="campaignStats?.topNumbers?.length > 0"
              title="Топ номеров"
              :data="campaignStats?.topNumbers || []"
              :height="350"
            /> -->
          </div>

          <!-- Анализ по времени -->
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <!-- Статистика по часам -->
            <div class="time-analysis-card">
              <h3 class="text-lg font-medium text-gray-900 mb-4">Анализ по часам</h3>
              <div class="hourly-stats">
                <div
                  v-for="hour in campaignStats?.hourlyStats || []"
                  :key="hour.hour"
                  class="hour-stat"
                >
                  <span class="hour-label">{{ hour.hour }}:00</span>
                  <div class="hour-bar-container">
                    <div
                      class="hour-bar"
                      :style="{
                        width: `${getHourBarWidth(hour.totalCalls)}%`,
                        backgroundColor: getHourBarColor(hour.totalCalls)
                      }"
                    ></div>
                    <span class="hour-value">{{ hour.totalCalls }}</span>
                  </div>
                </div>
              </div>
            </div>

            <!-- Статистика по дням недели -->
            <div class="time-analysis-card">
              <h3 class="text-lg font-medium text-gray-900 mb-4">Анализ по дням недели</h3>
              <div class="weekday-stats">
                <div
                  v-for="day in campaignStats?.weekdayStats || []"
                  :key="day.dayOfWeek"
                  class="weekday-stat"
                >
                  <span class="weekday-label">{{ getWeekdayName(day.dayOfWeek) }}</span>
                  <div class="weekday-bar-container">
                    <div
                      class="weekday-bar"
                      :style="{
                        width: `${getWeekdayBarWidth(day.totalCalls)}%`,
                        backgroundColor: getWeekdayBarColor(day.totalCalls)
                      }"
                    ></div>
                    <span class="weekday-value">{{ day.totalCalls }}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Сообщение когда не выбрана кампания -->
        <div v-else class="select-campaign-message">
          <el-icon size="48" class="text-gray-400 mb-4">
            <Select />
          </el-icon>
          <h3 class="text-lg font-medium text-gray-900 mb-2">Выберите кампанию</h3>
          <p class="text-gray-500">Выберите кампанию из выпадающего списка для просмотра детальной статистики</p>
        </div>
      </el-tab-pane>

      <el-tab-pane label="Сравнение кампаний" name="comparison">
        <!-- Сравнение кампаний -->
        <div class="comparison-controls mb-6">
          <el-select
            v-model="comparisonCampaignIds"
            multiple
            placeholder="Выберите кампании для сравнения"
            class="w-full"
            @change="loadComparisonData"
          >
            <el-option
              v-for="campaign in campaigns"
              :key="campaign.id"
              :label="campaign.name"
              :value="campaign.id"
            />
          </el-select>
        </div>

        <!-- Результаты сравнения -->
        <div v-if="comparisonData && comparisonData.length > 0" class="comparison-results">
          <!-- <CampaignComparisonChart
            title="Сравнение кампаний"
            :data="comparisonData"
            :height="400"
          /> -->

          <!-- Таблица сравнения -->
          <div class="comparison-table mt-8">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Сравнительная таблица</h3>
            <el-table :data="comparisonData" stripe style="width: 100%">
              <el-table-column prop="campaign.name" label="Кампания" />
              <el-table-column prop="stats.totalCalls" label="Всего звонков" />
              <el-table-column
                prop="stats.answerRate"
                label="Процент ответов"
                :formatter="(row: any) => formatPercentage(row.stats.answerRate) + '%'"
              />
              <el-table-column
                prop="stats.conversionRate"
                label="Конверсия"
                :formatter="(row: any) => formatPercentage(row.stats.conversionRate) + '%'"
              />
              <el-table-column
                prop="stats.averageCallDuration"
                label="Ср. длительность"
                :formatter="(row: any) => formatDuration(row.stats.averageCallDuration)"
              />
            </el-table>
          </div>
        </div>

        <!-- Сообщение когда не выбраны кампании -->
        <div v-else class="select-campaigns-message">
          <el-icon size="48" class="text-gray-400 mb-4">
            <DataAnalysis />
          </el-icon>
          <h3 class="text-lg font-medium text-gray-900 mb-2">Выберите кампании для сравнения</h3>
          <p class="text-gray-500">Выберите 2 или более кампаний для сравнения их производительности</p>
        </div>
      </el-tab-pane>
    </el-tabs>

    <!-- Состояние ошибки -->
    <div v-if="error" class="error-state">
      <el-result
        icon="error"
        title="Ошибка загрузки статистики"
        :sub-title="error"
      >
        <template #extra>
          <el-button @click="loadData" type="primary">Попробовать снова</el-button>
        </template>
      </el-result>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed, watch } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { DataAnalysis, ArrowDown, Refresh, Select } from '@element-plus/icons-vue'

// Компоненты
import StatsCards from '@/components/charts/StatsCards.vue'
import CallsStatsChart from '@/components/charts/CallsStatsChart.vue'
import TimeseriesChart from '@/components/charts/TimeseriesChart.vue'
// import HourlyPerformanceChart from '@/components/charts/HourlyPerformanceChart.vue'
// import WeekdayPerformanceChart from '@/components/charts/WeekdayPerformanceChart.vue'
// import TopNumbersChart from '@/components/charts/TopNumbersChart.vue'
// import CampaignComparisonChart from '@/components/charts/CampaignComparisonChart.vue'

// Сервисы и типы
import apiClient from '@/services/api'
import type { CampaignStatsOverview, CampaignDetailedStats, RealtimeStats } from '@/services/api'

// Router
const router = useRouter()

// Реактивные данные
const isLoading = ref(false)
const error = ref<string>('')
const selectedPeriod = ref('30d')
const activeTab = ref('overview')
const selectedCampaignId = ref<number | null>(null)
const comparisonCampaignIds = ref<number[]>([])

// Данные статистики
const overviewStats = ref<CampaignStatsOverview | null>(null)
const campaignStats = ref<CampaignDetailedStats | null>(null)
const comparisonData = ref<any[]>([])
const timeseriesData = ref<any[]>([])
const hourlyData = ref<any[]>([])
const weekdayData = ref<any[]>([])
const realtimeStats = ref<RealtimeStats | null>(null)
const campaigns = ref<any[]>([])
const lastUpdate = ref<Date>(new Date())

// Дебаг: отслеживание значений
watch(selectedPeriod, (newVal: string) => {
  console.log('Изменился selectedPeriod:', newVal)
}, { immediate: true })

watch(selectedCampaignId, (newVal: number | null) => {
  console.log('Изменился selectedCampaignId:', newVal)
}, { immediate: true })

watch(campaigns, (newVal: any[]) => {
  console.log('Изменились campaigns:', newVal)
}, { immediate: true, deep: true })

// Интервал для real-time обновлений
let realtimeInterval: number | null = null

// Вычисляемые свойства
const formattedOverviewStats = computed(() => {
  if (!overviewStats.value || !overviewStats.value.campaigns || !overviewStats.value.callsLast30Days) {
    return null
  }
  
  const { campaigns, callsLast30Days } = overviewStats.value
  
  return {
    totalCalls: callsLast30Days.totalCalls || 0,
    answeredCalls: callsLast30Days.answeredCalls || 0,
    answerRate: callsLast30Days.answerRate || 0,
    conversionRate: callsLast30Days.conversionRate || 0,
    leadsCreated: callsLast30Days.leadsCreated || 0,
    avgCallDuration: callsLast30Days.avgCallDuration || 0,
    machineAnswers: callsLast30Days.machineAnswers || 0,
    activeCampaigns: campaigns.active || 0,
    totalCampaigns: campaigns.total || 0,
  }
})

// Методы
async function loadData() {
  try {
    isLoading.value = true
    error.value = ''
    
    // Загружаем общую статистику
    try {
      console.log('Загружаем общую статистику...')
      overviewStats.value = await apiClient.stats.getOverview()
      console.log('Общая статистика загружена:', overviewStats.value)
    } catch (statsError) {
      console.error('Ошибка загрузки общей статистики:', statsError)
      // Устанавливаем пустые данные по умолчанию
      overviewStats.value = {
        campaigns: { total: 0, active: 0, completed: 0, totalCalls: 0, totalContacts: 0 },
        callsLast30Days: {
          totalCalls: 0,
          answeredCalls: 0,
          busyCalls: 0,
          noAnswerCalls: 0,
          failedCalls: 0,
          interestedResponses: 0,
          machineAnswers: 0,
          leadsCreated: 0,
          answerRate: 0,
          conversionRate: 0,
          avgCallDuration: 0,
          avgRingDuration: 0,
        }
      }
    }
    
    // Загружаем список кампаний
    try {
      console.log('Загружаем список кампаний...')
      const campaignsResponse = await apiClient.getCampaigns()
      campaigns.value = campaignsResponse.data || []
      console.log('Кампании загружены:', campaigns.value)
      console.log('Количество кампаний:', campaigns.value.length)
      
      // Отладочная информация для каждой кампании
      campaigns.value.forEach((campaign, index) => {
        console.log(`Кампания ${index}:`, {
          id: campaign.id,
          name: campaign.name,
          status: campaign.status
        })
      })
    } catch (campaignsError) {
      console.error('Ошибка загрузки кампаний:', campaignsError)
      campaigns.value = []
    }
    
    // Загружаем real-time данные
    await loadRealtimeStats()
    
    // Загружаем дополнительные данные если нужно
    if (selectedCampaignId.value) {
      await loadCampaignDetails(selectedCampaignId.value)
    }
    
    lastUpdate.value = new Date()
  } catch (err) {
    console.error('Общая ошибка загрузки данных:', err)
    error.value = err instanceof Error ? err.message : 'Неизвестная ошибка'
    ElMessage.error('Ошибка загрузки статистики')
  } finally {
    // Добавляем небольшую задержку перед снятием флага загрузки
    setTimeout(() => {
      isLoading.value = false
    }, 300)
  }
}

async function loadRealtimeStats() {
  try {
    console.log('Загружаем real-time статистику...')
    realtimeStats.value = await apiClient.stats.getRealtimeStats()
    console.log('Real-time статистика загружена:', realtimeStats.value)
  } catch (err) {
    console.error('Ошибка загрузки real-time статистики:', err)
    // Устанавливаем пустые данные по умолчанию
    realtimeStats.value = {
      callsLastHour: 0,
      answeredLastHour: 0,
      interestedLastHour: 0,
      callsLast10Min: 0,
      activeCampaigns: 0,
      timestamp: new Date().toISOString()
    }
  }
}

async function loadCampaignDetails(campaignId: number) {
  try {
    console.log('Загружаем детальную статистику кампании:', campaignId)
    const statsData = await apiClient.stats.getCampaignStats(campaignId)
    console.log('Детальная статистика загружена:', statsData)
    
    // Проверяем, что данные кампании загружены корректно
    if (statsData && statsData.campaign) {
      campaignStats.value = statsData
      
      // Обновляем данные для графиков
      if (statsData.timeseries) {
        timeseriesData.value = statsData.timeseries
      } else {
        timeseriesData.value = []
      }
      
      if (statsData.hourlyStats) {
        hourlyData.value = statsData.hourlyStats
      } else {
        hourlyData.value = []
      }
      
      if (statsData.weekdayStats) {
        weekdayData.value = statsData.weekdayStats
      } else {
        weekdayData.value = []
      }
    } else {
      throw new Error('Некорректные данные кампании')
    }
  } catch (err) {
    console.error('Ошибка загрузки детальной статистики:', err)
    ElMessage.error('Ошибка загрузки детальной статистики кампании')
    // Очищаем данные при ошибке
    campaignStats.value = null
    timeseriesData.value = []
    hourlyData.value = []
    weekdayData.value = []
  }
}

async function loadComparisonData() {
  if (comparisonCampaignIds.value.length < 2) {
    comparisonData.value = []
    return
  }
  
  try {
    const response = await apiClient.stats.compareCampaigns(comparisonCampaignIds.value)
    comparisonData.value = response.comparisons
  } catch (err) {
    console.error('Failed to load comparison data:', err)
    ElMessage.error('Ошибка загрузки данных сравнения')
  }
}

async function handleExport(format: string) {
  if (!selectedCampaignId.value) {
    ElMessage.warning('Выберите кампанию для экспорта')
    return
  }
  
  try {
    await apiClient.stats.exportCampaignStats(selectedCampaignId.value, format as 'csv' | 'json')
    ElMessage.success('Данные экспортированы')
  } catch (err) {
    console.error('Failed to export data:', err)
    ElMessage.error('Ошибка экспорта данных')
  }
}

function refreshData() {
  loadData()
}

function onPeriodChange() {
  console.log('onPeriodChange вызвана, новое значение:', selectedPeriod.value)
  loadData()
}

function onCampaignChange() {
  console.log('onCampaignChange вызвана, новое значение:', selectedCampaignId.value)
  if (selectedCampaignId.value) {
    loadCampaignDetails(selectedCampaignId.value)
  } else {
    campaignStats.value = null
    timeseriesData.value = []
    hourlyData.value = []
    weekdayData.value = []
  }
}

function onTabChange() {
  // Логика переключения вкладок
  if (activeTab.value === 'detailed' && selectedCampaignId.value) {
    loadCampaignDetails(selectedCampaignId.value)
  }
}

function getPeriodLabel(): string {
  switch (selectedPeriod.value) {
    case '24h': return 'последние 24 часа'
    case '7d': return 'последние 7 дней'
    case '30d': return 'последние 30 дней'
    case '90d': return 'последние 90 дней'
    default: return 'выбранный период'
  }
}

function formatLastUpdate(): string {
  return lastUpdate.value.toLocaleTimeString('ru-RU')
}

function formatDate(date: string): string {
  return new Date(date).toLocaleDateString('ru-RU')
}

function formatPercentage(value: number): string {
  return value.toFixed(1)
}

function formatDuration(seconds: number): string {
  if (seconds < 60) {
    return Math.round(seconds) + 'с'
  }
  
  const minutes = Math.floor(seconds / 60)
  const remainingSeconds = Math.round(seconds % 60)
  
  return `${minutes}м ${remainingSeconds}с`
}

function getWeekdayName(dayOfWeek: number): string {
  const days = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб']
  return days[dayOfWeek] || 'Неизвестно'
}

function getHourBarWidth(calls: number): number {
  if (!campaignStats.value?.hourlyStats || campaignStats.value.hourlyStats.length === 0) return 0
  const maxCalls = Math.max(...campaignStats.value.hourlyStats.map(h => h.totalCalls))
  return maxCalls > 0 ? (calls / maxCalls) * 100 : 0
}

function getHourBarColor(calls: number): string {
  if (!campaignStats.value?.hourlyStats || campaignStats.value.hourlyStats.length === 0) return '#e5e7eb'
  const maxCalls = Math.max(...campaignStats.value.hourlyStats.map(h => h.totalCalls))
  if (maxCalls === 0) return '#e5e7eb'
  const intensity = calls / maxCalls
  
  if (intensity > 0.8) return '#10b981'
  if (intensity > 0.6) return '#f59e0b'
  if (intensity > 0.3) return '#6b7280'
  return '#e5e7eb'
}

function getWeekdayBarWidth(calls: number): number {
  if (!campaignStats.value?.weekdayStats || campaignStats.value.weekdayStats.length === 0) return 0
  const maxCalls = Math.max(...campaignStats.value.weekdayStats.map(w => w.totalCalls))
  return maxCalls > 0 ? (calls / maxCalls) * 100 : 0
}

function getWeekdayBarColor(calls: number): string {
  if (!campaignStats.value?.weekdayStats || campaignStats.value.weekdayStats.length === 0) return '#e5e7eb'
  const maxCalls = Math.max(...campaignStats.value.weekdayStats.map(w => w.totalCalls))
  if (maxCalls === 0) return '#e5e7eb'
  const intensity = calls / maxCalls
  
  if (intensity > 0.8) return '#10b981'
  if (intensity > 0.6) return '#f59e0b'
  if (intensity > 0.3) return '#6b7280'
  return '#e5e7eb'
}

// Lifecycle hooks
onMounted(() => {
  console.log('Компонент смонтирован')
  console.log('Начальные значения:')
  console.log('- selectedPeriod:', selectedPeriod.value)
  console.log('- selectedCampaignId:', selectedCampaignId.value)
  console.log('- campaigns.length:', campaigns.value.length)
  
  loadData()
  
  // Запускаем real-time обновления каждые 30 секунд
  realtimeInterval = setInterval(loadRealtimeStats, 30000)
})

onUnmounted(() => {
  if (realtimeInterval) {
    clearInterval(realtimeInterval)
  }
})
</script>

<style scoped>
/* Базовые стили */
.statistics-view {
  padding: 1.5rem;
}

.statistics-view > * + * {
  margin-top: 1.5rem;
}

.page-header {
  margin-bottom: 1.5rem;
}

.loading-state {
  background-color: white;
  border-radius: 0.5rem;
  padding: 1.5rem;
}

.statistics-content {
  /* Промежутки между элементами */
}

.statistics-content > * + * {
  margin-top: 1.5rem;
}

.timeseries-placeholder {
  background-color: white;
  border-radius: 0.5rem;
  padding: 2rem;
  border: 1px solid #e5e7eb;
}

.placeholder-content {
  text-align: center;
}

.realtime-stats {
  background-color: white;
  border-radius: 0.5rem;
  padding: 1.5rem;
  border: 1px solid #e5e7eb;
}

.realtime-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.realtime-metric {
  text-align: center;
}

.metric-label {
  display: block;
  font-size: 0.875rem;
  font-weight: 500;
  color: #6b7280;
  margin-bottom: 0.25rem;
}

.metric-value {
  display: block;
  font-size: 1.5rem;
  font-weight: 700;
  color: #111827;
}

.error-state {
  background-color: white;
  border-radius: 0.5rem;
  box-shadow: 0 1px 2px 0 rgb(0 0 0 / 0.05);
  border: 1px solid #e5e7eb;
  padding: 1.5rem;
}

/* Стили для детальной статистики */
.campaign-details {
  background-color: white;
  border-radius: 0.5rem;
  padding: 1.5rem;
  border: 1px solid #e5e7eb;
}

.campaign-header {
  border-bottom: 1px solid #e5e7eb;
  padding-bottom: 1rem;
}

.detail-card {
  background-color: #f9fafb;
  border-radius: 0.5rem;
  padding: 1.5rem;
  text-align: center;
}

.detail-value {
  font-size: 1.5rem;
  font-weight: 700;
  color: #111827;
  margin-bottom: 0.5rem;
}

.detail-label {
  font-size: 0.875rem;
  color: #6b7280;
}

.time-analysis-card {
  background-color: #f9fafb;
  border-radius: 0.5rem;
  padding: 1.5rem;
}

.hourly-stats, .weekday-stats {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.hour-stat, .weekday-stat {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.hour-label, .weekday-label {
  font-size: 0.875rem;
  font-weight: 500;
  color: #374151;
  min-width: 3rem;
}

.hour-bar-container, .weekday-bar-container {
  flex: 1;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.hour-bar, .weekday-bar {
  height: 1rem;
  border-radius: 0.25rem;
  transition: width 0.3s ease;
}

.hour-value, .weekday-value {
  font-size: 0.75rem;
  font-weight: 500;
  color: #374151;
  min-width: 2rem;
}

/* Стили для сообщений */
.select-campaign-message, .select-campaigns-message {
  background-color: white;
  border-radius: 0.5rem;
  padding: 3rem;
  text-align: center;
  border: 1px solid #e5e7eb;
}

/* Стили для сравнения кампаний */
.comparison-controls {
  background-color: white;
  border-radius: 0.5rem;
  padding: 1.5rem;
  border: 1px solid #e5e7eb;
}

.comparison-results {
  background-color: white;
  border-radius: 0.5rem;
  padding: 1.5rem;
  border: 1px solid #e5e7eb;
}

.comparison-table {
  margin-top: 2rem;
}
</style> 