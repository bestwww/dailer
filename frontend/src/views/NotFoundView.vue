<template>
  <div class="min-h-96 flex items-center justify-center">
    <div class="text-center">
      <el-icon size="100" class="text-gray-400 mb-6">
        <WarnTriangleFilled />
      </el-icon>
      <h1 class="text-4xl font-bold text-gray-900 mb-4">404</h1>
      <h2 class="text-xl font-medium text-gray-700 mb-6">Страница не найдена</h2>
      <p class="text-gray-500 mb-8">
        Запрашиваемая страница не существует или была перемещена
      </p>
      <el-button type="primary" @click="goHome">
        Вернуться на главную
      </el-button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router'
import { WarnTriangleFilled } from '@element-plus/icons-vue'

const router = useRouter()

function goHome(): void {
  router.push('/')
}
</script> 