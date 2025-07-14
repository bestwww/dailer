<template>
  <div class="top-numbers-chart">
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

// Интерфейс для данных топ номеров
interface TopNumberData {
  phoneNumber: string
  totalCalls: number
  answeredCalls: number
  lastCallAt: Date | string
  lastCallStatus: string
}

// Пропсы компонента
interface Props {
  title: string
  subtitle?: string
  data: TopNumberData[]
  height?: number
}

const props = withDefaults(defineProps<Props>(), {
  height: 300
})

// Цветовая схема
const colors = {
  totalCalls: '#3B82F6',      // blue-500
  answeredCalls: '#10B981',   // green-500
}

// Форматирование номера телефона
function formatPhoneNumber(phone: string): string {
  // Убираем лишние символы и показываем только последние 4 цифры для читаемости
  const cleaned = phone.replace(/[^\d]/g, '')
  if (cleaned.length >= 4) {
    return `***${cleaned.slice(-4)}`
  }
  return phone
}

// Данные для диаграммы
const chartData = computed(() => {
  // Берем только первые 10 номеров для лучшей читаемости
  const topData = props.data.slice(0, 10)
  const labels = topData.map(item => formatPhoneNumber(item.phoneNumber))
  
  return {
    labels,
    datasets: [
      {
        label: 'Всего звонков',
        data: topData.map(item => item.totalCalls),
        backgroundColor: colors.totalCalls + '80',
        borderColor: colors.totalCalls,
        borderWidth: 1
      },
      {
        label: 'Отвечены',
        data: topData.map(item => item.answeredCalls),
        backgroundColor: colors.answeredCalls + '80',
        borderColor: colors.answeredCalls,
        borderWidth: 1
      }
    ]
  }
})

// Настройки диаграммы
const chartOptions = computed(() => ({
  responsive: true,
  maintainAspectRatio: false,
  indexAxis: 'y' as const, // Горизонтальная диаграмма
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
          const originalData = props.data[dataIndex]
          return originalData ? originalData.phoneNumber : ''
        },
        label: (context: any) => {
          const label = context.dataset.label || ''
          const value = context.raw
          return `${label}: ${value}`
        },
        afterLabel: (context: any) => {
          const dataIndex = context.dataIndex
          const originalData = props.data[dataIndex]
          if (originalData) {
            const lastCallDate = new Date(originalData.lastCallAt).toLocaleString('ru-RU')
            return [`Последний звонок: ${lastCallDate}`, `Статус: ${originalData.lastCallStatus}`]
          }
          return []
        }
      }
    }
  },
  scales: {
    x: {
      display: true,
      beginAtZero: true,
      title: {
        display: true,
        text: 'Количество звонков'
      }
    },
    y: {
      display: true,
      title: {
        display: true,
        text: 'Номера телефонов'
      }
    }
  }
}))
</script>

<style scoped>
.top-numbers-chart {
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