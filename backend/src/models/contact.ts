/**
 * Модель Contact - управление контактами для автодозвона
 */

import { BaseModel } from '@/config/database';
import { Contact, ContactStatus, CreateContactRequest, UpdateContactRequest } from '@/types';
import { log } from '@/utils/logger';

export class ContactModel extends BaseModel {
  private tableName = 'contacts';

  /**
   * Создание нового контакта
   */
  async createContact(data: CreateContactRequest): Promise<Contact> {
    try {
      const contactData = {
        campaign_id: data.campaignId,
        phone: data.phoneNumber,
        name: data.firstName && data.lastName ? `${data.firstName} ${data.lastName}` : (data.firstName || data.lastName || null),
        company: data.company || null,
        email: data.email || null,
        
        // Статус контакта
        status: 'new' as ContactStatus,
        
        // Данные для Битрикс24
        bitrix_contact_id: data.bitrixContactId || null,
        bitrix_lead_id: data.bitrixLeadId || null,
        
        // Статистика звонков
        call_attempts: 0,
        last_call_at: null,
        next_call_at: null,
        
        // Дополнительные данные
        additional_data: data.customFields || {},
      };

      const contact = await this.create<Contact>(this.tableName, contactData);

      log.debug(`Created contact: ${contact.phoneNumber} for campaign ${contact.campaignId}`);
      return this.formatContact(contact);

    } catch (error) {
      log.error('Failed to create contact:', error);
      throw error;
    }
  }

  /**
   * Импорт контактов из CSV
   */
  async importContacts(campaignId: number, contacts: CreateContactRequest[]): Promise<{
    imported: number;
    failed: number;
    errors: string[];
  }> {
    const result = {
      imported: 0,
      failed: 0,
      errors: [] as string[],
    };

    try {
      // Временно убрана transaction оболочка
        for (const contactData of contacts) {
          try {
            // Проверяем, что номер телефона не дублируется в кампании
            const existingContact = await this.findContactByPhone(campaignId, contactData.phoneNumber);
            
            if (existingContact) {
              result.failed++;
              result.errors.push(`Phone ${contactData.phoneNumber} already exists in campaign`);
              continue;
            }

            await this.createContact({
              ...contactData,
              campaignId,
            });

            result.imported++;

          } catch (error) {
            result.failed++;
            result.errors.push(`Failed to import ${contactData.phoneNumber}: ${error instanceof Error ? error.message : 'Unknown error'}`);
          }
        }

        // Обновляем счетчик контактов в кампании
        await this.updateCampaignContactsCount(campaignId);

      log.info(`Imported ${result.imported} contacts, failed: ${result.failed} for campaign ${campaignId}`);
      return result;

    } catch (error) {
      log.error(`Failed to import contacts for campaign ${campaignId}:`, error);
      throw error;
    }
  }

  /**
   * Получение контакта по ID
   */
  async getContactById(id: number): Promise<Contact | null> {
    try {
      const contact = await this.findById<any>(this.tableName, id);
      return contact ? this.formatContact(contact) : null;
    } catch (error) {
      log.error(`Failed to get contact ${id}:`, error);
      throw error;
    }
  }

  /**
   * Поиск контакта по номеру телефона в кампании
   */
  async findContactByPhone(campaignId: number, phoneNumber: string): Promise<Contact | null> {
    try {
      const result = await this.query<any>(
        'SELECT * FROM contacts WHERE campaign_id = $1 AND phone = $2 LIMIT 1',
        [campaignId, phoneNumber]
      );

      return result.rows.length > 0 ? this.formatContact(result.rows[0]) : null;

    } catch (error) {
      log.error(`Failed to find contact by phone ${phoneNumber}:`, error);
      throw error;
    }
  }

  /**
   * Получение контактов кампании с фильтрацией
   */
  async getContactsByCampaign(
    campaignId: number,
    page: number = 1,
    limit: number = 10,
    status?: ContactStatus,
    search?: string
  ): Promise<{
    contacts: Contact[];
    total: number;
    page: number;
    totalPages: number;
  }> {
    try {
      let whereClause = 'campaign_id = $1';
      const params: any[] = [campaignId];

      if (status) {
        whereClause += ` AND status = $${params.length + 1}`;
        params.push(status);
      }

      if (search && search.trim()) {
        whereClause += ` AND (
          phone ILIKE $${params.length + 1} OR
          name ILIKE $${params.length + 1} OR
          company ILIKE $${params.length + 1} OR
          email ILIKE $${params.length + 1}
        )`;
        params.push(`%${search.trim()}%`);
      }

      const result = await this.paginate<any>(
        this.tableName,
        page,
        limit,
        whereClause,
        'created_at DESC',
        params
      );

      return {
        contacts: result.items.map(item => this.formatContact(item)),
        total: result.total,
        page: result.page,
        totalPages: result.totalPages,
      };

    } catch (error) {
      log.error(`Failed to get contacts for campaign ${campaignId}:`, error);
      throw error;
    }
  }

  /**
   * Получение всех контактов с фильтрацией и пагинацией
   */
  async getAllContacts(
    page: number = 1,
    limit: number = 10,
    status?: ContactStatus,
    search?: string
  ): Promise<{
    contacts: Contact[];
    total: number;
    page: number;
    totalPages: number;
  }> {
    try {
      let whereClause = '1 = 1'; // Базовое условие для всех контактов
      const params: any[] = [];

      if (status) {
        whereClause += ` AND status = $${params.length + 1}`;
        params.push(status);
      }

      if (search && search.trim()) {
        whereClause += ` AND (
          phone ILIKE $${params.length + 1} OR
          name ILIKE $${params.length + 1} OR
          company ILIKE $${params.length + 1} OR
          email ILIKE $${params.length + 1}
        )`;
        params.push(`%${search.trim()}%`);
      }

      const result = await this.paginate<any>(
        this.tableName,
        page,
        limit,
        whereClause,
        'created_at DESC',
        params
      );

      return {
        contacts: result.items.map(item => this.formatContact(item)),
        total: result.total,
        page: result.page,
        totalPages: result.totalPages,
      };

    } catch (error) {
      log.error('Failed to get all contacts:', error);
      throw error;
    }
  }

  /**
   * Обновление контакта
   */
    async updateContact(id: number, data: UpdateContactRequest): Promise<Contact | null> {
    try {
      const updateData: any = {};

      // Обработка имени - объединяем firstName и lastName в поле name
      if (data.firstName !== undefined || data.lastName !== undefined) {
        // Получаем текущий контакт для сохранения существующих частей имени
        const currentContact = await this.getContactById(id);
        if (currentContact) {
          const currentFirstName = currentContact.firstName || '';
          const currentLastName = currentContact.lastName || '';
          
          const newFirstName = data.firstName !== undefined ? data.firstName : currentFirstName;
          const newLastName = data.lastName !== undefined ? data.lastName : currentLastName;
          
          // Формируем полное имя
          const fullName = [newFirstName, newLastName].filter(Boolean).join(' ').trim();
          updateData.name = fullName || null;
        }
      }

      // Основные поля (только те, что есть в БД)
      if (data.company !== undefined) updateData.company = data.company;
      if (data.email !== undefined) updateData.email = data.email;
      if (data.status !== undefined) updateData.status = data.status;

      // Обработка дополнительных данных (notes, timezone, customFields)
      if (data.notes !== undefined || data.timezone !== undefined || data.customFields !== undefined) {
        // Получаем текущие additional_data
        const currentContact = await this.getContactById(id);
        const currentAdditionalData = currentContact?.customFields || {};
        
        // Обновляем дополнительные данные
        const newAdditionalData = { ...currentAdditionalData };
        
        if (data.notes !== undefined) newAdditionalData.notes = data.notes;
        if (data.timezone !== undefined) newAdditionalData.timezone = data.timezone;
        if (data.customFields !== undefined) Object.assign(newAdditionalData, data.customFields);
        
        updateData.additional_data = newAdditionalData;
      }

      // Битрикс24
      if (data.bitrixContactId !== undefined) updateData.bitrix_contact_id = data.bitrixContactId;
      if (data.bitrixLeadId !== undefined) updateData.bitrix_lead_id = data.bitrixLeadId;

      const contact = await this.update<any>(this.tableName, id, updateData);

      if (contact) {
        log.debug(`Updated contact: ${contact.phone} (ID: ${id})`);
        return this.formatContact(contact);
      }

      return null;

    } catch (error) {
      log.error(`Failed to update contact ${id}:`, error);
      throw error;
    }
  }

  /**
   * Удаление контакта
   */
  async deleteContact(id: number): Promise<boolean> {
    try {
      const contact = await this.getContactById(id);
      
      if (!contact) {
        return false;
      }

      const deleted = await this.delete(this.tableName, id);
      
      if (deleted) {
        // Обновляем счетчик контактов в кампании
        await this.updateCampaignContactsCount(contact.campaignId);
        log.debug(`Deleted contact: ${contact.phoneNumber} (ID: ${id})`);
      }
      
      return deleted;
    } catch (error) {
      log.error(`Failed to delete contact ${id}:`, error);
      throw error;
    }
  }

  /**
   * Получение следующих контактов для звонков
   */
  async getNextContactsForCalling(
    campaignId: number,
    limit: number = 10,
    _timezone?: string
  ): Promise<Contact[]> {
    try {
      const now = new Date();
      
      let query = `
        SELECT * FROM contacts 
        WHERE campaign_id = $1 
        AND status IN ('new', 'retry', 'callback')
        AND (next_call_at IS NULL OR next_call_at <= $2)
        ORDER BY 
          CASE status 
            WHEN 'callback' THEN 1
            WHEN 'retry' THEN 2
            WHEN 'new' THEN 3
            ELSE 4
          END,
          call_attempts ASC,
          created_at ASC
        LIMIT $3
      `;

      const result = await this.query<any>(query, [campaignId, now, limit]);

      return result.rows.map(row => this.formatContact(row));

    } catch (error) {
      log.error(`Failed to get next contacts for campaign ${campaignId}:`, error);
      throw error;
    }
  }

  /**
   * Обновление статистики звонка контакта
   */
  async updateContactCallStats(
    id: number,
    status: ContactStatus,
    lastCallAt: Date,
    nextCallAt?: Date
  ): Promise<void> {
    try {
      const updateData: any = {
        status,
        last_call_at: lastCallAt,
        call_attempts: await this.query<any>(
          'SELECT call_attempts FROM contacts WHERE id = $1',
          [id]
        ).then(result => (result.rows[0]?.call_attempts || 0) + 1),
      };

      if (nextCallAt) {
        updateData.next_call_at = nextCallAt;
      }

      await this.update(this.tableName, id, updateData);
      log.debug(`Updated call stats for contact ${id}`);

    } catch (error) {
      log.error(`Failed to update contact ${id} call stats:`, error);
      throw error;
    }
  }

  /**
   * Получение статистики контактов по кампании
   */
  async getContactsStatsByCampaign(campaignId: number): Promise<{
    total: number;
    new: number;
    inProgress: number;
    completed: number;
    interested: number;
    notInterested: number;
    failed: number;
    callback: number;
  }> {
    try {
      const result = await this.query<any>(`
        SELECT 
          COUNT(*) as total,
          COUNT(CASE WHEN status = 'new' THEN 1 END) as new,
          COUNT(CASE WHEN status = 'calling' THEN 1 END) as in_progress,
          COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed,
          COUNT(CASE WHEN status = 'interested' THEN 1 END) as interested,
          COUNT(CASE WHEN status = 'not_interested' THEN 1 END) as not_interested,
          COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed,
          COUNT(CASE WHEN status = 'callback' THEN 1 END) as callback
        FROM contacts 
        WHERE campaign_id = $1
      `, [campaignId]);

      const row = result.rows[0];
      
      return {
        total: parseInt(row.total || '0', 10),
        new: parseInt(row.new || '0', 10),
        inProgress: parseInt(row.in_progress || '0', 10),
        completed: parseInt(row.completed || '0', 10),
        interested: parseInt(row.interested || '0', 10),
        notInterested: parseInt(row.not_interested || '0', 10),
        failed: parseInt(row.failed || '0', 10),
        callback: parseInt(row.callback || '0', 10),
      };

    } catch (error) {
      log.error(`Failed to get contact stats for campaign ${campaignId}:`, error);
      throw error;
    }
  }

  /**
   * Удаление всех контактов кампании
   */
  async deleteContactsByCampaign(campaignId: number): Promise<number> {
    try {
      const result = await this.query<any>(
        'DELETE FROM contacts WHERE campaign_id = $1',
        [campaignId]
      );

      const deletedCount = result.rowCount || 0;
      
      if (deletedCount > 0) {
        // Обновляем счетчик контактов в кампании
        await this.updateCampaignContactsCount(campaignId);
        log.info(`Deleted ${deletedCount} contacts from campaign ${campaignId}`);
      }

      return deletedCount;

    } catch (error) {
      log.error(`Failed to delete contacts for campaign ${campaignId}:`, error);
      throw error;
    }
  }

  /**
   * Поиск дубликатов номеров в кампании
   */
  async findDuplicatePhones(campaignId: number): Promise<string[]> {
    try {
      const result = await this.query<any>(`
        SELECT phone_number 
        FROM contacts 
        WHERE campaign_id = $1 
        GROUP BY phone_number 
        HAVING COUNT(*) > 1
      `, [campaignId]);

      return result.rows.map(row => row.phone_number);

    } catch (error) {
      log.error(`Failed to find duplicate phones for campaign ${campaignId}:`, error);
      throw error;
    }
  }

  /**
   * Обновление счетчика контактов в кампании
   */
  private async updateCampaignContactsCount(campaignId: number): Promise<void> {
    try {
      const countResult = await this.query<any>(
        'SELECT COUNT(*) as count FROM contacts WHERE campaign_id = $1',
        [campaignId]
      );

      const totalContacts = parseInt(countResult.rows[0]?.count || '0', 10);

      await this.query<any>(
        'UPDATE campaigns SET total_contacts = $1 WHERE id = $2',
        [totalContacts, campaignId]
      );

    } catch (error) {
      log.error(`Failed to update contacts count for campaign ${campaignId}:`, error);
    }
  }

  /**
   * Форматирование данных контакта для API
   */
  private formatContact(row: any): Contact {
    // Парсим имя из поля name (если есть)
    const nameParts = row.name ? row.name.split(' ') : []
    const firstName = nameParts.length > 0 ? nameParts[0] : undefined
    const lastName = nameParts.length > 1 ? nameParts.slice(1).join(' ') : undefined
    
    // Извлекаем дополнительные данные
    const additionalData = row.additional_data || {};
    
    return {
      id: row.id,
      campaignId: row.campaign_id,
      phoneNumber: row.phone,
      firstName,
      lastName,
      company: row.company,
      email: row.email,
      
      // Статус контакта
      status: row.status,
      
      // Метаданные
      customFields: additionalData,
      notes: additionalData.notes,
      
      // Битрикс24 интеграция
      bitrixContactId: row.bitrix_contact_id,
      bitrixLeadId: row.bitrix_lead_id,
      
      // Статистика звонков
      callAttempts: row.call_attempts || 0,
      ...(row.last_call_at && { lastCallAt: row.last_call_at }),
      ...(row.next_call_at && { nextCallAt: row.next_call_at }),
      
      // Временная зона (из additional_data или по умолчанию)
      timezone: additionalData.timezone || 'Europe/Moscow',
      
      // Временные метки
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }
}

/**
 * Singleton экземпляр модели контакта
 */
export const contactModel = new ContactModel(); 