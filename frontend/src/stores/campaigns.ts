import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { Campaign, PaginatedRequest, PaginatedResponse, ApiResponse } from '@/types'
import { apiService } from '@/services/api'
import { ElMessage } from 'element-plus'
import { debugCampaign, compareCampaigns } from '@/utils/debug'

export const useCampaignsStore = defineStore('campaigns', () => {
  // Состояние
  const campaigns = ref<Campaign[]>([])
  const currentCampaign = ref<Campaign | null>(null)
  const loading = ref(false)
  const pagination = ref({
    page: 1,
    limit: 10,
    total: 0,
    totalPages: 0
  })

  // Геттеры
  const activeCampaigns = computed(() => 
    campaigns.value.filter(campaign => campaign.status === 'active')
  )

  const draftCampaigns = computed(() => 
    campaigns.value.filter(campaign => campaign.status === 'draft')
  )

  const completedCampaigns = computed(() => 
    campaigns.value.filter(campaign => campaign.status === 'completed')
  )

  const totalCampaigns = computed(() => campaigns.value.length)

  // Действия
  
  /**
   * Загрузка списка кампаний
   */
  async function fetchCampaigns(params?: PaginatedRequest): Promise<void> {
    try {
      loading.value = true
      const response: PaginatedResponse<Campaign> = await apiService.getCampaigns(params)
      
      console.log('Ответ API getCampaigns:', response)
      
      campaigns.value = response.data || []
      pagination.value = response.pagination || {
        page: 1,
        limit: 10,
        total: 0,
        totalPages: 0
      }
      
      console.log('Обновленная пагинация:', pagination.value)
      console.log('Количество кампаний:', campaigns.value.length)
    } catch (error) {
      console.error('Ошибка загрузки кампаний:', error)
      ElMessage.error('Не удалось загрузить кампании')
      throw error
    } finally {
      loading.value = false
    }
  }

  /**
   * Загрузка одной кампании
   */
  async function fetchCampaign(id: number): Promise<Campaign> {
    try {
      loading.value = true
      const campaign = await apiService.getCampaign(id)
      
      // Обновляем состояние с использованием новой функции
      updateCampaignInList(campaign)
      
      return campaign
    } catch (error) {
      console.error('Ошибка загрузки кампании:', error)
      ElMessage.error('Не удалось загрузить кампанию')
      throw error
    } finally {
      loading.value = false
    }
  }

  /**
   * Создание новой кампании
   */
  async function createCampaign(data: Partial<Campaign>): Promise<Campaign> {
    try {
      loading.value = true
      const newCampaign = await apiService.createCampaign(data)
      
      campaigns.value.unshift(newCampaign)
      pagination.value.total += 1
      
      ElMessage.success('Кампания успешно создана')
      return newCampaign
    } catch (error) {
      console.error('Ошибка создания кампании:', error)
      ElMessage.error('Не удалось создать кампанию')
      throw error
    } finally {
      loading.value = false
    }
  }

  /**
   * Обновление кампании
   */
  async function updateCampaign(id: number, data: Partial<Campaign>): Promise<Campaign> {
    try {
      loading.value = true
      
      // Находим старую кампанию для сравнения
      const oldCampaign = campaigns.value.find(c => c.id === id)
      
      const updatedCampaign = await apiService.updateCampaign(id, data)
      
      console.log('Обновленная кампания получена из API:', updatedCampaign)
      debugCampaign(updatedCampaign, 'после обновления через API')
      
      // Сравниваем старую и новую кампанию
      if (oldCampaign) {
        compareCampaigns(oldCampaign, updatedCampaign)
      }
      
      // Обновляем в списке
      const index = campaigns.value.findIndex(c => c.id === id)
      if (index !== -1) {
        campaigns.value[index] = updatedCampaign
        console.log('Кампания обновлена в списке по индексу:', index)
      } else {
        console.warn('Кампания не найдена в списке для обновления, ID:', id)
      }
      
      // Обновляем текущую кампанию
      if (currentCampaign.value?.id === id) {
        currentCampaign.value = updatedCampaign
        console.log('Текущая кампания обновлена')
      }
      
      ElMessage.success('Кампания успешно обновлена')
      return updatedCampaign
    } catch (error) {
      console.error('Ошибка обновления кампании:', error)
      ElMessage.error('Не удалось обновить кампанию')
      throw error
    } finally {
      loading.value = false
    }
  }

  /**
   * Удаление кампании
   */
  async function deleteCampaign(id: number): Promise<void> {
    try {
      loading.value = true
      await apiService.deleteCampaign(id)
      
      // Удаляем из списка
      const index = campaigns.value.findIndex(c => c.id === id)
      if (index !== -1) {
        campaigns.value.splice(index, 1)
        pagination.value.total -= 1
      }
      
      // Очищаем текущую кампанию, если она была удалена
      if (currentCampaign.value?.id === id) {
        currentCampaign.value = null
      }
      
      ElMessage.success('Кампания успешно удалена')
    } catch (error) {
      console.error('Ошибка удаления кампании:', error)
      ElMessage.error('Не удалось удалить кампанию')
      throw error
    } finally {
      loading.value = false
    }
  }

  /**
   * Запуск кампании
   */
  async function startCampaign(id: number): Promise<void> {
    try {
      loading.value = true
      const response: ApiResponse = await apiService.startCampaign(id)
      
      if (response.success) {
        // Получаем обновленную кампанию и обновляем состояние
        const updatedCampaign = await apiService.getCampaign(id)
        updateCampaignInList(updatedCampaign)
        
        // Принудительно обновляем список кампаний для гарантии корректного отображения
        await fetchCampaigns()
        
        ElMessage.success('Кампания успешно запущена')
      } else {
        throw new Error(response.message || 'Не удалось запустить кампанию')
      }
    } catch (error) {
      console.error('Ошибка запуска кампании:', error)
      ElMessage.error('Не удалось запустить кампанию')
      throw error
    } finally {
      loading.value = false
    }
  }

  /**
   * Приостановка кампании
   */
  async function pauseCampaign(id: number): Promise<void> {
    try {
      loading.value = true
      const response: ApiResponse = await apiService.pauseCampaign(id)
      
      if (response.success) {
        // Получаем обновленную кампанию и обновляем состояние
        const updatedCampaign = await apiService.getCampaign(id)
        updateCampaignInList(updatedCampaign)
        
        // Принудительно обновляем список кампаний для гарантии корректного отображения
        await fetchCampaigns()
        
        ElMessage.success('Кампания приостановлена')
      } else {
        throw new Error(response.message || 'Не удалось приостановить кампанию')
      }
    } catch (error) {
      console.error('Ошибка приостановки кампании:', error)
      ElMessage.error('Не удалось приостановить кампанию')
      throw error
    } finally {
      loading.value = false
    }
  }

  /**
   * Остановка кампании
   */
  async function stopCampaign(id: number): Promise<void> {
    try {
      loading.value = true
      const response: ApiResponse = await apiService.stopCampaign(id)
      
      if (response.success) {
        // Получаем обновленную кампанию и обновляем состояние
        const updatedCampaign = await apiService.getCampaign(id)
        updateCampaignInList(updatedCampaign)
        
        // Принудительно обновляем список кампаний для гарантии корректного отображения
        await fetchCampaigns()
        
        ElMessage.success('Кампания остановлена')
      } else {
        throw new Error(response.message || 'Не удалось остановить кампанию')
      }
    } catch (error) {
      console.error('Ошибка остановки кампании:', error)
      ElMessage.error('Не удалось остановить кампанию')
      throw error
    } finally {
      loading.value = false
    }
  }

  /**
   * Установка текущей кампании
   */
  function setCurrentCampaign(campaign: Campaign | null): void {
    currentCampaign.value = campaign
  }

  /**
   * Очистка состояния
   */
  function clearState(): void {
    campaigns.value = []
    currentCampaign.value = null
    pagination.value = {
      page: 1,
      limit: 10,
      total: 0,
      totalPages: 0
    }
  }

  /**
   * Обновление кампании из WebSocket события
   */
  function updateCampaignFromWS(updatedCampaign: Campaign): void {
    updateCampaignInList(updatedCampaign)
  }

  /**
   * Вспомогательная функция для обновления кампании в списке
   */
  function updateCampaignInList(updatedCampaign: Campaign): void {
    console.log('🔄 Обновляю кампанию в списке:', updatedCampaign.id, 'статус:', updatedCampaign.status)
    
    const index = campaigns.value.findIndex(c => c.id === updatedCampaign.id)
    if (index !== -1) {
      // Создаем новый объект для гарантии реактивности
      const newCampaign = { ...updatedCampaign }
      campaigns.value.splice(index, 1, newCampaign)
      console.log('✅ Кампания обновлена в списке, новый статус:', newCampaign.status)
    } else {
      console.log('⚠️ Кампания не найдена в списке для обновления')
    }
    
    // Также обновляем currentCampaign если это та же кампания
    if (currentCampaign.value?.id === updatedCampaign.id) {
      currentCampaign.value = { ...updatedCampaign }
      console.log('✅ CurrentCampaign обновлена, новый статус:', currentCampaign.value.status)
    }
  }

  return {
    // Состояние
    campaigns,
    currentCampaign,
    loading,
    pagination,
    
    // Геттеры
    activeCampaigns,
    draftCampaigns,
    completedCampaigns,
    totalCampaigns,
    
    // Действия
    fetchCampaigns,
    fetchCampaign,
    createCampaign,
    updateCampaign,
    deleteCampaign,
    startCampaign,
    pauseCampaign,
    stopCampaign,
    setCurrentCampaign,
    clearState,
    updateCampaignFromWS,
    updateCampaignInList
  }
}) 