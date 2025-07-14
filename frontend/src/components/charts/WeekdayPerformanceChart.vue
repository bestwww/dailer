<template>
  <div class="weekday-performance-chart">
    <div class="chart-header">
      <h3 class="chart-title">{{ title }}</h3>
      <p class="chart-subtitle" v-if="subtitle">{{ subtitle }}</p>
    </div>
    
    <div class="chart-wrapper" :style="{ height: `${height}px` }">
      <BaseChart
        type="bar"
        :data="chartData"
        :options="chartOptions"
        :responsive="true"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import BaseChart from './BaseChart.vue'

// Интерфейс для данных по дням недели
interface WeekdayData {
  dayOfWeek: number
  totalCalls: number
  answeredCalls: number
  avgDuration: number
}

// Пропсы компонента
interface Props {
  title: string
  subtitle?: string
  data: WeekdayData[]
  height?: number
}

const props = withDefaults(defineProps<Props>(), {
  height: 300
})

// Цветовая схема
const colors = {
  totalCalls: '#3B82F6',      // blue-500
  answeredCalls: '#10B981',   // green-500
  avgDuration: '#8B5CF6'      // purple-500
}

// Названия дней недели
const weekdayNames = ['Воскресенье', 'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота']

// Получение названия дня недели
function getWeekdayName(dayOfWeek: number): string {
  return weekdayNames[dayOfWeek] || 'Неизвестно'
}

// Данные для диаграммы
const chartData = computed(() => {
  const labels = props.data.map(item => getWeekdayName(item.dayOfWeek))
  
  return {
    labels,
    datasets: [
      {
        label: 'Всего звонков',
        data: props.data.map(item => item.totalCalls),
        backgroundColor: colors.totalCalls + '80',
        borderColor: colors.totalCalls,
        borderWidth: 1,
        yAxisID: 'y'
      },
      {
        label: 'Отвечены',
        data: props.data.map(item => item.answeredCalls),
        backgroundColor: colors.answeredCalls + '80',
        borderColor: colors.answeredCalls,
        borderWidth: 1,
        yAxisID: 'y'
      },
      {
        label: 'Ср. длительность (сек)',
        data: props.data.map(item => Math.round(item.avgDuration || 0)),
        backgroundColor: colors.avgDuration + '80',
        borderColor: colors.avgDuration,
        borderWidth: 1,
        yAxisID: 'y1',
        type: 'line' as const
      }
    ]
  }
})

// Настройки диаграммы
const chartOptions = computed(() => ({
  responsive: true,
  maintainAspectRatio: false,
  interaction: {
    mode: 'index' as const,
    intersect: false,
  },
  plugins: {
    legend: {
      position: 'top' as const,
      labels: {
        usePointStyle: true,
        padding: 20
      }
    },
    tooltip: {
      mode: 'index' as const,
      intersect: false,
      callbacks: {
        label: (context: any) => {
          const label = context.dataset.label || ''
          const value = context.raw
          
          if (label.includes('длительность')) {
            return `${label}: ${value} сек`
          }
          
          return `${label}: ${value}`
        }
      }
    }
  },
  scales: {
    x: {
      display: true,
      title: {
        display: true,
        text: 'День недели'
      }
    },
    y: {
      type: 'linear' as const,
      display: true,
      position: 'left' as const,
      beginAtZero: true,
      title: {
        display: true,
        text: 'Количество звонков'
      }
    },
    y1: {
      type: 'linear' as const,
      display: true,
      position: 'right' as const,
      beginAtZero: true,
      title: {
        display: true,
        text: 'Длительность (сек)'
      },
      grid: {
        drawOnChartArea: false,
      },
    }
  }
}))
</script>

<style scoped>
.weekday-performance-chart {
  background-color: white;
  border-radius: 0.5rem;
  box-shadow: 0 1px 2px 0 rgb(0 0 0 / 0.05);
  border: 1px solid #e5e7eb;
  padding: 1.5rem;
}

.chart-header {
  margin-bottom: 1rem;
}

.chart-title {
  font-size: 1.125rem;
  font-weight: 600;
  color: #111827;
}

.chart-subtitle {
  font-size: 0.875rem;
  color: #4b5563;
  margin-top: 0.25rem;
}

.chart-wrapper {
  position: relative;
}
</style> 