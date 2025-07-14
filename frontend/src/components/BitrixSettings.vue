<template>
  <div class="bitrix-settings">
    <!-- Заголовок раздела -->
    <div class="mb-6">
      <h2 class="text-xl font-semibold text-gray-900 mb-2">
        Интеграция с Битрикс24
      </h2>
      <p class="text-gray-600">
        Настройте подключение к Битрикс24 для автоматического создания лидов
      </p>
    </div>

    <!-- Статус подключения -->
    <el-card class="mb-6">
      <template #header>
        <div class="flex items-center justify-between">
          <span class="text-lg font-medium">Статус подключения</span>
          <el-button 
            type="primary" 
            size="small" 
            @click="checkConnection"
            :loading="checking"
          >
            Проверить подключение
          </el-button>
        </div>
      </template>

      <div class="space-y-4">
        <!-- Индикатор состояния -->
        <div class="flex items-center space-x-3">
          <div 
            :class="[
              'w-3 h-3 rounded-full',
              connectionStatus.isConnected ? 'bg-green-500' : 'bg-red-500'
            ]"
          ></div>
          <span 
            :class="[
              'font-medium',
              connectionStatus.isConnected ? 'text-green-700' : 'text-red-700'
            ]"
          >
            {{ connectionStatus.isConnected ? 'Подключено' : 'Не подключено' }}
          </span>
        </div>

        <!-- Детальная информация -->
        <div class="grid grid-cols-2 gap-4 text-sm">
          <div class="space-y-2">
            <div class="flex justify-between">
              <span class="text-gray-600">Домен:</span>
              <span class="font-medium">{{ connectionStatus.domain || 'Не указан' }}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-gray-600">Конфигурация:</span>
              <el-tag 
                :type="connectionStatus.isConfigured ? 'success' : 'danger'"
                size="small"
              >
                {{ connectionStatus.isConfigured ? 'Настроено' : 'Не настроено' }}
              </el-tag>
            </div>
          </div>
          <div class="space-y-2">
            <div class="flex justify-between">
              <span class="text-gray-600">Токены:</span>
              <el-tag 
                :type="connectionStatus.hasTokens ? 'success' : 'warning'"
                size="small"
              >
                {{ connectionStatus.hasTokens ? 'Получены' : 'Отсутствуют' }}
              </el-tag>
            </div>
            <div class="flex justify-between">
              <span class="text-gray-600">Действительность:</span>
              <el-tag 
                :type="connectionStatus.isTokenValid ? 'success' : 'danger'"
                size="small"
              >
                {{ connectionStatus.isTokenValid ? 'Действительны' : 'Недействительны' }}
              </el-tag>
            </div>
          </div>
        </div>

        <!-- Время истечения токена -->
        <div v-if="connectionStatus.expiresAt" class="text-sm text-gray-600">
          Токен истекает: {{ formatDate(connectionStatus.expiresAt) }}
        </div>

        <!-- Действия -->
        <div class="flex space-x-3 pt-2">
          <el-button 
            v-if="!connectionStatus.isConnected"
            type="primary"
            @click="showConfigDialog = true"
          >
            Настроить подключение
          </el-button>
          <el-button 
            v-if="connectionStatus.isConfigured && !connectionStatus.hasTokens"
            type="warning"
            @click="authorize"
          >
            Авторизоваться
          </el-button>
          <el-button 
            v-if="connectionStatus.hasTokens"
            type="danger"
            @click="disconnect"
            :loading="disconnecting"
          >
            Отключить
          </el-button>
        </div>
      </div>
    </el-card>

    <!-- Статистика лидов -->
    <el-card v-if="connectionStatus.isConnected" class="mb-6">
      <template #header>
        <span class="text-lg font-medium">Статистика лидов</span>
      </template>

      <div class="grid grid-cols-3 gap-4 text-center">
        <div class="p-4 bg-blue-50 rounded-lg">
          <div class="text-2xl font-bold text-blue-600">{{ leadsStats.today }}</div>
          <div class="text-sm text-gray-600">Сегодня</div>
        </div>
        <div class="p-4 bg-green-50 rounded-lg">
          <div class="text-2xl font-bold text-green-600">{{ leadsStats.thisWeek }}</div>
          <div class="text-sm text-gray-600">За неделю</div>
        </div>
        <div class="p-4 bg-purple-50 rounded-lg">
          <div class="text-2xl font-bold text-purple-600">{{ leadsStats.total }}</div>
          <div class="text-sm text-gray-600">Всего</div>
        </div>
      </div>
    </el-card>

    <!-- Последние лиды -->
    <el-card v-if="connectionStatus.isConnected">
      <template #header>
        <div class="flex items-center justify-between">
          <span class="text-lg font-medium">Последние лиды</span>
          <el-button 
            size="small" 
            @click="loadRecentLeads"
            :loading="loadingLeads"
          >
            Обновить
          </el-button>
        </div>
      </template>

      <el-table 
        :data="recentLeads" 
        v-loading="loadingLeads"
        stripe
        style="width: 100%"
      >
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="title" label="Название" />
        <el-table-column prop="name" label="Имя" />
        <el-table-column prop="phone" label="Телефон" width="150" />
        <el-table-column prop="createdTime" label="Создан" width="180">
          <template #default="{ row }">
            {{ formatDate(row.createdTime) }}
          </template>
        </el-table-column>
        <el-table-column label="Действия" width="100">
          <template #default="{ row }">
            <el-button 
              size="small" 
              type="primary" 
              link
              @click="openInBitrix(row.id)"
            >
              Открыть
            </el-button>
          </template>
        </el-table-column>
      </el-table>

      <div v-if="!recentLeads.length && !loadingLeads" class="text-center py-8 text-gray-500">
        Лиды не найдены
      </div>
    </el-card>

    <!-- Диалог настройки -->
    <el-dialog 
      v-model="showConfigDialog"
      title="Настройка Битрикс24"
      width="600px"
      :close-on-click-modal="false"
    >
      <el-form 
        :model="configForm" 
        :rules="configRules"
        ref="configFormRef"
        label-width="140px"
      >
        <el-form-item label="Домен Битрикс24" prop="domain">
          <el-input 
            v-model="configForm.domain"
            placeholder="your-domain.bitrix24.ru"
            clearable
          />
          <div class="text-sm text-gray-600 mt-1">
            Без https:// и завершающего слеша
          </div>
        </el-form-item>

        <el-form-item label="Client ID" prop="clientId">
          <el-input 
            v-model="configForm.clientId"
            placeholder="Идентификатор приложения"
            clearable
          />
        </el-form-item>

        <el-form-item label="Client Secret" prop="clientSecret">
          <el-input 
            v-model="configForm.clientSecret"
            type="password"
            placeholder="Секретный ключ приложения"
            show-password
            clearable
          />
        </el-form-item>

        <el-form-item label="Redirect URI" prop="redirectUri">
          <el-input 
            v-model="configForm.redirectUri"
            placeholder="http://localhost:3000/api/bitrix/callback"
            clearable
          />
          <div class="text-sm text-gray-600 mt-1">
            URL для обратного вызова после авторизации
          </div>
        </el-form-item>
      </el-form>

      <template #footer>
        <span class="dialog-footer">
          <el-button @click="showConfigDialog = false">
            Отмена
          </el-button>
          <el-button 
            type="primary" 
            @click="saveConfig"
            :loading="saving"
          >
            Сохранить и авторизоваться
          </el-button>
        </span>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, ElMessageBox, type FormInstance } from 'element-plus'
import { apiService as apiClient } from '@/services/api'

// Реактивные данные
const checking = ref(false)
const disconnecting = ref(false)
const loadingLeads = ref(false)
const saving = ref(false)
const showConfigDialog = ref(false)

// Статус подключения
const connectionStatus = reactive({
  isConfigured: false,
  hasTokens: false,
  isTokenValid: false,
  isConnected: false,
  domain: '',
  expiresAt: null as string | null,
})

// Статистика лидов
const leadsStats = reactive({
  today: 0,
  thisWeek: 0,
  total: 0,
})

// Последние лиды
const recentLeads = ref<any[]>([])

// Форма конфигурации
const configForm = reactive({
  domain: '',
  clientId: '',
  clientSecret: '',
  redirectUri: 'http://localhost:3000/api/bitrix/callback',
})

const configFormRef = ref<FormInstance>()

// Правила валидации
const configRules = {
  domain: [
    { required: true, message: 'Укажите домен Битрикс24', trigger: 'blur' },
    { pattern: /^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/, message: 'Некорректный формат домена', trigger: 'blur' }
  ],
  clientId: [
    { required: true, message: 'Укажите Client ID', trigger: 'blur' }
  ],
  clientSecret: [
    { required: true, message: 'Укажите Client Secret', trigger: 'blur' }
  ],
  redirectUri: [
    { required: true, message: 'Укажите Redirect URI', trigger: 'blur' },
    { type: 'url', message: 'Некорректный формат URL', trigger: 'blur' }
  ]
}

/**
 * Загрузка статуса подключения
 */
async function loadConnectionStatus() {
  try {
    const response = await apiClient.getBitrixStatus()
    if (response.success) {
      Object.assign(connectionStatus, response.data)
    }
  } catch (error: any) {
    console.error('Ошибка загрузки статуса Bitrix24:', error)
    ElMessage.error('Ошибка загрузки статуса подключения')
  }
}

/**
 * Проверка подключения
 */
async function checkConnection() {
  checking.value = true
  try {
    const response = await apiClient.testBitrixConnection()
    if (response.success) {
      ElMessage.success(response.data.message)
      await loadConnectionStatus()
    } else {
      ElMessage.error(response.error)
    }
  } catch (error: any) {
    console.error('Ошибка проверки подключения:', error)
    ElMessage.error('Ошибка проверки подключения')
  } finally {
    checking.value = false
  }
}

/**
 * Сохранение конфигурации
 */
async function saveConfig() {
  if (!configFormRef.value) return

  try {
    await configFormRef.value.validate()
    saving.value = true

    const response = await apiClient.updateBitrixConfig(configForm)
    
    if (response.success) {
      ElMessage.success('Конфигурация сохранена')
      showConfigDialog.value = false
      
      // Открываем страницу авторизации
      if (response.data.authUrl) {
        window.open(response.data.authUrl, '_blank')
      }
      
      await loadConnectionStatus()
    } else {
      ElMessage.error(response.error)
    }
  } catch (error: any) {
    console.error('Ошибка сохранения конфигурации:', error)
    ElMessage.error('Ошибка сохранения конфигурации')
  } finally {
    saving.value = false
  }
}

/**
 * Авторизация в Битрикс24
 */
async function authorize() {
  try {
    const response = await apiClient.getBitrixAuthUrl()
    if (response.success && response.data.authUrl) {
      window.open(response.data.authUrl, '_blank')
    } else {
      ElMessage.error('Ошибка получения URL авторизации')
    }
  } catch (error: any) {
    console.error('Ошибка авторизации:', error)
    ElMessage.error('Ошибка авторизации')
  }
}

/**
 * Отключение от Битрикс24
 */
async function disconnect() {
  try {
    await ElMessageBox.confirm(
      'Вы уверены, что хотите отключиться от Битрикс24? Это прекратит создание лидов.',
      'Подтверждение отключения',
      {
        confirmButtonText: 'Отключить',
        cancelButtonText: 'Отмена',
        type: 'warning',
      }
    )

    disconnecting.value = true
    const response = await apiClient.disconnectBitrix()
    
    if (response.success) {
      ElMessage.success('Отключение выполнено')
      await loadConnectionStatus()
    } else {
      ElMessage.error(response.error)
    }
  } catch (error: any) {
    if (error !== 'cancel') {
      console.error('Ошибка отключения:', error)
      ElMessage.error('Ошибка отключения')
    }
  } finally {
    disconnecting.value = false
  }
}

/**
 * Загрузка последних лидов
 */
async function loadRecentLeads() {
  if (!connectionStatus.isConnected) return

  loadingLeads.value = true
  try {
    const response = await apiClient.getBitrixLeads({ limit: 10 })
    
    if (response.success) {
      recentLeads.value = response.data
    }
  } catch (error: any) {
    console.error('Ошибка загрузки лидов:', error)
    ElMessage.error('Ошибка загрузки лидов')
  } finally {
    loadingLeads.value = false
  }
}

/**
 * Загрузка статистики лидов
 */
async function loadLeadsStats() {
  if (!connectionStatus.isConnected) return

  try {
    // Здесь можно добавить вызов API для получения статистики
    // Пока оставляем заглушку
    leadsStats.today = 5
    leadsStats.thisWeek = 23
    leadsStats.total = 156
  } catch (error: any) {
    console.error('Ошибка загрузки статистики:', error)
  }
}

/**
 * Открытие лида в Битрикс24
 */
function openInBitrix(leadId: number) {
  if (connectionStatus.domain) {
    const url = `https://${connectionStatus.domain}/crm/lead/details/${leadId}/`
    window.open(url, '_blank')
  }
}

/**
 * Форматирование даты
 */
function formatDate(dateString: string): string {
  if (!dateString) return ''
  
  const date = new Date(dateString)
  
  // Проверяем, что дата валидна
  if (isNaN(date.getTime())) {
    return ''
  }
  
  return date.toLocaleString('ru-RU')
}

// Загрузка данных при монтировании
onMounted(async () => {
  await loadConnectionStatus()
  if (connectionStatus.isConnected) {
    await Promise.all([
      loadRecentLeads(),
      loadLeadsStats()
    ])
  }
})
</script>

<style scoped>
.bitrix-settings {
  max-width: 1000px;
  margin: 0 auto;
}

.el-card {
  margin-bottom: 0;
}

.el-card :deep(.el-card__header) {
  background-color: #f8f9fa;
  border-bottom: 1px solid #e9ecef;
}

.dialog-footer {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
}
</style> 