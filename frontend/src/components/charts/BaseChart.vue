<template>
  <div class="chart-container">
    <canvas :id="chartId" :width="width" :height="height"></canvas>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, watch, computed } from 'vue'
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  BarElement,
  ArcElement,
  Title,
  Tooltip,
  Legend,
  Filler,
  DoughnutController,
  PieController,
  LineController,
  BarController
} from 'chart.js'

// Регистрируем компоненты Chart.js
ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  BarElement,
  ArcElement,
  Title,
  Tooltip,
  Legend,
  Filler,
  DoughnutController,
  PieController,
  LineController,
  BarController
)

// Пропсы компонента
interface Props {
  type: 'line' | 'bar' | 'doughnut' | 'pie'
  data: any
  options?: any
  width?: number
  height?: number
  responsive?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  width: 400,
  height: 200,
  responsive: true,
  options: () => ({})
})

// Реактивные данные
const chartId = ref(`chart-${Math.random().toString(36).substr(2, 9)}`)
const chartInstance = ref<ChartJS | null>(null)

// Вычисляемые свойства
const chartOptions = computed(() => ({
  responsive: props.responsive,
  maintainAspectRatio: false,
  animation: {
    duration: 1000,
    easing: 'easeInOutQuart',
  },
  plugins: {
    legend: {
      position: 'top' as const,
    },
    tooltip: {
      mode: 'index' as const,
      intersect: false,
    },
  },
  scales: props.type === 'doughnut' || props.type === 'pie' ? undefined : {
    x: {
      display: true,
      grid: {
        display: false,
      },
    },
    y: {
      display: true,
      beginAtZero: true,
      grid: {
        color: 'rgba(0, 0, 0, 0.1)',
      },
    },
  },
  ...props.options,
}))

// Методы
function createChart() {
  if (chartInstance.value) {
    chartInstance.value.destroy()
    chartInstance.value = null
  }

  const canvas = document.getElementById(chartId.value) as HTMLCanvasElement
  if (!canvas) return

  // Проверяем, что данные валидны перед созданием диаграммы
  if (!props.data || !props.data.datasets || props.data.datasets.length === 0) {
    console.warn('Нет данных для создания диаграммы')
    return
  }

  try {
    chartInstance.value = new ChartJS(canvas, {
      type: props.type,
      data: props.data,
      options: chartOptions.value,
    })
  } catch (error) {
    console.error('Ошибка создания диаграммы:', error)
    chartInstance.value = null
  }
}

function updateChart() {
  if (!chartInstance.value) return

  try {
    // Проверяем, что данные валидны
    if (!props.data || !props.data.datasets || props.data.datasets.length === 0) {
      return
    }

    chartInstance.value.data = props.data
    chartInstance.value.options = chartOptions.value
    chartInstance.value.update('none') // Отключаем анимацию при обновлении
  } catch (error) {
    console.error('Ошибка обновления диаграммы:', error)
    // Пересоздаем диаграмму при ошибке
    createChart()
  }
}

// Lifecycle hooks
onMounted(() => {
  // Добавляем небольшую задержку для стабильности DOM
  setTimeout(() => {
    createChart()
  }, 200)
})

onUnmounted(() => {
  if (chartInstance.value) {
    chartInstance.value.destroy()
  }
})

// Watchers
watch(
  () => props.data,
  (newData) => {
    // Добавляем небольшую задержку для стабильности
    setTimeout(() => {
      if (newData && newData.datasets && newData.datasets.length > 0) {
        updateChart()
      }
    }, 100)
  },
  { deep: true }
)

watch(
  () => props.options,
  (newOptions) => {
    if (newOptions && chartInstance.value) {
      setTimeout(() => {
        updateChart()
      }, 100)
    }
  },
  { deep: true }
)

// Экспорт методов для родительского компонента
defineExpose({
  chart: chartInstance,
  updateChart,
  createChart,
})
</script>

<style scoped>
.chart-container {
  position: relative;
  width: 100%;
  height: 100%;
}

canvas {
  max-width: 100%;
  height: auto;
}
</style> 