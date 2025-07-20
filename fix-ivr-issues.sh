#!/bin/bash

# 🔧 ИСПРАВЛЕНИЕ ПРОБЛЕМ С IVR
# JavaScript модуль и диалплан

CONTAINER_NAME="freeswitch-test"
PHONE_NUMBER="79206054020"

echo "🔧 ИСПРАВЛЕНИЕ ПРОБЛЕМ С IVR"
echo "============================"
echo ""

echo "📋 ОБНАРУЖЕННЫЕ ПРОБЛЕМЫ:"
echo "1. ❌ JavaScript модуль mod_v8 не загружается"
echo "2. ❌ Диалплан не находится (xml_locate)"
echo "3. ❌ Локальные тесты: SUBSCRIBER_ABSENT"
echo "4. ✅ Но внешний звонок проходит!"
echo ""

# ЭТАП 1: Проверка установки модулей
echo "📋 ЭТАП 1: ПРОВЕРКА МОДУЛЕЙ"
echo "=========================="

echo ""
echo "1. 🔍 Проверка доступных модулей..."
AVAILABLE_MODULES=$(docker exec "$CONTAINER_NAME" ls /usr/local/freeswitch/mod/ | grep -E "(v8|javascript|spidermonkey)" || echo "Нет JS модулей")
echo "Доступные JS модули: $AVAILABLE_MODULES"

echo ""
echo "2. 🔍 Проверка конфигурации модулей..."
MODULE_CONFIG=$(docker exec "$CONTAINER_NAME" cat /usr/local/freeswitch/conf/autoload_configs/modules.conf.xml | grep -E "(v8|javascript|spidermonkey)" || echo "Не настроены")
echo "Конфигурация модулей: $MODULE_CONFIG"

echo ""
echo "3. 🔍 Проверка загруженных модулей..."
LOADED_MODULES=$(docker exec "$CONTAINER_NAME" fs_cli -x "show modules" | grep -E "(v8|javascript|spidermonkey)" || echo "Не загружены")
echo "Загруженные модули: $LOADED_MODULES"

# ЭТАП 2: Альтернативный диалплан без JavaScript
echo ""
echo "📋 ЭТАП 2: ДИАЛПЛАН БЕЗ JAVASCRIPT"
echo "================================"

echo ""
echo "Создаем простой IVR диалплан без JavaScript..."

# Создаем диалплан только с встроенными приложениями
cat > /tmp/simple_dialplan.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<!--
  ПРОСТОЙ IVR БЕЗ JAVASCRIPT
  Только встроенные FreeSWITCH приложения
-->
<include>
  <context name="default">
    
    <!-- Echo тест -->
    <extension name="echo_test">
      <condition field="destination_number" expression="^(echo|9196)$">
        <action application="answer"/>
        <action application="echo"/>
      </condition>
    </extension>

    <!-- Простой IVR с тонами -->
    <extension name="simple_ivr">
      <condition field="destination_number" expression="^(1201)$">
        <action application="answer"/>
        <action application="log" data="INFO === ПРОСТОЙ IVR ЗАПУЩЕН ==="/>
        <action application="sleep" data="1000"/>
        
        <!-- Приветственный тон -->
        <action application="playback" data="tone_stream://%(1000,500,800)"/>
        <action application="sleep" data="500"/>
        
        <!-- Сбор DTMF -->
        <action application="read" data="choice,1,1,tone_stream://%(200,100,300),choice,5000"/>
        <action application="log" data="INFO Выбор пользователя: ${choice}"/>
        
        <!-- Обработка выбора -->
        <action application="execute_extension" data="choice_${choice} XML default"/>
      </condition>
    </extension>

    <!-- Обработка выборов -->
    <extension name="choice_1">
      <condition field="destination_number" expression="^choice_1$">
        <action application="log" data="INFO Выбрана опция 1"/>
        <action application="playback" data="tone_stream://%(1000,500,1000)"/>
        <action application="sleep" data="2000"/>
        <action application="hangup"/>
      </condition>
    </extension>

    <extension name="choice_2">
      <condition field="destination_number" expression="^choice_2$">
        <action application="log" data="INFO Выбрана опция 2"/>
        <action application="playback" data="tone_stream://%(1000,500,500)"/>
        <action application="sleep" data="2000"/>
        <action application="hangup"/>
      </condition>
    </extension>

    <extension name="choice_9">
      <condition field="destination_number" expression="^choice_9$">
        <action application="log" data="INFO Выбрана опция 9 - Echo"/>
        <action application="echo"/>
      </condition>
    </extension>

    <!-- Обработка неверного выбора -->
    <extension name="choice_">
      <condition field="destination_number" expression="^choice_$">
        <action application="log" data="INFO Нет выбора, повтор"/>
        <action application="transfer" data="1201 XML default"/>
      </condition>
    </extension>

    <!-- Исходящие звонки -->
    <extension name="outbound_calls">
      <condition field="destination_number" expression="^(\d{11})$">
        <action application="set" data="caller_id_name=79058615815"/>
        <action application="set" data="caller_id_number=79058615815"/>
        <action application="set" data="hangup_after_bridge=true"/>
        <action application="bridge" data="sofia/gateway/sip_trunk/$1"/>
      </condition>
    </extension>

  </context>
</include>
EOF

echo "✅ Простой диалплан создан"

# ЭТАП 3: Установка нового диалплана
echo ""
echo "📋 ЭТАП 3: УСТАНОВКА ДИАЛПЛАНА"
echo "============================="

echo ""
echo "1. 📄 Устанавливаем новый диалплан..."
docker cp /tmp/simple_dialplan.xml "$CONTAINER_NAME:/usr/local/freeswitch/conf/dialplan/default.xml"

echo ""
echo "2. 🔄 Перезагружаем конфигурацию..."
RELOAD_RESULT=$(docker exec "$CONTAINER_NAME" fs_cli -x "reloadxml" 2>&1)
echo "Результат: $RELOAD_RESULT"

echo ""
echo "3. 🔍 Проверяем установку диалплана..."
DIALPLAN_CHECK=$(docker exec "$CONTAINER_NAME" fs_cli -x "xml_locate dialplan context default 1201" 2>&1)
echo "Проверка диалплана: $DIALPLAN_CHECK"

# ЭТАП 4: Создание пользователя для локальных тестов
echo ""
echo "📋 ЭТАП 4: СОЗДАНИЕ ПОЛЬЗОВАТЕЛЯ"
echo "==============================="

echo ""
echo "Создаем пользователя 1000 для локальных тестов..."

# Создаем конфиг пользователя
cat > /tmp/user_1000.xml << 'EOF'
<include>
  <user id="1000">
    <params>
      <param name="password" value="1234"/>
      <param name="vm-password" value="1000"/>
    </params>
    <variables>
      <variable name="toll_allow" value="domestic,international,local"/>
      <variable name="accountcode" value="1000"/>
      <variable name="user_context" value="default"/>
      <variable name="effective_caller_id_name" value="Test User"/>
      <variable name="effective_caller_id_number" value="1000"/>
    </variables>
  </user>
</include>
EOF

echo ""
echo "1. 📄 Создаем директорию пользователей..."
docker exec "$CONTAINER_NAME" mkdir -p /usr/local/freeswitch/conf/directory/default

echo ""
echo "2. 📄 Устанавливаем конфиг пользователя..."
docker cp /tmp/user_1000.xml "$CONTAINER_NAME:/usr/local/freeswitch/conf/directory/default/1000.xml"

echo ""
echo "3. 🔄 Перезагружаем конфигурацию..."
docker exec "$CONTAINER_NAME" fs_cli -x "reloadxml"

# ЭТАП 5: Тестирование исправленного IVR
echo ""
echo "🧪 ЭТАП 5: ТЕСТИРОВАНИЕ ИСПРАВЛЕНИЙ"
echo "=================================="

echo ""
echo "1. 🔍 Проверка диалплана..."
DIALPLAN_TEST=$(docker exec "$CONTAINER_NAME" fs_cli -x "xml_locate dialplan context default 1201" 2>&1)
if echo "$DIALPLAN_TEST" | grep -q "can't find"; then
    echo "❌ Диалплан все еще не найден"
    echo "Вывод: $DIALPLAN_TEST"
else
    echo "✅ Диалплан найден!"
    echo "Первые строки: $(echo "$DIALPLAN_TEST" | head -3)"
fi

echo ""
echo "2. 🧪 Локальный тест IVR..."
LOCAL_TEST=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate user/1000@default 1201" 2>&1)
echo "Локальный тест: $LOCAL_TEST"

sleep 3

echo ""
echo "3. 🧪 Внешний тест IVR..."
EXTERNAL_TEST=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/$PHONE_NUMBER 1201 XML default" 2>&1)
echo "Внешний тест: $EXTERNAL_TEST"

sleep 10

echo ""
echo "❓ ПОЛУЧИЛИ ЛИ ЗВОНОК С IVR (тоны и меню)?"
read -p "Введите да/нет: " IVR_RESULT

if [[ "$IVR_RESULT" =~ ^[ДдYy] ]]; then
    echo "🎉 IVR РАБОТАЕТ!"
    IVR_WORKS=true
else
    echo "❌ IVR не работает или работает частично"
    IVR_WORKS=false
fi

# ЭТАП 6: Логи и диагностика
echo ""
echo "📋 ЭТАП 6: ДИАГНОСТИКА"
echo "====================="

echo ""
echo "1. 📊 Последние логи FreeSWITCH..."
RECENT_LOGS=$(docker exec "$CONTAINER_NAME" fs_cli -x "show calls" 2>&1)
echo "Активные звонки: $RECENT_LOGS"

echo ""
echo "2. 📊 София статус..."
SOFIA_STATUS=$(docker exec "$CONTAINER_NAME" fs_cli -x "sofia status gateway sip_trunk" 2>&1)
echo "SIP trunk статус: $SOFIA_STATUS"

echo ""
echo "3. 📊 Проверка переменных..."
VARIABLES_CHECK=$(docker exec "$CONTAINER_NAME" fs_cli -x "global_getvar local_ip_v4" 2>&1)
echo "Локальный IP: $VARIABLES_CHECK"

# ЭТАП 7: Финальные рекомендации
echo ""
echo "📋 ЭТАП 7: РЕЗУЛЬТАТЫ И РЕКОМЕНДАЦИИ"
echo "=================================="

if [ "$IVR_WORKS" = true ]; then
    echo ""
    echo "🎉 УСПЕХ! IVR СИСТЕМА РАБОТАЕТ!"
    echo ""
    echo "✅ РАБОЧАЯ КОНФИГУРАЦИЯ:"
    echo "- Простой IVR без JavaScript"
    echo "- Встроенные FreeSWITCH приложения"
    echo "- Тоны вместо речи"
    echo "- DTMF обработка через read application"
    echo ""
    echo "📋 КОМАНДЫ ДЛЯ BACKEND:"
    echo ""
    echo "// Node.js пример:"
    echo "const callResult = await executeCommand("
    echo "    'docker exec freeswitch-test fs_cli -x \"originate sofia/gateway/sip_trunk/' + phoneNumber + ' 1201 XML default\"'"
    echo ");"
    echo ""
    echo "// Проверка успеха:"
    echo "if (callResult.includes('+OK')) {"
    echo "    console.log('IVR звонок запущен успешно');"
    echo "}"
    
else
    echo ""
    echo "🔧 ДОПОЛНИТЕЛЬНАЯ ДИАГНОСТИКА НУЖНА:"
    echo ""
    echo "1. Проверить логи звонка:"
    echo "   docker exec $CONTAINER_NAME fs_cli -x \"show channels\""
    echo ""
    echo "2. Проверить реальные логи:"
    echo "   docker exec $CONTAINER_NAME tail -f /usr/local/freeswitch/log/freeswitch.log"
    echo ""
    echo "3. Проверить SIP трейс:"
    echo "   docker exec $CONTAINER_NAME fs_cli -x \"sofia profile external siptrace on\""
fi

echo ""
echo "📋 ВАЖНЫЕ КОМАНДЫ ДЛЯ МОНИТОРИНГА:"
echo "================================"
echo ""
echo "# Проверка диалплана:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"xml_locate dialplan context default 1201\""
echo ""
echo "# Проверка активных звонков:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"show channels\""
echo ""
echo "# Запуск IVR звонка:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"originate sofia/gateway/sip_trunk/$PHONE_NUMBER 1201 XML default\""
echo ""
echo "# Мониторинг логов:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"console loglevel debug\""

echo ""
echo "🎯 IVR БЕЗ JAVASCRIPT НАСТРОЕН!"
echo "===============================" 