/**
 * Скрипт для выполнения миграций базы данных
 * Читает SQL-файлы из папки database/migrations и выполняет их
 */

import { readdir, readFile } from 'fs/promises';
import path from 'path';
import { query, checkConnection, getDatabaseInfo } from '../config/database';

/**
 * Интерфейс для файла миграции
 */
interface MigrationFile {
  filename: string;
  order: number;
  content: string;
}

/**
 * Создание таблицы для отслеживания миграций
 */
async function createMigrationsTable(): Promise<void> {
  console.log('📋 Создаю таблицу для отслеживания миграций...');
  
  const createTableQuery = `
    CREATE TABLE IF NOT EXISTS migrations (
      id SERIAL PRIMARY KEY,
      filename VARCHAR(255) NOT NULL UNIQUE,
      executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      checksum VARCHAR(32)
    );
  `;
  
  await query(createTableQuery);
  console.log('✅ Таблица migrations создана');
}

/**
 * Получение списка уже выполненных миграций
 */
async function getExecutedMigrations(): Promise<string[]> {
  const result = await query<{ filename: string }>('SELECT filename FROM migrations ORDER BY executed_at');
  return result.rows.map(row => row.filename);
}

/**
 * Чтение файлов миграций
 */
async function readMigrationFiles(): Promise<MigrationFile[]> {
  console.log('📁 Читаю файлы миграций...');
  
  const migrationsDir = path.join(process.cwd(), '../database/migrations');
  const files = await readdir(migrationsDir);
  
  const migrationFiles: MigrationFile[] = [];
  
  for (const filename of files) {
    if (filename.endsWith('.sql')) {
      const filePath = path.join(migrationsDir, filename);
      const content = await readFile(filePath, 'utf-8');
      
      // Извлекаем номер порядка из имени файла (например, 001_init_schema.sql)
      const orderMatch = filename.match(/^(\d+)_/);
      const order = orderMatch && orderMatch[1] ? parseInt(orderMatch[1], 10) : 999;
      
      migrationFiles.push({
        filename,
        order,
        content
      });
    }
  }
  
  // Сортируем по порядку
  migrationFiles.sort((a, b) => a.order - b.order);
  
  console.log(`📋 Найдено ${migrationFiles.length} файлов миграций`);
  return migrationFiles;
}

/**
 * Выполнение миграции
 */
async function executeMigration(migration: MigrationFile): Promise<void> {
  console.log(`🔄 Выполняю миграцию: ${migration.filename}`);
  
  try {
    // Разделяем контент на отдельные SQL-команды
    const sqlCommands = splitSqlCommands(migration.content);
    
    // Выполняем каждую команду отдельно
    for (let i = 0; i < sqlCommands.length; i++) {
      const command = sqlCommands[i]?.trim();
      if (command && command.length > 0) {
        try {
          await query(command);
        } catch (error) {
          console.error(`❌ Ошибка в команде ${i + 1}:`, command.substring(0, 100) + '...');
          throw error;
        }
      }
    }
    
    // Записываем в таблицу миграций
    await query(
      'INSERT INTO migrations (filename) VALUES ($1)',
      [migration.filename]
    );
    
    console.log(`✅ Миграция ${migration.filename} выполнена успешно`);
  } catch (error) {
    console.error(`❌ Ошибка выполнения миграции ${migration.filename}:`, error);
    throw error;
  }
}

/**
 * Разделение SQL-контента на отдельные команды
 */
function splitSqlCommands(content: string): string[] {
  // Простое разделение для начала - просто выполняем весь файл как одну команду
  // Это менее надежно, но должно работать для большинства случаев
  return [content];
}

/**
 * Основная функция для выполнения миграций
 */
async function runMigrations(): Promise<void> {
  console.log('🚀 Начинаю выполнение миграций...\n');
  
  try {
    // Проверяем подключение к базе данных
    console.log('🔍 Проверяю подключение к базе данных...');
    const isConnected = await checkConnection();
    if (!isConnected) {
      throw new Error('Не удается подключиться к базе данных');
    }
    
    // Получаем информацию о базе данных
    const dbInfo = await getDatabaseInfo();
    console.log(`📊 Подключен к: ${dbInfo.version}`);
    console.log(`🔗 Активных соединений: ${dbInfo.activeConnections}/${dbInfo.totalConnections}\n`);
    
    // Создаем таблицу миграций если её нет
    await createMigrationsTable();
    
    // Получаем список уже выполненных миграций
    const executedMigrations = await getExecutedMigrations();
    console.log(`📋 Уже выполнено миграций: ${executedMigrations.length}`);
    
    // Читаем файлы миграций
    const migrationFiles = await readMigrationFiles();
    
    // Фильтруем миграции которые еще не выполнены
    const pendingMigrations = migrationFiles.filter(
      migration => !executedMigrations.includes(migration.filename)
    );
    
    console.log(`⏳ Ожидающих выполнения: ${pendingMigrations.length}\n`);
    
    if (pendingMigrations.length === 0) {
      console.log('✅ Все миграции уже выполнены');
      return;
    }
    
    // Выполняем миграции по порядку
    for (const migration of pendingMigrations) {
      await executeMigration(migration);
    }
    
    console.log('\n🎉 Все миграции выполнены успешно!');
    
  } catch (error) {
    console.error('\n❌ Ошибка выполнения миграций:', error);
    process.exit(1);
  }
}

// Запускаем миграции если файл запущен напрямую
if (require.main === module) {
  runMigrations()
    .then(() => {
      console.log('\n👋 Завершено');
      process.exit(0);
    })
    .catch((error) => {
      console.error('❌ Критическая ошибка:', error);
      process.exit(1);
    });
}

export { runMigrations }; 