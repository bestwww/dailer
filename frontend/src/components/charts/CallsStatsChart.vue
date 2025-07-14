<template>
  <div class="calls-stats-chart">
    <div class="chart-header">
      <h3 class="chart-title">{{ title }}</h3>
      <p class="chart-subtitle" v-if="subtitle">{{ subtitle }}</p>
    </div>
    
    <div class="chart-wrapper" :style="{ height: `${height}px` }">
      <BaseChart
        type="doughnut"
        :data="chartData"
        :options="chartOptions"
        :responsive="true"
      />
    </div>
    
    <!-- Легенда с процентами -->
    <div class="chart-legend">
      <div
        v-for="(item, index) in legendItems"
        :key="index"
        class="legend-item"
      >
        <div
          class="legend-color"
          :style="{ backgroundColor: item.color }"
        ></div>
        <span class="legend-label">{{ item.label }}</span>
        <span class="legend-value">{{ item.value }} ({{ item.percentage }}%)</span>
      </div>
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
  stats: {
    totalCalls: number
    answeredCalls: number
    busyCalls: number
    noAnswerCalls: number
    failedCalls: number
  }
  height?: number
}

const props = withDefaults(defineProps<Props>(), {
  height: 300
})

// Цветовая схема для диаграммы
const colors = {
  answered: '#10B981', // green-500
  busy: '#F59E0B',     // amber-500
  noAnswer: '#6B7280', // gray-500
  failed: '#EF4444'    // red-500
}

// Данные для диаграммы
const chartData = computed(() => {
  const { stats } = props
  
  // Защита от undefined данных
  if (!stats || stats.totalCalls === 0) {
    return {
      labels: ['Отвечены', 'Занято', 'Не отвечают', 'Ошибка'],
      datasets: [
        {
          data: [1, 1, 1, 1], // Минимальные значения для отображения
          backgroundColor: [
            '#E5E7EB', // Серый для пустых данных
            '#E5E7EB',
            '#E5E7EB',
            '#E5E7EB'
          ],
          borderWidth: 0,
          hoverBorderWidth: 2,
          hoverBorderColor: '#fff'
        }
      ]
    }
  }
  
  const answeredCalls = stats.answeredCalls || 0
  const busyCalls = stats.busyCalls || 0
  const noAnswerCalls = stats.noAnswerCalls || 0
  const failedCalls = stats.failedCalls || 0
  
  // Если все значения равны 0, показываем пустую диаграмму
  if (answeredCalls === 0 && busyCalls === 0 && noAnswerCalls === 0 && failedCalls === 0) {
    return {
      labels: ['Нет данных'],
      datasets: [
        {
          data: [1],
          backgroundColor: ['#E5E7EB'],
          borderWidth: 0,
          hoverBorderWidth: 2,
          hoverBorderColor: '#fff'
        }
      ]
    }
  }
  
  return {
    labels: ['Отвечены', 'Занято', 'Не отвечают', 'Ошибка'],
    datasets: [
      {
        data: [answeredCalls, busyCalls, noAnswerCalls, failedCalls],
        backgroundColor: [
          colors.answered,
          colors.busy,
          colors.noAnswer,
          colors.failed
        ],
        borderWidth: 0,
        hoverBorderWidth: 2,
        hoverBorderColor: '#fff'
      }
    ]
  }
})

// Настройки диаграммы
const chartOptions = computed(() => ({
  responsive: true,
  maintainAspectRatio: false,
  animation: {
    duration: 800,
    easing: 'easeInOutQuart',
  },
  plugins: {
    legend: {
      display: false // Используем собственную легенду
    },
    tooltip: {
      callbacks: {
        label: (context: any) => {
          const total = props.stats?.totalCalls || 0
          const value = context.raw
          const percentage = total > 0 ? ((value / total) * 100).toFixed(1) : '0'
          return `${context.label}: ${value} (${percentage}%)`
        }
      }
    }
  },
  cutout: '60%', // Размер внутреннего отверстия
  elements: {
    arc: {
      borderWidth: 0,
      borderColor: 'transparent'
    }
  }
}))

// Данные для легенды
const legendItems = computed(() => {
  const { stats } = props
  
  // Защита от undefined данных
  if (!stats) {
    return [
      { label: 'Отвечены', value: 0, color: colors.answered, percentage: '0' },
      { label: 'Занято', value: 0, color: colors.busy, percentage: '0' },
      { label: 'Не отвечают', value: 0, color: colors.noAnswer, percentage: '0' },
      { label: 'Ошибка', value: 0, color: colors.failed, percentage: '0' }
    ]
  }
  
  const total = stats.totalCalls || 0
  
  const items = [
    {
      label: 'Отвечены',
      value: stats.answeredCalls || 0,
      color: colors.answered
    },
    {
      label: 'Занято',
      value: stats.busyCalls || 0,
      color: colors.busy
    },
    {
      label: 'Не отвечают',
      value: stats.noAnswerCalls || 0,
      color: colors.noAnswer
    },
    {
      label: 'Ошибка',
      value: stats.failedCalls || 0,
      color: colors.failed
    }
  ]
  
  return items.map(item => ({
    ...item,
    percentage: total > 0 ? ((item.value / total) * 100).toFixed(1) : '0'
  }))
})
</script>

<style scoped>
.calls-stats-chart {
  background-color: white;
  border-radius: 0.5rem;
  box-shadow: 0 1px 2px 0 rgb(0 0 0 / 0.05);
  border: 1px solid #e5e7eb;
  padding: 1.5rem;
}

.chart-header {
  margin-bottom: 1rem;
  text-align: center;
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
  margin-bottom: 1.5rem;
}

.chart-legend {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 0.75rem;
}

.legend-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.legend-color {
  width: 1rem;
  height: 1rem;
  border-radius: 0.125rem;
  flex-shrink: 0;
}

.legend-label {
  font-size: 0.875rem;
  color: #374151;
  flex: 1;
}

.legend-value {
  font-size: 0.875rem;
  font-weight: 500;
  color: #111827;
}

@media (max-width: 640px) {
  .chart-legend {
    grid-template-columns: 1fr;
  }
}
</style> 