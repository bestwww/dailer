#!/bin/bash

# 🔢 ПОЛНОЕ ТЕСТИРОВАНИЕ DTMF С ДЕТАЛЬНОЙ ДИАГНОСТИКОЙ
# Проверяем работу DTMF детекции и логирования

CONTAINER_NAME="freeswitch-test"
PHONE_NUMBER="79206054020"
LOG_FILE="/tmp/freeswitch_test.log"

echo "🔢 ПОЛНОЕ ТЕСТИРОВАНИЕ DTMF С ДЕТАЛЬНОЙ ДИАГНОСТИКОЙ"
echo "==================================================="
echo ""

echo "🎯 ЦЕЛЬ: Протестировать DTMF детекцию и найти проблемы"
echo "📞 НОМЕР: $PHONE_NUMBER"
echo "📄 ЛОГ: $LOG_FILE"
echo ""

# ЭТАП 1: Предварительная проверка
echo "📋 ЭТАП 1: ПРЕДВАРИТЕЛЬНАЯ ПРОВЕРКА"
echo "=================================="

echo ""
echo "1. 🔍 Проверяем статус FreeSWITCH..."
STATUS=$(docker exec "$CONTAINER_NAME" fs_cli -x "status" 2>&1)
echo "FreeSWITCH статус: $(echo "$STATUS" | head -1)"

echo ""
echo "2. 📊 Размер текущего лога..."
if docker exec "$CONTAINER_NAME" test -f "$LOG_FILE"; then
    CURRENT_SIZE=$(docker exec "$CONTAINER_NAME" wc -l "$LOG_FILE" | cut -d' ' -f1)
    echo "Текущий размер лога: $CURRENT_SIZE строк"
else
    echo "❌ Файл лога не существует"
    exit 1
fi

echo ""
echo "3. 🔧 Проверяем активные звонки..."
ACTIVE_CALLS=$(docker exec "$CONTAINER_NAME" fs_cli -x "show calls" 2>&1)
echo "Активные звонки:"
echo "$ACTIVE_CALLS"

# ЭТАП 2: Очистка и подготовка для чистого теста
echo ""
echo "📋 ЭТАП 2: ПОДГОТОВКА ЧИСТОГО ТЕСТА"
echo "=================================="

echo ""
echo "1. 🗑️  Завершаем все активные звонки..."
docker exec "$CONTAINER_NAME" fs_cli -x "hupall MANAGER_REQUEST" > /dev/null 2>&1

echo ""
echo "2. 📄 Создаем маркер начала теста в логе..."
docker exec "$CONTAINER_NAME" fs_cli -x "log CRIT ==============================================="
docker exec "$CONTAINER_NAME" fs_cli -x "log CRIT === НАЧАЛО DTMF ТЕСТА $(date) ==="
docker exec "$CONTAINER_NAME" fs_cli -x "log CRIT ==============================================="

echo ""
echo "3. 📊 Фиксируем начальный размер лога..."
START_SIZE=$(docker exec "$CONTAINER_NAME" wc -l "$LOG_FILE" | cut -d' ' -f1)
echo "Размер лога перед тестом: $START_SIZE строк"

# ЭТАП 3: Запуск мониторинга и звонка
echo ""
echo "📋 ЭТАП 3: ЗАПУСК ТЕСТА"
echo "====================="

echo ""
echo "🔧 ИНСТРУКЦИИ ДЛЯ ТЕСТА:"
echo "1. ⏰ Дождитесь когда звонок подключится (услышите тоны)"
echo "2. 🔢 Нажмите цифру '1' НЕСКОЛЬКО РАЗ"
echo "3. ⏳ Подождите 10 секунд"
echo "4. 🔢 Нажмите цифру '2' НЕСКОЛЬКО РАЗ"
echo "5. ⏳ Подождите еще 10 секунд"
echo "6. 📞 Положите трубку или дождитесь автоматического завершения"
echo ""

echo "🚀 ЗАПУСКАЕМ ТЕСТ ЧЕРЕЗ 5 СЕКУНД..."
sleep 5

echo ""
echo "📞 Инициируем звонок..."
CALL_UUID=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/$PHONE_NUMBER 1201 XML default" 2>&1)
echo "Результат вызова: $CALL_UUID"

# Извлекаем UUID из ответа если он есть
if [[ "$CALL_UUID" == *"+OK"* ]]; then
    UUID=$(echo "$CALL_UUID" | grep -oE '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}')
    if [[ -n "$UUID" ]]; then
        echo "UUID звонка: $UUID"
    fi
fi

echo ""
echo "⏰ ТЕСТ АКТИВЕН! Отвечайте на звонок и нажимайте цифры!"
echo "📊 Мониторинг будет длиться 90 секунд..."
echo ""

# ЭТАП 4: Мониторинг в реальном времени
echo "📋 ЭТАП 4: МОНИТОРИНГ DTMF СОБЫТИЙ"
echo "================================="

# Запускаем мониторинг на 90 секунд
timeout 90s docker exec "$CONTAINER_NAME" sh -c "
tail -f $LOG_FILE | while read line; do
    # Показываем только КРИТИЧЕСКИ важные строки для DTMF
    if echo \"\$line\" | grep -qE '(CRIT|DTMF|читать|choice|ПОЛУЧЕНО|СБОР|digit|tone|read|execute|ОБРАБОТЧИК|ВЕБХУК|hangup|transfer)'; then
        echo \"\$line\"
    fi
done
" || echo "⏰ Время мониторинга истекло"

# ЭТАП 5: Завершение теста и анализ
echo ""
echo "📋 ЭТАП 5: ЗАВЕРШЕНИЕ И АНАЛИЗ"
echo "============================"

echo ""
echo "1. 🛑 Завершаем все оставшиеся звонки..."
docker exec "$CONTAINER_NAME" fs_cli -x "hupall MANAGER_REQUEST" > /dev/null 2>&1

echo ""
echo "2. 📄 Маркируем конец теста..."
docker exec "$CONTAINER_NAME" fs_cli -x "log CRIT ==============================================="
docker exec "$CONTAINER_NAME" fs_cli -x "log CRIT === КОНЕЦ DTMF ТЕСТА $(date) ==="
docker exec "$CONTAINER_NAME" fs_cli -x "log CRIT ==============================================="

echo ""
echo "3. 📊 Финальный размер лога..."
END_SIZE=$(docker exec "$CONTAINER_NAME" wc -l "$LOG_FILE" | cut -d' ' -f1)
DIFF_SIZE=$((END_SIZE - START_SIZE))
echo "Размер лога после теста: $END_SIZE строк"
echo "Добавлено записей: $DIFF_SIZE строк"

# ЭТАП 6: Детальный анализ логов
echo ""
echo "📋 ЭТАП 6: АНАЛИЗ РЕЗУЛЬТАТОВ"
echo "=========================="

echo ""
echo "1. 🔍 Поиск DTMF событий в тесте..."
DTMF_EVENTS=$(docker exec "$CONTAINER_NAME" sed -n "${START_SIZE},${END_SIZE}p" "$LOG_FILE" | grep -E "(DTMF|choice|digit|ПОЛУЧЕНО|СБОР|read)" | wc -l)
echo "Найдено DTMF событий: $DTMF_EVENTS"

if [[ "$DTMF_EVENTS" -gt 0 ]]; then
    echo ""
    echo "📋 DTMF события:"
    docker exec "$CONTAINER_NAME" sed -n "${START_SIZE},${END_SIZE}p" "$LOG_FILE" | grep -E "(DTMF|choice|digit|ПОЛУЧЕНО|СБОР|read)" | tail -10
fi

echo ""
echo "2. 🔍 Поиск обработчиков цифр..."
HANDLERS=$(docker exec "$CONTAINER_NAME" sed -n "${START_SIZE},${END_SIZE}p" "$LOG_FILE" | grep -E "(ОБРАБОТЧИК|ВЕБХУК)" | wc -l)
echo "Найдено обработчиков: $HANDLERS"

if [[ "$HANDLERS" -gt 0 ]]; then
    echo ""
    echo "📋 Обработчики цифр:"
    docker exec "$CONTAINER_NAME" sed -n "${START_SIZE},${END_SIZE}p" "$LOG_FILE" | grep -E "(ОБРАБОТЧИК|ВЕБХУК)"
fi

echo ""
echo "3. 🔍 Поиск критических сообщений..."
CRIT_MESSAGES=$(docker exec "$CONTAINER_NAME" sed -n "${START_SIZE},${END_SIZE}p" "$LOG_FILE" | grep "CRIT" | grep -E "(===|ПОЛУЧЕНО|choice)" | wc -l)
echo "Найдено критических сообщений: $CRIT_MESSAGES"

if [[ "$CRIT_MESSAGES" -gt 0 ]]; then
    echo ""
    echo "📋 Критические сообщения теста:"
    docker exec "$CONTAINER_NAME" sed -n "${START_SIZE},${END_SIZE}p" "$LOG_FILE" | grep "CRIT" | grep -E "(===|ПОЛУЧЕНО|choice)" | tail -15
fi

echo ""
echo "4. 🔍 Поиск завершения звонка..."
HANGUP_EVENTS=$(docker exec "$CONTAINER_NAME" sed -n "${START_SIZE},${END_SIZE}p" "$LOG_FILE" | grep -iE "(hangup|завершен|transfer)" | wc -l)
echo "Найдено событий завершения: $HANGUP_EVENTS"

if [[ "$HANGUP_EVENTS" -gt 0 ]]; then
    echo ""
    echo "📋 События завершения:"
    docker exec "$CONTAINER_NAME" sed -n "${START_SIZE},${END_SIZE}p" "$LOG_FILE" | grep -iE "(hangup|завершен|transfer)" | tail -5
fi

# ЭТАП 7: Заключение и рекомендации
echo ""
echo "📋 ЭТАП 7: ЗАКЛЮЧЕНИЕ"
echo "==================="

echo ""
if [[ "$DTMF_EVENTS" -gt 0 ]]; then
    echo "🎉 DTMF СОБЫТИЯ НАЙДЕНЫ!"
    echo ""
    echo "✅ РЕЗУЛЬТАТ: FreeSWITCH получает и обрабатывает DTMF сигналы"
    echo ""
    echo "🔧 СЛЕДУЮЩИЕ ШАГИ:"
    echo "1. Настроить вебхуки для цифр 1 и 2"
    echo "2. Интегрировать с backend"
    echo "3. Протестировать в production"
    
elif [[ "$CRIT_MESSAGES" -gt 0 ]]; then
    echo "⚠️  IVR РАБОТАЕТ, НО DTMF НЕ ДЕТЕКТИТСЯ"
    echo ""
    echo "❌ ПРОБЛЕМА: Звонок доходит до IVR, но DTMF сигналы не передаются"
    echo ""
    echo "🔧 ВОЗМОЖНЫЕ ПРИЧИНЫ:"
    echo "1. Провайдер не поддерживает RFC2833 DTMF"
    echo "2. Неправильные настройки кодеков"
    echo "3. Проблемы с SIP trunk конфигурацией"
    echo "4. DTMF передается как SIP INFO (не RFC2833)"
    echo ""
    echo "💡 РЕКОМЕНДАЦИИ:"
    echo "1. Проверить настройки провайдера для DTMF"
    echo "2. Попробовать inband DTMF детекцию"
    echo "3. Настроить поддержку SIP INFO DTMF"
    
else
    echo "❌ КРИТИЧЕСКАЯ ПРОБЛЕМА"
    echo ""
    echo "❌ ПРОБЛЕМА: IVR не запускается корректно или звонок не проходит"
    echo ""
    echo "🔧 ТРЕБУЕТСЯ:"
    echo "1. Проверить SIP trunk подключение"
    echo "2. Диагностировать проблемы с провайдером"
    echo "3. Проверить диалплан конфигурацию"
fi

echo ""
echo "📄 ПОЛНЫЕ ЛОГИ ТЕСТА СОХРАНЕНЫ В: $LOG_FILE"
echo "📊 СТРОКИ $START_SIZE - $END_SIZE"
echo ""
echo "🔍 ДЛЯ ДЕТАЛЬНОГО АНАЛИЗА:"
echo "docker exec $CONTAINER_NAME sed -n '${START_SIZE},${END_SIZE}p' $LOG_FILE"
echo ""
echo "🔢 DTMF ТЕСТ ЗАВЕРШЕН!"
echo "====================" 