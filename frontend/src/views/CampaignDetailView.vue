<template>
  <div class="space-y-6">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Детали кампании</h1>
      <p class="mt-1 text-sm text-gray-500">
        Подробная информация о кампании ID: {{ id }}
      </p>
    </div>

    <!-- Заглушка контента -->
    <div class="card text-center py-12">
      <el-icon size="64" class="text-gray-400 mb-4">
        <Document />
      </el-icon>
      <h3 class="text-lg font-medium text-gray-900 mb-2">Страница в разработке</h3>
      <p class="text-gray-500">Скоро здесь будут детали кампании</p>
      <el-button class="mt-4" @click="goBack">
        Вернуться к кампаниям
      </el-button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router'
import { Document } from '@element-plus/icons-vue'

interface Props {
  id: string
}

defineProps<Props>()

const router = useRouter()

function goBack(): void {
  router.push('/campaigns')
}
</script> 