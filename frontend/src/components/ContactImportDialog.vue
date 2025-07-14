<template>
  <el-dialog
    v-model="dialogVisible"
    title="Массовый импорт контактов"
    :before-close="handleClose"
    width="700px"
  >
    <div class="space-y-6">
      <!-- Выбор кампании -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">
          Кампания для импорта
        </label>
        <el-select
          v-model="selectedCampaignId"
          placeholder="Выберите кампанию"
          style="width: 100%"
          :disabled="loading"
        >
          <el-option
            v-for="campaign in campaigns"
            :key="campaign.id"
            :label="campaign.name"
            :value="campaign.id"
          />
        </el-select>
      </div>

      <!-- Способы импорта -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">
          Способ импорта
        </label>
        <el-radio-group v-model="importMethod" :disabled="loading">
          <el-radio value="manual">Ручной ввод</el-radio>
          <el-radio value="csv">Из CSV файла</el-radio>
        </el-radio-group>
      </div>

      <!-- Ручной ввод -->
      <div v-if="importMethod === 'manual'">
        <label class="block text-sm font-medium text-gray-700 mb-2">
          Номера телефонов (по одному на строку)
        </label>
        <el-input
          v-model="manualInput"
          type="textarea"
          :rows="8"
          placeholder="Введите номера телефонов, по одному на строку:
+79001234567
+79007654321
89123456789"
          :disabled="loading"
        />
        <p class="mt-2 text-sm text-gray-500">
          Поддерживаются форматы: +7, 8, 7. Система автоматически нормализует номера.
        </p>
      </div>

      <!-- Загрузка CSV -->
      <div v-if="importMethod === 'csv'">
        <label class="block text-sm font-medium text-gray-700 mb-2">
          CSV файл
        </label>
        <el-upload
          ref="uploadRef"
          :auto-upload="false"
          :show-file-list="true"
          :limit="1"
          accept=".csv,.txt"
          :disabled="loading"
          @change="handleFileChange"
          :before-remove="handleFileRemove"
        >
          <template #trigger>
            <el-button :icon="Upload" :disabled="loading">
              Выбрать CSV файл
            </el-button>
          </template>
          <template #tip>
            <div class="el-upload__tip">
              CSV файл должен содержать номера телефонов в первом столбце
            </div>
          </template>
        </el-upload>

        <!-- Превью CSV -->
        <div v-if="csvPreview.length > 0" class="mt-4">
          <h4 class="text-sm font-medium text-gray-700 mb-2">Превью данных:</h4>
          <div class="border rounded-md p-3 bg-gray-50 max-h-40 overflow-y-auto">
            <div v-for="(row, index) in csvPreview.slice(0, 10)" :key="index" class="text-sm">
              {{ row.phone }} {{ row.name ? `- ${row.name}` : '' }}
            </div>
            <div v-if="csvPreview.length > 10" class="text-sm text-gray-500 mt-2">
              ... и еще {{ csvPreview.length - 10 }} записей
            </div>
          </div>
        </div>
      </div>

      <!-- Статистика импорта -->
      <div v-if="importResult" class="border rounded-md p-4 bg-blue-50">
        <h4 class="font-medium text-blue-900 mb-2">Результат импорта:</h4>
        <div class="text-sm space-y-1">
          <div class="text-green-600">✅ Успешно добавлено: {{ importResult.imported }}</div>
          <div v-if="importResult.failed > 0" class="text-red-600">
            ❌ Ошибок: {{ importResult.failed }}
          </div>
          <div v-if="importResult.errors.length > 0" class="mt-2">
            <details>
              <summary class="cursor-pointer text-red-600">Показать ошибки</summary>
              <div class="mt-2 max-h-32 overflow-y-auto">
                <div v-for="error in importResult.errors" :key="error" class="text-xs text-red-500">
                  {{ error }}
                </div>
              </div>
            </details>
          </div>
        </div>
      </div>
    </div>

    <template #footer>
      <div class="dialog-footer">
        <el-button @click="handleClose" :disabled="loading">
          {{ importResult ? 'Закрыть' : 'Отмена' }}
        </el-button>
        <el-button
          v-if="!importResult"
          type="primary"
          :loading="loading"
          :disabled="!canImport"
          @click="handleImport"
        >
          Импортировать контакты
        </el-button>
      </div>
    </template>
  </el-dialog>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { ElMessage, type UploadFile, type UploadFiles, type UploadInstance } from 'element-plus'
import { Upload } from '@element-plus/icons-vue'
import type { Campaign, CreateContactRequest } from '@/types'
import { apiService } from '@/services/api'

// Пропсы
interface Props {
  visible: boolean
  campaigns: Campaign[]
}

const props = withDefaults(defineProps<Props>(), {
  visible: false,
  campaigns: () => []
})

// Эмиты
const emit = defineEmits<{
  'update:visible': [visible: boolean]
  'success': []
}>()

// Реактивные переменные
const uploadRef = ref<UploadInstance>()
const loading = ref(false)
const selectedCampaignId = ref<number | null>(null)
const importMethod = ref<'manual' | 'csv'>('manual')
const manualInput = ref('')
const csvPreview = ref<Array<{ phone: string; name?: string }>>([])
const importResult = ref<{ imported: number; failed: number; errors: string[] } | null>(null)

// Вычисляемые свойства
const dialogVisible = computed({
  get: () => props.visible,
  set: (value) => emit('update:visible', value)
})

const canImport = computed(() => {
  if (!selectedCampaignId.value) return false
  
  if (importMethod.value === 'manual') {
    return manualInput.value.trim().length > 0
  } else {
    return csvPreview.value.length > 0
  }
})

// Методы
function handleClose(): void {
  if (!loading.value) {
    dialogVisible.value = false
    resetForm()
  }
}

function resetForm(): void {
  selectedCampaignId.value = null
  importMethod.value = 'manual'
  manualInput.value = ''
  csvPreview.value = []
  importResult.value = null
  uploadRef.value?.clearFiles()
}

function handleFileChange(file: UploadFile, _files: UploadFiles): void {
  if (file.raw) {
    parseCSVFile(file.raw)
  }
}

function handleFileRemove(): void {
  csvPreview.value = []
}

async function parseCSVFile(file: File): Promise<void> {
  try {
    const text = await file.text()
    const lines = text.split('\n').filter(line => line.trim())
    
    csvPreview.value = lines.map(line => {
      const columns = line.split(',').map(col => col.trim().replace(/['"]/g, ''))
      const phone = columns[0]
      const name = columns[1] || undefined
      
      return { phone, name }
    }).filter(item => item.phone)
    
  } catch (error) {
    console.error('Ошибка парсинга CSV:', error)
    ElMessage.error('Ошибка чтения файла')
  }
}

function parseManualInput(): Array<{ phone: string; name?: string }> {
  return manualInput.value
    .split('\n')
    .map(line => line.trim())
    .filter(line => line.length > 0)
    .map(line => ({ phone: line }))
}

async function handleImport(): Promise<void> {
  if (!selectedCampaignId.value) {
    ElMessage.error('Выберите кампанию')
    return
  }

  try {
    loading.value = true
    
    // Подготавливаем данные для импорта
    const contactsData = importMethod.value === 'manual' 
      ? parseManualInput()
      : csvPreview.value

    if (contactsData.length === 0) {
      ElMessage.error('Нет данных для импорта')
      return
    }

    // Преобразуем в формат API
    const contacts: CreateContactRequest[] = contactsData.map(item => ({
      campaignId: selectedCampaignId.value!,
      phoneNumber: item.phone,
      firstName: item.name || undefined
    }))

    // Выполняем импорт
    const response = await apiService.importContacts(selectedCampaignId.value, contacts)
    
    importResult.value = response.data
    
    if (response.data.imported > 0) {
      ElMessage.success(`Успешно импортировано ${response.data.imported} контактов`)
      emit('success')
    }
    
    if (response.data.failed > 0) {
      ElMessage.warning(`${response.data.failed} контактов не удалось импортировать`)
    }

  } catch (error) {
    console.error('Ошибка импорта:', error)
    ElMessage.error('Ошибка при импорте контактов')
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.dialog-footer {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
}
</style> 