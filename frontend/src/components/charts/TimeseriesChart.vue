<template>
  <div class="timeseries-chart">
    <div class="chart-header">
      <h3 class="chart-title">{{ title }}</h3>
      <p class="chart-subtitle" v-if="subtitle">{{ subtitle }}</p>
    </div>
    
    <div class="chart-wrapper" :style="{ height: `${height}px` }">
      <BaseChart
        type="line"
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

// Пропсы компонента
interface Props {
  title: string
  subtitle?: string
  data: Array<{
    timestamp: Date | string
    totalCalls: number
    answeredCalls: number
    failedCalls: number
    averageDuration: number
  }>
  height?: number
  showDuration?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  height: 400,
  showDuration: false
})

// Цветовая схема
const colors = {
  totalCalls: '#3B82F6',    // blue-500
  answeredCalls: '#10B981',  // green-500
  failedCalls: '#EF4444',   // red-500
  duration: '#8B5CF6'       // purple-500
}

// Форматирование времени для меток
function formatTime(timestamp: Date | string): string {
  const date = new Date(timestamp)
  const now = new Date()
  const diffInHours = Math.abs(now.getTime() - date.getTime()) / (1000 * 60 * 60)
  
  if (diffInHours < 24) {
    // Для данных за последние 24 часа показываем время
    return date.toLocaleTimeString('ru-RU', { 
      hour: '2-digit', 
      minute: '2-digit' 
    })
  } else {
    // Для более старых данных показываем дату
    return date.toLocaleDateString('ru-RU', {
      day: '2-digit',
      month: '2-digit'
    })
  }
}

// Данные для диаграммы
const chartData = computed(() => {
  const labels = props.data.map(item => formatTime(item.timestamp))
  
  const datasets = [
    {
      label: 'Всего звонков',
      data: props.data.map(item => item.totalCalls),
      borderColor: colors.totalCalls,
      backgroundColor: colors.totalCalls + '20',
      fill: true,
      tension: 0.4,
      pointRadius: 3,
      pointHoverRadius: 6
    },
    {
      label: 'Отвечены',
      data: props.data.map(item => item.answeredCalls),
      borderColor: colors.answeredCalls,
      backgroundColor: colors.answeredCalls + '20',
      fill: false,
      tension: 0.4,
      pointRadius: 3,
      pointHoverRadius: 6
    },
    {
      label: 'Неуспешные',
      data: props.data.map(item => item.failedCalls),
      borderColor: colors.failedCalls,
      backgroundColor: colors.failedCalls + '20',
      fill: false,
      tension: 0.4,
      pointRadius: 3,
      pointHoverRadius: 6
    }
  ]

  // Добавляем данные о длительности, если включено
  if (props.showDuration) {
    datasets.push({
      label: 'Ср. длительность (сек)',
      data: props.data.map(item => Math.round(item.averageDuration || 0)),
      borderColor: colors.duration,
      backgroundColor: colors.duration + '20',
      fill: false,
      tension: 0.4,
      pointRadius: 3,
      pointHoverRadius: 6
    } as any) // Временно используем any для решения проблемы с типами
  }
  
  return {
    labels,
    datasets
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
        title: (context: any) => {
          const dataIndex = context[0].dataIndex
          const originalTimestamp = props.data[dataIndex]?.timestamp
          if (originalTimestamp) {
            return new Date(originalTimestamp).toLocaleString('ru-RU')
          }
          return context[0].label
        },
        label: (context: any) => {
          const label = context.dataset.label || ''
          const value = context.raw
          
          if (label.includes('длительность')) {
            return `${label}: ${value} сек`
          }
          
          return `${label}: ${value} звонков`
        }
      }
    }
  },
  scales: {
    x: {
      display: true,
      grid: {
        display: false,
      },
      title: {
        display: true,
        text: 'Время'
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
      },
      grid: {
        color: 'rgba(0, 0, 0, 0.1)',
      }
    },
    ...(props.showDuration && {
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
    })
  }
}))
</script>

<style scoped>
.timeseries-chart {
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