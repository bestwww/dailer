<template>
  <div class="campaign-comparison-chart">
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

// Интерфейс для данных сравнения кампаний
interface CampaignComparisonData {
  campaign: {
    id: number
    name: string
    status: string
    createdAt: string
  }
  stats: {
    totalCalls: number
    answeredCalls: number
    busyCalls: number
    noAnswerCalls: number
    failedCalls: number
    averageCallDuration: number
    answerRate: number
    conversionRate: number
    interestedResponses: number
    humanAnswers: number
    machineAnswers: number
  }
}

// Пропсы компонента
interface Props {
  title: string
  subtitle?: string
  data: CampaignComparisonData[]
  height?: number
}

const props = withDefaults(defineProps<Props>(), {
  height: 400
})

// Цветовая схема
const colors = [
  '#3B82F6', // blue-500
  '#10B981', // green-500
  '#F59E0B', // amber-500
  '#EF4444', // red-500
  '#8B5CF6', // purple-500
  '#06B6D4', // cyan-500
  '#84CC16', // lime-500
  '#F97316', // orange-500
]

// Данные для диаграммы
const chartData = computed(() => {
  const labels = props.data.map(item => item.campaign.name)
  
  return {
    labels,
    datasets: [
      {
        label: 'Всего звонков',
        data: props.data.map(item => item.stats.totalCalls),
        backgroundColor: colors[0] + '80',
        borderColor: colors[0],
        borderWidth: 1
      },
      {
        label: 'Отвечены',
        data: props.data.map(item => item.stats.answeredCalls),
        backgroundColor: colors[1] + '80',
        borderColor: colors[1],
        borderWidth: 1
      },
      {
        label: 'Заинтересованы',
        data: props.data.map(item => item.stats.interestedResponses),
        backgroundColor: colors[2] + '80',
        borderColor: colors[2],
        borderWidth: 1
      },
      {
        label: 'Неуспешные',
        data: props.data.map(item => item.stats.failedCalls),
        backgroundColor: colors[3] + '80',
        borderColor: colors[3],
        borderWidth: 1
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
        title: (context: any) => {
          const dataIndex = context[0].dataIndex
          const campaign = props.data[dataIndex]?.campaign
          return campaign ? campaign.name : ''
        },
        label: (context: any) => {
          const label = context.dataset.label || ''
          const value = context.raw
          return `${label}: ${value}`
        },
        afterLabel: (context: any) => {
          const dataIndex = context.dataIndex
          const campaignData = props.data[dataIndex]
          if (campaignData) {
            const stats = campaignData.stats
            return [
              `Процент ответов: ${stats.answerRate.toFixed(1)}%`,
              `Конверсия: ${stats.conversionRate.toFixed(1)}%`,
              `Ср. длительность: ${Math.round(stats.averageCallDuration)}с`,
              `Статус: ${campaignData.campaign.status}`
            ]
          }
          return []
        }
      }
    }
  },
  scales: {
    x: {
      display: true,
      title: {
        display: true,
        text: 'Кампании'
      }
    },
    y: {
      display: true,
      beginAtZero: true,
      title: {
        display: true,
        text: 'Количество звонков'
      }
    }
  }
}))
</script>

<style scoped>
.campaign-comparison-chart {
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