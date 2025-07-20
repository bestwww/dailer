#!/bin/bash

# 🧪 ТЕСТ ОДИНОЧНОГО IVR ЗВОНКА
# Проверяем работает ли IVR меню после подключения звонка

CONTAINER_NAME="freeswitch-test"
PHONE_NUMBER="79206054020"

echo "🧪 ТЕСТ ОДИНОЧНОГО IVR ЗВОНКА"
echo "============================"
echo ""

echo "✅ ПРОБЛЕМА ЧАСТИЧНО РЕШЕНА:"
echo "- Звонки доходят до телефона!"
echo "- Успешных звонков: 6 из 22"
echo "- Получено на телефон: 2 (ограничение оператора 2 линии)"
echo ""

echo "🎯 ЦЕЛЬ ТЕСТА:"
echo "- Один звонок за раз"
echo "- Проверка работы IVR меню"
echo "- Детальные логи из файлов"
echo ""

# ЭТАП 1: Подготовка к тесту
echo "📋 ЭТАП 1: ПОДГОТОВКА К ТЕСТУ"
echo "============================"

echo ""
echo "1. 🧹 Очистка логов:"
echo "-------------------"
docker exec "$CONTAINER_NAME" fs_cli -x "console clear" > /dev/null 2>&1

echo ""
echo "2. 📊 Статистика ДО теста:"
echo "-------------------------"
STATS_BEFORE=$(docker exec "$CONTAINER_NAME" fs_cli -x "sofia status gateway internal::sip_trunk" | grep -E "(CallsOUT|FailedCallsOUT)")
echo "$STATS_BEFORE"

CALLS_BEFORE=$(echo "$STATS_BEFORE" | grep "CallsOUT" | head -1 | awk '{print $2}')
FAILED_BEFORE=$(echo "$STATS_BEFORE" | grep "FailedCallsOUT" | awk '{print $2}')

echo ""
echo "3. 🔧 Включение детального логирования:"
echo "--------------------------------------"
# Включаем детальные логи для lua и transfer
docker exec "$CONTAINER_NAME" fs_cli -x "log lua debug" > /dev/null 2>&1
docker exec "$CONTAINER_NAME" fs_cli -x "log switch_core debug" > /dev/null 2>&1

# ЭТАП 2: Единичный тест IVR
echo ""
echo "🧪 ЭТАП 2: ЕДИНИЧНЫЙ ТЕСТ IVR"
echo "============================"

echo ""
echo "📞 Выполняем ОДИН тестовый звонок с transfer:ivr_menu"
echo "----------------------------------------------------"

# Засекаем время начала теста
START_TIME=$(date +%s)

# Выполняем звонок
echo "Команда: originate sofia/gateway/sip_trunk/$PHONE_NUMBER &transfer:ivr_menu"
CALL_RESULT=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/$PHONE_NUMBER &transfer:ivr_menu" 2>&1)
echo "Результат: $CALL_RESULT"

# Извлекаем UUID из результата
CALL_UUID=$(echo "$CALL_RESULT" | grep -o '+OK [a-f0-9-]*' | awk '{print $2}')
echo "UUID звонка: $CALL_UUID"

echo ""
echo "⏱️ Ожидание завершения звонка (20 секунд)..."
echo "💡 В это время:"
echo "   - Ответьте на звонок"
echo "   - Попробуйте нажать кнопки: 1, 2, 9"
echo "   - Слушайте тоны в ответ на нажатия"

# Ждем завершения звонка
sleep 20

# ЭТАП 3: Анализ результатов
echo ""
echo "📋 ЭТАП 3: АНАЛИЗ РЕЗУЛЬТАТОВ"
echo "============================"

echo ""
echo "1. 📊 Статистика ПОСЛЕ теста:"
echo "----------------------------"
STATS_AFTER=$(docker exec "$CONTAINER_NAME" fs_cli -x "sofia status gateway internal::sip_trunk" | grep -E "(CallsOUT|FailedCallsOUT)")
echo "$STATS_AFTER"

CALLS_AFTER=$(echo "$STATS_AFTER" | grep "CallsOUT" | head -1 | awk '{print $2}')
FAILED_AFTER=$(echo "$STATS_AFTER" | grep "FailedCallsOUT" | awk '{print $2}')

NEW_CALLS=$((CALLS_AFTER - CALLS_BEFORE))
NEW_FAILED=$((FAILED_AFTER - FAILED_BEFORE))

echo ""
echo "📈 Изменения:"
echo "- Новых звонков: $NEW_CALLS"
echo "- Новых провалов: $NEW_FAILED"
if [ $NEW_CALLS -gt $NEW_FAILED ]; then
    echo "✅ Звонок успешен!"
else
    echo "❌ Звонок провалился"
fi

echo ""
echo "2. 🔍 Поиск UUID в логах через файлы:"
echo "------------------------------------"
if [ -n "$CALL_UUID" ]; then
    echo "Ищем UUID $CALL_UUID в логах..."
    
    # Проверяем основной лог
    UUID_FOUND=$(docker exec "$CONTAINER_NAME" find /usr/local/freeswitch/log -name "*.log" -exec grep -l "$CALL_UUID" {} \; 2>/dev/null | head -1)
    
    if [ -n "$UUID_FOUND" ]; then
        echo "✅ UUID найден в файле: $UUID_FOUND"
        echo ""
        echo "📋 Логи для этого звонка:"
        docker exec "$CONTAINER_NAME" grep "$CALL_UUID" "$UUID_FOUND" | tail -10
    else
        echo "❌ UUID не найден в файлах логов"
    fi
else
    echo "❌ UUID не определен"
fi

echo ""
echo "3. 🎭 Поиск IVR активности:"
echo "--------------------------"
# Ищем логи IVR в файлах
IVR_LOGS=$(docker exec "$CONTAINER_NAME" find /usr/local/freeswitch/log -name "*.log" -exec grep -l "IVR\|ivr_menu" {} \; 2>/dev/null | head -1)

if [ -n "$IVR_LOGS" ]; then
    echo "✅ IVR активность найдена в: $IVR_LOGS"
    echo ""
    echo "📋 Последние IVR логи:"
    docker exec "$CONTAINER_NAME" grep -i "IVR\|ivr_menu" "$IVR_LOGS" | tail -5
else
    echo "❌ IVR активность не найдена в логах"
    
    echo ""
    echo "🔍 Проверяем консольные логи (альтернативно):"
    # Пробуем через внутренние команды FreeSWITCH
    CONSOLE_LOGS=$(docker exec "$CONTAINER_NAME" fs_cli -x "eval \${domain}" 2>/dev/null)
    echo "Домен: $CONSOLE_LOGS"
fi

echo ""
echo "4. 🔧 Проверка выполнения Lua скрипта:"
echo "-------------------------------------"
# Ищем lua активность
LUA_LOGS=$(docker exec "$CONTAINER_NAME" find /usr/local/freeswitch/log -name "*.log" -exec grep -l "lua\|Menu запущен" {} \; 2>/dev/null | head -1)

if [ -n "$LUA_LOGS" ]; then
    echo "✅ Lua активность найдена в: $LUA_LOGS"
    echo ""
    echo "📋 Последние Lua логи:"
    docker exec "$CONTAINER_NAME" grep -i "lua\|Menu запущен\|Session" "$LUA_LOGS" | tail -5
else
    echo "❌ Lua активность не найдена"
fi

# ЭТАП 4: Проверка структуры логов
echo ""
echo "📋 ЭТАП 4: СТРУКТУРА ЛОГИРОВАНИЯ"
echo "==============================="

echo ""
echo "📁 Доступные лог файлы:"
docker exec "$CONTAINER_NAME" ls -la /usr/local/freeswitch/log/ 2>/dev/null || echo "❌ Папка логов недоступна"

echo ""
echo "🔧 Конфигурация логирования:"
LOG_CONFIG=$(docker exec "$CONTAINER_NAME" find /usr/local/freeswitch/conf -name "*log*" 2>/dev/null)
if [ -n "$LOG_CONFIG" ]; then
    echo "Найдены конфиги логов: $LOG_CONFIG"
else
    echo "❌ Конфиги логов не найдены"
fi

# ЭТАП 5: Рекомендации
echo ""
echo "💡 ЭТАП 5: ВЫВОДЫ И РЕКОМЕНДАЦИИ"
echo "==============================="

echo ""
echo "🎯 РЕЗУЛЬТАТ ТЕСТА:"
if [ $NEW_CALLS -gt $NEW_FAILED ]; then
    echo "✅ ЗВОНОК ПРОШЕЛ УСПЕШНО!"
    echo ""
    echo "❓ ПОЛУЧИЛИ ЛИ ВЫ ЗВОНОК НА ТЕЛЕФОН?"
    echo "❓ СЛЫШАЛИ ЛИ ТОНЫ ПРИ НАЖАТИИ КНОПОК?"
    echo ""
    echo "Если да - IVR РАБОТАЕТ! 🎉"
    echo "Если нет - проблема в логировании"
else
    echo "❌ Звонок провалился"
fi

echo ""
echo "🔧 СЛЕДУЮЩИЕ ШАГИ:"
echo ""
echo "1. 📞 ЕСЛИ ЗВОНОК ПРИШЕЛ:"
echo "   - IVR menu работает корректно"
echo "   - Проблема только в отображении логов"
echo "   - Можно интегрировать с backend"
echo ""
echo "2. 📞 ЕСЛИ ЗВОНКА НЕ БЫЛО:"
echo "   - Проверить настройки логирования"
echo "   - Попробовать альтернативные команды"
echo ""
echo "3. 🎭 ЕСЛИ IVR НЕ РАБОТАЕТ:"
echo "   - Исправить диалплан"
echo "   - Проверить Lua окружение"

echo ""
echo "📋 КОМАНДЫ ДЛЯ РУЧНОЙ ПРОВЕРКИ:"
echo "=============================="
echo ""
echo "# Повторить тест:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"originate sofia/gateway/sip_trunk/$PHONE_NUMBER &transfer:ivr_menu\""
echo ""
echo "# Прямой IVR без transfer:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"originate sofia/gateway/sip_trunk/$PHONE_NUMBER ivr_menu\""
echo ""
echo "# Проверка активных звонков:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"show channels\""

echo ""
echo "✅ Тест завершен!" 