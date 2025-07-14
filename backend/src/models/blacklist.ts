/**
 * Модель Blacklist - управление черным списком номеров
 */

import { BaseModel } from '@/config/database';
import { 
  BlacklistEntry, 
  BlacklistReason,
  CreateBlacklistRequest, 
  UpdateBlacklistRequest,
  BulkBlacklistRequest,
  BlacklistStats
} from '@/types';
import { log } from '@/utils/logger';

export class BlacklistModel extends BaseModel {
  private tableName = 'blacklist';

  /**
   * Добавление номера в черный список
   */
  async addToBlacklist(data: CreateBlacklistRequest, addedBy?: number): Promise<BlacklistEntry> {
    try {
      // Нормализация номера телефона
      const normalizedPhone = this.normalizePhoneNumber(data.phone);

      // Проверка существования номера
      const existing = await this.getByPhone(normalizedPhone);
      if (existing && existing.isActive) {
        throw new Error(`Номер ${normalizedPhone} уже находится в черном списке`);
      }

      const blacklistData = {
        phone: normalizedPhone,
        reason: data.reason || null,
        reason_type: data.reasonType,
        added_by: addedBy || null,
        source: data.source || 'manual',
        is_active: true,
        expires_at: data.expiresAt || null,
        attempt_count: 0,
        notes: data.notes || null,
      };

      const entry = await this.create<any>(this.tableName, blacklistData);

      log.info(`Added phone ${normalizedPhone} to blacklist (ID: ${entry.id})`);
      return this.formatBlacklistEntry(entry);

    } catch (error) {
      log.error('Failed to add to blacklist:', error);
      throw error;
    }
  }

  /**
   * Массовое добавление номеров в черный список
   */
  async bulkAddToBlacklist(data: BulkBlacklistRequest, addedBy?: number): Promise<{
    added: number;
    skipped: number;
    errors: Array<{ phone: string; error: string }>;
  }> {
    try {
      const result = {
        added: 0,
        skipped: 0,
        errors: [] as Array<{ phone: string; error: string }>
      };

      for (const phone of data.phones) {
        try {
          const normalizedPhone = this.normalizePhoneNumber(phone);

          // Проверка существования номера
          const existing = await this.getByPhone(normalizedPhone);
          if (existing && existing.isActive) {
            result.skipped++;
            continue;
          }

          const requestData: CreateBlacklistRequest = {
            phone: normalizedPhone,
            reasonType: data.reasonType,
            source: data.source || 'bulk_import'
          };
          
          if (data.reason) requestData.reason = data.reason;
          if (data.notes) requestData.notes = data.notes;
          
          await this.addToBlacklist(requestData, addedBy);

          result.added++;

        } catch (error) {
          result.errors.push({
            phone,
            error: error instanceof Error ? error.message : 'Unknown error'
          });
        }
      }

      log.info(`Bulk blacklist operation: ${result.added} added, ${result.skipped} skipped, ${result.errors.length} errors`);
      return result;

    } catch (error) {
      log.error('Failed to bulk add to blacklist:', error);
      throw error;
    }
  }

  /**
   * Получение записи по номеру телефона
   */
  async getByPhone(phone: string): Promise<BlacklistEntry | null> {
    try {
      const normalizedPhone = this.normalizePhoneNumber(phone);
      
      const result = await this.query<any>(
        'SELECT * FROM blacklist WHERE phone = $1 ORDER BY created_at DESC LIMIT 1',
        [normalizedPhone]
      );

      return result.rows.length > 0 ? this.formatBlacklistEntry(result.rows[0]) : null;

    } catch (error) {
      log.error(`Failed to get blacklist entry for phone ${phone}:`, error);
      throw error;
    }
  }

  /**
   * Проверка, находится ли номер в черном списке
   */
  async isBlacklisted(phone: string): Promise<{
    isBlacklisted: boolean;
    entry?: BlacklistEntry;
    reason?: string;
  }> {
    try {
      const normalizedPhone = this.normalizePhoneNumber(phone);
      
      const result = await this.query<any>(
        `SELECT * FROM blacklist 
         WHERE phone = $1 
         AND is_active = true 
         AND (expires_at IS NULL OR expires_at > NOW())
         ORDER BY created_at DESC 
         LIMIT 1`,
        [normalizedPhone]
      );

      if (result.rows.length === 0) {
        return { isBlacklisted: false };
      }

      const entry = this.formatBlacklistEntry(result.rows[0]);
      return {
        isBlacklisted: true,
        entry,
        reason: entry.reason || `Заблокирован по причине: ${entry.reasonType}`
      };

    } catch (error) {
      log.error(`Failed to check blacklist status for phone ${phone}:`, error);
      throw error;
    }
  }

  /**
   * Получение записи по ID
   */
  async getById(id: number): Promise<BlacklistEntry | null> {
    try {
      const entry = await this.findById<any>(this.tableName, id);
      return entry ? this.formatBlacklistEntry(entry) : null;
    } catch (error) {
      log.error(`Failed to get blacklist entry ${id}:`, error);
      throw error;
    }
  }

  /**
   * Получение списка записей с пагинацией
   */
  async getBlacklistEntries(
    page: number = 1,
    limit: number = 10,
    reasonType?: BlacklistReason,
    isActive?: boolean,
    search?: string
  ): Promise<{
    entries: BlacklistEntry[];
    total: number;
    page: number;
    totalPages: number;
  }> {
    try {
      let whereClause = '';
      const params: any[] = [];

      if (reasonType) {
        whereClause += 'reason_type = $1';
        params.push(reasonType);
      }

      if (isActive !== undefined) {
        whereClause += whereClause ? ' AND ' : '';
        whereClause += `is_active = $${params.length + 1}`;
        params.push(isActive);
      }

      if (search) {
        whereClause += whereClause ? ' AND ' : '';
        whereClause += `(phone ILIKE $${params.length + 1} OR reason ILIKE $${params.length + 1} OR notes ILIKE $${params.length + 1})`;
        params.push(`%${search}%`);
      }

      const result = await this.paginate<any>(
        this.tableName,
        page,
        limit,
        whereClause || undefined,
        'created_at DESC',
        params.length > 0 ? params : undefined
      );

      return {
        entries: result.items.map(item => this.formatBlacklistEntry(item)),
        total: result.total,
        page: result.page,
        totalPages: result.totalPages,
      };

    } catch (error) {
      log.error('Failed to get blacklist entries:', error);
      throw error;
    }
  }

  /**
   * Обновление записи черного списка
   */
  async updateBlacklistEntry(id: number, data: UpdateBlacklistRequest): Promise<BlacklistEntry | null> {
    try {
      const updateData: any = {};

      if (data.reason !== undefined) updateData.reason = data.reason;
      if (data.reasonType !== undefined) updateData.reason_type = data.reasonType;
      if (data.isActive !== undefined) updateData.is_active = data.isActive;
      if (data.expiresAt !== undefined) updateData.expires_at = data.expiresAt;
      if (data.notes !== undefined) updateData.notes = data.notes;

      const entry = await this.update<any>(this.tableName, id, updateData);

      if (entry) {
        log.info(`Updated blacklist entry: ${entry.phone} (ID: ${id})`);
        return this.formatBlacklistEntry(entry);
      }

      return null;

    } catch (error) {
      log.error(`Failed to update blacklist entry ${id}:`, error);
      throw error;
    }
  }

  /**
   * Удаление записи из черного списка
   */
  async removeFromBlacklist(id: number): Promise<boolean> {
    try {
      // Не удаляем физически, а деактивируем
      const updated = await this.update(this.tableName, id, { is_active: false });
      
      if (updated) {
        log.info(`Removed from blacklist ID: ${id}`);
        return true;
      }
      
      return false;
    } catch (error) {
      log.error(`Failed to remove from blacklist ${id}:`, error);
      throw error;
    }
  }

  /**
   * Физическое удаление записи
   */
  async deleteBlacklistEntry(id: number): Promise<boolean> {
    try {
      const deleted = await this.delete(this.tableName, id);
      
      if (deleted) {
        log.info(`Deleted blacklist entry ID: ${id}`);
      }
      
      return deleted;
    } catch (error) {
      log.error(`Failed to delete blacklist entry ${id}:`, error);
      throw error;
    }
  }

  /**
   * Увеличение счетчика попыток звонков
   */
  async incrementAttemptCount(phone: string): Promise<void> {
    try {
      const normalizedPhone = this.normalizePhoneNumber(phone);
      
      await this.query(
        `UPDATE blacklist 
         SET attempt_count = attempt_count + 1, 
             last_attempt_at = NOW()
         WHERE phone = $1 AND is_active = true`,
        [normalizedPhone]
      );

      log.debug(`Incremented attempt count for blacklisted phone: ${normalizedPhone}`);

    } catch (error) {
      log.error(`Failed to increment attempt count for phone ${phone}:`, error);
      throw error;
    }
  }

  /**
   * Получение статистики черного списка
   */
  async getBlacklistStats(): Promise<BlacklistStats> {
    try {
      // Общая статистика
      const overallStats = await this.query<any>(`
        SELECT 
          COUNT(*) as total_entries,
          COUNT(CASE WHEN is_active = true THEN 1 END) as active_entries,
          COUNT(CASE WHEN expires_at IS NOT NULL AND expires_at <= NOW() THEN 1 END) as expired_entries
        FROM blacklist
      `);

      // Статистика заблокированных звонков
      const callStats = await this.query<any>(`
        SELECT 
          COUNT(CASE WHEN DATE(last_attempt_at) = CURRENT_DATE THEN 1 END) as blocked_calls_today,
          SUM(attempt_count) as blocked_calls_total
        FROM blacklist 
        WHERE is_active = true
      `);

      // Топ причин блокировки
      const reasonStats = await this.query<any>(`
        SELECT 
          reason_type,
          COUNT(*) as count
        FROM blacklist 
        WHERE is_active = true
        GROUP BY reason_type
        ORDER BY count DESC
        LIMIT 10
      `);

      const stats = overallStats.rows[0];
      const calls = callStats.rows[0];

      return {
        totalEntries: parseInt(stats.total_entries || '0', 10),
        activeEntries: parseInt(stats.active_entries || '0', 10),
        expiredEntries: parseInt(stats.expired_entries || '0', 10),
        blockedCallsToday: parseInt(calls.blocked_calls_today || '0', 10),
        blockedCallsTotal: parseInt(calls.blocked_calls_total || '0', 10),
        topReasons: reasonStats.rows.map(row => ({
          reasonType: row.reason_type,
          count: parseInt(row.count, 10)
        }))
      };

    } catch (error) {
      log.error('Failed to get blacklist statistics:', error);
      throw error;
    }
  }

  /**
   * Очистка истекших записей
   */
  async cleanupExpiredEntries(): Promise<number> {
    try {
      const result = await this.query<any>(
        'UPDATE blacklist SET is_active = false WHERE expires_at IS NOT NULL AND expires_at <= NOW() AND is_active = true'
      );

      const deactivated = result.rowCount || 0;
      
      if (deactivated > 0) {
        log.info(`Deactivated ${deactivated} expired blacklist entries`);
      }

      return deactivated;

    } catch (error) {
      log.error('Failed to cleanup expired blacklist entries:', error);
      throw error;
    }
  }

  /**
   * Экспорт черного списка в CSV
   */
  async exportToCSV(): Promise<string> {
    try {
      const result = await this.query<any>(
        `SELECT phone, reason, reason_type, source, is_active, 
                expires_at, attempt_count, created_at, notes
         FROM blacklist 
         ORDER BY created_at DESC`
      );

      const headers = [
        'Телефон', 'Причина', 'Тип причины', 'Источник', 'Активен',
        'Истекает', 'Попытки звонков', 'Дата добавления', 'Заметки'
      ];

      const csvLines = [headers.join(',')];

      for (const row of result.rows) {
        const line = [
          `"${row.phone}"`,
          `"${row.reason || ''}"`,
          `"${row.reason_type}"`,
          `"${row.source || ''}"`,
          row.is_active ? 'Да' : 'Нет',
          row.expires_at ? `"${new Date(row.expires_at).toLocaleDateString()}"` : '',
          row.attempt_count || 0,
          `"${new Date(row.created_at).toLocaleDateString()}"`,
          `"${row.notes || ''}"`
        ];
        csvLines.push(line.join(','));
      }

      return csvLines.join('\n');

    } catch (error) {
      log.error('Failed to export blacklist to CSV:', error);
      throw error;
    }
  }

  /**
   * Нормализация номера телефона
   */
  private normalizePhoneNumber(phone: string): string {
    // Удаляем все символы кроме цифр и плюса
    let normalized = phone.replace(/[^\d+]/g, '');
    
    // Если номер начинается с 8, заменяем на +7
    if (normalized.startsWith('8')) {
      normalized = '+7' + normalized.substring(1);
    }
    
    // Если номер начинается с 7 (без +), добавляем +
    if (normalized.startsWith('7') && !normalized.startsWith('+7')) {
      normalized = '+' + normalized;
    }

    // Если номер не имеет кода страны, добавляем +7
    if (!normalized.startsWith('+')) {
      normalized = '+7' + normalized;
    }

    return normalized;
  }

  /**
   * Форматирование данных записи для API
   */
  private formatBlacklistEntry(row: any): BlacklistEntry {
    return {
      id: row.id,
      phone: row.phone,
      reason: row.reason,
      reasonType: row.reason_type,
      addedBy: row.added_by,
      addedByName: row.added_by_name,
      source: row.source,
      isActive: row.is_active,
      ...(row.expires_at && { expiresAt: new Date(row.expires_at) }),
      ...(row.last_attempt_at && { lastAttemptAt: new Date(row.last_attempt_at) }),
      attemptCount: row.attempt_count || 0,
      notes: row.notes,
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at),
    };
  }
}

/**
 * Singleton экземпляр модели черного списка
 */
export const blacklistModel = new BlacklistModel(); 