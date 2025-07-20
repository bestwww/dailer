#!/bin/bash

# 🔍 БЫСТРЫЙ АНАЛИЗ SIP ЛОГОВ
# Определяем почему провайдер отклоняет звонки

CONTAINER_NAME="freeswitch-test"

echo "🔍 БЫСТРЫЙ АНАЛИЗ SIP ПРОБЛЕМ"
echo "============================"
echo ""

echo "🚨 ОБНАРУЖЕНО: FailedCallsOUT 3/3 - провайдер отклоняет ВСЕ звонки!"
echo ""

echo "📋 АНАЛИЗ ПОСЛЕДНИХ SIP ЛОГОВ"
echo "============================="

echo ""
echo "1. 🔍 ПОИСК SIP ОШИБОК В ЛОГАХ:"
echo "------------------------------"
docker exec "$CONTAINER_NAME" fs_cli -x "console last 200" | grep -i -E "(4[0-9][0-9]|5[0-9][0-9]|6[0-9][0-9])" | tail -10

echo ""
echo "2. 🔍 ПОСЛЕДНИЕ INVITE СООБЩЕНИЯ:"
echo "--------------------------------"
docker exec "$CONTAINER_NAME" fs_cli -x "console last 200" | grep -A3 -B1 "INVITE" | tail -20

echo ""
echo "3. 🔍 ОТВЕТЫ ПРОВАЙДЕРА:"
echo "----------------------"
docker exec "$CONTAINER_NAME" fs_cli -x "console last 200" | grep -E "(1[0-9][0-9]|2[0-9][0-9]|3[0-9][0-9]|4[0-9][0-9]|5[0-9][0-9]|6[0-9][0-9]) " | tail -15

echo ""
echo "4. 🔍 ПОЛНЫЙ КОНТЕКСТ ПОСЛЕДНЕГО ЗВОНКА:"
echo "---------------------------------------"
docker exec "$CONTAINER_NAME" fs_cli -x "console last 100" | grep -A10 -B5 "79206054020"

echo ""
echo "5. 📊 ДЕТАЛЬНАЯ СТАТИСТИКА GATEWAY:"
echo "----------------------------------"
docker exec "$CONTAINER_NAME" fs_cli -x "sofia status gateway internal::sip_trunk verbose"

echo ""
echo "6. 🧪 НОВЫЙ ТЕСТОВЫЙ ЗВОНОК С SIP TRACE:"
echo "---------------------------------------"
echo "Включаем максимальный SIP trace..."
docker exec "$CONTAINER_NAME" fs_cli -x "sofia profile internal siptrace on"
docker exec "$CONTAINER_NAME" fs_cli -x "sofia loglevel all 9"

echo ""
echo "Делаем тестовый звонок..."
CALL_RESULT=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/79206054020 &echo" 2>&1)
echo "Результат: $CALL_RESULT"

echo ""
echo "Ждем завершения звонка..."
sleep 5

echo ""
echo "📋 SIP TRACE НОВОГО ЗВОНКА:"
echo "--------------------------"
docker exec "$CONTAINER_NAME" fs_cli -x "console last 50" | grep -A20 -B5 "send.*INVITE\|recv.*SIP"

echo ""
echo "💡 ВОЗМОЖНЫЕ ПРИЧИНЫ И РЕШЕНИЯ:"
echo "==============================="
echo ""
echo "По статистике FailedCallsOUT: 3/3 - проблемы:"
echo ""
echo "1. 🔐 IP НЕ АВТОРИЗОВАН:"
echo "   - Код 403 Forbidden"
echo "   - Ваш IP 46.173.16.147 не в белом списке провайдера"
echo ""
echo "2. 📞 НЕПРАВИЛЬНЫЙ ФОРМАТ НОМЕРА:"
echo "   - Код 404 Not Found"  
echo "   - Провайдер не распознает формат 79206054020"
echo ""
echo "3. 💰 НЕТ БАЛАНСА/БЛОКИРОВКА:"
echo "   - Код 402 Payment Required"
echo "   - Код 503 Service Unavailable"
echo ""
echo "4. ⚙️ НЕПРАВИЛЬНЫЕ SIP ПАРАМЕТРЫ:"
echo "   - Код 488 Not Acceptable Here (кодеки)"
echo "   - Отсутствуют обязательные заголовки"
echo ""

echo ""
echo "🎯 СЛЕДУЮЩИЕ ШАГИ:"
echo "=================="
echo "1. Найдите код ошибки в SIP trace выше"
echo "2. Свяжитесь с провайдером для:"
echo "   - Добавления IP 46.173.16.147 в белый список"
echo "   - Уточнения формата номеров"
echo "   - Проверки баланса"
echo "3. При необходимости изменим конфигурацию"

echo ""
echo "✅ Анализ завершен!" 