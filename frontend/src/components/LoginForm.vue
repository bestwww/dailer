<template>
  <div class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center px-4">
    <div class="max-w-md w-full space-y-8">
      <!-- Заголовок -->
      <div class="text-center">
        <el-icon class="mx-auto h-12 w-12 text-indigo-600" size="48">
          <Lock />
        </el-icon>
        <h2 class="mt-6 text-3xl font-extrabold text-gray-900">
          Вход в систему
        </h2>
        <p class="mt-2 text-sm text-gray-600">
          Система автодозвона
        </p>
      </div>

      <!-- Форма входа -->
      <div class="bg-white py-8 px-6 shadow-lg rounded-lg">
        <el-form
          ref="loginFormRef"
          :model="loginForm"
          :rules="loginRules"
          label-position="top"
          @submit.prevent="handleLogin"
        >
          <el-form-item label="Логин или Email" prop="identifier">
            <el-input
              v-model="loginForm.identifier"
              :prefix-icon="User"
              placeholder="Введите логин или email"
              size="large"
              :disabled="loading"
              @keyup.enter="handleLogin"
            />
          </el-form-item>

          <el-form-item label="Пароль" prop="password">
            <el-input
              v-model="loginForm.password"
              type="password"
              :prefix-icon="Lock"
              placeholder="Введите пароль"
              size="large"
              :disabled="loading"
              show-password
              @keyup.enter="handleLogin"
            />
          </el-form-item>

          <!-- Сообщение об ошибке -->
          <el-alert
            v-if="errorMessage"
            :title="errorMessage"
            type="error"
            :closable="false"
            class="mb-4"
          />

          <!-- Кнопка входа -->
          <el-form-item>
            <el-button
              type="primary"
              size="large"
              :loading="loading"
              @click="handleLogin"
              class="w-full"
            >
              <span v-if="loading">Вход...</span>
              <span v-else>Войти</span>
            </el-button>
          </el-form-item>

          <!-- Дополнительная информация -->
          <div class="text-center text-sm text-gray-500">
            <p>Забыли пароль? Обратитесь к администратору</p>
            <p class="mt-2">
              Учетные данные по умолчанию: admin / admin123
            </p>
          </div>
        </el-form>
      </div>

      <!-- Системная информация -->
      <div class="text-center">
        <p class="text-xs text-gray-500">
          Dialer System v1.0 © 2024
        </p>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage, type FormInstance, type FormRules } from 'element-plus'
import { Lock, User } from '@element-plus/icons-vue'
import { useAuthStore } from '@/stores/auth'

// Роутер и store
const router = useRouter()
const authStore = useAuthStore()

// Реактивные данные
const loginFormRef = ref<FormInstance>()
const loading = ref(false)
const errorMessage = ref('')

// Форма входа
const loginForm = reactive({
  identifier: '',
  password: ''
})

// Правила валидации
const loginRules: FormRules = {
  identifier: [
    { required: true, message: 'Пожалуйста, введите логин или email', trigger: 'blur' },
    { min: 3, message: 'Логин должен содержать минимум 3 символа', trigger: 'blur' }
  ],
  password: [
    { required: true, message: 'Пожалуйста, введите пароль', trigger: 'blur' },
    { min: 6, message: 'Пароль должен содержать минимум 6 символов', trigger: 'blur' }
  ]
}

/**
 * Обработчик входа в систему
 */
async function handleLogin(): Promise<void> {
  if (!loginFormRef.value) return

  try {
    // Валидация формы
    await loginFormRef.value.validate()
    
    loading.value = true
    errorMessage.value = ''

    // Попытка входа
    const success = await authStore.login(loginForm.identifier, loginForm.password)
    
    if (success) {
      ElMessage.success('Вход выполнен успешно!')
      
      // Получаем redirect путь из query параметров или используем главную страницу
      const redirectPath = (router.currentRoute.value.query.redirect as string) || '/'
      
      // Ждем следующий tick для обновления состояния
      await nextTick()
      
      // Используем replace вместо push для более плавного перехода
      await router.replace(redirectPath)
    } else {
      errorMessage.value = authStore.error || 'Неверные учетные данные'
    }
  } catch (error) {
    console.error('Ошибка входа:', error)
    errorMessage.value = 'Ошибка валидации формы'
  } finally {
    loading.value = false
  }
}

/**
 * Проверка, если пользователь уже авторизован
 */
onMounted(() => {
  if (authStore.isAuthenticated) {
    router.push('/')
  }
})
</script>

<style scoped>
/* Дополнительные стили для анимации */
.bg-gradient-to-br {
  background-image: linear-gradient(to bottom right, var(--tw-gradient-stops));
}

.from-blue-50 {
  --tw-gradient-from: #eff6ff;
  --tw-gradient-stops: var(--tw-gradient-from), var(--tw-gradient-to, rgba(239, 246, 255, 0));
}

.to-indigo-100 {
  --tw-gradient-to: #e0e7ff;
}

/* Анимация для формы */
.bg-white {
  transition: all 0.3s ease;
}

.bg-white:hover {
  transform: translateY(-2px);
  box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
}

/* Стили для кнопки */
.el-button.w-full {
  width: 100%;
}

/* Responsive дизайн */
@media (max-width: 640px) {
  .max-w-md {
    max-width: 100%;
  }
  
  .bg-white {
    margin: 1rem;
  }
}
</style> 