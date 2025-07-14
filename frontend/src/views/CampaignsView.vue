<template>
  <div class="space-y-6">
    <!-- Заголовок и действия -->
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between">
      <div>
        <h1 class="text-2xl font-bold text-gray-900">Кампании</h1>
        <p class="mt-1 text-sm text-gray-500">
          Управление кампаниями автодозвона
        </p>
      </div>
      <div class="mt-4 sm:mt-0">
        <el-button 
          type="primary" 
          :icon="Plus" 
          @click="openCreateDialog"
        >
          Создать кампанию
        </el-button>
      </div>
    </div>

    <!-- Фильтры и поиск -->
    <div class="card">
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <!-- Поиск -->
        <el-input
          v-model="searchQuery"
          placeholder="Поиск кампаний..."
          :prefix-icon="Search"
          @input="handleSearch"
          clearable
        />
        
        <!-- Фильтр по статусу -->
        <el-select
          v-model="statusFilter"
          placeholder="Фильтр по статусу"
          @change="handleFilter"
          clearable
        >
          <el-option label="Все статусы" value="" />
          <el-option label="Черновик" value="draft" />
          <el-option label="Активная" value="active" />
          <el-option label="Приостановлена" value="paused" />
          <el-option label="Завершена" value="completed" />
        </el-select>

        <!-- Обновить -->
        <el-button 
          :icon="Refresh" 
          @click="refreshCampaigns"
          :loading="loading"
        >
          Обновить
        </el-button>
      </div>
    </div>

    <!-- Таблица кампаний -->
    <div class="card">
      <el-table
        v-loading="loading"
        :data="filteredCampaigns"
        style="width: 100%"
        @row-click="handleRowClick"
        class="cursor-pointer"
      >
        <el-table-column prop="name" label="Название" min-width="200">
          <template #default="scope">
            <div>
              <div class="font-medium text-gray-900">{{ scope.row.name }}</div>
              <div class="text-sm text-gray-500">{{ scope.row.description }}</div>
            </div>
          </template>
        </el-table-column>

        <el-table-column prop="status" label="Статус" width="120">
          <template #default="scope">
            <el-tag 
              :type="getStatusTagType(scope.row.status)"
              size="small"
            >
              {{ getStatusText(scope.row.status) }}
            </el-tag>
          </template>
        </el-table-column>

        <el-table-column label="Прогресс" width="150">
          <template #default="scope">
            <div class="space-y-1">
              <div class="text-sm text-gray-600">
                {{ scope.row.completedContacts || 0 }}/{{ scope.row.totalContacts || 0 }}
              </div>
              <el-progress 
                :percentage="getProgressPercentage(scope.row)"
                :stroke-width="6"
                :show-text="false"
              />
            </div>
          </template>
        </el-table-column>

        <el-table-column prop="successfulCalls" label="Успешные" width="100" align="center">
          <template #default="scope">
            <span class="font-medium text-success-600">
              {{ scope.row.successfulCalls || 0 }}
            </span>
          </template>
        </el-table-column>

        <el-table-column prop="createdAt" label="Создана" width="120">
          <template #default="scope">
            {{ formatDate(scope.row.createdAt) }}
          </template>
        </el-table-column>

        <el-table-column label="Действия" width="200" align="center">
          <template #default="scope">
            <div class="flex items-center justify-center space-x-2">
              <!-- Управление кампанией -->
              <el-button
                v-if="scope.row.status === 'draft'"
                type="success"
                size="small"
                :icon="VideoPlay"
                @click.stop="startCampaign(scope.row)"
              >
                Запустить
              </el-button>
              
              <el-button
                v-else-if="scope.row.status === 'active'"
                type="warning"
                size="small"
                :icon="VideoPause"
                @click.stop="pauseCampaign(scope.row)"
              >
                Пауза
              </el-button>
              
              <el-button
                v-else-if="scope.row.status === 'paused'"
                type="success"
                size="small"
                :icon="VideoPlay"
                @click.stop="resumeCampaign(scope.row)"
              >
                Продолжить
              </el-button>

              <!-- Дополнительные действия -->
              <el-dropdown @command="handleCommand">
                <el-button size="small" :icon="More" />
                <template #dropdown>
                  <el-dropdown-menu>
                    <el-dropdown-item 
                      :command="{ action: 'edit', campaign: scope.row }"
                      :icon="Edit"
                    >
                      Редактировать
                    </el-dropdown-item>
                    <el-dropdown-item 
                      :command="{ action: 'duplicate', campaign: scope.row }"
                      :icon="CopyDocument"
                    >
                      Дублировать
                    </el-dropdown-item>
                    <el-dropdown-item 
                      :command="{ action: 'statistics', campaign: scope.row }"
                      :icon="DataAnalysis"
                    >
                      Статистика
                    </el-dropdown-item>
                    <el-dropdown-item 
                      :command="{ action: 'delete', campaign: scope.row }"
                      :icon="Delete"
                      divided
                    >
                      Удалить
                    </el-dropdown-item>
                  </el-dropdown-menu>
                </template>
              </el-dropdown>
            </div>
          </template>
        </el-table-column>
      </el-table>

      <!-- Пагинация -->
      <div class="flex justify-center mt-6">
        <el-pagination
          v-if="pagination"
          v-model:current-page="pagination.page"
          v-model:page-size="pagination.limit"
          :total="pagination.total"
          :page-sizes="[10, 20, 50, 100]"
          layout="total, sizes, prev, pager, next, jumper"
          @size-change="handleSizeChange"
          @current-change="handlePageChange"
        />
      </div>
    </div>

    <!-- Диалог создания/редактирования кампании -->
    <el-dialog
      v-model="dialogVisible"
      :title="dialogTitle"
      width="600px"
      :before-close="handleDialogClose"
    >
      <campaign-form
        ref="campaignFormRef"
        :campaign="currentCampaign"
        :loading="formLoading"
        @submit="handleFormSubmit"
        @cancel="closeDialog"
      />
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { 
  Plus, 
  Search, 
  Refresh, 
  VideoPlay, 
  VideoPause, 
  More, 
  Edit, 
  Delete, 
  CopyDocument, 
  DataAnalysis 
} from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { useCampaignsStore } from '@/stores/campaigns'
import { wsService } from '@/services/websocket'
import { apiService } from '@/services/api'
import type { Campaign, CampaignStatus } from '@/types'
import CampaignForm from '@/components/CampaignForm.vue'

// Store
const campaignsStore = useCampaignsStore()

// Реактивные данные
const loading = ref(false)
const formLoading = ref(false)
const searchQuery = ref('')
const statusFilter = ref<CampaignStatus | ''>('')
const dialogVisible = ref(false)
const currentCampaign = ref<Campaign | null>(null)

// Ссылки на компоненты
const campaignFormRef = ref()

// Computed свойства
const filteredCampaigns = computed(() => {
  let campaigns = campaignsStore.campaigns
  
  // Фильтр по поиску
  if (searchQuery.value) {
    const query = searchQuery.value.toLowerCase()
    campaigns = campaigns.filter(campaign => 
      campaign.name.toLowerCase().includes(query) ||
      (campaign.description && campaign.description.toLowerCase().includes(query))
    )
  }
  
  // Фильтр по статусу
  if (statusFilter.value) {
    campaigns = campaigns.filter(campaign => campaign.status === statusFilter.value)
  }
  
  return campaigns
})

const pagination = computed(() => campaignsStore.pagination)

const dialogTitle = computed(() => 
  currentCampaign.value ? 'Редактировать кампанию' : 'Создать кампанию'
)

// Методы таблицы
function getStatusTagType(status: CampaignStatus): string {
  const types = {
    'draft': 'info',      // Черновик - синий цвет
    'active': 'success',   // Активна - зеленый цвет
    'paused': 'warning',   // Пауза - желтый цвет
    'completed': 'primary', // Завершена - голубой цвет
    'cancelled': 'danger'  // Отменена - красный цвет
  }
  return types[status] || 'info'
}

function getStatusText(status: CampaignStatus): string {
  const texts = {
    'draft': 'Черновик',
    'active': 'Активна',
    'paused': 'Пауза',
    'completed': 'Завершена',
    'cancelled': 'Отменена'
  }
  return texts[status] || status
}

function getProgressPercentage(campaign: Campaign): number {
  if (!campaign.totalContacts || campaign.totalContacts === 0) return 0
  return Math.round(((campaign.completedContacts || 0) / campaign.totalContacts) * 100)
}

function formatDate(dateString: string): string {
  // Проверяем валидность даты
  if (!dateString) {
    return 'Не указана'
  }
  
  const date = new Date(dateString)
  
  // Проверяем, что дата валидна
  if (isNaN(date.getTime())) {
    return 'Не указана'
  }
  
  return date.toLocaleDateString('ru-RU')
}

// Обработчики событий
async function refreshCampaigns(): Promise<void> {
  try {
    loading.value = true
    await campaignsStore.fetchCampaigns({
      page: pagination.value?.page || 1,
      limit: pagination.value?.limit || 10
    })
  } finally {
    loading.value = false
  }
}

function handleSearch(): void {
  // Поиск выполняется через computed свойство filteredCampaigns
}

function handleFilter(): void {
  // Фильтрация выполняется через computed свойство filteredCampaigns
}

function handleRowClick(campaign: Campaign): void {
  // Можно открыть детальную информацию о кампании
  console.log('Клик по кампании:', campaign)
}

function handleSizeChange(size: number): void {
  refreshCampaigns()
}

function handlePageChange(page: number): void {
  refreshCampaigns()
}

// Управление кампаниями
async function startCampaign(campaign: Campaign): Promise<void> {
  try {
    console.log('🚀 Запускаю кампанию:', campaign.id, 'текущий статус:', campaign.status)
    await campaignsStore.startCampaign(campaign.id)
    console.log('✅ Кампания запущена успешно')
  } catch (error) {
    console.error('Ошибка запуска кампании:', error)
  }
}

async function pauseCampaign(campaign: Campaign): Promise<void> {
  try {
    console.log('⏸️ Приостанавливаю кампанию:', campaign.id, 'текущий статус:', campaign.status)
    await campaignsStore.pauseCampaign(campaign.id)
    console.log('✅ Кампания приостановлена успешно')
  } catch (error) {
    console.error('Ошибка приостановки кампании:', error)
  }
}

async function resumeCampaign(campaign: Campaign): Promise<void> {
  try {
    console.log('▶️ Возобновляю кампанию:', campaign.id, 'текущий статус:', campaign.status)
    await campaignsStore.resumeCampaign(campaign.id)
    console.log('✅ Кампания возобновлена успешно')
  } catch (error) {
    console.error('Ошибка возобновления кампании:', error)
  }
}

// Действия с кампаниями
function handleCommand(command: { action: string; campaign: Campaign }): void {
  const { action, campaign } = command
  
  switch (action) {
    case 'edit':
      openEditDialog(campaign)
      break
    case 'duplicate':
      duplicateCampaign(campaign)
      break
    case 'statistics':
      openStatistics(campaign)
      break
    case 'delete':
      deleteCampaign(campaign)
      break
  }
}

// Диалоги
function openCreateDialog(): void {
  currentCampaign.value = null
  dialogVisible.value = true
}

function openEditDialog(campaign: Campaign): void {
  currentCampaign.value = { ...campaign }
  dialogVisible.value = true
}

function closeDialog(): void {
  dialogVisible.value = false
  currentCampaign.value = null
}

function handleDialogClose(): void {
  closeDialog()
}

async function handleFormSubmit(formData: Partial<Campaign>): Promise<void> {
  try {
    formLoading.value = true
    
    // Извлекаем информацию о файле для загрузки
    const pendingFile = (formData as any)._pendingAudioFile
    const cleanFormData = { ...formData }
    delete (cleanFormData as any)._pendingAudioFile
    
    // Отладочная информация
    console.log('🔍 DEBUG: Обработка отправки формы кампании')
    console.log('📁 Ожидающий файл:', pendingFile)
    console.log('📂 Есть ли raw файл:', pendingFile?.raw)
    console.log('📋 Чистые данные формы:', cleanFormData)
    console.log('✏️ Режим редактирования:', !!currentCampaign.value)
    
    let campaign: Campaign
    
    if (currentCampaign.value) {
      // Обновление существующей кампании
      campaign = await campaignsStore.updateCampaign(currentCampaign.value.id, cleanFormData)
    } else {
      // Создание новой кампании
      campaign = await campaignsStore.createCampaign(cleanFormData)
    }
    
    console.log('💾 Результат сохранения кампании:', campaign)
    
    // Если есть файл для загрузки, загружаем его
    if (pendingFile && pendingFile.raw) {
      console.log('🎵 Начинаем загрузку аудиофайла для кампании:', campaign.id)
      try {
        const uploadResult = await apiService.uploadCampaignAudio(campaign.id, pendingFile.raw)
        console.log('✅ Аудиофайл успешно загружен:', uploadResult)
        ElMessage.success('Аудиофайл успешно загружен')
      } catch (audioError) {
        console.error('❌ Ошибка загрузки аудиофайла:', audioError)
        ElMessage.warning('Кампания создана, но аудиофайл не загружен')
      }
    } else {
      console.log('⚠️ Файл для загрузки отсутствует')
    }
    
    // Обновляем список кампаний для гарантии корректного отображения
    await refreshCampaigns()
    
    closeDialog()
  } catch (error) {
    console.error('❌ Ошибка сохранения кампании:', error)
  } finally {
    formLoading.value = false
  }
}

// Дополнительные действия
async function duplicateCampaign(campaign: Campaign): Promise<void> {
  try {
    const duplicatedData = {
      name: `Копия - ${campaign.name}`,
      description: campaign.description,
      audioFilePath: campaign.audioFilePath
    }
    
    await campaignsStore.createCampaign(duplicatedData)
    ElMessage.success('Кампания успешно дублирована')
  } catch (error) {
    console.error('Ошибка дублирования кампании:', error)
  }
}

function openStatistics(campaign: Campaign): void {
  // TODO: Открыть страницу статистики для конкретной кампании
  console.log('Открыть статистику для кампании:', campaign.id)
}

async function deleteCampaign(campaign: Campaign): Promise<void> {
  try {
    await ElMessageBox.confirm(
      `Вы уверены, что хотите удалить кампанию "${campaign.name}"? Это действие нельзя отменить.`,
      'Подтверждение удаления',
      {
        confirmButtonText: 'Удалить',
        cancelButtonText: 'Отмена',
        type: 'warning',
      }
    )
    
    await campaignsStore.deleteCampaign(campaign.id)
  } catch (error) {
    if (error !== 'cancel') {
      console.error('Ошибка удаления кампании:', error)
    }
  }
}

// WebSocket обработчики
function handleCampaignUpdate(data: { campaignId: number; status: string; campaign?: Campaign }): void {
  console.log('🔄 Получено WebSocket событие campaign_updated:', data)
  
  if (data.campaign) {
    // Если получен полный объект кампании, используем его
    campaignsStore.updateCampaignFromWS(data.campaign)
  } else {
    // Если только статус, находим кампанию в store и обновляем её статус
    const existingCampaign = campaignsStore.campaigns.find(c => c.id === data.campaignId)
    if (existingCampaign) {
      const updatedCampaign = { 
        ...existingCampaign, 
        status: data.status as CampaignStatus 
      }
      campaignsStore.updateCampaignFromWS(updatedCampaign)
      console.log(`✅ Обновлен статус кампании ${data.campaignId} на ${data.status}`)
    } else {
      console.warn(`⚠️ Кампания ${data.campaignId} не найдена в store для обновления статуса`)
      // Если кампания не найдена, перезагружаем список
      refreshCampaigns()
    }
  }
}

// Жизненный цикл
onMounted(() => {
  // Загружаем кампании
  refreshCampaigns()
  
  // Подписываемся на WebSocket события
  wsService.on('campaign_updated', handleCampaignUpdate)
})

onUnmounted(() => {
  // Отписываемся от событий
  wsService.off('campaign_updated', handleCampaignUpdate)
})
</script> 