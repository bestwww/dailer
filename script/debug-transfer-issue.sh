#!/bin/bash

# 🔍 ДЕТАЛЬНАЯ ДИАГНОСТИКА TRANSFER:IVR_MENU
# Выясняем почему звонки создаются (+OK) но не доходят до абонента

CONTAINER_NAME="freeswitch-test"

echo "🔍 ДИАГНОСТИКА TRANSFER:IVR_MENU ПРОБЛЕМЫ"
echo "========================================"
echo ""

echo "🚨 ПРОБЛЕМА:"
echo "- UUID создается (+OK 0c9060f3-0cf6-4f8c-a792-eabaafe03179)"
echo "- Логи IVR пустые - скрипт не выполняется"
echo "- Звонка не приходит на мобильный"
echo ""

# ЭТАП 1: Проверяем последний звонок детально
echo "📋 ЭТАП 1: АНАЛИЗ ПОСЛЕДНЕГО ЗВОНКА"
echo "=================================="

echo ""
echo "1. 🔍 Поиск UUID в логах:"
echo "------------------------"
LAST_UUID="0c9060f3-0cf6-4f8c-a792-eabaafe03179"
UUID_LOGS=$(docker exec "$CONTAINER_NAME" fs_cli -x "console last 200" | grep "$LAST_UUID" | head -10)
if [ -n "$UUID_LOGS" ]; then
    echo "Найдены логи для UUID $LAST_UUID:"
    echo "$UUID_LOGS"
else
    echo "❌ Логи для UUID $LAST_UUID не найдены"
fi

echo ""
echo "2. 🔍 Поиск информации о transfer:"
echo "--------------------------------"
TRANSFER_LOGS=$(docker exec "$CONTAINER_NAME" fs_cli -x "console last 100" | grep -i -E "(transfer|ivr_menu)" | tail -10)
if [ -n "$TRANSFER_LOGS" ]; then
    echo "Найдены логи transfer:"
    echo "$TRANSFER_LOGS"
else
    echo "❌ Логи transfer не найдены"
fi

echo ""
echo "3. 🔍 Поиск ошибок в последних логах:"
echo "-----------------------------------"
ERROR_LOGS=$(docker exec "$CONTAINER_NAME" fs_cli -x "console last 100" | grep -i -E "(error|fail|exception|timeout|refused)" | tail -15)
if [ -n "$ERROR_LOGS" ]; then
    echo "Найдены ошибки:"
    echo "$ERROR_LOGS"
else
    echo "Явных ошибок не найдено"
fi

# ЭТАП 2: Проверяем работает ли transfer вообще
echo ""
echo "🧪 ЭТАП 2: ТЕСТИРОВАНИЕ TRANSFER МЕХАНИЗМА"
echo "========================================"

echo ""
echo "Тест 1: Простой transfer на echo"
echo "--------------------------------"
echo "Включаем детальные логи..."
docker exec "$CONTAINER_NAME" fs_cli -x "console loglevel debug"
docker exec "$CONTAINER_NAME" fs_cli -x "console clear"

ECHO_TRANSFER=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/79206054020 &transfer:echo" 2>&1)
echo "Результат transfer на echo: $ECHO_TRANSFER"

sleep 8

echo ""
echo "📋 Логи echo transfer:"
ECHO_LOGS=$(docker exec "$CONTAINER_NAME" fs_cli -x "console last 50" | grep -E "(transfer|echo)" | tail -10)
if [ -n "$ECHO_LOGS" ]; then
    echo "$ECHO_LOGS"
else
    echo "Логи echo transfer не найдены"
fi

# ЭТАП 3: Проверяем диалплан
echo ""
echo "📋 ЭТАП 3: ПРОВЕРКА ДИАЛПЛАНА"
echo "============================"

echo ""
echo "1. 📄 Текущий диалплан для ivr_menu:"
DIALPLAN_CONTENT=$(docker exec "$CONTAINER_NAME" cat /usr/local/freeswitch/conf/dialplan/default.xml | grep -A8 "ivr_menu")
if [ -n "$DIALPLAN_CONTENT" ]; then
    echo "$DIALPLAN_CONTENT"
else
    echo "❌ Диалплан для ivr_menu не найден"
fi

echo ""
echo "2. 🔍 Проверяем синтаксис диалплана:"
DIALPLAN_SYNTAX=$(docker exec "$CONTAINER_NAME" xmllint --noout /usr/local/freeswitch/conf/dialplan/default.xml 2>&1)
if [ -z "$DIALPLAN_SYNTAX" ]; then
    echo "✅ Синтаксис диалплана корректен"
else
    echo "❌ Ошибки в диалплане: $DIALPLAN_SYNTAX"
fi

# ЭТАП 4: Проверяем IVR скрипт
echo ""
echo "📋 ЭТАП 4: ПРОВЕРКА IVR СКРИПТА"
echo "============================"

echo ""
echo "1. 📄 Наличие IVR скрипта:"
if docker exec "$CONTAINER_NAME" test -f /usr/local/freeswitch/scripts/ivr_menu.lua; then
    echo "✅ IVR скрипт найден"
    
    echo ""
    echo "2. 📋 Первые строки IVR скрипта:"
    docker exec "$CONTAINER_NAME" head -10 /usr/local/freeswitch/scripts/ivr_menu.lua
    
    echo ""
    echo "3. 🧪 Тест синтаксиса Lua:"
    LUA_SYNTAX=$(docker exec "$CONTAINER_NAME" lua -l /usr/local/freeswitch/scripts/ivr_menu.lua 2>&1)
    if echo "$LUA_SYNTAX" | grep -q "error"; then
        echo "❌ Ошибки синтаксиса Lua: $LUA_SYNTAX"
    else
        echo "✅ Синтаксис Lua корректен"
    fi
else
    echo "❌ IVR скрипт НЕ найден!"
fi

# ЭТАП 5: Прямой тест IVR без transfer
echo ""
echo "🧪 ЭТАП 5: ПРЯМОЙ ТЕСТ IVR"
echo "========================="

echo ""
echo "Тест 2: Прямой вызов IVR extension"
echo "----------------------------------"
docker exec "$CONTAINER_NAME" fs_cli -x "console clear"

DIRECT_IVR=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/79206054020 ivr_menu" 2>&1)
echo "Результат прямого IVR: $DIRECT_IVR"

sleep 10

echo ""
echo "📋 Логи прямого IVR:"
DIRECT_LOGS=$(docker exec "$CONTAINER_NAME" fs_cli -x "console last 50" | grep -E "(IVR|ivr|Menu|Session)" | tail -15)
if [ -n "$DIRECT_LOGS" ]; then
    echo "$DIRECT_LOGS"
else
    echo "Логи прямого IVR не найдены"
fi

# ЭТАП 6: Альтернативный подход - inline execute
echo ""
echo "🧪 ЭТАП 6: АЛЬТЕРНАТИВНЫЙ ПОДХОД"
echo "==============================="

echo ""
echo "Тест 3: Inline execute lua"
echo "---------------------------"
docker exec "$CONTAINER_NAME" fs_cli -x "console clear"

INLINE_TEST=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/79206054020 '&lua(/usr/local/freeswitch/scripts/ivr_menu.lua)'" 2>&1)
echo "Результат inline lua: $INLINE_TEST"

sleep 10

echo ""
echo "📋 Логи inline теста:"
INLINE_LOGS=$(docker exec "$CONTAINER_NAME" fs_cli -x "console last 50" | grep -E "(IVR|lua|Menu)" | tail -10)
if [ -n "$INLINE_LOGS" ]; then
    echo "$INLINE_LOGS"
else
    echo "Логи inline теста не найдены"
fi

# ЭТАП 7: Финальная статистика
echo ""
echo "📊 ЭТАП 7: ФИНАЛЬНАЯ СТАТИСТИКА"
echo "============================="

echo ""
echo "📊 Статистика gateway после тестов:"
FINAL_STATS=$(docker exec "$CONTAINER_NAME" fs_cli -x "sofia status gateway internal::sip_trunk" | grep -E "(CallsOUT|FailedCallsOUT)")
echo "$FINAL_STATS"

echo ""
echo "📋 Последние 20 строк логов:"
echo "----------------------------"
docker exec "$CONTAINER_NAME" fs_cli -x "console last 20"

echo ""
echo "💡 АНАЛИЗ И РЕКОМЕНДАЦИИ"
echo "======================="

# Анализ результатов
TOTAL_CALLS=$(echo "$FINAL_STATS" | grep "CallsOUT" | head -1 | awk '{print $2}')
FAILED_CALLS=$(echo "$FINAL_STATS" | grep "FailedCallsOUT" | awk '{print $2}')

echo ""
echo "🔍 РЕЗУЛЬТАТ ТЕСТОВ:"
echo "- Всего звонков: $TOTAL_CALLS"
echo "- Провалившихся: $FAILED_CALLS"
echo "- Успешных: $((TOTAL_CALLS - FAILED_CALLS))"

echo ""
echo "🎯 ВОЗМОЖНЫЕ ПРИЧИНЫ:"
echo ""
echo "1. 📞 TRANSFER НЕ РАБОТАЕТ:"
echo "   - Возможно transfer: не поддерживается этой версией"
echo "   - Нужно использовать прямой вызов extension"
echo ""
echo "2. 🎭 IVR EXTENSION НЕ НАЙДЕН:"
echo "   - Диалплан не загружен корректно"
echo "   - Extension name не совпадает"
echo ""
echo "3. 📋 TIMING ПРОБЛЕМА:"
echo "   - Transfer выполняется до ответа звонка"
echo "   - Нужно добавить answer перед transfer"
echo ""
echo "4. 🔧 LUA МОДУЛЬ ПРОБЛЕМА:"
echo "   - mod_lua работает, но context не передается"
echo "   - Нужно использовать inline execute"

echo ""
echo "🔧 РЕКОМЕНДАЦИИ:"
echo "==============="
echo ""
echo "1. Если echo transfer работает, а ivr_menu нет:"
echo "   - Проблема в диалплане или IVR скрипте"
echo ""
echo "2. Если все transfer не работают:"
echo "   - Использовать прямой вызов extension"
echo ""
echo "3. Если inline lua работает:"
echo "   - Изменить синтаксис команды"

echo ""
echo "✅ Детальная диагностика завершена!" 