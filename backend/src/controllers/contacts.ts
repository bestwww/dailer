/**
 * Контроллер управления контактами
 * Обрабатывает операции CRUD, импорт и статистику контактов
 */

import { Request, Response } from 'express';
import { ContactModel } from '@/models/contact';
import { CampaignModel } from '@/models/campaign';
import { BlacklistModel } from '@/models/blacklist';
import { log } from '@/utils/logger';
import { ContactStatus, CreateContactRequest, UpdateContactRequest } from '@/types';

const contactModel = new ContactModel();
const campaignModel = new CampaignModel();
const blacklistModel = new BlacklistModel();

/**
 * Получение списка контактов с фильтрацией
 * GET /api/contacts
 */
export async function getContacts(req: Request, res: Response): Promise<void> {
  try {
    const page = parseInt(req.query.page as string) || 1;
    const limit = parseInt(req.query.limit as string) || 10;
    const campaignId = req.query.campaignId ? parseInt(req.query.campaignId as string) : undefined;
    const status = req.query.status as ContactStatus;
    const search = req.query.search as string;

    // Если указана кампания, получаем контакты по кампании
    if (campaignId) {
      const result = await contactModel.getContactsByCampaign(
        campaignId,
        page,
        limit,
        status,
        search
      );

      res.json({
        success: true,
        data: result.contacts,
        pagination: {
          page: result.page,
          limit,
          total: result.total,
          totalPages: result.totalPages,
        },
      });
    } else {
      // Если кампания не указана, получаем все контакты
      const result = await contactModel.getAllContacts(
        page,
        limit,
        status,
        search
      );

      res.json({
        success: true,
        data: result.contacts,
        pagination: {
          page: result.page,
          limit,
          total: result.total,
          totalPages: result.totalPages,
        },
      });
    }
  } catch (error) {
    log.error('Error fetching contacts:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
      message: 'Failed to fetch contacts',
    });
  }
}

/**
 * Получение контакта по ID
 * GET /api/contacts/:id
 */
export async function getContact(req: Request, res: Response): Promise<void> {
  try {
    const contactId = parseInt(req.params.id || '');

    if (isNaN(contactId)) {
      res.status(400).json({
        success: false,
        error: 'Invalid contact ID',
        message: 'Contact ID must be a valid number',
      });
      return;
    }

    const contact = await contactModel.getContactById(contactId);

    if (!contact) {
      res.status(404).json({
        success: false,
        error: 'Contact not found',
        message: `Contact with ID ${contactId} not found`,
      });
      return;
    }

    res.json({
      success: true,
      data: contact,
    });
  } catch (error) {
    log.error('Error fetching contact:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
      message: 'Failed to fetch contact',
    });
  }
}

/**
 * Создание нового контакта
 * POST /api/contacts
 */
export async function createContact(req: Request, res: Response): Promise<void> {
  try {
    const contactData: CreateContactRequest = req.body;

    // Валидация обязательных полей
    if (!contactData.phoneNumber || !contactData.campaignId) {
      res.status(400).json({
        success: false,
        error: 'Missing required fields',
        message: 'Phone number and campaign ID are required',
      });
      return;
    }

    // Проверяем, существует ли кампания
    const campaign = await campaignModel.getCampaignById(contactData.campaignId);
    if (!campaign) {
      res.status(404).json({
        success: false,
        error: 'Campaign not found',
        message: `Campaign with ID ${contactData.campaignId} not found`,
      });
      return;
    }

    // Нормализуем номер телефона
    const normalizedPhone = normalizePhoneNumber(contactData.phoneNumber);

    // Проверяем, нет ли номера в черном списке
    const blacklistCheck = await blacklistModel.isBlacklisted(normalizedPhone);
    if (blacklistCheck.isBlacklisted) {
      res.status(409).json({
        success: false,
        error: 'Phone number is blacklisted',
        message: `Phone number ${normalizedPhone} is in blacklist`,
      });
      return;
    }

    // Проверяем, нет ли дубликата в этой кампании
    const existingContact = await contactModel.findContactByPhone(
      contactData.campaignId,
      normalizedPhone
    );

    if (existingContact) {
      res.status(409).json({
        success: false,
        error: 'Duplicate contact',
        message: `Contact with phone ${normalizedPhone} already exists in this campaign`,
      });
      return;
    }

    // Создаем контакт
    const contact = await contactModel.createContact({
      ...contactData,
      phoneNumber: normalizedPhone,
    });

    log.info(`Contact created: ${contact.phoneNumber} for campaign ${contact.campaignId}`);

    res.status(201).json({
      success: true,
      data: contact,
      message: 'Contact created successfully',
    });
  } catch (error) {
    log.error('Error creating contact:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
      message: 'Failed to create contact',
    });
  }
}

/**
 * Обновление контакта
 * PUT /api/contacts/:id
 */
export async function updateContact(req: Request, res: Response): Promise<void> {
  try {
    const contactId = parseInt(req.params.id || '');
    const updateData: UpdateContactRequest = req.body;

    if (isNaN(contactId)) {
      res.status(400).json({
        success: false,
        error: 'Invalid contact ID',
        message: 'Contact ID must be a valid number',
      });
      return;
    }

    const contact = await contactModel.updateContact(contactId, updateData);

    if (!contact) {
      res.status(404).json({
        success: false,
        error: 'Contact not found',
        message: `Contact with ID ${contactId} not found`,
      });
      return;
    }

    log.info(`Contact updated: ${contact.phoneNumber} (ID: ${contactId})`);

    res.json({
      success: true,
      data: contact,
      message: 'Contact updated successfully',
    });
  } catch (error) {
    log.error('Error updating contact:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
      message: 'Failed to update contact',
    });
  }
}

/**
 * Удаление контакта
 * DELETE /api/contacts/:id
 */
export async function deleteContact(req: Request, res: Response): Promise<void> {
  try {
    const contactId = parseInt(req.params.id || '');

    if (isNaN(contactId)) {
      res.status(400).json({
        success: false,
        error: 'Invalid contact ID',
        message: 'Contact ID must be a valid number',
      });
      return;
    }

    const deleted = await contactModel.deleteContact(contactId);

    if (!deleted) {
      res.status(404).json({
        success: false,
        error: 'Contact not found',
        message: `Contact with ID ${contactId} not found`,
      });
      return;
    }

    log.info(`Contact deleted: ID ${contactId}`);

    res.json({
      success: true,
      message: 'Contact deleted successfully',
    });
  } catch (error) {
    log.error('Error deleting contact:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
      message: 'Failed to delete contact',
    });
  }
}

/**
 * Массовый импорт контактов
 * POST /api/contacts/import
 */
export async function importContacts(req: Request, res: Response): Promise<void> {
  try {
    const { campaignId, contacts } = req.body;

    if (!campaignId || !contacts || !Array.isArray(contacts)) {
      res.status(400).json({
        success: false,
        error: 'Invalid request data',
        message: 'Campaign ID and contacts array are required',
      });
      return;
    }

    // Проверяем, существует ли кампания
    const campaign = await campaignModel.getCampaignById(campaignId);
    if (!campaign) {
      res.status(404).json({
        success: false,
        error: 'Campaign not found',
        message: `Campaign with ID ${campaignId} not found`,
      });
      return;
    }

    // Нормализуем номера телефонов
    const normalizedContacts = contacts.map((contact: CreateContactRequest) => ({
      ...contact,
      phoneNumber: normalizePhoneNumber(contact.phoneNumber),
    }));

    // Выполняем импорт
    const result = await contactModel.importContacts(campaignId, normalizedContacts);

    log.info(`Import completed for campaign ${campaignId}: ${result.imported} imported, ${result.failed} failed`);

    res.json({
      success: true,
      data: result,
      message: `Import completed: ${result.imported} contacts imported, ${result.failed} failed`,
    });
  } catch (error) {
    log.error('Error importing contacts:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
      message: 'Failed to import contacts',
    });
  }
}

/**
 * Получение статистики контактов по кампании
 * GET /api/contacts/stats/:campaignId
 */
export async function getContactsStats(req: Request, res: Response): Promise<void> {
  try {
    const campaignId = parseInt(req.params.campaignId || '');

    if (isNaN(campaignId)) {
      res.status(400).json({
        success: false,
        error: 'Invalid campaign ID',
        message: 'Campaign ID must be a valid number',
      });
      return;
    }

    const stats = await contactModel.getContactsStatsByCampaign(campaignId);

    res.json({
      success: true,
      data: stats,
    });
  } catch (error) {
    log.error('Error fetching contacts stats:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
      message: 'Failed to fetch contacts stats',
    });
  }
}

/**
 * Получение контактов для звонков
 * GET /api/contacts/next-for-calling/:campaignId
 */
export async function getNextContactsForCalling(req: Request, res: Response): Promise<void> {
  try {
    const campaignId = parseInt(req.params.campaignId || '');
    const limit = parseInt(req.query.limit as string) || 10;
    const timezone = req.query.timezone as string;

    if (isNaN(campaignId)) {
      res.status(400).json({
        success: false,
        error: 'Invalid campaign ID',
        message: 'Campaign ID must be a valid number',
      });
      return;
    }

    const contacts = await contactModel.getNextContactsForCalling(
      campaignId,
      limit,
      timezone
    );

    res.json({
      success: true,
      data: contacts,
    });
  } catch (error) {
    log.error('Error fetching next contacts for calling:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
      message: 'Failed to fetch next contacts for calling',
    });
  }
}

/**
 * Нормализация номера телефона
 * Убирает лишние символы и приводит к единому формату
 */
function normalizePhoneNumber(phone: string): string {
  // Убираем все символы кроме цифр и +
  let normalized = phone.replace(/[^\d+]/g, '');
  
  // Если номер начинается с 8, заменяем на +7
  if (normalized.startsWith('8')) {
    normalized = '+7' + normalized.substring(1);
  }
  
  // Если номер начинается с 7 (без +), добавляем +
  if (normalized.startsWith('7') && !normalized.startsWith('+7')) {
    normalized = '+' + normalized;
  }
  
  // Если номер не начинается с +, добавляем +7
  if (!normalized.startsWith('+')) {
    normalized = '+7' + normalized;
  }
  
  return normalized;
} 