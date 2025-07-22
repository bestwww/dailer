import { fileURLToPath, URL } from 'node:url'

import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueDevTools from 'vite-plugin-vue-devtools'
import tailwindcss from '@tailwindcss/vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    tailwindcss(),
    vue(),
    vueDevTools(),
  ],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url))
    },
  },
  build: {
    // Оптимизация сборки
    rollupOptions: {
      output: {
        // Разделяем код на отдельные чанки для лучшей производительности
        manualChunks: {
          // Vue экосистема
          'vue-vendor': ['vue', 'vue-router', 'pinia'],
          
          // UI библиотеки
          'ui-vendor': ['element-plus', '@element-plus/icons-vue', '@heroicons/vue'],
          
          // Графики и визуализация
          'chart-vendor': ['chart.js', 'vue-chartjs'],
          
          // Утилиты и HTTP
          'utils-vendor': ['axios', 'socket.io-client', '@vueuse/core']
        }
      }
    },
    // Увеличиваем лимит предупреждения до 1000 kB
    chunkSizeWarningLimit: 1000,
    
    // Минификация кода (упрощенная конфигурация для совместимости)
    minify: 'terser'
  }
})
