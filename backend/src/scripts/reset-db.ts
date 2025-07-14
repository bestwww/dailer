/**
 * Скрипт для сброса базы данных и повторного запуска миграций
 */

import { query, checkConnection } from '../config/database';
import { runMigrations } from './migrate';

async function resetDatabase(): Promise<void> {
  console.log('🔄 Сброс базы данных и повторный запуск миграций...\n');
  
  try {
    // Проверяем подключение
    const isConnected = await checkConnection();
    if (!isConnected) {
      throw new Error('Не удается подключиться к базе данных');
    }
    
    console.log('🗑️  Удаляю существующие таблицы...');
    
    // Удаляем таблицы в правильном порядке (с учетом внешних ключей)
    const tablesToDrop = [
      'blacklist_audit',
      'blacklist', 
      'call_results',
      'contacts',
      'campaigns',
      'scheduler_logs',
      'system_settings',
      'users',
      'migrations'
    ];
    
    // Удаляем представления
    await query('DROP VIEW IF EXISTS v_active_blacklist CASCADE;');
    await query('DROP VIEW IF EXISTS v_blacklist_stats CASCADE;');
    await query('DROP VIEW IF EXISTS v_scheduled_campaigns CASCADE;');
    
    // Удаляем функции
    await query('DROP FUNCTION IF EXISTS update_blacklist_updated_at() CASCADE;');
    await query('DROP FUNCTION IF EXISTS normalize_phone_number(TEXT) CASCADE;');
    await query('DROP FUNCTION IF EXISTS normalize_blacklist_phone() CASCADE;');
    await query('DROP FUNCTION IF EXISTS check_blacklist_expiry(TEXT) CASCADE;');
    await query('DROP FUNCTION IF EXISTS cleanup_expired_blacklist_entries() CASCADE;');
    await query('DROP FUNCTION IF EXISTS blacklist_audit_function() CASCADE;');
    await query('DROP FUNCTION IF EXISTS update_campaign_updated_at() CASCADE;');
    await query('DROP FUNCTION IF EXISTS update_contact_updated_at() CASCADE;');
    await query('DROP FUNCTION IF EXISTS update_user_updated_at() CASCADE;');
    
    // Удаляем типы enum
    await query('DROP TYPE IF EXISTS blacklist_reason_type CASCADE;');
    await query('DROP TYPE IF EXISTS campaign_status CASCADE;');
    await query('DROP TYPE IF EXISTS contact_status CASCADE;');
    await query('DROP TYPE IF EXISTS call_status CASCADE;');
    await query('DROP TYPE IF EXISTS user_role CASCADE;');
    await query('DROP TYPE IF EXISTS scheduler_status CASCADE;');
    
    // Удаляем таблицы
    for (const table of tablesToDrop) {
      await query(`DROP TABLE IF EXISTS ${table} CASCADE;`);
      console.log(`   ✅ Удалена таблица: ${table}`);
    }
    
    console.log('\n🚀 Запускаю миграции...');
    
    // Запускаем миграции
    await runMigrations();
    
    console.log('\n🎉 Сброс и миграции завершены успешно!');
    
  } catch (error) {
    console.error('\n❌ Ошибка при сбросе базы данных:', error);
    throw error;
  }
}

// Запускаем сброс если файл запущен напрямую
if (require.main === module) {
  resetDatabase()
    .then(() => {
      console.log('\n👋 Завершено');
      process.exit(0);
    })
    .catch((error) => {
      console.error('❌ Критическая ошибка:', error);
      process.exit(1);
    });
}

export { resetDatabase }; 