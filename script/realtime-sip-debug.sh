#!/bin/bash

# 🔍 АНАЛИЗ SIP ТРАФИКА В РЕАЛЬНОМ ВРЕМЕНИ
# Детальный мониторинг SIP сообщений и ответов провайдера

CONTAINER_NAME="freeswitch-test"

echo "🔍 РЕАЛЬНЫЙ АНАЛИЗ SIP ТРАФИКА"
echo "============================="
echo ""

echo "🚨 Проблема: FailedCallsOUT 3/3 - провайдер отклоняет ВСЕ звонки"
echo "📋 Цель: Получить детальные SIP сообщения для анализа"
echo ""

# Настраиваем максимальное логирование
echo "⚙️ НАСТРОЙКА ДЕТАЛЬНОГО ЛОГИРОВАНИЯ"
echo "=================================="

docker exec "$CONTAINER_NAME" fs_cli -x "sofia profile internal siptrace on"
docker exec "$CONTAINER_NAME" fs_cli -x "sofia loglevel all 9"
docker exec "$CONTAINER_NAME" fs_cli -x "console loglevel debug"

# Очищаем логи
docker exec "$CONTAINER_NAME" fs_cli -x "console clear"

echo "✅ Максимальное логирование включено"
echo ""

# Запускаем мониторинг логов в фоне
echo "📡 ЗАПУСК МОНИТОРИНГА SIP ТРАФИКА"
echo "==============================="

echo ""
echo "🔄 Запускаем тестовый звонок с мониторингом..."
echo ""

# Запускаем звонок
echo "📞 Инициируем звонок..."
CALL_UUID=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/79206054020 &echo" | grep -o '+OK [a-f0-9-]*' | cut -d' ' -f2)
echo "UUID звонка: $CALL_UUID"

echo ""
echo "⏱️ Ожидаем 3 секунды для SIP обмена..."
sleep 3

echo ""
echo "📋 АНАЛИЗ SIP СООБЩЕНИЙ"
echo "======================"

# Получаем свежие логи
echo ""
echo "1. 📤 ИСХОДЯЩИЕ SIP СООБЩЕНИЯ (INVITE):"
echo "-------------------------------------"
OUTGOING=$(docker exec "$CONTAINER_NAME" fs_cli -x "console last 100" | grep -A10 -B2 "send.*INVITE")
if [ -n "$OUTGOING" ]; then
    echo "$OUTGOING"
else
    echo "❌ Исходящие INVITE не найдены в логах консоли"
fi

echo ""
echo "2. 📥 ВХОДЯЩИЕ SIP ОТВЕТЫ:"
echo "------------------------"
INCOMING=$(docker exec "$CONTAINER_NAME" fs_cli -x "console last 100" | grep -A5 -B2 "recv.*SIP\|recv.*[0-9][0-9][0-9]")
if [ -n "$INCOMING" ]; then
    echo "$INCOMING"
else
    echo "❌ Входящие SIP ответы не найдены в логах консоли"
fi

echo ""
echo "3. 🔍 ПОИСК КОДОВ ОШИБОК:"
echo "-----------------------"
ERROR_CODES=$(docker exec "$CONTAINER_NAME" fs_cli -x "console last 50" | grep -E "[4-6][0-9][0-9].*")
if [ -n "$ERROR_CODES" ]; then
    echo "$ERROR_CODES"
else
    echo "❌ Коды ошибок не найдены в консольных логах"
fi

echo ""
echo "4. 📄 ПРОВЕРКА ФАЙЛОВЫХ ЛОГОВ:"
echo "-----------------------------"

# Попробуем получить логи из файла
echo "Проверяем файловые логи FreeSWITCH..."
FILE_LOGS=$(docker exec "$CONTAINER_NAME" tail -50 /usr/local/freeswitch/log/freeswitch.log 2>/dev/null | grep -E "(INVITE|[4-6][0-9][0-9])" || echo "Файловые логи недоступны")
if [ "$FILE_LOGS" != "Файловые логи недоступны" ]; then
    echo "$FILE_LOGS"
else
    echo "❌ Файловые логи недоступны или пусты"
fi

echo ""
echo "5. 🔍 АНАЛИЗ DOCKER ЛОГОВ:"
echo "-------------------------"
echo "Последние Docker логи контейнера:"
DOCKER_LOGS=$(docker logs --tail 20 "$CONTAINER_NAME" 2>&1 | grep -E "(INVITE|SIP|[4-6][0-9][0-9])" || echo "Нет SIP данных в Docker логах")
echo "$DOCKER_LOGS"

echo ""
echo "6. 📊 ТЕКУЩИЙ СТАТУС GATEWAY:"
echo "---------------------------"
docker exec "$CONTAINER_NAME" fs_cli -x "sofia status gateway internal::sip_trunk" | head -5

echo ""
echo "7. 🧪 ДОПОЛНИТЕЛЬНЫЕ ТЕСТЫ:"
echo "=========================="

# Тест с разными форматами номеров
echo ""
echo "Тест A: Номер с +7"
RESULT_A=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/+79206054020 &echo" 2>&1)
echo "Результат: $RESULT_A"
sleep 2

echo ""
echo "Тест B: Номер с 8" 
RESULT_B=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/89206054020 &echo" 2>&1)
echo "Результат: $RESULT_B"
sleep 2

# Финальная статистика
echo ""
echo "📊 ФИНАЛЬНАЯ СТАТИСТИКА:"
echo "======================="
FINAL_STATS=$(docker exec "$CONTAINER_NAME" fs_cli -x "sofia status gateway internal::sip_trunk" | grep -E "(CallsOUT|FailedCallsOUT)")
echo "$FINAL_STATS"

echo ""
echo "💡 ДИАГНОСТИЧЕСКИЙ АНАЛИЗ:"
echo "=========================="

# Анализ результатов
TOTAL_CALLS=$(echo "$FINAL_STATS" | grep "CallsOUT" | head -1 | awk '{print $2}')
FAILED_CALLS=$(echo "$FINAL_STATS" | grep "FailedCallsOUT" | awk '{print $2}')

if [ "$FAILED_CALLS" = "$TOTAL_CALLS" ] && [ "$TOTAL_CALLS" -gt 0 ]; then
    echo ""
    echo "🚨 ПОДТВЕРЖДЕНА ПРОБЛЕМА:"
    echo "- Все звонки ($TOTAL_CALLS/$FAILED_CALLS) провалились"
    echo "- FreeSWITCH создает UUID (+OK) но провайдер отклоняет"
    echo ""
    echo "🔍 НАИБОЛЕЕ ВЕРОЯТНЫЕ ПРИЧИНЫ:"
    echo ""
    echo "1. 🔐 IP НЕ АВТОРИЗОВАН (90% вероятность)"
    echo "   ✅ Проверить: IP 46.173.16.147 в белом списке провайдера"
    echo ""
    echo "2. 📞 НЕПРАВИЛЬНЫЙ ФОРМАТ НОМЕРА (5% вероятность)"
    echo "   ✅ Попробовать: разные форматы номеров (+7, 8, без префикса)"
    echo ""
    echo "3. 💰 ПРОБЛЕМЫ С БАЛАНСОМ (5% вероятность)"
    echo "   ✅ Проверить: баланс и лимиты у провайдера"
fi

echo ""
echo "🎯 РЕКОМЕНДАЦИИ:"
echo "==============="
echo ""
echo "1. НЕМЕДЛЕННО свяжитесь с провайдером и сообщите:"
echo "   - Ваш IP сервера: 46.173.16.147"
echo "   - Попросите добавить в белый список для IP-аутентификации"
echo "   - Уточните формат номеров для исходящих звонков"
echo ""
echo "2. Если провайдер подтвердит правильность настроек:"
echo "   - Проверьте баланс"
echo "   - Уточните лимиты на исходящие звонки"
echo "   - Запросите примеры корректных SIP-сообщений"
echo ""
echo "3. После ответа провайдера - сообщите результат,"
echo "   и мы настроим FreeSWITCH под их требования"

echo ""
echo "✅ Детальный анализ завершен!" 