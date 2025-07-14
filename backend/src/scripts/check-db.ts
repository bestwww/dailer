/**
 * Скрипт для проверки состояния базы данных
 */

import { query, checkConnection } from '../config/database';

async function checkDatabaseState(): Promise<void> {
  console.log('🔍 Проверяю состояние базы данных...\n');
  
  try {
    // Проверяем подключение
    const isConnected = await checkConnection();
    if (!isConnected) {
      throw new Error('Не удается подключиться к базе данных');
    }
    
    // Проверяем существующие таблицы
    console.log('📋 Существующие таблицы:');
    const tablesResult = await query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      ORDER BY table_name;
    `);
    
    if (tablesResult.rows.length === 0) {
      console.log('   Нет таблиц');
    } else {
      tablesResult.rows.forEach(row => {
        console.log(`   - ${row.table_name}`);
      });
    }
    
    // Проверяем структуру таблицы blacklist, если она существует
    console.log('\n🔍 Проверяю структуру таблицы blacklist:');
    try {
      const columnsResult = await query(`
        SELECT column_name, data_type, is_nullable, column_default 
        FROM information_schema.columns 
        WHERE table_name = 'blacklist' 
        AND table_schema = 'public'
        ORDER BY ordinal_position;
      `);
      
      if (columnsResult.rows.length === 0) {
        console.log('   Таблица blacklist не существует');
      } else {
        console.log('   Колонки в таблице blacklist:');
        columnsResult.rows.forEach(row => {
          console.log(`   - ${row.column_name}: ${row.data_type} (nullable: ${row.is_nullable})`);
        });
      }
    } catch (error) {
      console.log('   Ошибка при проверке структуры таблицы blacklist:', error);
    }
    
    // Проверяем индексы
    console.log('\n🔍 Проверяю существующие индексы:');
    const indexesResult = await query(`
      SELECT indexname, tablename 
      FROM pg_indexes 
      WHERE schemaname = 'public' 
      ORDER BY tablename, indexname;
    `);
    
    if (indexesResult.rows.length === 0) {
      console.log('   Нет индексов');
    } else {
      indexesResult.rows.forEach(row => {
        console.log(`   - ${row.indexname} (таблица: ${row.tablename})`);
      });
    }
    
    // Проверяем выполненные миграции
    console.log('\n📋 Выполненные миграции:');
    try {
      const migrationsResult = await query(`
        SELECT filename, executed_at 
        FROM migrations 
        ORDER BY executed_at;
      `);
      
      if (migrationsResult.rows.length === 0) {
        console.log('   Нет выполненных миграций');
      } else {
        migrationsResult.rows.forEach(row => {
          console.log(`   - ${row.filename} (${row.executed_at})`);
        });
      }
    } catch (error) {
      console.log('   Таблица migrations не существует');
    }
    
    console.log('\n✅ Проверка завершена');
    
  } catch (error) {
    console.error('❌ Ошибка при проверке базы данных:', error);
  }
}

// Запускаем проверку если файл запущен напрямую
if (require.main === module) {
  checkDatabaseState()
    .then(() => {
      console.log('\n👋 Завершено');
      process.exit(0);
    })
    .catch((error) => {
      console.error('❌ Критическая ошибка:', error);
      process.exit(1);
    });
} 