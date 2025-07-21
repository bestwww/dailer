#!/bin/bash

# 🔧 ПРИНУДИТЕЛЬНАЯ АКТИВАЦИЯ ЛОГИРОВАНИЯ FREESWITCH
# Исправление проблемы с модулем logfile

CONTAINER_NAME="freeswitch-test"
PHONE_NUMBER="79206054020"

echo "🔧 ПРИНУДИТЕЛЬНАЯ АКТИВАЦИЯ ЛОГИРОВАНИЯ FREESWITCH"
echo "================================================"
echo ""

echo "🔍 ПРОБЛЕМА: Конфигурация установлена, но файл логов не создается"
echo "🎯 РЕШЕНИЕ: Принудительно активировать модуль logfile"
echo ""

# ЭТАП 1: Диагностика модулей
echo "📋 ЭТАП 1: ДИАГНОСТИКА МОДУЛЕЙ ЛОГИРОВАНИЯ"
echo "========================================"

echo ""
echo "1. 🔍 Проверяем загруженные модули..."
LOADED_MODULES=$(docker exec "$CONTAINER_NAME" fs_cli -x "show modules" | grep -i log 2>&1)
echo "Модули логирования:"
echo "$LOADED_MODULES"

echo ""
echo "2. 📂 Проверяем modules.conf.xml..."
MODULES_CONFIG=$(docker exec "$CONTAINER_NAME" grep -A5 -B5 "logfile" /usr/local/freeswitch/conf/autoload_configs/modules.conf.xml 2>&1)
echo "Конфигурация модулей:"
echo "$MODULES_CONFIG"

echo ""
echo "3. 🔍 Проверяем состояние модуля logfile..."
LOGFILE_STATUS=$(docker exec "$CONTAINER_NAME" fs_cli -x "module_exists mod_logfile" 2>&1)
echo "Статус mod_logfile: $LOGFILE_STATUS"

# ЭТАП 2: Принудительная загрузка модуля logfile
echo ""
echo "📋 ЭТАП 2: ПРИНУДИТЕЛЬНАЯ ЗАГРУЗКА МОДУЛЯ LOGFILE"
echo "=============================================="

echo ""
echo "1. 🔧 Загружаем модуль logfile..."
LOAD_RESULT=$(docker exec "$CONTAINER_NAME" fs_cli -x "load mod_logfile" 2>&1)
echo "Результат загрузки: $LOAD_RESULT"

echo ""
echo "2. 🔄 Перезагружаем модуль logfile..."
RELOAD_RESULT=$(docker exec "$CONTAINER_NAME" fs_cli -x "reload mod_logfile" 2>&1)
echo "Результат перезагрузки: $RELOAD_RESULT"

echo ""
echo "3. 📝 Проверяем статус после загрузки..."
STATUS_AFTER=$(docker exec "$CONTAINER_NAME" fs_cli -x "show modules" | grep -i logfile 2>&1)
echo "Статус mod_logfile после загрузки:"
echo "$STATUS_AFTER"

# ЭТАП 3: Обновление modules.conf.xml
echo ""
echo "📋 ЭТАП 3: ОБНОВЛЕНИЕ MODULES.CONF.XML"
echo "===================================="

echo ""
echo "1. 📄 Создаем обновленный modules.conf.xml с logfile..."

# Создаем modules.conf.xml с явным включением mod_logfile
cat > /tmp/modules.conf.xml << 'EOF'
<configuration name="modules.conf" description="Modules">
  <modules>
    <!-- Обязательные модули -->
    <load module="mod_console"/>
    <load module="mod_dptools"/>
    <load module="mod_enum"/>
    <load module="mod_event_socket"/>
    <load module="mod_expr"/>
    <load module="mod_hash"/>
    
    <!-- КРИТИЧЕСКИ ВАЖНО: модуль логирования -->
    <load module="mod_logfile"/>
    
    <!-- Диалплан -->
    <load module="mod_dialplan_xml"/>
    
    <!-- Sofia SIP -->
    <load module="mod_sofia"/>
    
    <!-- Аудио кодеки -->
    <load module="mod_g711"/>
    <load module="mod_g722"/>
    <load module="mod_g729"/>
    <load module="mod_gsm"/>
    <load module="mod_speex"/>
    
    <!-- Аудио приложения -->
    <load module="mod_tone_stream"/>
    <load module="mod_local_stream"/>
    <load module="mod_sndfile"/>
    <load module="mod_native_file"/>
    
    <!-- Таймеры -->
    <load module="mod_timerfd"/>
    
    <!-- Форматы -->
    <load module="mod_wav"/>
    <load module="mod_shout"/>
    
    <!-- Say -->
    <load module="mod_say_en"/>
    
    <!-- ASR/TTS -->
    <load module="mod_flite"/>
    
    <!-- DTMF -->
    <load module="mod_dtmf"/>
    
    <!-- Конференции -->
    <load module="mod_conference"/>
    
    <!-- Voicemail -->
    <load module="mod_voicemail"/>
    
    <!-- Commands -->
    <load module="mod_commands"/>
    
    <!-- Directories -->
    <load module="mod_directory"/>
    
    <!-- Endpoints -->
    <load module="mod_loopback"/>
    
    <!-- ESL -->
    <load module="mod_event_socket"/>
    
    <!-- CDR -->
    <load module="mod_xml_cdr"/>
    
  </modules>
</configuration>
EOF

echo "✅ Обновленный modules.conf.xml создан"

echo ""
echo "2. 📄 Устанавливаем обновленную конфигурацию модулей..."
docker cp /tmp/modules.conf.xml "$CONTAINER_NAME:/usr/local/freeswitch/conf/autoload_configs/modules.conf.xml"

# ЭТАП 4: Альтернативный способ - прямая команда logfile
echo ""
echo "📋 ЭТАП 4: АЛЬТЕРНАТИВНЫЙ СПОСОБ АКТИВАЦИИ"
echo "========================================"

echo ""
echo "1. 🔧 Пробуем прямую команду logfile..."
DIRECT_LOGFILE=$(docker exec "$CONTAINER_NAME" fs_cli -x "logfile /usr/local/freeswitch/log/freeswitch.log" 2>&1)
echo "Результат прямой команды: $DIRECT_LOGFILE"

echo ""
echo "2. 📝 Создаем файл логов вручную..."
docker exec "$CONTAINER_NAME" touch /usr/local/freeswitch/log/freeswitch.log
docker exec "$CONTAINER_NAME" chmod 644 /usr/local/freeswitch/log/freeswitch.log

echo ""
echo "3. 🔧 Пробуем fsctl команду..."
FSCTL_RESULT=$(docker exec "$CONTAINER_NAME" fs_cli -x "fsctl loglevel debug" 2>&1)
echo "Результат fsctl: $FSCTL_RESULT"

# ЭТАП 5: Перезапуск с новой конфигурацией
echo ""
echo "📋 ЭТАП 5: ПЕРЕЗАПУСК С НОВОЙ КОНФИГУРАЦИЕЙ"
echo "=========================================="

echo ""
echo "1. 🔄 Полный перезапуск FreeSWITCH..."
docker restart "$CONTAINER_NAME"

echo ""
echo "⏰ Ожидаем запуска (30 секунд)..."
sleep 30

echo ""
echo "2. 🔍 Проверяем статус после перезапуска..."
STATUS_FINAL=$(docker exec "$CONTAINER_NAME" fs_cli -x "status" 2>&1)
echo "Статус FreeSWITCH:"
echo "$STATUS_FINAL"

echo ""
echo "3. 📂 Проверяем файлы логов..."
LOG_FILES_FINAL=$(docker exec "$CONTAINER_NAME" ls -la /usr/local/freeswitch/log/ 2>&1)
echo "Файлы логов:"
echo "$LOG_FILES_FINAL"

echo ""
echo "4. 📝 Проверяем создание freeswitch.log..."
if docker exec "$CONTAINER_NAME" test -f /usr/local/freeswitch/log/freeswitch.log; then
    echo "✅ Файл freeswitch.log создан!"
    
    # Проверяем размер и содержимое
    LOG_SIZE=$(docker exec "$CONTAINER_NAME" wc -l /usr/local/freeswitch/log/freeswitch.log 2>&1)
    echo "Размер лога: $LOG_SIZE"
    
    if [[ "$LOG_SIZE" =~ [0-9]+ ]] && [[ ${LOG_SIZE%% *} -gt 0 ]]; then
        echo "✅ Логи записываются в файл!"
        echo ""
        echo "📝 Последние записи:"
        docker exec "$CONTAINER_NAME" tail -10 /usr/local/freeswitch/log/freeswitch.log
    else
        echo "⚠️  Файл создан, но пустой"
    fi
else
    echo "❌ Файл freeswitch.log все еще не создан"
fi

# ЭТАП 6: Принудительное тестирование DTMF
echo ""
echo "📋 ЭТАП 6: ПРИНУДИТЕЛЬНОЕ ТЕСТИРОВАНИЕ DTMF"
echo "========================================"

echo ""
echo "1. 🔧 Включаем максимальное логирование..."
docker exec "$CONTAINER_NAME" fs_cli -x "console loglevel debug"
docker exec "$CONTAINER_NAME" fs_cli -x "sofia loglevel all 9"

echo ""
echo "2. 🧪 Запускаем тестовый звонок..."
TEST_CALL=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/$PHONE_NUMBER 1201 XML default" 2>&1)
echo "Тестовый звонок: $TEST_CALL"

# Ждем 5 секунд
sleep 5

# Завершаем звонок
docker exec "$CONTAINER_NAME" fs_cli -x "hupall MANAGER_REQUEST"

echo ""
echo "3. 📊 Проверяем логирование после звонка..."
if docker exec "$CONTAINER_NAME" test -f /usr/local/freeswitch/log/freeswitch.log; then
    LOG_SIZE_AFTER=$(docker exec "$CONTAINER_NAME" wc -l /usr/local/freeswitch/log/freeswitch.log 2>&1)
    echo "Размер лога после звонка: $LOG_SIZE_AFTER"
    
    # Ищем записи о звонке
    CALL_LOGS=$(docker exec "$CONTAINER_NAME" grep -E "(1201|originate|CRIT)" /usr/local/freeswitch/log/freeswitch.log | tail -10 2>&1)
    echo ""
    echo "🔍 Записи о звонке:"
    echo "$CALL_LOGS"
    
    # Ищем DTMF записи
    DTMF_LOGS=$(docker exec "$CONTAINER_NAME" grep -i "dtmf\|CRIT.*===" /usr/local/freeswitch/log/freeswitch.log 2>&1)
    echo ""
    echo "🔍 DTMF записи:"
    echo "$DTMF_LOGS"
fi

# ЭТАП 7: Результаты
echo ""
echo "📋 ЭТАП 7: РЕЗУЛЬТАТЫ ПРИНУДИТЕЛЬНОЙ АКТИВАЦИИ"
echo "============================================"

if docker exec "$CONTAINER_NAME" test -f /usr/local/freeswitch/log/freeswitch.log; then
    LOG_SIZE_CHECK=$(docker exec "$CONTAINER_NAME" wc -l /usr/local/freeswitch/log/freeswitch.log | cut -d' ' -f1)
    
    if [[ "$LOG_SIZE_CHECK" -gt 0 ]]; then
        echo ""
        echo "🎉 ЛОГИРОВАНИЕ УСПЕШНО АКТИВИРОВАНО!"
        echo ""
        echo "✅ РЕЗУЛЬТАТЫ:"
        echo "- Файл freeswitch.log создан и работает"
        echo "- Логи записываются в файл ($LOG_SIZE_CHECK строк)"
        echo "- Модуль logfile загружен"
        echo "- Готово к DTMF мониторингу"
        echo ""
        echo "🔍 КОМАНДЫ ДЛЯ DTMF ТЕСТИРОВАНИЯ:"
        echo ""
        echo "# Мониторинг DTMF в реальном времени:"
        echo "docker exec $CONTAINER_NAME tail -f /usr/local/freeswitch/log/freeswitch.log | grep -E '(CRIT|DTMF|ОБРАБОТЧИК)'"
        echo ""
        echo "# Тест DTMF:"
        echo "docker exec $CONTAINER_NAME fs_cli -x \"originate sofia/gateway/sip_trunk/$PHONE_NUMBER 1201 XML default\""
        echo ""
        echo "# Поиск DTMF событий:"
        echo "docker exec $CONTAINER_NAME grep -E '(DTMF|CRIT.*===)' /usr/local/freeswitch/log/freeswitch.log | tail -20"
        
    else
        echo ""
        echo "⚠️  ФАЙЛ СОЗДАН, НО ЛОГИ НЕ ЗАПИСЫВАЮТСЯ"
        echo ""
        echo "🔧 ДОПОЛНИТЕЛЬНЫЕ ДЕЙСТВИЯ:"
        echo "1. Проверить права доступа"
        echo "2. Возможно нужен другой подход"
        echo "3. Рассмотреть альтернативные методы мониторинга"
    fi
    
else
    echo ""
    echo "❌ ЛОГИРОВАНИЕ В ФАЙЛ НЕ АКТИВИРОВАНО"
    echo ""
    echo "🔧 АЛЬТЕРНАТИВНОЕ РЕШЕНИЕ:"
    echo "Возможно нужно использовать мониторинг через консоль"
    echo "или другие методы отслеживания DTMF"
fi

echo ""
echo "🔧 ПРИНУДИТЕЛЬНАЯ АКТИВАЦИЯ ЗАВЕРШЕНА!"
echo "=====================================" 