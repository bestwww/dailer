<template>
  <div class="stats-cards">
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
      <!-- Общие звонки -->
      <div class="stat-card">
        <div class="stat-card-content">
          <div class="stat-icon stat-icon-primary">
            <PhoneIcon class="w-6 h-6" />
          </div>
          <div class="stat-details">
            <p class="stat-label">Всего звонков</p>
            <p class="stat-value">{{ formatNumber(stats.totalCalls) }}</p>
            <p class="stat-change" :class="getChangeColor(stats.totalCallsChange)">
              <ArrowTrendingUpIcon v-if="(stats.totalCallsChange || 0) > 0" class="w-4 h-4" />
              <ArrowTrendingDownIcon v-else-if="(stats.totalCallsChange || 0) < 0" class="w-4 h-4" />
              {{ formatChange(stats.totalCallsChange) }}
            </p>
          </div>
        </div>
      </div>

      <!-- Процент ответивших -->
      <div class="stat-card">
        <div class="stat-card-content">
          <div class="stat-icon stat-icon-success">
            <CheckCircleIcon class="w-6 h-6" />
          </div>
          <div class="stat-details">
            <p class="stat-label">Процент ответов</p>
            <p class="stat-value">{{ formatPercentage(stats.answerRate) }}%</p>
            <p class="stat-change" :class="getChangeColor(stats.answerRateChange)">
              <ArrowTrendingUpIcon v-if="(stats.answerRateChange || 0) > 0" class="w-4 h-4" />
              <ArrowTrendingDownIcon v-else-if="(stats.answerRateChange || 0) < 0" class="w-4 h-4" />
              {{ formatChange(stats.answerRateChange, true) }}
            </p>
          </div>
        </div>
      </div>

      <!-- Конверсия -->
      <div class="stat-card">
        <div class="stat-card-content">
          <div class="stat-icon stat-icon-warning">
            <StarIcon class="w-6 h-6" />
          </div>
          <div class="stat-details">
            <p class="stat-label">Конверсия</p>
            <p class="stat-value">{{ formatPercentage(stats.conversionRate) }}%</p>
            <p class="stat-change" :class="getChangeColor(stats.conversionRateChange)">
              <ArrowTrendingUpIcon v-if="(stats.conversionRateChange || 0) > 0" class="w-4 h-4" />
              <ArrowTrendingDownIcon v-else-if="(stats.conversionRateChange || 0) < 0" class="w-4 h-4" />
              {{ formatChange(stats.conversionRateChange, true) }}
            </p>
          </div>
        </div>
      </div>

      <!-- Созданные лиды -->
      <div class="stat-card">
        <div class="stat-card-content">
          <div class="stat-icon stat-icon-info">
            <UserPlusIcon class="w-6 h-6" />
          </div>
          <div class="stat-details">
            <p class="stat-label">Лиды создано</p>
            <p class="stat-value">{{ formatNumber(stats.leadsCreated) }}</p>
            <p class="stat-change" :class="getChangeColor(stats.leadsCreatedChange)">
              <ArrowTrendingUpIcon v-if="(stats.leadsCreatedChange || 0) > 0" class="w-4 h-4" />
              <ArrowTrendingDownIcon v-else-if="(stats.leadsCreatedChange || 0) < 0" class="w-4 h-4" />
              {{ formatChange(stats.leadsCreatedChange) }}
            </p>
          </div>
        </div>
      </div>
    </div>

    <!-- Дополнительные метрики -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mt-6">
      <!-- Средняя длительность -->
      <div class="stat-card">
        <div class="stat-card-content">
          <div class="stat-icon stat-icon-secondary">
            <ClockIcon class="w-6 h-6" />
          </div>
          <div class="stat-details">
            <p class="stat-label">Ср. длительность</p>
            <p class="stat-value">{{ formatDuration(stats.avgCallDuration) }}</p>
            <p class="stat-description">секунд на звонок</p>
          </div>
        </div>
      </div>

      <!-- Автоответчики -->
      <div class="stat-card">
        <div class="stat-card-content">
          <div class="stat-icon stat-icon-danger">
            <SpeakerXMarkIcon class="w-6 h-6" />
          </div>
          <div class="stat-details">
            <p class="stat-label">Автоответчики</p>
            <p class="stat-value">{{ formatNumber(stats.machineAnswers) }}</p>
            <p class="stat-description">{{ formatPercentage(getMachinePercentage()) }}% от ответов</p>
          </div>
        </div>
      </div>

      <!-- Активные кампании -->
      <div class="stat-card">
        <div class="stat-card-content">
          <div class="stat-icon stat-icon-primary">
            <PlayCircleIcon class="w-6 h-6" />
          </div>
          <div class="stat-details">
            <p class="stat-label">Активные кампании</p>
            <p class="stat-value">{{ formatNumber(stats.activeCampaigns) }}</p>
            <p class="stat-description">из {{ formatNumber(stats.totalCampaigns) }} всего</p>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import {
  PhoneIcon,
  CheckCircleIcon,
  StarIcon,
  UserPlusIcon,
  ClockIcon,
  SpeakerXMarkIcon,
  PlayCircleIcon,
  ArrowTrendingUpIcon,
  ArrowTrendingDownIcon
} from '@heroicons/vue/24/outline'

// Пропсы компонента
interface Props {
  stats: {
    totalCalls: number
    answeredCalls: number
    answerRate: number
    conversionRate: number
    leadsCreated: number
    avgCallDuration: number
    machineAnswers: number
    activeCampaigns: number
    totalCampaigns: number
    
    // Изменения относительно предыдущего периода (опциональные)
    totalCallsChange?: number
    answerRateChange?: number
    conversionRateChange?: number
    leadsCreatedChange?: number
  }
}

const props = defineProps<Props>()

// Форматирование чисел
function formatNumber(value: number): string {
  if (value >= 1000000) {
    return (value / 1000000).toFixed(1) + 'M'
  } else if (value >= 1000) {
    return (value / 1000).toFixed(1) + 'K'
  }
  return value.toString()
}

// Форматирование процентов
function formatPercentage(value: number): string {
  return value.toFixed(1)
}

// Форматирование изменений
function formatChange(value: number | undefined, isPercentage: boolean = false): string {
  if (value === undefined || value === 0) return '—'
  
  const sign = value > 0 ? '+' : ''
  const suffix = isPercentage ? 'п.п.' : ''
  
  return `${sign}${value.toFixed(1)}${suffix}`
}

// Форматирование длительности
function formatDuration(seconds: number): string {
  if (seconds < 60) {
    return Math.round(seconds).toString()
  }
  
  const minutes = Math.floor(seconds / 60)
  const remainingSeconds = Math.round(seconds % 60)
  
  return `${minutes}:${remainingSeconds.toString().padStart(2, '0')}`
}

// Цвет для изменений
function getChangeColor(value: number | undefined): string {
  if (value === undefined || value === 0) return 'text-gray-500'
  return value > 0 ? 'text-green-600' : 'text-red-600'
}

// Процент автоответчиков
function getMachinePercentage(): number {
  const { answeredCalls, machineAnswers } = props.stats
  if (answeredCalls === 0) return 0
  return (machineAnswers / answeredCalls) * 100
}
</script>

<style scoped>
.stats-cards {
  /* Заменяем @apply space-y-6 на нативный CSS для совместимости с Tailwind CSS v4 */
}

.stats-cards > * + * {
  margin-top: 1.5rem; /* 24px, эквивалент space-y-6 */
}

.stat-card {
  background-color: white;
  border-radius: 0.5rem;
  box-shadow: 0 1px 2px 0 rgb(0 0 0 / 0.05);
  border: 1px solid #e5e7eb;
  padding: 1.5rem;
  transition: box-shadow 0.2s ease-in-out;
}

.stat-card:hover {
  box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1);
}

.stat-card-content {
  display: flex;
  align-items: flex-start;
  gap: 1rem;
}

.stat-icon {
  padding: 0.75rem;
  border-radius: 0.5rem;
  flex-shrink: 0;
}

.stat-icon-primary {
  background-color: #dbeafe;
  color: #2563eb;
}

.stat-icon-success {
  background-color: #dcfce7;
  color: #16a34a;
}

.stat-icon-warning {
  background-color: #fef3c7;
  color: #d97706;
}

.stat-icon-info {
  background-color: #dbeafe;
  color: #2563eb;
}

.stat-icon-secondary {
  background-color: #f3f4f6;
  color: #6b7280;
}

.stat-icon-danger {
  background-color: #fee2e2;
  color: #dc2626;
}

.stat-details {
  flex: 1;
}

.stat-label {
  font-size: 0.875rem;
  font-weight: 500;
  color: #6b7280;
  margin-bottom: 0.25rem;
}

.stat-value {
  font-size: 1.5rem;
  font-weight: 700;
  color: #111827;
  margin-bottom: 0.25rem;
}

.stat-change {
  font-size: 0.875rem;
  font-weight: 500;
  display: flex;
  align-items: center;
  gap: 0.25rem;
}

.stat-description {
  font-size: 0.75rem;
  color: #6b7280;
  margin-top: 0.25rem;
}

@media (max-width: 768px) {
  .stat-card-content {
    flex-direction: column;
    gap: 0.75rem;
  }
  
  .stat-icon {
    align-self: flex-start;
  }
}
</style> 