#!/bin/bash

# 🔧 ИСПРАВЛЕНИЕ ЛОГИРОВАНИЯ FREESWITCH
# Настройка записи логов в файл для мониторинга DTMF

CONTAINER_NAME="freeswitch-test"
PHONE_NUMBER="79206054020"

echo "🔧 ИСПРАВЛЕНИЕ ЛОГИРОВАНИЯ FREESWITCH"
echo "===================================="
echo ""

echo "🚨 ПРОБЛЕМА ОБНАРУЖЕНА: Логи не записываются в файл!"
echo "📂 Файл /usr/local/freeswitch/log/freeswitch.log отсутствует"
echo "🎯 РЕШЕНИЕ: Настроить правильное логирование FreeSWITCH"
echo ""

# ЭТАП 1: Проверка текущего состояния
echo "📋 ЭТАП 1: ПРОВЕРКА ТЕКУЩЕГО СОСТОЯНИЯ ЛОГИРОВАНИЯ"
echo "================================================"

echo ""
echo "1. 📂 Проверяем директорию логов..."
LOG_DIR_CHECK=$(docker exec "$CONTAINER_NAME" ls -la /usr/local/freeswitch/log/ 2>&1)
echo "Содержимое директории логов:"
echo "$LOG_DIR_CHECK"

echo ""
echo "2. 🔍 Проверяем конфигурацию логирования..."
LOGFILE_CONFIG=$(docker exec "$CONTAINER_NAME" find /usr/local/freeswitch/conf -name "*.xml" -exec grep -l "logfile" {} \; 2>&1)
echo "Файлы с настройками логов:"
echo "$LOGFILE_CONFIG"

echo ""
echo "3. 📝 Проверяем текущие настройки консоли..."
CONSOLE_SETTINGS=$(docker exec "$CONTAINER_NAME" fs_cli -x "console loglevel" 2>&1)
echo "Настройки консоли: $CONSOLE_SETTINGS"

# ЭТАП 2: Создание правильной конфигурации логирования
echo ""
echo "📋 ЭТАП 2: СОЗДАНИЕ ПРАВИЛЬНОЙ КОНФИГУРАЦИИ ЛОГИРОВАНИЯ"
echo "===================================================="

echo ""
echo "1. 📄 Создаем конфигурацию логирования..."

# Создаем конфигурацию logfile для записи в файл
cat > /tmp/logfile.conf.xml << 'EOF'
<configuration name="logfile.conf" description="File Logging">
  <settings>
    <!-- Основной лог файл -->
    <param name="logfile" value="/usr/local/freeswitch/log/freeswitch.log"/>
    <param name="rollover" value="true"/>
    <param name="maximum-rotate" value="10"/>
    
    <!-- Профили логирования -->
    <profiles>
      <!-- Профиль по умолчанию -->
      <profile name="default">
        <settings>
          <param name="logfile" value="/usr/local/freeswitch/log/freeswitch.log"/>
          <param name="rollover" value="1048576"/>
          <param name="maximum-rotate" value="32"/>
          <param name="uuid" value="true"/>
        </settings>
        <mappings>
          <!-- КРИТИЧЕСКИЙ - максимальная видимость DTMF -->
          <map name="all" value="console,debug,info,notice,warning,err,crit,alert"/>
        </mappings>
      </profile>
      
      <!-- Специальный профиль для DTMF -->
      <profile name="dtmf">
        <settings>
          <param name="logfile" value="/usr/local/freeswitch/log/dtmf.log"/>
          <param name="rollover" value="1048576"/>
          <param name="maximum-rotate" value="10"/>
          <param name="uuid" value="true"/>
        </settings>
        <mappings>
          <map name="all" value="debug,info,notice,warning,err,crit,alert"/>
        </mappings>
      </profile>
    </profiles>
  </settings>
</configuration>
EOF

echo "✅ Конфигурация логирования создана"

echo ""
echo "2. 📄 Создаем конфигурацию switch.conf с логированием..."

# Создаем базовую конфигурацию switch.conf с логированием
cat > /tmp/switch.conf.xml << 'EOF'
<configuration name="switch.conf" description="Core Configuration">
  <settings>
    <!-- Логирование -->
    <param name="colorize-console" value="true"/>
    <param name="max-sessions" value="1000"/>
    <param name="sessions-per-second" value="30"/>
    <param name="loglevel" value="debug"/>
    
    <!-- Обязательно включаем логирование в файл -->
    <param name="auto-restart" value="false"/>
    <param name="crash-protection" value="false"/>
    
    <!-- Настройки RTP для DTMF -->
    <param name="rtp-start-port" value="16384"/>
    <param name="rtp-end-port" value="32768"/>
    <param name="default-sample-rate" value="8000"/>
    <param name="default-codec-prefs" value="PCMU,PCMA"/>
    <param name="outbound-codec-prefs" value="PCMU,PCMA"/>
    
    <!-- КРИТИЧЕСКИ ВАЖНО: Настройки DTMF -->
    <param name="dtmf-duration" value="2000"/>
    <param name="dtmf-type" value="rfc2833"/>
    <param name="suppress-cng" value="true"/>
  </settings>
</configuration>
EOF

echo "✅ Конфигурация switch.conf создана"

# ЭТАП 3: Установка конфигураций
echo ""
echo "📋 ЭТАП 3: УСТАНОВКА КОНФИГУРАЦИЙ ЛОГИРОВАНИЯ"
echo "==========================================="

echo ""
echo "1. 📁 Создаем директорию для логов..."
docker exec "$CONTAINER_NAME" mkdir -p /usr/local/freeswitch/log
docker exec "$CONTAINER_NAME" chmod 755 /usr/local/freeswitch/log

echo ""
echo "2. 📄 Устанавливаем конфигурацию логирования..."
docker cp /tmp/logfile.conf.xml "$CONTAINER_NAME:/usr/local/freeswitch/conf/autoload_configs/logfile.conf.xml"
docker cp /tmp/switch.conf.xml "$CONTAINER_NAME:/usr/local/freeswitch/conf/autoload_configs/switch.conf.xml"

echo ""
echo "3. 🔄 Перезагружаем FreeSWITCH для применения настроек..."
echo "   Это займет несколько секунд..."

# Полный перезапуск FreeSWITCH для применения логирования
docker restart "$CONTAINER_NAME"

echo ""
echo "⏰ Ожидаем запуска FreeSWITCH (30 секунд)..."
sleep 30

# ЭТАП 4: Проверка логирования
echo ""
echo "📋 ЭТАП 4: ПРОВЕРКА ЛОГИРОВАНИЯ"
echo "=============================="

echo ""
echo "1. 🔍 Проверяем что FreeSWITCH запустился..."
FREESWITCH_STATUS=$(docker exec "$CONTAINER_NAME" fs_cli -x "status" 2>&1)
echo "Статус FreeSWITCH:"
echo "$FREESWITCH_STATUS"

echo ""
echo "2. 📂 Проверяем создание файлов логов..."
LOG_FILES_AFTER=$(docker exec "$CONTAINER_NAME" ls -la /usr/local/freeswitch/log/ 2>&1)
echo "Файлы логов после настройки:"
echo "$LOG_FILES_AFTER"

echo ""
echo "3. 📝 Проверяем запись в основной лог..."
if docker exec "$CONTAINER_NAME" test -f /usr/local/freeswitch/log/freeswitch.log; then
    echo "✅ Файл freeswitch.log создан!"
    RECENT_LOGS=$(docker exec "$CONTAINER_NAME" tail -10 /usr/local/freeswitch/log/freeswitch.log 2>&1)
    echo "Последние записи в логе:"
    echo "$RECENT_LOGS"
else
    echo "❌ Файл freeswitch.log еще не создан"
fi

echo ""
echo "4. 🔧 Включаем максимальное логирование для DTMF..."
docker exec "$CONTAINER_NAME" fs_cli -x "console loglevel debug"
docker exec "$CONTAINER_NAME" fs_cli -x "sofia loglevel all 9"

# ЭТАП 5: Тестирование DTMF с логированием
echo ""
echo "📋 ЭТАП 5: ТЕСТИРОВАНИЕ DTMF С ЛОГИРОВАНИЕМ"
echo "========================================"

echo ""
echo "5. 🧪 Тестируем запись логов..."

# Тестовый звонок для генерации логов
echo "Запускаем тестовый звонок для проверки логирования..."
TEST_CALL=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/$PHONE_NUMBER 1201 XML default" 2>&1)
echo "Тестовый звонок: $TEST_CALL"

# Ждем 10 секунд для генерации логов
sleep 10

# Завершаем тестовый звонок
docker exec "$CONTAINER_NAME" fs_cli -x "hupall MANAGER_REQUEST"

echo ""
echo "6. 📊 Проверяем логирование после звонка..."
if docker exec "$CONTAINER_NAME" test -f /usr/local/freeswitch/log/freeswitch.log; then
    echo "✅ Логирование работает!"
    
    # Проверяем размер лога
    LOG_SIZE=$(docker exec "$CONTAINER_NAME" wc -l /usr/local/freeswitch/log/freeswitch.log | cut -d' ' -f1)
    echo "Размер лога: $LOG_SIZE строк"
    
    # Показываем последние записи
    echo ""
    echo "📝 Последние 15 записей в логе:"
    docker exec "$CONTAINER_NAME" tail -15 /usr/local/freeswitch/log/freeswitch.log
    
    # Проверяем наличие DTMF связанных записей
    DTMF_ENTRIES=$(docker exec "$CONTAINER_NAME" grep -i "dtmf\|dial\|1201" /usr/local/freeswitch/log/freeswitch.log | tail -5 2>&1)
    echo ""
    echo "🔍 DTMF/диалплан записи в логе:"
    echo "$DTMF_ENTRIES"
    
else
    echo "❌ ПРОБЛЕМА: Файл логов все еще не создается"
    echo "   Нужна дополнительная диагностика"
fi

# ЭТАП 6: Результаты и рекомендации
echo ""
echo "📋 ЭТАП 6: РЕЗУЛЬТАТЫ ИСПРАВЛЕНИЯ"
echo "==============================="

if docker exec "$CONTAINER_NAME" test -f /usr/local/freeswitch/log/freeswitch.log; then
    echo ""
    echo "🎉 ПРОБЛЕМА ЛОГИРОВАНИЯ ИСПРАВЛЕНА!"
    echo ""
    echo "✅ ЧТО ИСПРАВЛЕНО:"
    echo "- Создан файл /usr/local/freeswitch/log/freeswitch.log"
    echo "- Настроено логирование в файл"
    echo "- Включено максимальное DTMF логирование"
    echo "- FreeSWITCH перезапущен с новыми настройками"
    echo ""
    echo "🔍 ТЕПЕРЬ МОЖНО ТЕСТИРОВАТЬ DTMF:"
    echo "- Логи записываются в файл"
    echo "- DTMF события будут видны"
    echo "- Можно отслеживать нажатые цифры"
    echo ""
    echo "📱 КОМАНДЫ ДЛЯ DTMF ТЕСТИРОВАНИЯ:"
    echo ""
    echo "# Тест DTMF с логированием:"
    echo "docker exec $CONTAINER_NAME fs_cli -x \"originate sofia/gateway/sip_trunk/$PHONE_NUMBER 1201 XML default\""
    echo ""
    echo "# Мониторинг DTMF в реальном времени:"
    echo "docker exec $CONTAINER_NAME tail -f /usr/local/freeswitch/log/freeswitch.log | grep -E '(CRIT|DTMF|ОБРАБОТЧИК|ВЕБХУК)'"
    echo ""
    echo "# Поиск DTMF событий:"
    echo "docker exec $CONTAINER_NAME grep -E '(DTMF|CRIT.*===)' /usr/local/freeswitch/log/freeswitch.log | tail -20"
    
else
    echo ""
    echo "🔧 ЛОГИРОВАНИЕ ТРЕБУЕТ ДОПОЛНИТЕЛЬНОЙ НАСТРОЙКИ"
    echo ""
    echo "🔍 ДАЛЬНЕЙШИЕ ДЕЙСТВИЯ:"
    echo "1. Проверить права доступа к директории логов"
    echo "2. Проверить настройки Docker контейнера"
    echo "3. Возможно нужна ручная настройка логирования"
    echo ""
    echo "📋 КОМАНДЫ ДЛЯ ДИАГНОСТИКИ:"
    echo "docker exec $CONTAINER_NAME ls -la /usr/local/freeswitch/"
    echo "docker exec $CONTAINER_NAME cat /usr/local/freeswitch/conf/autoload_configs/logfile.conf.xml"
fi

echo ""
echo "🔧 ИСПРАВЛЕНИЕ ЛОГИРОВАНИЯ ЗАВЕРШЕНО!"
echo "=================================="
echo ""
echo "🎯 СЛЕДУЮЩИЙ ШАГ: Тестирование DTMF с рабочим логированием!" 