/**
 * Утилиты для отладки
 */

import type { Campaign } from '@/types'

/**
 * Проверяет валидность данных кампании
 */
export function validateCampaignData(campaign: Campaign): {
  isValid: boolean
  errors: string[]
} {
  const errors: string[] = []
  
  // Проверка обязательных полей
  if (!campaign.id) {
    errors.push('Отсутствует ID кампании')
  }
  
  if (!campaign.name) {
    errors.push('Отсутствует название кампании')
  }
  
  if (!campaign.status) {
    errors.push('Отсутствует статус кампании')
  }
  
  if (!campaign.createdAt) {
    errors.push('Отсутствует дата создания')
  }
  
  // Проверка даты создания
  if (campaign.createdAt) {
    const date = new Date(campaign.createdAt)
    if (isNaN(date.getTime())) {
      errors.push('Невалидная дата создания')
    }
  }
  
  // Проверка числовых полей
  if (campaign.totalContacts !== undefined && campaign.totalContacts < 0) {
    errors.push('Негативное количество контактов')
  }
  
  if (campaign.completedContacts !== undefined && campaign.completedContacts < 0) {
    errors.push('Негативное количество завершенных контактов')
  }
  
  if (campaign.successfulCalls !== undefined && campaign.successfulCalls < 0) {
    errors.push('Негативное количество успешных звонков')
  }
  
  return {
    isValid: errors.length === 0,
    errors
  }
}

/**
 * Логирует данные кампании для отладки
 */
export function debugCampaign(campaign: Campaign, context: string = ''): void {
  console.group(`🔍 DEBUG: Кампания ${context}`)
  console.log('ID:', campaign.id)
  console.log('Название:', campaign.name)
  console.log('Описание:', campaign.description)
  console.log('Статус:', campaign.status)
  console.log('Создана:', campaign.createdAt)
  console.log('Обновлена:', campaign.updatedAt)
  console.log('Всего контактов:', campaign.totalContacts)
  console.log('Завершенных контактов:', campaign.completedContacts)
  console.log('Успешных звонков:', campaign.successfulCalls)
  console.log('Аудиофайл:', campaign.audioFilePath)
  
  const validation = validateCampaignData(campaign)
  if (!validation.isValid) {
    console.warn('❌ Ошибки валидации:', validation.errors)
  } else {
    console.log('✅ Данные валидны')
  }
  
  console.groupEnd()
}

/**
 * Сравнивает две кампании и выводит различия
 */
export function compareCampaigns(oldCampaign: Campaign, newCampaign: Campaign): void {
  console.group('🔄 Сравнение кампаний')
  
  const keys = Object.keys(oldCampaign) as (keyof Campaign)[]
  
  keys.forEach(key => {
    const oldValue = oldCampaign[key]
    const newValue = newCampaign[key]
    
    if (oldValue !== newValue) {
      console.log(`📝 ${key}: ${oldValue} → ${newValue}`)
    }
  })
  
  console.groupEnd()
} 