<template>
  <div class="space-y-6">
    <!-- Заголовок страницы -->
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-2xl font-bold text-gray-900">Контакты</h1>
        <p class="mt-1 text-sm text-gray-500">
          Управление базой контактов для обзвона
        </p>
      </div>
      <div class="flex items-center space-x-3">
        <!-- Объединенная кнопка добавления контактов -->
        <el-dropdown @command="handleAddCommand">
          <el-button type="primary" :icon="Plus">
            Добавить контакты
            <el-icon class="ml-1">
              <ArrowDown />
            </el-icon>
          </el-button>
          <template #dropdown>
            <el-dropdown-menu>
              <el-dropdown-item command="single">
                <el-icon><User /></el-icon>
                Добавить один контакт
              </el-dropdown-item>
              <el-dropdown-item command="import">
                <el-icon><Upload /></el-icon>
                Массовый импорт
              </el-dropdown-item>
            </el-dropdown-menu>
          </template>
        </el-dropdown>
      </div>
    </div>

    <!-- Фильтры -->
    <div class="card">
      <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
        <el-input
          v-model="searchQuery"
          placeholder="Поиск по номеру или имени..."
          :prefix-icon="Search"
          clearable
          @input="debounceSearch"
        />
        <el-select
          v-model="campaignFilter"
          placeholder="Фильтр по кампании"
          clearable
          @change="handleFilterChange"
        >
          <el-option label="Все кампании" value="" />
          <el-option
            v-for="campaign in campaigns"
            :key="campaign.id"
            :label="campaign.name"
            :value="campaign.id"
          />
        </el-select>
        <el-select
          v-model="statusFilter"
          placeholder="Статус"
          clearable
          @change="handleFilterChange"
        >
          <el-option label="Все статусы" value="" />
          <el-option label="Ожидание" value="pending" />
          <el-option label="Звонок" value="calling" />
          <el-option label="Завершен" value="completed" />
          <el-option label="Ошибка" value="failed" />
          <el-option label="Черный список" value="blacklisted" />
          <el-option label="Не звонить" value="do_not_call" />
        </el-select>
        <el-button 
          :icon="Refresh" 
          @click="refreshData"
          :loading="loading"
        >
          Обновить
        </el-button>
      </div>
    </div>

    <!-- Таблица контактов -->
    <div class="card">
      <el-table
        v-loading="loading"
        :data="contacts"
        style="width: 100%"
        empty-text="Нет данных"
      >
        <el-table-column prop="phoneNumber" label="Номер телефона" width="180" />
        <el-table-column label="Имя" width="200">
          <template #default="scope">
            {{ getContactName(scope.row) }}
          </template>
        </el-table-column>
        <el-table-column label="Кампания" width="200">
          <template #default="scope">
            {{ getCampaignName(scope.row.campaignId) }}
          </template>
        </el-table-column>
        <el-table-column prop="status" label="Статус" width="140">
          <template #default="scope">
            <el-tag :type="getStatusType(scope.row.status)" size="small">
              {{ getStatusText(scope.row.status) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="callAttempts" label="Попытки" width="120" />
        <el-table-column prop="createdAt" label="Добавлен" width="140">
          <template #default="scope">
            {{ formatDate(scope.row.createdAt) }}
          </template>
        </el-table-column>
        <el-table-column label="Действия" width="120" align="center">
          <template #default="scope">
            <el-button size="small" :icon="Edit" @click="editContact(scope.row)" />
            <el-button 
              size="small" 
              type="danger" 
              :icon="Delete" 
              @click="deleteContact(scope.row)"
            />
          </template>
        </el-table-column>
      </el-table>

      <!-- Пагинация -->
      <div class="flex justify-center mt-6">
        <el-pagination
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

    <!-- Диалог формы контакта -->
    <ContactForm
      v-model:visible="contactFormVisible"
      :contact="selectedContact"
      :campaigns="campaigns"
      @success="handleContactSaved"
    />

    <!-- Диалог импорта контактов -->
    <ContactImportDialog
      v-model:visible="importDialogVisible"
      :campaigns="campaigns"
      @success="handleImportSuccess"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { 
  Plus, 
  Upload, 
  Search, 
  Refresh, 
  Edit, 
  Delete,
  ArrowDown,
  User
} from '@element-plus/icons-vue'
import type { Contact, ContactStatus, Campaign } from '@/types'
import { apiService } from '@/services/api'
import { useDebounceFn } from '@vueuse/core'
import ContactForm from '@/components/ContactForm.vue'
import ContactImportDialog from '@/components/ContactImportDialog.vue'

// Реактивные данные
const loading = ref(false)
const searchQuery = ref('')
const campaignFilter = ref<number | string>('')
const statusFilter = ref<ContactStatus | string>('')
const contacts = ref<Contact[]>([])
const campaigns = ref<Campaign[]>([])
const contactFormVisible = ref(false)
const importDialogVisible = ref(false)
const selectedContact = ref<Contact | undefined>(undefined)

const pagination = ref({
  page: 1,
  limit: 10,
  total: 0
})

// Вычисляемые свойства
const selectedCampaignId = computed(() => {
  return typeof campaignFilter.value === 'number' ? campaignFilter.value : undefined
})

// Debounced поиск
const debounceSearch = useDebounceFn(() => {
  handleFilterChange()
}, 300)

// Методы
async function loadCampaigns(): Promise<void> {
  try {
    const response = await apiService.getCampaigns()
    campaigns.value = response.data
  } catch (error) {
    console.error('Ошибка загрузки кампаний:', error)
    ElMessage.error('Ошибка загрузки кампаний')
  }
}

async function loadContacts(): Promise<void> {
  try {
    loading.value = true
    
    const params = {
      page: pagination.value.page,
      limit: pagination.value.limit,
      search: searchQuery.value || undefined,
      status: statusFilter.value || undefined
    }

    const response = await apiService.getContacts(selectedCampaignId.value, params)
    
    contacts.value = response.data
    pagination.value.total = response.pagination.total
  } catch (error) {
    console.error('Ошибка загрузки контактов:', error)
    ElMessage.error('Ошибка загрузки контактов')
  } finally {
    loading.value = false
  }
}

function refreshData(): void {
  loadContacts()
}

function handleFilterChange(): void {
  pagination.value.page = 1
  loadContacts()
}

function handleSizeChange(): void {
  pagination.value.page = 1
  loadContacts()
}

function handlePageChange(): void {
  loadContacts()
}

/**
 * Обработка команд выпадающего меню добавления контактов
 */
function handleAddCommand(command: string): void {
  if (command === 'single') {
    openCreateDialog()
  } else if (command === 'import') {
    openImportDialog()
  }
}

function openImportDialog(): void {
  importDialogVisible.value = true
}

function openCreateDialog(): void {
  selectedContact.value = undefined
  contactFormVisible.value = true
}

function editContact(contact: Contact): void {
  selectedContact.value = contact
  contactFormVisible.value = true
}

async function deleteContact(contact: Contact): Promise<void> {
  try {
    await ElMessageBox.confirm(
      `Вы уверены, что хотите удалить контакт ${contact.phoneNumber}?`,
      'Подтверждение удаления',
      {
        confirmButtonText: 'Удалить',
        cancelButtonText: 'Отмена',
        type: 'warning'
      }
    )

    await apiService.deleteContact(contact.id)
    ElMessage.success('Контакт удален')
    loadContacts()
  } catch (error) {
    if (error !== 'cancel') {
      console.error('Ошибка удаления контакта:', error)
      ElMessage.error('Ошибка удаления контакта')
    }
  }
}

function handleContactSaved(): void {
  loadContacts()
}

function handleImportSuccess(): void {
  loadContacts()
  ElMessage.success('Контакты успешно импортированы')
}

function getContactName(contact: Contact): string {
  if (contact.firstName && contact.lastName) {
    return `${contact.firstName} ${contact.lastName}`
  } else if (contact.firstName) {
    return contact.firstName
  } else if (contact.lastName) {
    return contact.lastName
  }
  return 'Не указано'
}

function getCampaignName(campaignId: number): string {
  const campaign = campaigns.value.find(c => c.id === campaignId)
  return campaign?.name || 'Неизвестная кампания'
}

function getStatusType(status: ContactStatus): string {
  const types = {
    'pending': 'info',
    'calling': 'warning',
    'completed': 'success',
    'failed': 'danger',
    'blacklisted': 'danger',
    'do_not_call': 'danger'
  }
  return types[status] || 'info'
}

function getStatusText(status: ContactStatus): string {
  const texts = {
    'pending': 'Ожидание',
    'calling': 'Звонок',
    'completed': 'Завершен',
    'failed': 'Ошибка',
    'blacklisted': 'Черный список',
    'do_not_call': 'Не звонить'
  }
  return texts[status] || 'Неизвестно'
}

function formatDate(dateString: string): string {
  if (!dateString) {
    return 'Не указана'
  }
  
  const date = new Date(dateString)
  
  if (isNaN(date.getTime())) {
    return 'Не указана'
  }
  
  return date.toLocaleDateString('ru-RU')
}

// Жизненный цикл
onMounted(() => {
  loadCampaigns()
  loadContacts()
})
</script> 