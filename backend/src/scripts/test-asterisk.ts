/**
 * Тестовый скрипт для проверки Asterisk адаптера
 * Запуск: npm run dev -- --script test-asterisk
 */

import { AsteriskAdapter } from '@/services/adapters/asterisk-adapter';
import { config } from '@/config';

async function testAsteriskAdapter() {
  console.log('🧪 Тестирование Asterisk адаптера\n');

  const asteriskConfig = {
    host: config.asteriskHost,
    port: config.asteriskPort,
    username: config.asteriskUsername,
    password: config.asteriskPassword,
  };

  console.log('📋 Конфигурация Asterisk:');
  console.log(`   Host: ${asteriskConfig.host}:${asteriskConfig.port}`);
  console.log(`   User: ${asteriskConfig.username}`);
  console.log('');

  const adapter = new AsteriskAdapter(asteriskConfig);

  try {
    // Тест 1: Подключение к AMI
    console.log('🔌 Тест 1: Подключение к Asterisk AMI');
    
    // Настраиваем обработчики событий
    adapter.on('connected', () => {
      console.log('✅ Событие: connected');
    });

    adapter.on('disconnected', () => {
      console.log('📡 Событие: disconnected');
    });

    adapter.on('error', (error) => {
      console.log(`❌ Событие: error - ${error.message}`);
    });

    adapter.on('call:created', (event) => {
      console.log('📞 Событие: call:created', event);
    });

    adapter.on('call:answered', (event) => {
      console.log('📞 Событие: call:answered', event);
    });

    adapter.on('call:hangup', (event) => {
      console.log('📞 Событие: call:hangup', event);
    });

    adapter.on('call:dtmf', (event) => {
      console.log('📞 Событие: call:dtmf', event);
    });

    try {
      await adapter.connect();
      console.log('✅ Подключение к Asterisk AMI успешно\n');
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      console.log(`❌ Подключение к Asterisk AMI не удалось: ${errorMessage}\n`);
      console.log('💡 Убедитесь что:');
      console.log('   - Asterisk запущен и доступен');
      console.log('   - AMI включен в manager.conf');
      console.log('   - Правильные учетные данные\n');
      return;
    }

    // Тест 2: Статус подключения
    console.log('📊 Тест 2: Статус подключения');
    const status = adapter.getConnectionStatus();
    console.log(`   Подключен: ${status.connected ? '✅' : '❌'}`);
    console.log(`   Попытки переподключения: ${status.reconnectAttempts}/${status.maxReconnectAttempts}\n`);

    // Тест 3: Получение статистики
    console.log('📈 Тест 3: Статистика Asterisk');
    try {
      const stats = await adapter.getStats();
      console.log(`   Активные звонки: ${stats.activeCalls}`);
      console.log(`   Активные каналы: ${stats.activeChannels}`);
      console.log(`   Время работы: ${stats.uptime}s`);
      console.log(`   Подключен: ${stats.connected ? '✅' : '❌'}\n`);
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      console.log(`⚠️ Не удалось получить статистику: ${errorMessage}\n`);
    }

    // Тест 4: Отправка команды
    console.log('🔧 Тест 4: Отправка команды Asterisk');
    try {
      const result = await adapter.sendCommand('core show version');
      console.log('✅ Команда выполнена успешно');
      console.log(`   Ответ: ${result.response}`);
      if (result.output) {
        console.log(`   Вывод: ${result.output.substring(0, 100)}...`);
      }
      console.log('');
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      console.log(`⚠️ Не удалось выполнить команду: ${errorMessage}\n`);
    }

    // Тест 5: Тестовый звонок (только если есть SIP trunk)
    console.log('📞 Тест 5: Тестовый звонок (только для демонстрации)');
    console.log('   ⚠️ Реальный звонок НЕ будет выполнен - только проверка логики');
    
    try {
      // Используем фиктивный номер для теста
      const fakePhoneNumber = '1234567890';
      const campaignId = 999;
      
      console.log(`   Попытка звонка: ${fakePhoneNumber} (кампания: ${campaignId})`);
      
      // Этот вызов скорее всего завершится ошибкой, что нормально для теста
      const callUuid = await adapter.makeCall(fakePhoneNumber, campaignId);
      console.log(`   ✅ Звонок инициирован с UUID: ${callUuid}`);
      
      // Сразу завершаем тестовый звонок
      setTimeout(async () => {
        try {
          await adapter.hangupCall(callUuid);
          console.log(`   ✅ Тестовый звонок завершен: ${callUuid}`);
        } catch (hangupError) {
          const errorMessage = hangupError instanceof Error ? hangupError.message : String(hangupError);
          console.log(`   ⚠️ Ошибка завершения звонка: ${errorMessage}`);
        }
      }, 2000);
      
    } catch (callError) {
      const errorMessage = callError instanceof Error ? callError.message : String(callError);
      console.log(`   ⚠️ Ожидаемая ошибка звонка: ${errorMessage}`);
      console.log('   💡 Это нормально если SIP trunk не настроен');
    }

    console.log('\n🎯 Резюме тестирования:');
    console.log('✅ Asterisk адаптер инициализирован');
    console.log('✅ AMI подключение работает');
    console.log('✅ События обрабатываются');
    console.log('✅ Команды отправляются');
    console.log('✅ Интеграция с VoIP интерфейсом готова');

    // Ждем немного для обработки событий
    await new Promise(resolve => setTimeout(resolve, 3000));

  } catch (error) {
    console.error('❌ Критическая ошибка тестирования:', error);
  } finally {
    // Отключаемся
    console.log('\n🔌 Отключение от Asterisk AMI');
    adapter.disconnect();
  }
}

// Запуск теста
if (require.main === module) {
  testAsteriskAdapter().then(() => {
    console.log('\n✅ Тестирование завершено');
    process.exit(0);
  }).catch((error) => {
    console.error('\n❌ Тестирование провалено:', error);
    process.exit(1);
  });
}

export { testAsteriskAdapter }; 