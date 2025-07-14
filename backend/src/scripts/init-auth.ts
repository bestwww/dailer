#!/usr/bin/env node

/**
 * Скрипт для инициализации системы аутентификации
 * Создает необходимые таблицы и пользователя-администратора
 */

import { userModel } from '@/models/user';
import { tokenBlacklistModel } from '@/models/token-blacklist';
import { createPool, closePool } from '@/config/database';

/**
 * Основная функция инициализации
 */
async function initializeAuth(): Promise<void> {
  try {
    console.log('🔧 Инициализация системы аутентификации...');
    
    // Создаем пул соединений
    createPool();
    
    // Создаем таблицы
    console.log('📋 Создание таблиц...');
    await userModel.createTable();
    await tokenBlacklistModel.createTable();
    console.log('✅ Таблицы созданы');
    
    // Создаем администратора по умолчанию
    console.log('👤 Создание пользователя-администратора...');
    const admin = await userModel.createDefaultAdmin();
    console.log(`✅ Администратор создан: ${admin.username}`);
    
    console.log('\n🎉 Инициализация завершена!');
    console.log('📝 Учетные данные администратора:');
    console.log(`   Логин: ${admin.username}`);
    console.log(`   Пароль: admin123`);
    console.log('\n⚠️  ВНИМАНИЕ: Обязательно измените пароль после первого входа!');
    
  } catch (error) {
    console.error('❌ Ошибка инициализации:', error);
    process.exit(1);
  } finally {
    // Закрываем пул соединений
    await closePool();
  }
}

/**
 * Функция для очистки просроченных токенов
 */
async function cleanupExpiredTokens(): Promise<void> {
  try {
    console.log('🧹 Очистка просроченных токенов...');
    
    createPool();
    await tokenBlacklistModel.cleanupExpiredTokens();
    
    console.log('✅ Просроченные токены удалены');
    
  } catch (error) {
    console.error('❌ Ошибка очистки токенов:', error);
    process.exit(1);
  } finally {
    await closePool();
  }
}

/**
 * Функция для создания нового пользователя
 */
async function createUser(username: string, email: string, password: string, role: string): Promise<void> {
  try {
    console.log(`👤 Создание пользователя: ${username}...`);
    
    createPool();
    
    const hashedPassword = await userModel.hashPassword(password);
    
    const userData = {
      username,
      email,
      passwordHash: hashedPassword,
      role: role as 'admin' | 'manager' | 'user' | 'viewer',
      permissions: userModel.getDefaultPermissions(role),
      isActive: true,
      isVerified: true,
      timezone: 'UTC',
      language: 'ru'
    };
    
    const user = await userModel.createUser(userData);
    console.log(`✅ Пользователь создан: ${user.username} (${user.email})`);
    
  } catch (error) {
    console.error('❌ Ошибка создания пользователя:', error);
    process.exit(1);
  } finally {
    await closePool();
  }
}



// Обработка аргументов командной строки
const args = process.argv.slice(2);
const command = args[0] || '';

switch (command) {
  case 'init':
    initializeAuth();
    break;
  case 'cleanup':
    cleanupExpiredTokens();
    break;
  case 'create-user':
    if (args.length < 5) {
      console.error('❌ Использование: npm run auth:create-user <username> <email> <password> <role>');
      process.exit(1);
    }
    createUser(args[1] || '', args[2] || '', args[3] || '', args[4] || '');
    break;
  default:
    console.log('📖 Доступные команды:');
    console.log('  init                                    - Инициализация системы аутентификации');
    console.log('  cleanup                                 - Очистка просроченных токенов');
    console.log('  create-user <username> <email> <password> <role> - Создание нового пользователя');
    break;
} 