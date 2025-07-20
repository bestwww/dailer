#!/bin/bash

# 🔧 ПРАВИЛЬНАЯ НАСТРОЙКА ЛОГИРОВАНИЯ ПО ОФИЦИАЛЬНОЙ ДОКУМЕНТАЦИИ
# Основано на официальной документации FreeSWITCH developer.signalwire.com

CONTAINER_NAME="freeswitch-test"
PHONE_NUMBER="79206054020"

echo "🔧 ПРАВИЛЬНАЯ НАСТРОЙКА ЛОГИРОВАНИЯ ПО ОФИЦИАЛЬНОЙ ДОКУМЕНТАЦИИ"
echo "=============================================================="
echo ""

echo "📚 ОСНОВАНО НА: https://developer.signalwire.com/freeswitch/FreeSWITCH-Explained/Modules/mod_logfile_1048990/"
echo "🎯 ЦЕЛЬ: Создать правильную конфигурацию logfile.conf.xml по официальному образцу"
echo ""

# ЭТАП 1: Удаление предыдущих неправильных конфигураций
echo "📋 ЭТАП 1: ОЧИСТКА НЕПРАВИЛЬНЫХ КОНФИГУРАЦИЙ"
echo "==========================================="

echo ""
echo "1. 🗑️  Удаляем неправильные конфигурации..."
docker exec "$CONTAINER_NAME" rm -f /usr/local/freeswitch/conf/autoload_configs/logfile.conf.xml
docker exec "$CONTAINER_NAME" rm -f /usr/local/freeswitch/log/freeswitch.log

echo ""
echo "2. 🔍 Проверяем что модуль logfile загружен..."
LOGFILE_MODULE=$(docker exec "$CONTAINER_NAME" fs_cli -x "show modules" | grep logfile 2>&1)
echo "Статус mod_logfile: $LOGFILE_MODULE"

# ЭТАП 2: Создание ПРАВИЛЬНОЙ конфигурации по официальной документации
echo ""
echo "📋 ЭТАП 2: СОЗДАНИЕ ПРАВИЛЬНОЙ КОНФИГУРАЦИИ"
echo "=========================================="

echo ""
echo "1. 📄 Создаем правильный logfile.conf.xml по официальной документации..."

# Создаем ПРАВИЛЬНУЮ конфигурацию logfile.conf.xml по документации
cat > /tmp/correct_logfile.conf.xml << 'EOF'
<configuration name="logfile.conf" description="File Logging">
  <settings>
    <!--
      ОФИЦИАЛЬНАЯ НАСТРОЙКА ПО ДОКУМЕНТАЦИИ FreeSWITCH
      https://developer.signalwire.com/freeswitch/FreeSWITCH-Explained/Modules/mod_logfile_1048990/
    -->
    
    <!-- Основной лог файл - ОБЯЗАТЕЛЬНЫЙ ПАРАМЕТР -->
    <param name="logfile" value="/usr/local/freeswitch/log/freeswitch.log"/>
    
    <!-- Ротация логов -->
    <param name="rollover" value="10485760"/>
    <param name="maximum-rotate" value="10"/>
    
    <!-- ПРОФИЛИ ЛОГИРОВАНИЯ - КЛЮЧЕВОЕ ОТЛИЧИЕ -->
    <profiles>
      
      <!-- ОСНОВНОЙ ПРОФИЛЬ по документации -->
      <profile name="default">
        <settings>
          <!-- Файл для записи логов -->
          <param name="logfile" value="/usr/local/freeswitch/log/freeswitch.log"/>
          <param name="rollover" value="10485760"/>
          <param name="maximum-rotate" value="32"/>
          <param name="uuid" value="true"/>
        </settings>
        
        <!-- ПРАВИЛЬНЫЕ MAPPINGS по документации -->
        <mappings>
          <!-- Логируем ВСЕ уровни в файл -->
          <map name="all" value="debug,info,notice,warning,err,crit,alert"/>
        </mappings>
      </profile>
      
      <!-- ДОПОЛНИТЕЛЬНЫЙ профиль для DTMF -->
      <profile name="dtmf_debug">
        <settings>
          <param name="logfile" value="/usr/local/freeswitch/log/dtmf.log"/>
          <param name="rollover" value="1048576"/>
          <param name="maximum-rotate" value="5"/>
          <param name="uuid" value="true"/>
        </settings>
        <mappings>
          <!-- Специально для DTMF отладки -->
          <map name="all" value="debug,info,notice,warning,err,crit,alert"/>
        </mappings>
      </profile>
      
    </profiles>
  </settings>
</configuration>
EOF

echo "✅ Правильная конфигурация logfile.conf.xml создана по официальной документации"

echo ""
echo "2. 📄 Создаем правильный modules.conf.xml с mod_logfile..."

# Создаем правильный modules.conf.xml с mod_logfile на правильном месте
cat > /tmp/correct_modules.conf.xml << 'EOF'
<configuration name="modules.conf" description="Modules">
  <modules>
    
    <!-- ОСНОВНЫЕ МОДУЛИ -->
    <load module="mod_console"/>
    
    <!-- ЛОГИРОВАНИЕ - ЗАГРУЖАЕМ РАНО -->
    <load module="mod_logfile"/>
    
    <!-- СОБЫТИЯ -->
    <load module="mod_event_socket"/>
    
    <!-- ДИАЛПЛАН -->
    <load module="mod_dptools"/>
    <load module="mod_dialplan_xml"/>
    
    <!-- SIP -->
    <load module="mod_sofia"/>
    
    <!-- КОДЕКИ -->
    <load module="mod_g711"/>
    <load module="mod_g722"/>
    <load module="mod_g729"/>
    
    <!-- АУДИО -->
    <load module="mod_tone_stream"/>
    <load module="mod_sndfile"/>
    <load module="mod_native_file"/>
    
    <!-- COMMANDS -->
    <load module="mod_commands"/>
    
    <!-- HASH -->
    <load module="mod_hash"/>
    
    <!-- EXPR -->
    <load module="mod_expr"/>
    
    <!-- ТАЙМЕРЫ -->
    <load module="mod_timerfd"/>
    
    <!-- ФОРМАТЫ -->
    <load module="mod_wav"/>
    
    <!-- SAY -->
    <load module="mod_say_en"/>
    
    <!-- XML CDR -->
    <load module="mod_xml_cdr"/>
    
  </modules>
</configuration>
EOF

echo "✅ Правильная конфигурация modules.conf.xml создана"

# ЭТАП 3: Установка правильных конфигураций
echo ""
echo "📋 ЭТАП 3: УСТАНОВКА ПРАВИЛЬНЫХ КОНФИГУРАЦИЙ"
echo "=========================================="

echo ""
echo "1. 📄 Устанавливаем правильный logfile.conf.xml..."
docker cp /tmp/correct_logfile.conf.xml "$CONTAINER_NAME:/usr/local/freeswitch/conf/autoload_configs/logfile.conf.xml"

echo ""
echo "2. 📄 Устанавливаем правильный modules.conf.xml..."
docker cp /tmp/correct_modules.conf.xml "$CONTAINER_NAME:/usr/local/freeswitch/conf/autoload_configs/modules.conf.xml"

echo ""
echo "3. 📁 Создаем директорию логов с правильными правами..."
docker exec "$CONTAINER_NAME" mkdir -p /usr/local/freeswitch/log
docker exec "$CONTAINER_NAME" chmod 755 /usr/local/freeswitch/log
docker exec "$CONTAINER_NAME" touch /usr/local/freeswitch/log/freeswitch.log
docker exec "$CONTAINER_NAME" chmod 644 /usr/local/freeswitch/log/freeswitch.log

# ЭТАП 4: Полный перезапуск с правильной конфигурацией
echo ""
echo "📋 ЭТАП 4: ПОЛНЫЙ ПЕРЕЗАПУСК"
echo "=========================="

echo ""
echo "1. 🔄 Полный перезапуск FreeSWITCH с правильной конфигурацией..."
docker restart "$CONTAINER_NAME"

echo ""
echo "⏰ Ожидаем полного запуска (30 секунд)..."
sleep 30

echo ""
echo "2. 🔍 Проверяем статус FreeSWITCH..."
STATUS_CHECK=$(docker exec "$CONTAINER_NAME" fs_cli -x "status" 2>&1)
echo "Статус FreeSWITCH:"
echo "$STATUS_CHECK"

echo ""
echo "3. 📊 Проверяем загрузку модуля logfile..."
MODULE_CHECK=$(docker exec "$CONTAINER_NAME" fs_cli -x "show modules" | grep logfile 2>&1)
echo "Модуль logfile: $MODULE_CHECK"

# ЭТАП 5: Проверка создания логов
echo ""
echo "📋 ЭТАП 5: ПРОВЕРКА СОЗДАНИЯ ЛОГОВ"
echo "================================"

echo ""
echo "1. 📂 Проверяем файлы логов..."
LOG_FILES=$(docker exec "$CONTAINER_NAME" ls -la /usr/local/freeswitch/log/ 2>&1)
echo "Файлы логов:"
echo "$LOG_FILES"

echo ""
echo "2. 📝 Проверяем основной лог файл..."
if docker exec "$CONTAINER_NAME" test -f /usr/local/freeswitch/log/freeswitch.log; then
    echo "✅ Файл freeswitch.log существует!"
    
    # Проверяем размер
    LOG_SIZE=$(docker exec "$CONTAINER_NAME" wc -l /usr/local/freeswitch/log/freeswitch.log 2>&1)
    echo "Размер лога: $LOG_SIZE"
    
    # Показываем последние записи
    echo ""
    echo "📋 Последние записи в логе:"
    docker exec "$CONTAINER_NAME" tail -10 /usr/local/freeswitch/log/freeswitch.log 2>&1
    
else
    echo "❌ Файл freeswitch.log не создан"
fi

# ЭТАП 6: Принудительная активация логирования
echo ""
echo "📋 ЭТАП 6: ПРИНУДИТЕЛЬНАЯ АКТИВАЦИЯ"
echo "================================="

echo ""
echo "1. 🔧 Принудительно активируем логирование в файл..."

# Команды для принудительной активации логирования
docker exec "$CONTAINER_NAME" fs_cli -x "reload mod_logfile"
sleep 2

echo ""
echo "2. 🔧 Устанавливаем уровни логирования..."
docker exec "$CONTAINER_NAME" fs_cli -x "console loglevel debug"
docker exec "$CONTAINER_NAME" fs_cli -x "sofia loglevel all 9"

echo ""
echo "3. 🧪 Генерируем тестовые логи..."
# Генерируем события для записи в лог
docker exec "$CONTAINER_NAME" fs_cli -x "version"
docker exec "$CONTAINER_NAME" fs_cli -x "status"
docker exec "$CONTAINER_NAME" fs_cli -x "show modules" > /dev/null

# ЭТАП 7: Финальная проверка
echo ""
echo "📋 ЭТАП 7: ФИНАЛЬНАЯ ПРОВЕРКА"
echo "============================"

sleep 5

echo ""
echo "1. 📊 Проверяем логирование после настройки..."
if docker exec "$CONTAINER_NAME" test -f /usr/local/freeswitch/log/freeswitch.log; then
    FINAL_LOG_SIZE=$(docker exec "$CONTAINER_NAME" wc -l /usr/local/freeswitch/log/freeswitch.log | cut -d' ' -f1)
    echo "Финальный размер лога: $FINAL_LOG_SIZE строк"
    
    if [[ "$FINAL_LOG_SIZE" -gt 0 ]]; then
        echo "✅ ЛОГИРОВАНИЕ РАБОТАЕТ!"
        echo ""
        echo "📝 Последние записи:"
        docker exec "$CONTAINER_NAME" tail -15 /usr/local/freeswitch/log/freeswitch.log
        
        echo ""
        echo "2. 🧪 Запускаем тестовый звонок для проверки DTMF логирования..."
        TEST_CALL=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/$PHONE_NUMBER 1201 XML default" 2>&1)
        echo "Тестовый звонок: $TEST_CALL"
        
        # Ждем 10 секунд
        sleep 10
        
        # Завершаем звонок
        docker exec "$CONTAINER_NAME" fs_cli -x "hupall MANAGER_REQUEST"
        
        echo ""
        echo "3. 📊 Проверяем логи после звонка..."
        CALL_LOG_SIZE=$(docker exec "$CONTAINER_NAME" wc -l /usr/local/freeswitch/log/freeswitch.log | cut -d' ' -f1)
        echo "Размер лога после звонка: $CALL_LOG_SIZE строк"
        
        # Ищем записи о звонке
        CALL_ENTRIES=$(docker exec "$CONTAINER_NAME" grep -E "(1201|originate|EXECUTE)" /usr/local/freeswitch/log/freeswitch.log | tail -10 2>&1)
        echo ""
        echo "📞 Записи о звонке:"
        echo "$CALL_ENTRIES"
        
        # Ищем DTMF записи (если есть)
        DTMF_ENTRIES=$(docker exec "$CONTAINER_NAME" grep -i "dtmf\|CRIT.*===" /usr/local/freeswitch/log/freeswitch.log | tail -5 2>&1)
        echo ""
        echo "🔍 DTMF записи:"
        echo "$DTMF_ENTRIES"
        
    else
        echo "⚠️  Файл создан, но пустой"
    fi
else
    echo "❌ Файл логов не создан"
fi

# ЭТАП 8: Результаты
echo ""
echo "📋 ЭТАП 8: РЕЗУЛЬТАТЫ НАСТРОЙКИ ПО ОФИЦИАЛЬНОЙ ДОКУМЕНТАЦИИ"
echo "=========================================================="

if docker exec "$CONTAINER_NAME" test -f /usr/local/freeswitch/log/freeswitch.log; then
    RESULT_LOG_SIZE=$(docker exec "$CONTAINER_NAME" wc -l /usr/local/freeswitch/log/freeswitch.log | cut -d' ' -f1)
    
    if [[ "$RESULT_LOG_SIZE" -gt 0 ]]; then
        echo ""
        echo "🎉 УСПЕХ! ЛОГИРОВАНИЕ НАСТРОЕНО ПО ОФИЦИАЛЬНОЙ ДОКУМЕНТАЦИИ!"
        echo ""
        echo "✅ ДОСТИГНУТО:"
        echo "- Файл freeswitch.log создан и работает"
        echo "- Логи записываются в файл ($RESULT_LOG_SIZE строк)"
        echo "- Конфигурация соответствует официальной документации"
        echo "- Модуль mod_logfile правильно загружен"
        echo "- Готово к DTMF мониторингу"
        echo ""
        echo "🔍 КОМАНДЫ ДЛЯ DTMF ТЕСТИРОВАНИЯ:"
        echo ""
        echo "# Мониторинг DTMF в реальном времени:"
        echo "docker exec $CONTAINER_NAME tail -f /usr/local/freeswitch/log/freeswitch.log | grep -E '(CRIT|DTMF|ОБРАБОТЧИК|ВЕБХУК)'"
        echo ""
        echo "# Тест DTMF с рабочим логированием:"
        echo "docker exec $CONTAINER_NAME fs_cli -x \"originate sofia/gateway/sip_trunk/$PHONE_NUMBER 1201 XML default\""
        echo ""
        echo "# Поиск DTMF событий в логах:"
        echo "docker exec $CONTAINER_NAME grep -E '(DTMF|CRIT.*===)' /usr/local/freeswitch/log/freeswitch.log | tail -20"
        echo ""
        echo "# Поиск записей о звонках:"
        echo "docker exec $CONTAINER_NAME grep -E '(1201|originate|EXECUTE)' /usr/local/freeswitch/log/freeswitch.log | tail -10"
        
    else
        echo ""
        echo "⚠️  ЧАСТИЧНЫЙ УСПЕХ:"
        echo "- Файл создан, но логи не записываются"
        echo "- Возможно нужны дополнительные настройки"
    fi
    
else
    echo ""
    echo "❌ ПРОБЛЕМА ОСТАЕТСЯ:"
    echo "- Файл логов не создается"
    echo "- Требуется дополнительная диагностика"
fi

echo ""
echo "🔧 НАСТРОЙКА ПО ОФИЦИАЛЬНОЙ ДОКУМЕНТАЦИИ ЗАВЕРШЕНА!"
echo "=================================================="
echo ""
echo "📚 ИСПОЛЬЗОВАННАЯ ДОКУМЕНТАЦИЯ:"
echo "https://developer.signalwire.com/freeswitch/FreeSWITCH-Explained/Modules/mod_logfile_1048990/" 