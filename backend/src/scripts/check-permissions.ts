#!/usr/bin/env node

/**
 * Скрипт для проверки разрешений пользователя
 */

import { userModel } from '@/models/user';
import { createPool, closePool } from '@/config/database';

/**
 * Проверка разрешений пользователя
 */
async function checkUserPermissions(username: string = 'admin'): Promise<void> {
  try {
    console.log(`🔍 Проверка разрешений пользователя: ${username}`);
    
    // Создаем пул соединений
    createPool();
    
    // Находим пользователя
    const user = await userModel.findByUsername(username);
    
    if (!user) {
      console.error(`❌ Пользователь ${username} не найден`);
      return;
    }
    
    console.log(`\n👤 Информация о пользователе:`);
    console.log(`   ID: ${user.id}`);
    console.log(`   Логин: ${user.username}`);
    console.log(`   Email: ${user.email}`);
    console.log(`   Роль: ${user.role}`);
    console.log(`   Активен: ${user.isActive}`);
    
    console.log(`\n🔐 Разрешения пользователя:`);
    
    if (user.permissions && typeof user.permissions === 'object') {
      Object.entries(user.permissions).forEach(([permission, hasPermission]) => {
        const status = hasPermission ? '✅' : '❌';
        console.log(`   ${status} ${permission}: ${hasPermission}`);
      });
    } else {
      console.log(`   ❌ Разрешения не найдены или имеют неверный формат`);
    }
    
    console.log(`\n📊 Итого разрешений: ${Object.keys(user.permissions || {}).length}`);
    
  } catch (error) {
    console.error('❌ Ошибка проверки разрешений:', error);
  } finally {
    await closePool();
  }
}

/**
 * Обновление разрешений пользователя
 */
async function updateUserPermissions(username: string, role: string): Promise<void> {
  try {
    console.log(`🔄 Обновление разрешений пользователя: ${username} (роль: ${role})`);
    
    createPool();
    
    // Находим пользователя
    const user = await userModel.findByUsername(username);
    
    if (!user) {
      console.error(`❌ Пользователь ${username} не найден`);
      return;
    }
    
    // Обновляем разрешения
    const updatedUser = await userModel.updateUserPermissionsByRole(user.id, role);
    
    if (updatedUser) {
      console.log(`✅ Разрешения пользователя ${username} обновлены`);
      console.log(`📊 Новые разрешения:`);
      
      Object.entries(updatedUser.permissions || {}).forEach(([permission, hasPermission]) => {
        const status = hasPermission ? '✅' : '❌';
        console.log(`   ${status} ${permission}: ${hasPermission}`);
      });
    } else {
      console.error(`❌ Не удалось обновить разрешения пользователя ${username}`);
    }
    
  } catch (error) {
    console.error('❌ Ошибка обновления разрешений:', error);
  } finally {
    await closePool();
  }
}

// Обработка аргументов командной строки
const args = process.argv.slice(2);
const command = args[0];

if (command === 'check') {
  const username = args[1] || 'admin';
  checkUserPermissions(username);
} else if (command === 'update') {
  const username = args[1];
  const role = args[2];
  
  if (!username || !role) {
    console.error('❌ Использование: npm run check-permissions update <username> <role>');
    console.error('   Доступные роли: admin, manager, user, viewer');
    process.exit(1);
  }
  
  updateUserPermissions(username, role);
} else {
  console.log('🔧 Скрипт проверки разрешений пользователей');
  console.log('');
  console.log('Использование:');
  console.log('  npm run check-permissions check [username]     - Проверить разрешения пользователя');
  console.log('  npm run check-permissions update <username> <role> - Обновить разрешения пользователя');
  console.log('');
  console.log('Доступные роли: admin, manager, user, viewer');
  console.log('');
  console.log('Примеры:');
  console.log('  npm run check-permissions check admin');
  console.log('  npm run check-permissions update admin admin');
} 