#!/bin/bash

# 🔍 ДИАГНОСТИКА РЕАЛЬНЫХ ЗВОНКОВ ЧЕРЕЗ ПРОВАЙДЕРА
# Детальный анализ SIP трафика и логов

set -e

CONTAINER_NAME="freeswitch-test"

# 🎨 Функции для красивого вывода
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1"
}

log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] ✅ $1"
}

log_warning() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] ⚠️ $1"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] ❌ $1"
}

echo "🔍 ДИАГНОСТИКА РЕАЛЬНЫХ ЗВОНКОВ"
echo "==============================="
echo ""

# ЭТАП 1: Проверяем текущий статус
echo "📋 ЭТАП 1: ТЕКУЩИЙ СТАТУС СИСТЕМЫ"
echo "================================="

log_info "Проверяем статус FreeSWITCH..."
FS_STATUS=$(docker exec "$CONTAINER_NAME" fs_cli -x "status" 2>/dev/null)
echo "$FS_STATUS"

log_info "Проверяем SIP gateway..."
GATEWAY_STATUS=$(docker exec "$CONTAINER_NAME" fs_cli -x "sofia status gateway" 2>/dev/null)
echo "$GATEWAY_STATUS"

if echo "$GATEWAY_STATUS" | grep -q "NOREG.*23\."; then
    log_success "SIP trunk подключен, ping работает"
else
    log_warning "Возможны проблемы с SIP trunk"
fi

# ЭТАП 2: Включаем детальное логирование
echo ""
echo "📝 ЭТАП 2: ВКЛЮЧЕНИЕ ДЕТАЛЬНОГО ЛОГИРОВАНИЯ"
echo "=========================================="

log_info "Включаем SIP trace для детального анализа..."
docker exec "$CONTAINER_NAME" fs_cli -x "sofia profile internal siptrace on"

log_info "Устанавливаем debug уровень..."
docker exec "$CONTAINER_NAME" fs_cli -x "console loglevel debug"

log_success "Детальное логирование включено"

# ЭТАП 3: Анализ параметров звонка
echo ""
echo "📞 ЭТАП 3: АНАЛИЗ ПАРАМЕТРОВ ЗВОНКА"
echo "=================================="

log_info "Текущие параметры SIP trunk:"
docker exec "$CONTAINER_NAME" fs_cli -x "sofia status gateway internal::sip_trunk"

# Проверяем кодеки
log_info "Проверяем поддерживаемые кодеки..."
CODECS=$(docker exec "$CONTAINER_NAME" fs_cli -x "show codec" | grep -E "PCMU|PCMA|G729")
echo "Поддерживаемые кодеки:"
echo "$CODECS"

# ЭТАП 4: Тестовый звонок с детальными логами
echo ""
echo "🧪 ЭТАП 4: ТЕСТОВЫЙ ЗВОНОК С ЛОГИРОВАНИЕМ"
echo "========================================"

# Очищаем старые логи
log_info "Очищаем логи для чистого анализа..."
docker exec "$CONTAINER_NAME" fs_cli -x "console clear"

log_info "Выполняем тестовый звонок на номер 79206054020..."
echo ""
echo "🔄 Запускаем звонок..."

# Выполняем звонок и сразу смотрим результат
CALL_RESULT=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/79206054020 &echo" 2>&1)
echo "Результат команды: $CALL_RESULT"

# Ждем немного для завершения звонка
log_info "Ожидаем завершения звонка (10 секунд)..."
sleep 10

# ЭТАП 5: Анализ логов звонка
echo ""
echo "📋 ЭТАП 5: АНАЛИЗ ЛОГОВ ЗВОНКА"
echo "============================="

log_info "Последние SIP сообщения (INVITE, ответы):"
echo "----------------------------------------"
docker exec "$CONTAINER_NAME" fs_cli -x "console last 100" | grep -E "(INVITE|1[0-9][0-9]|2[0-9][0-9]|3[0-9][0-9]|4[0-9][0-9]|5[0-9][0-9]|6[0-9][0-9])" | tail -20
echo "----------------------------------------"

log_info "Ошибки в логах:"
echo "----------------------------------------"
docker exec "$CONTAINER_NAME" fs_cli -x "console last 50" | grep -i -E "(error|fail|reject|busy|timeout)" | tail -10
echo "----------------------------------------"

log_info "Успешные соединения:"
echo "----------------------------------------"
docker exec "$CONTAINER_NAME" fs_cli -x "console last 50" | grep -i -E "(answer|connect|bridge|200 OK)" | tail -10
echo "----------------------------------------"

# ЭТАП 6: Проверка причин отказа
echo ""
echo "🔍 ЭТАП 6: АНАЛИЗ ПРИЧИН ОТКАЗА"
echo "=============================="

log_info "Проверяем SIP ответы от провайдера..."

# Ищем последний звонок в логах
LAST_CALL_LOGS=$(docker exec "$CONTAINER_NAME" fs_cli -x "console last 100" | grep -A5 -B5 "79206054020")
if [ -n "$LAST_CALL_LOGS" ]; then
    echo "Логи последнего звонка:"
    echo "$LAST_CALL_LOGS"
else
    log_warning "Логи звонка не найдены"
fi

# Проверяем статистику gateway
log_info "Статистика звонков gateway:"
docker exec "$CONTAINER_NAME" fs_cli -x "sofia status gateway internal::sip_trunk" | grep -E "(Calls|Failed)"

# ЭТАП 7: Проверка формата номера
echo ""
echo "📞 ЭТАП 7: ПРОВЕРКА ФОРМАТА НОМЕРА"
echo "================================="

log_info "Тестируем разные форматы номера..."

# Тест 1: Полный российский формат
echo ""
echo "Тест 1: Номер с +7"
CALL_TEST1=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/+79206054020 &echo" 2>&1)
echo "Результат: $CALL_TEST1"
sleep 3

# Тест 2: Формат 8
echo ""
echo "Тест 2: Номер с 8"  
CALL_TEST2=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/89206054020 &echo" 2>&1)
echo "Результат: $CALL_TEST2"
sleep 3

# Тест 3: Без префикса
echo ""
echo "Тест 3: Номер без префикса"
CALL_TEST3=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/9206054020 &echo" 2>&1)
echo "Результат: $CALL_TEST3"
sleep 3

# ЭТАП 8: Рекомендации
echo ""
echo "💡 ЭТАП 8: РЕКОМЕНДАЦИИ ПО УСТРАНЕНИЮ"
echo "===================================="

echo ""
echo "🔍 ВОЗМОЖНЫЕ ПРИЧИНЫ ПРОБЛЕМЫ:"
echo ""
echo "1. 📞 ФОРМАТ НОМЕРА:"
echo "   - Провайдер может требовать конкретный формат (+7, 8, без префикса)"
echo "   - Попробуйте разные варианты выше"
echo ""
echo "2. 🔐 АУТЕНТИФИКАЦИЯ:"
echo "   - Провайдер может блокировать звонки с неизвестных IP"
echo "   - Проверьте что IP сервера добавлен в белый список"
echo ""
echo "3. ⚙️ ПАРАМЕТРЫ SIP:"
echo "   - Неправильные кодеки или SIP заголовки"
echo "   - Провайдер может требовать специальные параметры"
echo ""
echo "4. 💰 БАЛАНС/ЛИМИТЫ:"
echo "   - Недостаточно средств на счету"
echo "   - Лимиты на исходящие звонки"
echo ""
echo "5. 🕐 ВРЕМЯ:"
echo "   - Возможны ограничения по времени звонков"
echo ""

echo "🎯 КОМАНДЫ ДЛЯ ДАЛЬНЕЙШЕЙ ДИАГНОСТИКИ:"
echo "====================================="
echo ""
echo "# Посмотреть все логи звонка:"
echo "docker exec $CONTAINER_NAME fs_cli -x 'console last 200' | grep -A10 -B10 '79206054020'"
echo ""
echo "# Проверить SIP trace:"
echo "docker exec $CONTAINER_NAME fs_cli -x 'sofia profile internal siptrace on'"
echo "# Сделать звонок и посмотреть:"
echo "docker logs -f $CONTAINER_NAME"
echo ""
echo "# Посмотреть детальные SIP сообщения:"
echo "docker exec $CONTAINER_NAME tail -f /usr/local/freeswitch/log/freeswitch.log"
echo ""

echo ""
log_success "🎉 Диагностика завершена!"

echo ""
echo "📋 СЛЕДУЮЩИЕ ШАГИ:"
echo "=================="
echo "1. Проанализируйте логи выше"
echo "2. Свяжитесь с провайдером для уточнения:"
echo "   - Правильного формата номеров"
echo "   - Статуса IP в белом списке" 
echo "   - Баланса и лимитов"
echo "3. Попробуйте тестовые звонки с разными форматами"
echo "" 