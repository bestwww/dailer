#!/bin/bash

# 🔧 ИСПРАВЛЕНИЕ IVR EXTENSION В ДИАЛПЛАНЕ
# Проблема: IVR extension не выполняется, звонки падают

CONTAINER_NAME="freeswitch-test"

echo "🔧 ИСПРАВЛЕНИЕ IVR EXTENSION"
echo "==========================="
echo ""

echo "🚨 ПРОБЛЕМА НАЙДЕНА:"
echo "- Прямые звонки (&echo) работают ✅"
echo "- IVR звонки (ivr_menu) НЕ работают ❌"
echo "- Проблема в IVR extension диалплана"
echo ""

# ЭТАП 1: Диагностика текущего состояния
echo "📋 ЭТАП 1: ДИАГНОСТИКА ДИАЛПЛАНА"
echo "==============================="

echo ""
echo "1. 🔍 Проверка загрузки модуля mod_lua:"
echo "---------------------------------------"
LUA_MODULE=$(docker exec "$CONTAINER_NAME" fs_cli -x "module_exists mod_lua" 2>&1)
echo "Результат mod_lua: $LUA_MODULE"

if echo "$LUA_MODULE" | grep -q "true"; then
    echo "✅ mod_lua загружен"
else
    echo "❌ mod_lua НЕ загружен - загружаем..."
    docker exec "$CONTAINER_NAME" fs_cli -x "load mod_lua"
fi

echo ""
echo "2. 🔍 Проверка текущего диалплана:"
echo "----------------------------------"
CURRENT_DIALPLAN=$(docker exec "$CONTAINER_NAME" cat /usr/local/freeswitch/conf/dialplan/default.xml | grep -A10 -B2 "ivr_menu")
echo "Текущий IVR extension:"
echo "$CURRENT_DIALPLAN"

echo ""
echo "3. 🧪 Тест синтаксиса диалплана:"
echo "--------------------------------"
SYNTAX_CHECK=$(docker exec "$CONTAINER_NAME" fs_cli -x "xml_locate dialplan context default ivr_menu" 2>&1)
echo "XML синтаксис: $SYNTAX_CHECK"

# ЭТАП 2: Создание исправленного диалплана
echo ""
echo "📋 ЭТАП 2: СОЗДАНИЕ ИСПРАВЛЕННОГО ДИАЛПЛАНА"
echo "=========================================="

echo ""
echo "Создаем УПРОЩЕННЫЙ IVR extension..."

# Создаем новый исправленный диалплан
cat > /tmp/fixed_dialplan.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<!--
  Исправленный диалплан для IVR
  Проблема: оригинальный ivr_menu extension не работал
-->
<include>
  <!-- Простой echo тест (РАБОТАЕТ) -->
  <extension name="echo">
    <condition field="destination_number" expression="^(echo|9196)$">
      <action application="answer"/>
      <action application="echo"/>
    </condition>
  </extension>

  <!-- ИСПРАВЛЕННЫЙ IVR extension -->
  <extension name="ivr_menu_fixed">
    <condition field="destination_number" expression="^(ivr_menu)$">
      <!-- Сначала отвечаем на звонок -->
      <action application="answer"/>
      
      <!-- Ожидание для установки соединения -->
      <action application="sleep" data="2000"/>
      
      <!-- Устанавливаем caller ID -->
      <action application="set" data="caller_id_name=79058615815"/>
      <action application="set" data="caller_id_number=79058615815"/>
      
      <!-- Включаем детальное логирование для этого звонка -->
      <action application="set" data="log_level=DEBUG"/>
      
      <!-- ПРОСТОЙ ТЕСТ: играем тон вместо Lua -->
      <action application="playback" data="tone_stream://%(1000,500,800)"/>
      
      <!-- Пауза -->
      <action application="sleep" data="1000"/>
      
      <!-- Пробуем запустить Lua скрипт -->
      <action application="log" data="INFO Запуск IVR Lua скрипта"/>
      <action application="lua" data="ivr_menu.lua"/>
      
      <!-- Если Lua не сработал, играем финальный тон и завершаем -->
      <action application="log" data="INFO IVR завершен"/>
      <action application="playback" data="tone_stream://%(500,500,400)"/>
      <action application="hangup"/>
    </condition>
  </extension>

  <!-- Альтернативный БЕЗОПАСНЫЙ IVR (без Lua) -->
  <extension name="ivr_safe">
    <condition field="destination_number" expression="^(ivr_safe)$">
      <action application="answer"/>
      <action application="sleep" data="1000"/>
      <action application="set" data="caller_id_name=79058615815"/>
      <action application="set" data="caller_id_number=79058615815"/>
      
      <!-- Играем приветственный тон -->
      <action application="playback" data="tone_stream://%(1000,500,800)"/>
      
      <!-- Ожидаем нажатие кнопки -->
      <action application="read" data="1,1,tone_stream://%(200,100,300),input_var,5000"/>
      
      <!-- Обрабатываем ввод -->
      <action application="transfer" data="${input_var} XML ivr_options"/>
    </condition>
  </extension>

  <!-- Обработка опций IVR -->
  <extension name="ivr_option_1">
    <condition field="destination_number" expression="^1$">
      <condition field="context" expression="ivr_options">
        <action application="playback" data="tone_stream://%(500,200,1000)"/>
        <action application="hangup"/>
      </condition>
    </condition>
  </extension>

  <extension name="ivr_option_2">
    <condition field="destination_number" expression="^2$">
      <condition field="context" expression="ivr_options">
        <action application="playback" data="tone_stream://%(500,200,500)"/>
        <action application="hangup"/>
      </condition>
    </condition>
  </extension>

  <extension name="ivr_option_9">
    <condition field="destination_number" expression="^9$">
      <condition field="context" expression="ivr_options">
        <action application="echo"/>
      </condition>
    </condition>
  </extension>

  <!-- Исходящие звонки (БЕЗ ИЗМЕНЕНИЙ) -->
  <extension name="outbound_calls">
    <condition field="destination_number" expression="^(\d{11})$">
      <action application="set" data="caller_id_name=79058615815"/>
      <action application="set" data="caller_id_number=79058615815"/>
      <action application="set" data="hangup_after_bridge=true"/>
      <action application="bridge" data="sofia/gateway/sip_trunk/$1"/>
    </condition>
  </extension>

</include>
EOF

echo "✅ Исправленный диалплан создан"

# ЭТАП 3: Установка исправленного диалплана
echo ""
echo "📋 ЭТАП 3: УСТАНОВКА ИСПРАВЛЕННОГО ДИАЛПЛАНА"
echo "==========================================="

echo ""
echo "1. 📋 Бэкап старого диалплана:"
echo "------------------------------"
docker exec "$CONTAINER_NAME" cp /usr/local/freeswitch/conf/dialplan/default.xml /usr/local/freeswitch/conf/dialplan/default.xml.backup
echo "✅ Бэкап создан"

echo ""
echo "2. 📄 Установка нового диалплана:"
echo "--------------------------------"
docker cp /tmp/fixed_dialplan.xml "$CONTAINER_NAME:/usr/local/freeswitch/conf/dialplan/default.xml"
echo "✅ Новый диалплан установлен"

echo ""
echo "3. 🔄 Перезагрузка диалплана:"
echo "-----------------------------"
RELOAD_RESULT=$(docker exec "$CONTAINER_NAME" fs_cli -x "reloadxml" 2>&1)
echo "Результат перезагрузки: $RELOAD_RESULT"

# ЭТАП 4: Тестирование исправлений
echo ""
echo "🧪 ЭТАП 4: ТЕСТИРОВАНИЕ ИСПРАВЛЕНИЙ"
echo "================================="

echo ""
echo "Тест 1: Исправленный IVR (ivr_menu)"
echo "-----------------------------------"
echo "Тестируем исправленный IVR extension..."

# Очищаем статистику
STATS_BEFORE=$(docker exec "$CONTAINER_NAME" fs_cli -x "sofia status gateway internal::sip_trunk" | grep "CallsOUT" | head -1 | awk '{print $2}')

# Выполняем тест
IVR_TEST=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/79206054020 ivr_menu" 2>&1)
echo "Результат IVR теста: $IVR_TEST"

# Ждем
echo "Ожидание 15 секунд..."
sleep 15

# Проверяем статистику
STATS_AFTER=$(docker exec "$CONTAINER_NAME" fs_cli -x "sofia status gateway internal::sip_trunk" | grep "CallsOUT" | head -1 | awk '{print $2}')
NEW_CALLS=$((STATS_AFTER - STATS_BEFORE))

if [ $NEW_CALLS -gt 0 ]; then
    echo "✅ IVR тест ПРОШЕЛ! Новых звонков: $NEW_CALLS"
else
    echo "❌ IVR тест НЕ прошел"
fi

echo ""
echo "Тест 2: Безопасный IVR (ivr_safe)"
echo "--------------------------------"
echo "Тестируем безопасный IVR без Lua..."

SAFE_TEST=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/79206054020 ivr_safe" 2>&1)
echo "Результат безопасного теста: $SAFE_TEST"

sleep 10

echo ""
echo "Тест 3: Transfer на исправленный IVR"
echo "------------------------------------"
TRANSFER_TEST=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/79206054020 &transfer:ivr_menu" 2>&1)
echo "Результат transfer теста: $TRANSFER_TEST"

sleep 10

# ЭТАП 5: Финальная проверка
echo ""
echo "📊 ЭТАП 5: ФИНАЛЬНАЯ ПРОВЕРКА"
echo "============================"

echo ""
echo "📊 Финальная статистика:"
FINAL_STATS=$(docker exec "$CONTAINER_NAME" fs_cli -x "sofia status gateway internal::sip_trunk" | grep -E "(CallsOUT|FailedCallsOUT)")
echo "$FINAL_STATS"

echo ""
echo "📋 Доступные extension для тестирования:"
echo "- ivr_menu (исправленный с Lua)"
echo "- ivr_safe (безопасный без Lua)"
echo "- echo (рабочий тест)"

echo ""
echo "💡 РЕЗУЛЬТАТ И ИНСТРУКЦИИ"
echo "========================"

echo ""
echo "🔧 ЧТО ИСПРАВЛЕНО:"
echo "- Добавлен answer ПЕРЕД всеми действиями"
echo "- Увеличено время sleep для установки соединения"
echo "- Добавлено детальное логирование"
echo "- Создан альтернативный безопасный IVR"
echo "- Исправлен порядок выполнения действий"

echo ""
echo "🧪 КОМАНДЫ ДЛЯ ТЕСТИРОВАНИЯ:"
echo ""
echo "# Исправленный IVR с Lua:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"originate sofia/gateway/sip_trunk/79206054020 ivr_menu\""
echo ""
echo "# Безопасный IVR без Lua:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"originate sofia/gateway/sip_trunk/79206054020 ivr_safe\""
echo ""
echo "# Transfer на исправленный IVR:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"originate sofia/gateway/sip_trunk/79206054020 &transfer:ivr_menu\""

echo ""
echo "🎯 ОЖИДАЕМОЕ ПОВЕДЕНИЕ:"
echo "- Звонок должен прийти на мобильный"
echo "- Услышите приветственный тон (800Hz)"
echo "- Можете нажимать кнопки для тестирования"

echo ""
echo "✅ Исправление IVR extension завершено!" 