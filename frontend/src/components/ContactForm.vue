<template>
  <el-dialog
    v-model="dialogVisible"
    :title="isEdit ? 'Редактировать контакт' : 'Добавить контакт'"
    :before-close="handleClose"
    width="600px"
  >
    <el-form
      ref="formRef"
      :model="formData"
      :rules="formRules"
      label-width="140px"
      label-position="left"
    >
      <!-- Кампания -->
      <el-form-item label="Кампания" prop="campaignId">
        <el-select
          v-model="formData.campaignId"
          placeholder="Выберите кампанию"
          style="width: 100%"
          :disabled="isEdit"
        >
          <el-option
            v-for="campaign in campaigns"
            :key="campaign.id"
            :label="campaign.name"
            :value="campaign.id"
          />
        </el-select>
      </el-form-item>

      <!-- Номер телефона -->
      <el-form-item label="Номер телефона" prop="phoneNumber">
        <el-input
          v-model="formData.phoneNumber"
          placeholder="+7 (999) 123-45-67"
          :disabled="isEdit"
        />
      </el-form-item>

      <!-- Имя -->
      <el-form-item label="Имя" prop="firstName">
        <el-input
          v-model="formData.firstName"
          placeholder="Введите имя"
        />
      </el-form-item>

      <!-- Фамилия -->
      <el-form-item label="Фамилия" prop="lastName">
        <el-input
          v-model="formData.lastName"
          placeholder="Введите фамилию"
        />
      </el-form-item>

      <!-- Email -->
      <el-form-item label="Email" prop="email">
        <el-input
          v-model="formData.email"
          placeholder="email@example.com"
          type="email"
        />
      </el-form-item>

      <!-- Компания -->
      <el-form-item label="Компания" prop="company">
        <el-input
          v-model="formData.company"
          placeholder="Название компании"
        />
      </el-form-item>

      <!-- Статус (только для редактирования) -->
      <el-form-item v-if="isEdit" label="Статус" prop="status">
        <el-select
          v-model="formData.status"
          placeholder="Выберите статус"
          style="width: 100%"
        >
          <el-option label="Ожидание" value="pending" />
          <el-option label="Звонок" value="calling" />
          <el-option label="Завершен" value="completed" />
          <el-option label="Ошибка" value="failed" />
          <el-option label="Черный список" value="blacklisted" />
          <el-option label="Не звонить" value="do_not_call" />
        </el-select>
      </el-form-item>

      <!-- Временная зона -->
      <el-form-item label="Временная зона" prop="timezone">
        <el-select
          v-model="formData.timezone"
          placeholder="Выберите временную зону"
          style="width: 100%"
        >
          <el-option label="Москва (UTC+3)" value="Europe/Moscow" />
          <el-option label="Санкт-Петербург (UTC+3)" value="Europe/Moscow" />
          <el-option label="Екатеринбург (UTC+5)" value="Asia/Yekaterinburg" />
          <el-option label="Новосибирск (UTC+7)" value="Asia/Novosibirsk" />
          <el-option label="Красноярск (UTC+7)" value="Asia/Krasnoyarsk" />
          <el-option label="Иркутск (UTC+8)" value="Asia/Irkutsk" />
          <el-option label="Владивосток (UTC+10)" value="Asia/Vladivostok" />
        </el-select>
      </el-form-item>

      <!-- Заметки -->
      <el-form-item label="Заметки" prop="notes">
        <el-input
          v-model="formData.notes"
          type="textarea"
          :rows="3"
          placeholder="Дополнительные заметки..."
        />
      </el-form-item>
    </el-form>

    <template #footer>
      <div class="dialog-footer">
        <el-button @click="handleClose">Отмена</el-button>
        <el-button
          type="primary"
          :loading="loading"
          @click="handleSubmit"
        >
          {{ isEdit ? 'Сохранить' : 'Добавить' }}
        </el-button>
      </div>
    </template>
  </el-dialog>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { ElMessage, type FormInstance, type FormRules } from 'element-plus'
import type { Contact, CreateContactRequest, UpdateContactRequest, Campaign, ContactStatus } from '@/types'
import { apiService } from '@/services/api'

// Пропсы
interface Props {
  visible: boolean
  contact?: Contact
  campaigns: Campaign[]
}

const props = withDefaults(defineProps<Props>(), {
  visible: false,
  contact: undefined,
  campaigns: () => []
})

// Эмиты
const emit = defineEmits<{
  'update:visible': [visible: boolean]
  'success': [contact: Contact]
}>()

// Реактивные переменные
const formRef = ref<FormInstance>()
const loading = ref(false)

// Вычисляемые свойства
const dialogVisible = computed({
  get: () => props.visible,
  set: (value) => emit('update:visible', value)
})

const isEdit = computed(() => !!props.contact)

// Данные формы
const formData = ref<CreateContactRequest & { status?: ContactStatus }>({
  campaignId: 0,
  phoneNumber: '',
  firstName: '',
  lastName: '',
  email: '',
  company: '',
  timezone: 'Europe/Moscow',
  notes: ''
})

// Правила валидации
const formRules: FormRules = {
  campaignId: [
    { required: true, message: 'Выберите кампанию', trigger: 'change' }
  ],
  phoneNumber: [
    { required: true, message: 'Введите номер телефона', trigger: 'blur' },
    { 
      pattern: /^\+?[1-9]\d{1,14}$/,
      message: 'Введите корректный номер телефона',
      trigger: 'blur'
    }
  ],
  email: [
    {
      type: 'email',
      message: 'Введите корректный email',
      trigger: 'blur'
    }
  ]
}

// Отслеживание изменений контакта
watch(
  () => props.contact,
  (newContact) => {
    if (newContact) {
      // Заполняем форму данными контакта
      formData.value = {
        campaignId: newContact.campaignId,
        phoneNumber: newContact.phoneNumber,
        firstName: newContact.firstName || '',
        lastName: newContact.lastName || '',
        email: newContact.email || '',
        company: newContact.company || '',
        timezone: newContact.timezone || 'Europe/Moscow',
        notes: newContact.notes || '',
        status: newContact.status
      }
    } else {
      // Сбрасываем форму
      resetForm()
    }
  },
  { immediate: true }
)

// Методы
function resetForm(): void {
  formData.value = {
    campaignId: 0,
    phoneNumber: '',
    firstName: '',
    lastName: '',
    email: '',
    company: '',
    timezone: 'Europe/Moscow',
    notes: ''
  }
  formRef.value?.resetFields()
}

function handleClose(): void {
  dialogVisible.value = false
  resetForm()
}

async function handleSubmit(): Promise<void> {
  if (!formRef.value) return

  try {
    const isValid = await formRef.value.validate()
    if (!isValid) return

    loading.value = true

    let savedContact: Contact

    if (isEdit.value && props.contact) {
      // Обновляем существующий контакт
      const updateData: UpdateContactRequest = {
        firstName: formData.value.firstName || undefined,
        lastName: formData.value.lastName || undefined,
        email: formData.value.email || undefined,
        company: formData.value.company || undefined,
        timezone: formData.value.timezone || undefined,
        notes: formData.value.notes || undefined,
        status: formData.value.status
      }

      savedContact = await apiService.updateContact(props.contact.id, updateData)
      ElMessage.success('Контакт успешно обновлен')
    } else {
      // Создаем новый контакт
      const createData: CreateContactRequest = {
        campaignId: formData.value.campaignId,
        phoneNumber: formData.value.phoneNumber,
        firstName: formData.value.firstName || undefined,
        lastName: formData.value.lastName || undefined,
        email: formData.value.email || undefined,
        company: formData.value.company || undefined,
        timezone: formData.value.timezone || undefined,
        notes: formData.value.notes || undefined
      }

      savedContact = await apiService.createContact(createData)
      ElMessage.success('Контакт успешно добавлен')
    }

    emit('success', savedContact)
    handleClose()
  } catch (error) {
    console.error('Ошибка при сохранении контакта:', error)
    ElMessage.error('Ошибка при сохранении контакта')
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