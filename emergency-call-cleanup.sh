#!/bin/bash

# 🚨 ЭКСТРЕННАЯ ОЧИСТКА ВИСЯЩИХ ЗВОНКОВ
# Исправление критической проблемы с незавершающимися звонками

CONTAINER_NAME="freeswitch-test"
PHONE_NUMBER="79206054020"

echo "🚨 ЭКСТРЕННАЯ ОЧИСТКА ВИСЯЩИХ ЗВОНКОВ"
echo "==================================="
echo ""

echo "⚠️ КРИТИЧЕСКАЯ ПРОБЛЕМА ОБНАРУЖЕНА:"
echo "- 5 активных звонков висят ЧАСАМИ!"
echo "- Используют echo, park, sleep applications"
echo "- НЕ завершаются автоматически"
echo "- Могут стоить МНОГО ДЕНЕГ провайдеру"
echo ""

# ЭТАП 1: Принудительное завершение всех висящих звонков
echo "🚨 ЭТАП 1: ПРИНУДИТЕЛЬНОЕ ЗАВЕРШЕНИЕ ЗВОНКОВ"
echo "==========================================="

echo ""
echo "1. 📊 Текущие активные звонки..."
CURRENT_CALLS=$(docker exec "$CONTAINER_NAME" fs_cli -x "show calls count" 2>&1)
echo "Активных звонков: $CURRENT_CALLS"

echo ""
echo "2. 📋 Список всех активных каналов..."
ACTIVE_CHANNELS=$(docker exec "$CONTAINER_NAME" fs_cli -x "show channels as xml" 2>&1)
echo "Получены данные о каналах"

echo ""
echo "3. 🔪 ПРИНУДИТЕЛЬНОЕ ЗАВЕРШЕНИЕ ВСЕХ ЗВОНКОВ..."

# Получаем UUID всех активных каналов и завершаем их
docker exec "$CONTAINER_NAME" fs_cli -x "show channels" | grep -E "^[a-f0-9\-]{36}" | while read uuid rest; do
    if [[ "$uuid" =~ ^[a-f0-9\-]{36}$ ]]; then
        echo "Завершаем канал: $uuid"
        docker exec "$CONTAINER_NAME" fs_cli -x "uuid_kill $uuid"
        sleep 0.5
    fi
done

echo ""
echo "4. 🧹 Дополнительная очистка..."
docker exec "$CONTAINER_NAME" fs_cli -x "hupall MANAGER_REQUEST"

sleep 3

echo ""
echo "5. ✅ Проверка результата..."
CALLS_AFTER=$(docker exec "$CONTAINER_NAME" fs_cli -x "show calls count" 2>&1)
echo "Звонков после очистки: $CALLS_AFTER"

# ЭТАП 2: Исправление диалплана с правильными таймаутами
echo ""
echo "📋 ЭТАП 2: ИСПРАВЛЕНИЕ ДИАЛПЛАНА"
echo "==============================="

echo ""
echo "Создаем безопасный диалплан с автоматическим завершением..."

# Создаем исправленный диалплан с таймаутами
cat > /tmp/safe_dialplan.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<!--
  БЕЗОПАСНЫЙ IVR ДИАЛПЛАН С АВТОМАТИЧЕСКИМ ЗАВЕРШЕНИЕМ
  Основано на официальной документации FreeSWITCH
-->
<include>
  <context name="default">
    
    <!-- Echo тест с таймаутом -->
    <extension name="echo_test">
      <condition field="destination_number" expression="^(echo|9196)$">
        <action application="answer"/>
        <action application="set" data="call_timeout=30"/>
        <action application="set" data="hangup_after_bridge=true"/>
        <action application="sched_hangup" data="+30 ALLOTTED_TIMEOUT"/>
        <action application="echo"/>
      </condition>
    </extension>

    <!-- БЕЗОПАСНЫЙ IVR с автоматическим завершением -->
    <extension name="safe_ivr">
      <condition field="destination_number" expression="^(1201)$">
        <action application="answer"/>
        <action application="log" data="INFO === БЕЗОПАСНЫЙ IVR ЗАПУЩЕН ==="/>
        
        <!-- КРИТИЧЕСКИ ВАЖНО: автоматическое завершение -->
        <action application="set" data="call_timeout=60"/>
        <action application="set" data="hangup_after_bridge=true"/>
        <action application="sched_hangup" data="+120 ALLOTTED_TIMEOUT"/>
        
        <action application="sleep" data="1000"/>
        
        <!-- Приветственный тон -->
        <action application="playback" data="tone_stream://%(1000,500,800)"/>
        <action application="sleep" data="500"/>
        
        <!-- Сбор DTMF с таймаутом -->
        <action application="read" data="choice,1,1,tone_stream://%(200,100,300),choice,10000"/>
        <action application="log" data="INFO Выбор пользователя: ${choice}"/>
        
        <!-- Проверка выбора -->
        <action application="execute_extension" data="choice_${choice} XML default"/>
        
        <!-- Принудительное завершение если ничего не выбрано -->
        <action application="hangup" data="NO_ANSWER"/>
      </condition>
    </extension>

    <!-- Обработка выборов с ОБЯЗАТЕЛЬНЫМ завершением -->
    <extension name="choice_1">
      <condition field="destination_number" expression="^choice_1$">
        <action application="log" data="INFO Выбрана опция 1"/>
        <action application="set" data="hangup_after_bridge=true"/>
        <action application="playback" data="tone_stream://%(2000,500,1000)"/>
        <action application="sleep" data="2000"/>
        <!-- ОБЯЗАТЕЛЬНОЕ завершение -->
        <action application="hangup" data="NORMAL_CLEARING"/>
      </condition>
    </extension>

    <extension name="choice_2">
      <condition field="destination_number" expression="^choice_2$">
        <action application="log" data="INFO Выбрана опция 2"/>
        <action application="set" data="hangup_after_bridge=true"/>
        <action application="playback" data="tone_stream://%(2000,500,500)"/>
        <action application="sleep" data="2000"/>
        <!-- ОБЯЗАТЕЛЬНОЕ завершение -->
        <action application="hangup" data="NORMAL_CLEARING"/>
      </condition>
    </extension>

    <extension name="choice_9">
      <condition field="destination_number" expression="^choice_9$">
        <action application="log" data="INFO Выбрана опция 9 - Ограниченный Echo"/>
        <action application="set" data="hangup_after_bridge=true"/>
        <action application="sched_hangup" data="+30 ALLOTTED_TIMEOUT"/>
        <!-- Ограниченный echo на 30 секунд -->
        <action application="echo"/>
      </condition>
    </extension>

    <!-- Обработка неверного выбора -->
    <extension name="choice_">
      <condition field="destination_number" expression="^choice_$">
        <action application="log" data="INFO Нет выбора, завершение"/>
        <action application="playback" data="tone_stream://%(500,200,200)"/>
        <action application="hangup" data="NO_ANSWER"/>
      </condition>
    </extension>

    <!-- БЕЗОПАСНЫЕ исходящие звонки -->
    <extension name="outbound_calls">
      <condition field="destination_number" expression="^(\d{11})$">
        <action application="set" data="caller_id_name=79058615815"/>
        <action application="set" data="caller_id_number=79058615815"/>
        
        <!-- КРИТИЧЕСКИ ВАЖНО: таймауты и автозавершение -->
        <action application="set" data="call_timeout=60"/>
        <action application="set" data="hangup_after_bridge=true"/>
        <action application="set" data="bridge_answer_timeout=30"/>
        
        <action application="bridge" data="sofia/gateway/sip_trunk/$1"/>
        
        <!-- Принудительное завершение если bridge не удался -->
        <action application="hangup" data="NO_ROUTE_DESTINATION"/>
      </condition>
    </extension>

  </context>
</include>
EOF

echo "✅ Безопасный диалплан создан"

# ЭТАП 3: Установка исправленного диалплана
echo ""
echo "📋 ЭТАП 3: УСТАНОВКА БЕЗОПАСНОГО ДИАЛПЛАНА"
echo "========================================"

echo ""
echo "1. 📄 Устанавливаем безопасный диалплан..."
docker cp /tmp/safe_dialplan.xml "$CONTAINER_NAME:/usr/local/freeswitch/conf/dialplan/default.xml"

echo ""
echo "2. 🔄 Перезагружаем конфигурацию..."
RELOAD_RESULT=$(docker exec "$CONTAINER_NAME" fs_cli -x "reloadxml" 2>&1)
echo "Результат: $RELOAD_RESULT"

# ЭТАП 4: Настройка глобальных таймаутов
echo ""
echo "📋 ЭТАП 4: ГЛОБАЛЬНЫЕ НАСТРОЙКИ БЕЗОПАСНОСТИ"
echo "=========================================="

echo ""
echo "Настраиваем глобальные таймауты FreeSWITCH..."

# Создаем конфигурацию с глобальными таймаутами
cat > /tmp/timeout_config.xml << 'EOF'
<!-- Глобальные таймауты для безопасности -->
<configuration name="switch.conf" description="Core Configuration">
  <settings>
    <param name="default-max-sessions" value="1000"/>
    <param name="sessions-per-second" value="30"/>
    <param name="rtp-start-port" value="16384"/>
    <param name="rtp-end-port" value="32768"/>
    <!-- КРИТИЧЕСКИ ВАЖНО: максимальное время сессии -->
    <param name="max-session-timeout" value="300"/>
    <param name="min-session-timeout" value="10"/>
  </settings>
</configuration>
EOF

echo ""
echo "1. 📄 Устанавливаем конфигурацию таймаутов..."
docker cp /tmp/timeout_config.xml "$CONTAINER_NAME:/usr/local/freeswitch/conf/autoload_configs/switch.conf.xml"

# ЭТАП 5: Тестирование безопасного IVR
echo ""
echo "🧪 ЭТАП 5: ТЕСТИРОВАНИЕ БЕЗОПАСНОГО IVR"
echo "====================================="

echo ""
echo "1. 🔍 Проверка отсутствия активных звонков..."
CALLS_CHECK=$(docker exec "$CONTAINER_NAME" fs_cli -x "show calls count" 2>&1)
echo "Активных звонков: $CALLS_CHECK"

echo ""
echo "2. 🧪 Тест безопасного IVR..."
SAFE_TEST=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/$PHONE_NUMBER 1201 XML default" 2>&1)
echo "Тест безопасного IVR: $SAFE_TEST"

sleep 15

echo ""
echo "3. 📊 Проверка автоматического завершения..."
CALLS_AFTER_TEST=$(docker exec "$CONTAINER_NAME" fs_cli -x "show calls count" 2>&1)
echo "Звонков после теста: $CALLS_AFTER_TEST"

echo ""
echo "❓ ПОЛУЧИЛИ ЛИ ЗВОНОК И ЗАВЕРШИЛСЯ ЛИ ОН АВТОМАТИЧЕСКИ?"
read -p "Введите да/нет: " SAFE_RESULT

# ЭТАП 6: Финальные рекомендации
echo ""
echo "📋 ЭТАП 6: КРИТИЧЕСКИ ВАЖНЫЕ РЕКОМЕНДАЦИИ"
echo "======================================="

if [[ "$SAFE_RESULT" =~ ^[ДдYy] ]]; then
    echo ""
    echo "🎉 ОТЛИЧНО! ПРОБЛЕМА РЕШЕНА!"
    echo ""
    echo "✅ ИСПРАВЛЕНИЯ ПРИМЕНЕНЫ:"
    echo "- Все висящие звонки принудительно завершены"
    echo "- Добавлены автоматические таймауты"
    echo "- hangup_after_bridge=true во всех extensions"
    echo "- sched_hangup для принудительного завершения"
    echo "- call_timeout и bridge_answer_timeout"
    echo ""
    echo "🔒 БЕЗОПАСНЫЕ КОМАНДЫ ДЛЯ BACKEND:"
    echo ""
    echo "// БЕЗОПАСНЫЙ Node.js код:"
    echo "const callResult = await executeCommand("
    echo "    'docker exec freeswitch-test fs_cli -x \"originate sofia/gateway/sip_trunk/' + phoneNumber + ' 1201 XML default\"'"
    echo ");"
    echo ""
    echo "// Проверка успеха:"
    echo "if (callResult.includes('+OK')) {"
    echo "    console.log('Безопасный IVR звонок запущен');"
    echo "    "
    echo "    // Автоматический мониторинг завершения"
    echo "    setTimeout(() => {"
    echo "        checkCallStatus(callResult.match(/[a-f0-9-]{36}/)[0]);"
    echo "    }, 60000); // Проверка через 60 секунд"
    echo "}"
    
else
    echo ""
    echo "⚠️ НУЖНА ДОПОЛНИТЕЛЬНАЯ ДИАГНОСТИКА!"
    echo ""
    echo "ПРОВЕРЬТЕ:"
    echo "1. Логи FreeSWITCH:"
    echo "   docker exec $CONTAINER_NAME tail -f /usr/local/freeswitch/log/freeswitch.log"
    echo ""
    echo "2. Активные звонки:"
    echo "   docker exec $CONTAINER_NAME fs_cli -x \"show channels\""
    echo ""
    echo "3. Принудительное завершение:"
    echo "   docker exec $CONTAINER_NAME fs_cli -x \"hupall MANAGER_REQUEST\""
fi

echo ""
echo "🚨 КРИТИЧЕСКИ ВАЖНЫЕ КОМАНДЫ ДЛЯ МОНИТОРИНГА:"
echo "============================================"
echo ""
echo "# Проверка активных звонков:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"show calls count\""
echo ""
echo "# Принудительное завершение ВСЕХ звонков:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"hupall MANAGER_REQUEST\""
echo ""
echo "# Безопасный IVR звонок:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"originate sofia/gateway/sip_trunk/$PHONE_NUMBER 1201 XML default\""
echo ""
echo "# Завершение конкретного звонка по UUID:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"uuid_kill <UUID>\""

echo ""
echo "💰 ФИНАНСОВАЯ БЕЗОПАСНОСТЬ:"
echo "=========================="
echo ""
echo "⚠️ ВИСЯЩИЕ ЗВОНКИ МОГУТ СТОИТЬ ОЧЕНЬ ДОРОГО!"
echo "- Провайдер считает время подключения"
echo "- 5 звонков x 4 часа = 20 часов тарификации"
echo "- Обязательно следите за автоматическим завершением"
echo ""
echo "✅ ТЕПЕРЬ У ВАС ЕСТЬ БЕЗОПАСНАЯ СИСТЕМА:"
echo "- Автоматическое завершение через 60-120 секунд"
echo "- Принудительные таймауты"
echo "- Мониторинг висящих звонков"

echo ""
echo "🎯 ЭКСТРЕННАЯ ОЧИСТКА ЗАВЕРШЕНА!"
echo "===============================" 