<template>
  <div class="space-y-6">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Настройки</h1>
      <p class="mt-1 text-sm text-gray-500">
        Конфигурация системы автодозвона
      </p>
    </div>

    <!-- Заглушка контента -->
    <div class="card text-center py-12">
      <el-icon size="64" class="text-gray-400 mb-4">
        <Setting />
      </el-icon>
      <h3 class="text-lg font-medium text-gray-900 mb-2">Страница в разработке</h3>
      <p class="text-gray-500">Скоро здесь будут настройки системы</p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { Setting } from '@element-plus/icons-vue'
</script> 