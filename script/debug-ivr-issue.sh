#!/bin/bash

# 🔍 ДИАГНОСТИКА ПРОБЛЕМ С IVR МЕНЮ
# Анализируем почему transfer:ivr_menu не работает

CONTAINER_NAME="freeswitch-test"

echo "🔍 ДИАГНОСТИКА IVR ПРОБЛЕМ"
echo "========================="
echo ""

echo "✅ ПОДТВЕРЖДЕНО:"
echo "- Звонки через &echo РАБОТАЮТ и доходят до мобильного"
echo "- Звонки через &transfer:ivr_menu НЕ доходят до мобильного"
echo "- Проблема в IVR обработке, НЕ в провайдере!"
echo ""

# ЭТАП 1: Проверяем IVR скрипт
echo "📋 ЭТАП 1: ПРОВЕРКА IVR СКРИПТА"
echo "============================="

echo ""
echo "1. 📄 Проверяем наличие IVR скрипта:"
if docker exec "$CONTAINER_NAME" test -f /usr/local/freeswitch/scripts/ivr_menu.lua; then
    echo "✅ IVR скрипт найден"
    
    echo ""
    echo "📋 Содержимое IVR скрипта:"
    docker exec "$CONTAINER_NAME" head -20 /usr/local/freeswitch/scripts/ivr_menu.lua
else
    echo "❌ IVR скрипт НЕ найден!"
fi

echo ""
echo "2. 🔍 Проверяем диалплан для ivr_menu:"
DIALPLAN_CHECK=$(docker exec "$CONTAINER_NAME" cat /usr/local/freeswitch/conf/dialplan/default.xml | grep -A5 "ivr_menu")
if [ -n "$DIALPLAN_CHECK" ]; then
    echo "✅ Диалплан для ivr_menu найден:"
    echo "$DIALPLAN_CHECK"
else
    echo "❌ Диалплан для ivr_menu НЕ найден!"
fi

# ЭТАП 2: Тестируем IVR напрямую
echo ""
echo "🧪 ЭТАП 2: ТЕСТИРОВАНИЕ IVR НАПРЯМУЮ"
echo "=================================="

echo ""
echo "Тест 1: Прямой вызов IVR через loopback"
echo "---------------------------------------"

# Сначала проверим есть ли loopback модуль
echo "Проверяем loopback модуль..."
LOOPBACK_STATUS=$(docker exec "$CONTAINER_NAME" fs_cli -x "module_exists mod_loopback" 2>&1)
if echo "$LOOPBACK_STATUS" | grep -q "true"; then
    echo "✅ mod_loopback загружен"
    
    echo ""
    echo "Тестируем IVR через loopback:"
    LOOPBACK_TEST=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate loopback/ivr_menu &echo" 2>&1)
    echo "Результат: $LOOPBACK_TEST"
else
    echo "⚠️ mod_loopback не загружен, пропускаем тест"
fi

echo ""
echo "Тест 2: Прямой вызов Lua скрипта"
echo "--------------------------------"

# Тестируем Lua скрипт напрямую
echo "Тестируем Lua скрипт..."
LUA_TEST=$(docker exec "$CONTAINER_NAME" fs_cli -x "lua /usr/local/freeswitch/scripts/ivr_menu.lua" 2>&1)
echo "Результат Lua теста: $LUA_TEST"

# ЭТАП 3: Анализ логов IVR звонка
echo ""
echo "📋 ЭТАП 3: АНАЛИЗ ЛОГОВ IVR ЗВОНКА"
echo "================================="

echo ""
echo "Очищаем логи для чистого анализа..."
docker exec "$CONTAINER_NAME" fs_cli -x "console clear"

echo ""
echo "Выполняем проблемный звонок с детальными логами..."
docker exec "$CONTAINER_NAME" fs_cli -x "console loglevel debug"

PROBLEM_CALL=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/79206054020 &transfer:ivr_menu" 2>&1)
echo "Результат проблемного звонка: $PROBLEM_CALL"

echo ""
echo "Ожидаем завершения звонка..."
sleep 8

echo ""
echo "📋 Анализ логов проблемного звонка:"
echo "-----------------------------------"

# Ищем ошибки в логах
echo ""
echo "1. Ошибки в логах:"
ERROR_LOGS=$(docker exec "$CONTAINER_NAME" fs_cli -x "console last 100" | grep -i -E "(error|fail|exception|timeout)" | tail -10)
if [ -n "$ERROR_LOGS" ]; then
    echo "$ERROR_LOGS"
else
    echo "Нет явных ошибок в логах"
fi

echo ""
echo "2. Информация о transfer и IVR:"
IVR_LOGS=$(docker exec "$CONTAINER_NAME" fs_cli -x "console last 100" | grep -i -E "(transfer|ivr|lua)" | tail -15)
if [ -n "$IVR_LOGS" ]; then
    echo "$IVR_LOGS"
else
    echo "Нет информации о transfer/IVR в логах"
fi

echo ""
echo "3. Информация о соединении с провайдером:"
PROVIDER_LOGS=$(docker exec "$CONTAINER_NAME" fs_cli -x "console last 100" | grep -i -E "(answer|bridge|hangup)" | tail -10)
if [ -n "$PROVIDER_LOGS" ]; then
    echo "$PROVIDER_LOGS"
else
    echo "Нет информации о соединении в логах"
fi

# ЭТАП 4: Упрощенный тест без IVR
echo ""
echo "🧪 ЭТАП 4: УПРОЩЕННЫЕ ТЕСТЫ"
echo "=========================="

echo ""
echo "Тест 3: Звонок с простым ответом (без IVR)"
echo "-------------------------------------------"

# Тест с простым playback вместо IVR
SIMPLE_TEST=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/79206054020 &playback:/usr/local/freeswitch/sounds/en/us/callie/misc/8000/thank_you_for_calling.wav" 2>&1)
echo "Результат простого теста: $SIMPLE_TEST"

sleep 5

echo ""
echo "Тест 4: Звонок с простым sleep"
echo "------------------------------"

SLEEP_TEST=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/79206054020 &sleep:5000" 2>&1)
echo "Результат sleep теста: $SLEEP_TEST"

sleep 8

# ЭТАП 5: Анализ и рекомендации
echo ""
echo "💡 ЭТАП 5: АНАЛИЗ И РЕКОМЕНДАЦИИ"
echo "==============================="

echo ""
echo "🔍 ВОЗМОЖНЫЕ ПРИЧИНЫ ПРОБЛЕМЫ:"
echo ""
echo "1. 🎭 ПРОБЛЕМА С IVR СКРИПТОМ:"
echo "   - Lua скрипт падает или зависает"
echo "   - Ошибка в логике IVR"
echo "   - Неправильные пути к файлам"
echo ""
echo "2. 📞 ПРОБЛЕМА С TRANSFER:"
echo "   - Transfer не работает корректно"
echo "   - Диалплан не найден"
echo "   - Контекст transfer неправильный"
echo ""
echo "3. ⏱️ ПРОБЛЕМА С TIMING:"
echo "   - IVR запускается слишком рано"
echo "   - Нет ожидания answer от провайдера"
echo "   - Провайдер разрывает соединение"
echo ""

echo ""
echo "🔧 РЕКОМЕНДУЕМЫЕ ИСПРАВЛЕНИЯ:"
echo "============================"
echo ""
echo "1. Упростить IVR скрипт"
echo "2. Добавить answer перед transfer"
echo "3. Использовать прямой вызов вместо transfer"
echo "4. Добавить детальное логирование в IVR"

echo ""
echo "✅ Диагностика завершена!"

echo ""
echo "🎯 СЛЕДУЮЩИЕ ШАГИ:"
echo "=================="
echo "1. Проанализируйте логи выше"
echo "2. Если нужно - упростим IVR скрипт"
echo "3. Изменим диалплан для корректной работы"
echo "4. Протестируем исправления" 