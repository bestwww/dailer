<template>
  <div>
    <el-form
      ref="formRef"
      :model="formData"
      :rules="formRules"
      label-width="120px"
      label-position="top"
    >
      <!-- Название кампании -->
      <el-form-item label="Название кампании" prop="name">
        <el-input
          v-model="formData.name"
          placeholder="Введите название кампании"
          maxlength="255"
          show-word-limit
        />
      </el-form-item>

      <!-- Описание -->
      <el-form-item label="Описание" prop="description">
        <el-input
          v-model="formData.description"
          type="textarea"
          :rows="3"
          placeholder="Введите описание кампании (необязательно)"
          maxlength="500"
          show-word-limit
        />
      </el-form-item>

      <!-- Аудиофайл -->
      <el-form-item label="Аудиоприветствие" prop="audioFilePath">
        <div class="space-y-3">
          <!-- Загрузка файла -->
          <el-upload
            ref="uploadRef"
            :action="uploadUrl"
            :headers="uploadHeaders"
            :before-upload="beforeUpload"
            :on-success="handleUploadSuccess"
            :on-error="handleUploadError"
            :on-change="handleFileChange"
            :file-list="fileList"
            accept=".mp3,.wav,.m4a"
            :limit="1"
            :auto-upload="false"
          >
            <el-button :icon="Upload" type="primary">
              Выбрать аудиофайл
            </el-button>
            <template #tip>
              <div class="text-sm text-gray-500">
                Поддерживаются форматы: MP3, WAV, M4A. Максимальный размер: 10MB
              </div>
            </template>
          </el-upload>

          <!-- Текущий файл (при редактировании) -->
          <div v-if="currentAudioFile" class="flex items-center space-x-3 p-3 bg-gray-50 rounded-lg">
            <el-icon class="text-primary-600"><VideoPlay /></el-icon>
            <div class="flex-1">
              <div class="text-sm font-medium">Текущий файл</div>
              <div class="text-xs text-gray-500">{{ currentAudioFileName || currentAudioFile }}</div>
            </div>
            <div class="flex items-center space-x-2">
              <el-button size="small" :icon="Delete" @click="removeCurrentFile">
                Удалить
              </el-button>
            </div>
          </div>

          <!-- Выбранный файл для загрузки -->
          <div v-if="fileList.length > 0" class="flex items-center space-x-3 p-3 bg-blue-50 rounded-lg">
            <el-icon class="text-blue-600"><Upload /></el-icon>
            <div class="flex-1">
              <div class="text-sm font-medium">Выбранный файл</div>
              <div class="text-xs text-gray-500">{{ fileList[0].name }}</div>
            </div>
            <div class="flex items-center space-x-2">
              <el-button size="small" :icon="Delete" @click="removeSelectedFile">
                Удалить
              </el-button>
            </div>
          </div>

          <!-- Аудио плеер -->
          <div class="mt-3 p-3  rounded-lg">

            <audio
              ref="audioPlayer"
              class="w-full"
              controls
              preload="metadata"
              crossorigin="anonymous"
            >
              Ваш браузер не поддерживает воспроизведение аудио.
            </audio>
          </div>
        </div>
      </el-form-item>

      <!-- Настройки кампании -->
      <el-form-item label="Дополнительные настройки">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <!-- Максимальное количество одновременных звонков -->
          <el-form-item label="Макс. одновременных звонков" prop="maxConcurrentCalls">
            <el-input-number
              v-model="formData.maxConcurrentCalls"
              :min="1"
              :max="50"
              :step="1"
              placeholder="10"
            />
          </el-form-item>

          <!-- Количество звонков в минуту -->
          <el-form-item label="Звонков в минуту" prop="callsPerMinute">
            <el-input-number
              v-model="formData.callsPerMinute"
              :min="1"
              :max="100"
              :step="1"
              placeholder="20"
            />
          </el-form-item>

          <!-- Количество попыток -->
          <el-form-item label="Попыток дозвона" prop="retryAttempts">
            <el-input-number
              v-model="formData.retryAttempts"
              :min="1"
              :max="5"
              :step="1"
              placeholder="3"
            />
          </el-form-item>

          <!-- Задержка между попытками (секунды) -->
          <el-form-item label="Задержка (сек)" prop="retryDelay">
            <el-input-number
              v-model="formData.retryDelay"
              :min="30"
              :max="3600"
              :step="30"
              placeholder="300"
            />
          </el-form-item>
        </div>
      </el-form-item>

      <!-- Настройки AMD -->
      <el-form-item label="Детектор автоответчика (AMD)">
        <div class="space-y-3">
          <el-switch
            v-model="formData.amdEnabled"
            active-text="Включить AMD"
            inactive-text="Отключить AMD"
          />
          <div v-if="formData.amdEnabled" class="text-sm text-gray-600">
            При обнаружении автоответчика звонок будет автоматически завершен
          </div>
        </div>
      </el-form-item>

      <!-- Интеграция с Битрикс24 -->
      <el-form-item label="Интеграция с Битрикс24">
        <div class="space-y-3">
          <el-switch
            v-model="formData.bitrixIntegrationEnabled"
            active-text="Создавать лиды в Битрикс24"
            inactive-text="Не создавать лиды"
          />
          <div v-if="formData.bitrixIntegrationEnabled" class="text-sm text-gray-600">
            Лиды будут создаваться для контактов, нажавших 1 или 2
          </div>
        </div>
      </el-form-item>

      <!-- Рабочие часы -->
      <el-form-item label="Рабочие часы">
        <div class="grid grid-cols-2 gap-4">
          <el-form-item label="Начало" prop="workingHoursStart">
            <el-time-picker
              v-model="formData.workingHoursStart"
              format="HH:mm"
              placeholder="09:00"
              :clearable="false"
            />
          </el-form-item>
          <el-form-item label="Окончание" prop="workingHoursEnd">
            <el-time-picker
              v-model="formData.workingHoursEnd"
              format="HH:mm"
              placeholder="18:00"
              :clearable="false"
            />
          </el-form-item>
        </div>
        <div class="text-sm text-gray-600">
          Звонки будут осуществляться только в указанные часы
        </div>
      </el-form-item>

      <!-- Временная зона кампании -->
      <el-form-item label="Временная зона" prop="timezone">
        <el-select
          v-model="formData.timezone"
          placeholder="Выберите временную зону"
          style="width: 100%"
        >
          <el-option label="Калининград (UTC+2)" value="Europe/Kaliningrad" />
          <el-option label="Москва (UTC+3)" value="Europe/Moscow" />
          <el-option label="Самара (UTC+4)" value="Europe/Samara" />
          <el-option label="Екатеринбург (UTC+5)" value="Asia/Yekaterinburg" />
          <el-option label="Омск (UTC+6)" value="Asia/Omsk" />
          <el-option label="Красноярск (UTC+7)" value="Asia/Krasnoyarsk" />
          <el-option label="Иркутск (UTC+8)" value="Asia/Irkutsk" />
          <el-option label="Якутск (UTC+9)" value="Asia/Yakutsk" />
          <el-option label="Владивосток (UTC+10)" value="Asia/Vladivostok" />
          <el-option label="Магадан (UTC+11)" value="Asia/Magadan" />
          <el-option label="Петропавловск-Камчатский (UTC+12)" value="Asia/Kamchatka" />
        </el-select>
        <div class="text-sm text-gray-600">
          Временная зона используется для расчета рабочих часов и планирования звонков
        </div>
      </el-form-item>
    </el-form>

    <!-- Кнопки действий -->
    <div class="flex justify-end space-x-3 mt-6 pt-6 border-t border-gray-200">
      <el-button @click="handleCancel">
        Отмена
      </el-button>
      <el-button 
        type="primary" 
        @click="handleSubmit"
        :loading="loading"
      >
        {{ isEditing ? 'Сохранить' : 'Создать кампанию' }}
      </el-button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import { Upload, Delete } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import type { FormInstance, FormRules, UploadProps, UploadFile } from 'element-plus'
import type { Campaign } from '@/types'
import { apiService } from '@/services/api'

// Props
interface Props {
  campaign?: Campaign | null
  loading?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  campaign: null,
  loading: false
})

// Emits
const emit = defineEmits<{
  submit: [data: Partial<Campaign>]
  cancel: []
}>()

// Ссылки на компоненты
const formRef = ref<FormInstance>()
const uploadRef = ref()
const audioPlayer = ref<HTMLAudioElement>()

// Реактивные данные
const fileList = ref<UploadFile[]>([])
const currentAudioFile = ref<string>('')
const currentAudioFileName = ref<string>('')
const currentAudioUrl = ref<string>('')
const uploadedFilePath = ref<string>('')

// Утилитарные функции для работы с временем
/**
 * Преобразует строку времени в объект Date
 * @param timeString - строка времени в формате "HH:mm"
 * @returns объект Date с установленным временем
 */
function timeStringToDate(timeString: string): Date {
  try {
    const [hours, minutes] = timeString.split(':').map(Number)
    const date = new Date()
    date.setHours(hours, minutes, 0, 0)
    return date
  } catch (error) {
    console.error('Ошибка парсинга времени:', error)
    // Возвращаем значение по умолчанию при ошибке
    const date = new Date()
    date.setHours(9, 0, 0, 0)
    return date
  }
}

/**
 * Преобразует объект Date в строку времени
 * @param date - объект Date или null
 * @returns строка времени в формате "HH:mm" или пустая строка
 */
function dateToTimeString(date: Date | null): string {
  if (!date || !(date instanceof Date) || isNaN(date.getTime())) return ''
  return `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`
}

/**
 * Получает рабочие часы для кампании
 * @param campaign - объект кампании или null
 * @param field - поле для получения ('start' или 'end')
 * @returns объект Date с установленным временем
 */
function getWorkingHours(campaign: Campaign | null, field: 'start' | 'end'): Date {
  // Значения по умолчанию для рабочих часов
  const defaultStart = '09:00'
  const defaultEnd = '18:00'
  
  const defaultValue = field === 'start' ? defaultStart : defaultEnd
  
  if (campaign) {
    // Если в кампании есть настройки рабочих часов, используем их
    // Проверяем разные возможные названия полей (для совместимости)
    const campaignValue = field === 'start' 
      ? (campaign.workTimeStart || campaign.workingHoursStart) 
      : (campaign.workTimeEnd || campaign.workingHoursEnd)
    if (campaignValue && typeof campaignValue === 'string') {
      return timeStringToDate(campaignValue)
    }
  }
  
  // Используем значения по умолчанию
  return timeStringToDate(defaultValue)
}

// Computed свойства
const isEditing = computed(() => !!props.campaign)
const uploadUrl = computed(() => `${import.meta.env.VITE_API_URL}/api/audio/upload`)
const uploadHeaders = computed(() => ({
  'Authorization': 'Bearer token' // TODO: Добавить реальный токен
}))

/**
 * Данные формы создания/редактирования кампании
 * Важно: workingHoursStart и workingHoursEnd используют объекты Date
 * для совместимости с el-time-picker из Element Plus
 */
const formData = ref({
  name: '',                          // Название кампании
  description: '',                   // Описание кампании
  audioFilePath: '',                 // Путь к аудиофайлу
  maxConcurrentCalls: 10,            // Максимальное количество одновременных звонков
  callsPerMinute: 20,                // Количество звонков в минуту
  retryAttempts: 3,                  // Количество попыток дозвона
  retryDelay: 300,                   // Задержка между попытками (в секундах)
  amdEnabled: true,                  // Включить детектор автоответчика
  bitrixIntegrationEnabled: true,    // Включить интеграцию с Битрикс24
  workingHoursStart: timeStringToDate('09:00'),  // Начало рабочего времени (объект Date)
  workingHoursEnd: timeStringToDate('18:00'),    // Конец рабочего времени (объект Date)
  timezone: 'Europe/Moscow'          // Временная зона кампании
})

// Правила валидации
const formRules: FormRules = {
  name: [
    { required: true, message: 'Пожалуйста, введите название кампании', trigger: 'blur' },
    { min: 3, max: 255, message: 'Длина должна быть от 3 до 255 символов', trigger: 'blur' }
  ],
  description: [
    { max: 500, message: 'Описание не должно превышать 500 символов', trigger: 'blur' }
  ],
  maxConcurrentCalls: [
    { required: true, message: 'Укажите максимальное количество одновременных звонков', trigger: 'blur' }
  ],
  callsPerMinute: [
    { required: true, message: 'Укажите количество звонков в минуту', trigger: 'blur' }
  ],
  retryAttempts: [
    { required: true, message: 'Укажите количество попыток', trigger: 'blur' }
  ],
  retryDelay: [
    { required: true, message: 'Укажите задержку между попытками', trigger: 'blur' }
  ],
  workingHoursStart: [
    { required: true, message: 'Укажите время начала работы', trigger: 'blur' },
    { 
      validator: (rule: any, value: any, callback: any) => {
        if (!value || !(value instanceof Date) || isNaN(value.getTime())) {
          callback(new Error('Некорректное время начала работы'))
        } else {
          callback()
        }
      }, 
      trigger: 'blur' 
    }
  ],
  workingHoursEnd: [
    { required: true, message: 'Укажите время окончания работы', trigger: 'blur' },
    { 
      validator: (rule: any, value: any, callback: any) => {
        if (!value || !(value instanceof Date) || isNaN(value.getTime())) {
          callback(new Error('Некорректное время окончания работы'))
        } else if (formData.value.workingHoursStart && value <= formData.value.workingHoursStart) {
          callback(new Error('Время окончания должно быть позже времени начала'))
        } else {
          callback()
        }
      }, 
      trigger: 'blur' 
    }
  ]
}

// Методы загрузки файлов
const beforeUpload: UploadProps['beforeUpload'] = (file) => {
  console.log('🔍 Проверка файла:', file.name)
  
  const isAudio = file.type.startsWith('audio/') || 
    ['mp3', 'wav', 'm4a'].some(ext => file.name.toLowerCase().endsWith(ext))
  
  if (!isAudio) {
    console.log('❌ Файл не является аудиофайлом')
    ElMessage.error('Можно загружать только аудиофайлы!')
    return false
  }
  
  const isLt10M = file.size / 1024 / 1024 < 10
  if (!isLt10M) {
    console.log('❌ Файл слишком большой')
    ElMessage.error('Размер файла не должен превышать 10MB!')
    return false
  }
  
  console.log('✅ Файл прошел проверку')
  // Возвращаем false для предотвращения автоматической загрузки
  return false
}

const handleUploadSuccess = (response: any, file: UploadFile) => {
  uploadedFilePath.value = response.data.filePath
  formData.value.audioFilePath = response.data.filePath
  // Сохраняем оригинальное имя файла
  currentAudioFileName.value = file.name || response.data.originalName || ''
  ElMessage.success('Файл успешно загружен')
}

const handleUploadError = (error: any) => {
  console.error('Ошибка загрузки файла:', error)
  ElMessage.error('Ошибка загрузки файла')
}

const handleFileChange = (file: UploadFile, uploadFileList: UploadFile[]) => {
  console.log('📁 Файл выбран:', file.name)
  
  // Обновляем список файлов
  fileList.value = uploadFileList
  
  // Если файл удален, очищаем данные
  if (uploadFileList.length === 0) {
    formData.value.audioFilePath = ''
    uploadedFilePath.value = ''
    console.log('🗑️ Файл удален из списка')
  }
}

function removeCurrentFile(): void {
  currentAudioFile.value = ''
  currentAudioFileName.value = ''
  formData.value.audioFilePath = ''
  uploadedFilePath.value = ''
  fileList.value = []
  cleanupAudioPlayer()
}

/**
 * Удаление выбранного файла для загрузки
 */
function removeSelectedFile(): void {
  fileList.value = []
  cleanupAudioPlayer()
}



/**
 * Очистка audio player
 */
function cleanupAudioPlayer(): void {
  if (audioPlayer.value) {
    // Останавливаем текущее воспроизведение
    audioPlayer.value.pause()
    audioPlayer.value.currentTime = 0
    
    // Очищаем источник
    audioPlayer.value.src = ''
  }
}

/**
 * Очистка аудио плеера и освобождение ресурсов
 */
function cleanupAudioPlayback(): void {
  console.log('🔇 Очистка аудио плеера')
  currentAudioUrl.value = ''
  
  if (audioPlayer.value) {
    // Освобождаем URL если он был создан через createObjectURL
    if (audioPlayer.value.src.startsWith('blob:')) {
      URL.revokeObjectURL(audioPlayer.value.src)
    }
  }
  
  cleanupAudioPlayer()
}



/**
 * Обработчик отправки формы
 * Валидирует данные, загружает файл (если есть) и отправляет данные
 */
async function handleSubmit(): Promise<void> {
  if (!formRef.value) return
  
  try {
    // Валидируем форму
    await formRef.value.validate()

    // Отладочная информация
    console.log('🔍 DEBUG: Отправка формы кампании')
    console.log('📂 Количество файлов:', fileList.value.length)
    if (fileList.value.length > 0) {
      console.log('📁 Выбранный файл:', fileList.value[0].name)
    }

    // Подготавливаем данные для отправки
    // Преобразуем объекты Date обратно в строки для API и маппим поля
    const submitData = {
      name: formData.value.name,
      description: formData.value.description,
      audioFilePath: formData.value.audioFilePath,
      maxConcurrentCalls: formData.value.maxConcurrentCalls,
      callsPerMinute: formData.value.callsPerMinute,
      retryAttempts: formData.value.retryAttempts,
      retryDelay: formData.value.retryDelay,
      amdEnabled: formData.value.amdEnabled,
      workTimeStart: dateToTimeString(formData.value.workingHoursStart),
      workTimeEnd: dateToTimeString(formData.value.workingHoursEnd),
      timezone: formData.value.timezone,
      bitrixCreateLeads: formData.value.bitrixIntegrationEnabled,
      // Добавляем информацию о файле для загрузки
      _pendingAudioFile: fileList.value.length > 0 ? fileList.value[0] : null
    }
    
    console.log('📋 Данные для отправки:', submitData)
    
    // Отправляем данные родительскому компоненту
    emit('submit', submitData)
  } catch (error) {
    console.error('Ошибка валидации формы:', error)
  }
}

function handleCancel(): void {
  emit('cancel')
}

/**
 * Заполняет форму данными кампании при редактировании
 * или устанавливает значения по умолчанию при создании новой кампании
 */
function populateForm(): void {
  // Очищаем аудиоплеер при переключении
  cleanupAudioPlayback()
  
  if (props.campaign) {
    formData.value = {
      name: props.campaign.name || '',
      description: props.campaign.description || '',
      audioFilePath: props.campaign.audioFilePath || '',
      maxConcurrentCalls: props.campaign.maxConcurrentCalls || 10,
      callsPerMinute: props.campaign.callsPerMinute || 20,
      retryAttempts: props.campaign.retryAttempts || 3,
      retryDelay: props.campaign.retryDelay || 300,
      amdEnabled: props.campaign.amdEnabled ?? true,
      bitrixIntegrationEnabled: props.campaign.bitrixIntegrationEnabled ?? props.campaign.bitrixCreateLeads ?? true,
      workingHoursStart: getWorkingHours(props.campaign, 'start'),
      workingHoursEnd: getWorkingHours(props.campaign, 'end'),
      timezone: props.campaign.timezone || 'Europe/Moscow'
    }
    
    if (props.campaign.audioFilePath) {
      currentAudioFile.value = props.campaign.audioFilePath
      currentAudioFileName.value = props.campaign.audioFileName || ''
      console.log('🎵 Установлен currentAudioFile:', currentAudioFile.value)
      console.log('🎵 Установлен currentAudioFileName:', currentAudioFileName.value)
    } else {
      currentAudioFile.value = ''
      currentAudioFileName.value = ''
      console.log('🎵 Очищен currentAudioFile (audioFilePath пустой)')
    }
  } else {
    // Сброс формы для создания новой кампании
    formData.value = {
      name: '',
      description: '',
      audioFilePath: '',
      maxConcurrentCalls: 10,
      callsPerMinute: 20,
      retryAttempts: 3,
      retryDelay: 300,
      amdEnabled: true,
      bitrixIntegrationEnabled: true,
      workingHoursStart: getWorkingHours(null, 'start'),
      workingHoursEnd: getWorkingHours(null, 'end'),
      timezone: 'Europe/Moscow'
    }
    currentAudioFile.value = ''
    currentAudioFileName.value = ''
    uploadedFilePath.value = ''
    fileList.value = []
  }
}

// Watchers
watch(() => props.campaign, populateForm, { immediate: true, deep: true })

// Автоматическая загрузка файлов в плеер
watch([currentAudioFile, fileList], () => {
  if (!audioPlayer.value) return
  
  // Приоритет: сначала выбранный файл, затем текущий
  if (fileList.value.length > 0 && fileList.value[0].raw) {
    // Загружаем выбранный файл для предварительного прослушивания
    const audioUrl = URL.createObjectURL(fileList.value[0].raw)
    currentAudioUrl.value = audioUrl
    
    console.log('🎵 Автоматическая загрузка выбранного файла:', fileList.value[0].name)
    audioPlayer.value.src = audioUrl
    audioPlayer.value.load()
    
  } else if (currentAudioFile.value) {
    // Загружаем текущий файл (уже загруженный)
    const baseUrl = import.meta.env.VITE_API_URL.replace('/api', '')
    
    let fileName = currentAudioFile.value
    if (fileName.startsWith('audio\\') || fileName.startsWith('audio/')) {
      fileName = fileName.replace(/^audio[\\\/]/, '')
    }
    fileName = fileName.replace(/\\/g, '/')
    
    const audioUrl = `${baseUrl}/audio/${fileName}`
    currentAudioUrl.value = audioUrl
    
    console.log('🎵 Автоматическая загрузка текущего файла:', fileName)
    audioPlayer.value.src = audioUrl
    audioPlayer.value.load()
    
  } else {
    // Очищаем плеер если нет файлов
    currentAudioUrl.value = ''
    audioPlayer.value.src = ''
    console.log('🎵 Очистка плеера - нет файлов для загрузки')
  }
}, { deep: true })

// Жизненный цикл
onMounted(() => {
  populateForm()
})

onUnmounted(() => {
  console.log('🧹 Очистка компонента при размонтировании')
  // Очищаем ресурсы аудиоплеера при размонтировании
  cleanupAudioPlayback()
})
</script> 