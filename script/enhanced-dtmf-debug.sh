#!/bin/bash

# 🔧 УЛУЧШЕННАЯ ДИАГНОСТИКА DTMF ПРОБЛЕМ
# Детальный анализ почему DTMF события не видны в логах

CONTAINER_NAME="freeswitch-test"
PHONE_NUMBER="79206054020"

echo "🔧 УЛУЧШЕННАЯ ДИАГНОСТИКА DTMF ПРОБЛЕМ"
echo "====================================="
echo ""

echo "🚨 ПРОБЛЕМА: Звонок приходит, но DTMF события не логируются"
echo "🎯 ЦЕЛЬ: Найти причину и исправить DTMF мониторинг"
echo ""

# ЭТАП 1: Диагностика текущего состояния
echo "📋 ЭТАП 1: ДИАГНОСТИКА ТЕКУЩЕГО СОСТОЯНИЯ"
echo "========================================"

echo ""
echo "1. 📊 Проверяем активные звонки..."
ACTIVE_CALLS=$(docker exec "$CONTAINER_NAME" fs_cli -x "show calls" 2>&1)
echo "Активные звонки:"
echo "$ACTIVE_CALLS"

echo ""
echo "2. 🔍 Проверяем настройки логирования..."
LOG_LEVEL=$(docker exec "$CONTAINER_NAME" fs_cli -x "console loglevel" 2>&1)
echo "Уровень логирования: $LOG_LEVEL"

echo ""
echo "3. 📂 Проверяем доступность файлов логов..."
LOG_FILES=$(docker exec "$CONTAINER_NAME" ls -la /usr/local/freeswitch/log/ 2>&1)
echo "Файлы логов:"
echo "$LOG_FILES"

echo ""
echo "4. 📝 Проверяем последние записи в основном логе..."
RECENT_LOGS=$(docker exec "$CONTAINER_NAME" tail -20 /usr/local/freeswitch/log/freeswitch.log 2>&1)
echo "Последние логи:"
echo "$RECENT_LOGS"

# ЭТАП 2: Завершение висящих звонков
echo ""
echo "📋 ЭТАП 2: ОЧИСТКА ВИСЯЩИХ ЗВОНКОВ"
echo "================================="

echo ""
echo "1. 🛑 Завершаем все активные звонки..."
HANGUP_RESULT=$(docker exec "$CONTAINER_NAME" fs_cli -x "hupall MANAGER_REQUEST" 2>&1)
echo "Результат: $HANGUP_RESULT"

echo ""
echo "2. 📊 Проверяем очистку..."
CALLS_AFTER=$(docker exec "$CONTAINER_NAME" fs_cli -x "show calls count" 2>&1)
echo "Звонков после очистки: $CALLS_AFTER"

# ЭТАП 3: Создание улучшенного диалплана с максимальным логированием
echo ""
echo "📋 ЭТАП 3: МАКСИМАЛЬНОЕ ЛОГИРОВАНИЕ DTMF"
echo "======================================"

echo ""
echo "3. 📝 Создаем диалплан с МАКСИМАЛЬНЫМ логированием..."

# Создаем диалплан с самым детальным DTMF логированием
cat > /tmp/max_dtmf_logging.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<!--
  МАКСИМАЛЬНОЕ DTMF ЛОГИРОВАНИЕ
  Каждое событие логируется детально
-->
<include>
  <context name="default">

    <!-- Echo тест для проверки -->
    <extension name="echo_test">
      <condition field="destination_number" expression="^(echo|9196)$">
        <action application="answer"/>
        <action application="log" data="CRIT ======= ECHO TEST START ======="/>
        <action application="set" data="call_timeout=300"/>
        <action application="set" data="hangup_after_bridge=true"/>
        <action application="sched_hangup" data="+300 ALLOTTED_TIMEOUT"/>
        <action application="echo"/>
      </condition>
    </extension>

    <!-- МАКСИМАЛЬНЫЙ DTMF мониторинг -->
    <extension name="max_dtmf_logging">
      <condition field="destination_number" expression="^(1201)$">
        
        <!-- КРИТИЧЕСКИЙ уровень логирования для видимости -->
        <action application="log" data="CRIT ================================"/>
        <action application="log" data="CRIT === IVR МАКСИМАЛЬНЫЙ ЛОРГИНГ ==="/>
        <action application="log" data="CRIT ================================"/>
        <action application="log" data="CRIT UUID: ${uuid}"/>
        <action application="log" data="CRIT Caller ID: ${caller_id_number}"/>
        <action application="log" data="CRIT Destination: ${destination_number}"/>
        <action application="log" data="CRIT Start Time: ${strftime()}"/>
        
        <action application="answer"/>
        <action application="log" data="CRIT === ЗВОНОК ОТВЕЧЕН ==="/>
        
        <!-- Максимальные настройки безопасности -->
        <action application="set" data="call_timeout=600"/>
        <action application="set" data="hangup_after_bridge=true"/>
        <action application="sched_hangup" data="+600 ALLOTTED_TIMEOUT"/>
        
        <!-- КРИТИЧЕСКИЕ настройки DTMF -->
        <action application="set" data="drop_dtmf=false"/>
        <action application="set" data="dtmf_type=rfc2833"/>
        <action application="set" data="rtp_timer_name=soft"/>
        <action application="log" data="CRIT === DTMF НАСТРОЙКИ УСТАНОВЛЕНЫ ==="/>
        
        <!-- Пауза для поднятия трубки -->
        <action application="log" data="CRIT === ПАУЗА ДЛЯ ПОДНЯТИЯ ТРУБКИ ==="/>
        <action application="sleep" data="3000"/>
        <action application="log" data="CRIT === ПАУЗА ЗАВЕРШЕНА ==="/>
        
        <!-- Приветственные тоны с логированием -->
        <action application="log" data="CRIT === НАЧАЛО ПРИВЕТСТВЕННЫХ ТОНОВ ==="/>
        <action application="playback" data="tone_stream://%(2000,500,800)"/>
        <action application="log" data="CRIT === ПРИВЕТСТВЕННЫЙ ТОН ЗАВЕРШЕН ==="/>
        <action application="sleep" data="1000"/>
        
        <!-- Объяснение меню -->
        <action application="log" data="CRIT === ОБЪЯСНЕНИЕ МЕНЮ ТОНАМИ ==="/>
        <action application="playback" data="tone_stream://%(500,200,1000)"/>
        <action application="sleep" data="500"/>
        <action application="playback" data="tone_stream://%(500,200,500)"/>
        <action application="sleep" data="500"/>
        <action application="playback" data="tone_stream://%(500,200,300)"/>
        <action application="sleep" data="1000"/>
        <action application="log" data="CRIT === МЕНЮ ОБЪЯСНЕНО ==="/>
        
        <!-- КРИТИЧЕСКИ ВАЖНО: Подробный сбор DTMF -->
        <action application="log" data="CRIT ================================"/>
        <action application="log" data="CRIT === НАЧИНАЕМ СБОР DTMF ==="/>
        <action application="log" data="CRIT === ЖДЕМ 30 СЕКУНД ==="/>
        <action application="log" data="CRIT ================================"/>
        
        <!-- Проигрываем тон ожидания ввода -->
        <action application="playback" data="tone_stream://%(200,100,400)"/>
        
        <!-- Детальный сбор DTMF с максимальным логированием -->
        <action application="read" data="dtmf_choice,1,5,tone_stream://%(200,100,400),dtmf_timeout,30000"/>
        
        <action application="log" data="CRIT ================================"/>
        <action application="log" data="CRIT === DTMF СБОР ЗАВЕРШЕН ==="/>
        <action application="log" data="CRIT ПОЛУЧЕНО: ${dtmf_choice}"/>
        <action application="log" data="CRIT ДЛИНА: ${dtmf_choice:strlen}"/>
        <action application="log" data="CRIT ================================"/>
        
        <!-- Проверяем что получили -->
        <action application="execute_extension" data="dtmf_handler_${dtmf_choice} XML default"/>
        
        <!-- Если не обработано -->
        <action application="log" data="CRIT === DTMF НЕ ОБРАБОТАН ==="/>
        <action application="execute_extension" data="dtmf_handler_unknown XML default"/>
        
      </condition>
    </extension>

    <!-- ДЕТАЛЬНЫЕ обработчики DTMF -->
    
    <!-- Обработчик для цифры 1 -->
    <extension name="dtmf_handler_1">
      <condition field="destination_number" expression="^dtmf_handler_1$">
        <action application="log" data="CRIT ================================"/>
        <action application="log" data="CRIT === ОБРАБОТЧИК ЦИФРЫ 1 ==="/>
        <action application="log" data="CRIT UUID: ${uuid}"/>
        <action application="log" data="CRIT Время: ${strftime()}"/>
        <action application="log" data="CRIT ДЕЙСТВИЕ: ИНФОРМАЦИЯ"/>
        <action application="log" data="CRIT [ВЕБХУК] DTMF=1, Action=information"/>
        <action application="log" data="CRIT ================================"/>
        
        <action application="set" data="dtmf_pressed=1"/>
        <action application="set" data="menu_action=information"/>
        
        <!-- Информационные тоны -->
        <action application="playback" data="tone_stream://%(3000,500,1000)"/>
        <action application="sleep" data="2000"/>
        <action application="playback" data="tone_stream://%(1000,200,800)"/>
        <action application="sleep" data="2000"/>
        
        <action application="log" data="CRIT === ОПЦИЯ 1 ЗАВЕРШЕНА, ВОЗВРАТ В МЕНЮ ==="/>
        <action application="transfer" data="1201 XML default"/>
      </condition>
    </extension>

    <!-- Обработчик для цифры 2 -->
    <extension name="dtmf_handler_2">
      <condition field="destination_number" expression="^dtmf_handler_2$">
        <action application="log" data="CRIT ================================"/>
        <action application="log" data="CRIT === ОБРАБОТЧИК ЦИФРЫ 2 ==="/>
        <action application="log" data="CRIT UUID: ${uuid}"/>
        <action application="log" data="CRIT Время: ${strftime()}"/>
        <action application="log" data="CRIT ДЕЙСТВИЕ: ПОДДЕРЖКА"/>
        <action application="log" data="CRIT [ВЕБХУК] DTMF=2, Action=support"/>
        <action application="log" data="CRIT ================================"/>
        
        <action application="set" data="dtmf_pressed=2"/>
        <action application="set" data="menu_action=support"/>
        
        <!-- Тоны поддержки -->
        <action application="playback" data="tone_stream://%(2000,500,500)"/>
        <action application="sleep" data="1000"/>
        <action application="playback" data="tone_stream://%(1000,300,400)"/>
        <action application="sleep" data="2000"/>
        
        <action application="log" data="CRIT === ОПЦИЯ 2 ЗАВЕРШЕНА, ВОЗВРАТ В МЕНЮ ==="/>
        <action application="transfer" data="1201 XML default"/>
      </condition>
    </extension>

    <!-- Обработчик для цифры 9 -->
    <extension name="dtmf_handler_9">
      <condition field="destination_number" expression="^dtmf_handler_9$">
        <action application="log" data="CRIT ================================"/>
        <action application="log" data="CRIT === ОБРАБОТЧИК ЦИФРЫ 9 ==="/>
        <action application="log" data="CRIT UUID: ${uuid}"/>
        <action application="log" data="CRIT ДЕЙСТВИЕ: ЭХО ТЕСТ"/>
        <action application="log" data="CRIT [ВЕБХУК] DTMF=9, Action=echo_test"/>
        <action application="log" data="CRIT ================================"/>
        
        <action application="set" data="dtmf_pressed=9"/>
        <action application="set" data="menu_action=echo_test"/>
        <action application="sched_hangup" data="+180 ALLOTTED_TIMEOUT"/>
        <action application="playback" data="tone_stream://%(1000,200,600)"/>
        <action application="sleep" data="1000"/>
        <action application="echo"/>
      </condition>
    </extension>

    <!-- Обработчик для цифры 0 -->
    <extension name="dtmf_handler_0">
      <condition field="destination_number" expression="^dtmf_handler_0$">
        <action application="log" data="CRIT ================================"/>
        <action application="log" data="CRIT === ОБРАБОТЧИК ЦИФРЫ 0 ==="/>
        <action application="log" data="CRIT UUID: ${uuid}"/>
        <action application="log" data="CRIT ДЕЙСТВИЕ: ЗАВЕРШЕНИЕ"/>
        <action application="log" data="CRIT [ВЕБХУК] DTMF=0, Action=hangup"/>
        <action application="log" data="CRIT ================================"/>
        
        <action application="set" data="dtmf_pressed=0"/>
        <action application="set" data="menu_action=hangup"/>
        <action application="playback" data="tone_stream://%(1000,500,300)"/>
        <action application="sleep" data="1000"/>
        <action application="hangup" data="NORMAL_CLEARING"/>
      </condition>
    </extension>

    <!-- Обработчик тайм-аута -->
    <extension name="dtmf_handler_dtmf_timeout">
      <condition field="destination_number" expression="^dtmf_handler_dtmf_timeout$">
        <action application="log" data="CRIT ================================"/>
        <action application="log" data="CRIT === ТАЙМ-АУТ DTMF ==="/>
        <action application="log" data="CRIT UUID: ${uuid}"/>
        <action application="log" data="CRIT ПОЛУЧЕНО: ПУСТО (ТАЙМ-АУТ)"/>
        <action application="log" data="CRIT [ВЕБХУК] DTMF=timeout, Action=retry"/>
        <action application="log" data="CRIT ================================"/>
        
        <action application="set" data="dtmf_pressed=timeout"/>
        <action application="set" data="menu_action=retry"/>
        <action application="playback" data="tone_stream://%(500,200,200)"/>
        <action application="sleep" data="1000"/>
        <action application="log" data="CRIT === ВОЗВРАТ В МЕНЮ ПОСЛЕ ТАЙМ-АУТА ==="/>
        <action application="transfer" data="1201 XML default"/>
      </condition>
    </extension>

    <!-- Обработчик неизвестного ввода -->
    <extension name="dtmf_handler_unknown">
      <condition field="destination_number" expression="^dtmf_handler_unknown$">
        <action application="log" data="CRIT ================================"/>
        <action application="log" data="CRIT === НЕИЗВЕСТНЫЙ DTMF ==="/>
        <action application="log" data="CRIT UUID: ${uuid}"/>
        <action application="log" data="CRIT ПОЛУЧЕНО: ${dtmf_choice}"/>
        <action application="log" data="CRIT [ВЕБХУК] DTMF=unknown, Action=retry"/>
        <action application="log" data="CRIT ================================"/>
        
        <action application="set" data="dtmf_pressed=unknown"/>
        <action application="set" data="menu_action=retry"/>
        <action application="playback" data="tone_stream://%(500,200,200)"/>
        <action application="sleep" data="1000"/>
        <action application="log" data="CRIT === ВОЗВРАТ В МЕНЮ ПОСЛЕ ОШИБКИ ==="/>
        <action application="transfer" data="1201 XML default"/>
      </condition>
    </extension>

    <!-- Исходящие звонки -->
    <extension name="outbound_calls">
      <condition field="destination_number" expression="^(\d{11})$">
        <action application="set" data="caller_id_name=79058615815"/>
        <action application="set" data="caller_id_number=79058615815"/>
        <action application="set" data="call_timeout=300"/>
        <action application="set" data="hangup_after_bridge=true"/>
        <action application="set" data="bridge_answer_timeout=60"/>
        <action application="bridge" data="sofia/gateway/sip_trunk/$1"/>
        <action application="hangup" data="NO_ROUTE_DESTINATION"/>
      </condition>
    </extension>

  </context>
</include>
EOF

echo "✅ Диалплан с МАКСИМАЛЬНЫМ логированием создан"

# ЭТАП 4: Установка улучшенного диалплана
echo ""
echo "📋 ЭТАП 4: УСТАНОВКА МАКСИМАЛЬНОГО ЛОГИРОВАНИЯ"
echo "============================================"

echo ""
echo "1. 📄 Устанавливаем улучшенный диалплан..."
docker cp /tmp/max_dtmf_logging.xml "$CONTAINER_NAME:/usr/local/freeswitch/conf/dialplan/default.xml"

echo ""
echo "2. 🔄 Перезагружаем конфигурацию..."
RELOAD_RESULT=$(docker exec "$CONTAINER_NAME" fs_cli -x "reloadxml" 2>&1)
echo "Результат: $RELOAD_RESULT"

echo ""
echo "3. 🔧 Устанавливаем максимальное логирование..."
docker exec "$CONTAINER_NAME" fs_cli -x "console loglevel debug"
docker exec "$CONTAINER_NAME" fs_cli -x "sofia loglevel all 9"

# ЭТАП 5: Тестирование с детальным мониторингом
echo ""
echo "📋 ЭТАП 5: ТЕСТИРОВАНИЕ С ДЕТАЛЬНЫМ МОНИТОРИНГОМ"
echo "=============================================="

echo ""
echo "🔍 ИНСТРУКЦИИ ДЛЯ ТЕСТИРОВАНИЯ:"
echo "1. Мы сейчас запустим звонок"
echo "2. Поднимите трубку"
echo "3. Нажмите ЛЮБУЮ цифру: 1, 2, 9, 0"
echo "4. Смотрите на экран - логи будут в РЕАЛЬНОМ ВРЕМЕНИ"
echo "5. Ищите строки с === и CRIT"
echo ""

read -p "Готовы к тестированию? Нажмите Enter..."

echo ""
echo "🚀 ЗАПУСК ТЕСТА С МАКСИМАЛЬНЫМ ЛОГИРОВАНИЕМ..."
echo "============================================"

# Запускаем мониторинг логов в фоне
echo "1. 📊 Запускаем мониторинг логов..."
timeout 90 bash -c "
docker exec '$CONTAINER_NAME' fs_cli -x 'console loglevel debug' > /dev/null 2>&1
docker exec '$CONTAINER_NAME' tail -f /usr/local/freeswitch/log/freeswitch.log | grep --line-buffered -E '(CRIT|===|DTMF|ВЕБХУК)'
" &

MONITOR_PID=$!

sleep 2

echo ""
echo "2. 📞 Запускаем тестовый звонок..."
TEST_CALL=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/$PHONE_NUMBER 1201 XML default" 2>&1)
echo "Звонок: $TEST_CALL"

# Извлекаем UUID
UUID=$(echo "$TEST_CALL" | grep -o '+OK [a-f0-9-]\{36\}' | cut -d' ' -f2)
echo "UUID: $UUID"

echo ""
echo "3. 🔍 МОНИТОРИНГ АКТИВЕН! СЛЕДИТЕ ЗА ЛОГАМИ ВЫШЕ!"
echo "================================================="
echo ""
echo "🎯 ИЩИТЕ В ЛОГАХ:"
echo "=== IVR МАКСИМАЛЬНЫЙ ЛОРГИНГ ==="
echo "=== ЗВОНОК ОТВЕЧЕН ==="
echo "=== НАЧИНАЕМ СБОР DTMF ==="
echo "=== ОБРАБОТЧИК ЦИФРЫ [X] ==="
echo "[ВЕБХУК] DTMF=[цифра], Action=[действие]"
echo ""
echo "⏰ У вас 60 секунд для тестирования..."

sleep 60

# Останавливаем мониторинг
kill $MONITOR_PID 2>/dev/null

# ЭТАП 6: Анализ результатов
echo ""
echo "📋 ЭТАП 6: АНАЛИЗ РЕЗУЛЬТАТОВ"
echo "============================"

echo ""
echo "1. 📊 Проверяем состояние звонков..."
FINAL_CALLS=$(docker exec "$CONTAINER_NAME" fs_cli -x "show calls" 2>&1)
echo "Финальное состояние:"
echo "$FINAL_CALLS"

echo ""
echo "2. 📝 Ищем DTMF события в файле логов..."
DTMF_EVENTS=$(docker exec "$CONTAINER_NAME" grep -E "(CRIT.*DTMF|CRIT.*ОБРАБОТЧИК|CRIT.*ВЕБХУК)" /usr/local/freeswitch/log/freeswitch.log | tail -20 2>&1)
echo "DTMF события в логах:"
echo "$DTMF_EVENTS"

echo ""
echo "3. 📋 Проверяем последние КРИТИЧЕСКИЕ события..."
CRIT_EVENTS=$(docker exec "$CONTAINER_NAME" grep "CRIT" /usr/local/freeswitch/log/freeswitch.log | tail -10 2>&1)
echo "Последние КРИТИЧЕСКИЕ события:"
echo "$CRIT_EVENTS"

echo ""
echo "❓ РЕЗУЛЬТАТЫ МАКСИМАЛЬНОГО МОНИТОРИНГА:"
echo "1. Видели ли логи === IVR МАКСИМАЛЬНЫЙ ЛОРГИНГ ===?"
echo "2. Появлялись ли строки === ОБРАБОТЧИК ЦИФРЫ [X] ===?"
echo "3. Отображались ли [ВЕБХУК] сообщения?"
read -p "Введите да/нет: " MAX_RESULT

echo ""
echo "📋 ДИАГНОСТИКА ЗАВЕРШЕНА"
echo "======================="

if [[ "$MAX_RESULT" =~ ^[ДдYy] ]]; then
    echo ""
    echo "🎉 ОТЛИЧНО! МАКСИМАЛЬНЫЙ МОНИТОРИНГ РАБОТАЕТ!"
    echo ""
    echo "✅ DTMF СОБЫТИЯ ОТСЛЕЖИВАЮТСЯ:"
    echo "- Нажатые цифры видны в логах"
    echo "- Обработчики срабатывают"
    echo "- Вебхук места готовы"
    echo ""
    echo "🔗 ГОТОВНОСТЬ К ИНТЕГРАЦИИ ВЕБХУКОВ:"
    echo "Строки [ВЕБХУК] показывают где добавить HTTP запросы"
    
else
    echo ""
    echo "🔧 ПРОБЛЕМА ТРЕБУЕТ ДАЛЬНЕЙШЕЙ ДИАГНОСТИКИ"
    echo ""
    echo "🔍 ВОЗМОЖНЫЕ ПРИЧИНЫ:"
    echo "1. DTMF не поддерживается провайдером"
    echo "2. Неправильные настройки кодеков"
    echo "3. Проблемы с сетью/протоколом"
    echo "4. Настройки телефона/устройства"
    echo ""
    echo "📋 ДАЛЬНЕЙШИЕ ДЕЙСТВИЯ:"
    echo "1. Проверить поддержку DTMF у провайдера"
    echo "2. Тестировать с другого устройства"
    echo "3. Проверить настройки кодеков"
fi

echo ""
echo "📋 КОМАНДЫ ДЛЯ ДАЛЬНЕЙШЕГО МОНИТОРИНГА:"
echo "====================================="
echo ""
echo "# Мониторинг в реальном времени:"
echo "docker exec $CONTAINER_NAME tail -f /usr/local/freeswitch/log/freeswitch.log | grep -E '(CRIT|===|DTMF)'"
echo ""
echo "# Поиск DTMF событий:"
echo "docker exec $CONTAINER_NAME grep -E '(ОБРАБОТЧИК|ВЕБХУК|DTMF)' /usr/local/freeswitch/log/freeswitch.log | tail -20"
echo ""
echo "# Тест с максимальным логированием:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"originate sofia/gateway/sip_trunk/$PHONE_NUMBER 1201 XML default\""

echo ""
echo "🔧 МАКСИМАЛЬНАЯ ДИАГНОСТИКА ЗАВЕРШЕНА!"
echo "====================================" 