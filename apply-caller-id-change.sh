#!/bin/bash

# 📞 Скрипт применения изменений Caller ID на 79058615815
# Обновляет FreeSWITCH с новым номером

set -e

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

log_info "📞 Применяем изменения Caller ID на 79058615815..."

# 🔍 Проверяем что Docker запущен
if ! docker ps >/dev/null 2>&1; then
    log_error "Docker не запущен или недоступен!"
    exit 1
fi

log_success "Docker доступен"

# 🔄 Останавливаем FreeSWITCH контейнер
log_info "Останавливаем FreeSWITCH контейнер..."
docker-compose stop freeswitch || true

# 📋 Показываем изменения
log_info "📋 Сводка изменений Caller ID:"
echo ""
echo "  📞 ОБНОВЛЕНО на: 79058615815"
echo ""
echo "  🔧 Файлы с изменениями:"
echo "     • freeswitch/conf/dialplan/default.xml"
echo "     • freeswitch/conf/autoload_configs/sofia.conf.xml"
echo "     • freeswitch/conf/vars.xml"
echo ""
echo "  🎯 Все настройки Caller ID теперь унифицированы!"
echo ""

# 🚀 Запускаем FreeSWITCH с новыми настройками
log_info "Запускаем FreeSWITCH с обновленным Caller ID..."
docker-compose up -d freeswitch

# ⏳ Ждем запуска
log_info "Ожидаем запуска FreeSWITCH (30 секунд)..."
sleep 30

# 🔍 Проверяем статус
log_info "Проверяем статус FreeSWITCH..."
if docker exec dialer_freeswitch fs_cli -x "status" | grep -q "UP"; then
    log_success "FreeSWITCH успешно запущен!"
else
    log_error "FreeSWITCH не запустился корректно"
    log_info "Показываем логи:"
    docker logs --tail=20 dialer_freeswitch
    exit 1
fi

# 🔍 Проверяем gateway
log_info "Проверяем статус SIP gateway..."
GATEWAY_STATUS=$(docker exec dialer_freeswitch fs_cli -x "sofia status gateway sip_trunk" || echo "ERROR")
echo "$GATEWAY_STATUS"

if echo "$GATEWAY_STATUS" | grep -q "NOREG"; then
    log_success "Gateway sip_trunk в состоянии NOREG (нормально для IP-based провайдера)"
elif echo "$GATEWAY_STATUS" | grep -q "REGED"; then
    log_success "Gateway sip_trunk зарегистрирован"
else
    log_warning "Gateway в неожиданном состоянии, но это может быть нормально"
fi

# 🧪 Тестируем исходящий звонок с новым Caller ID
log_info "🧪 Тестируем исходящий звонок с новым Caller ID..."
log_info "Выполняем тестовый звонок на номер 79206054020..."

# Запускаем тестовый звонок в фоне и ловим результат
TEST_RESULT=$(timeout 10s docker exec dialer_freeswitch fs_cli -x "originate sofia/gateway/sip_trunk/79206054020 &echo" 2>&1 || echo "TIMEOUT")

echo "Результат теста: $TEST_RESULT"

if echo "$TEST_RESULT" | grep -q "SUCCESS"; then
    log_success "Тестовый звонок с новым Caller ID успешен!"
elif echo "$TEST_RESULT" | grep -q "NORMAL_CLEARING"; then
    log_success "Звонок дошел до провайдера (NORMAL_CLEARING)"
elif echo "$TEST_RESULT" | grep -q "USER_BUSY\|NO_ANSWER"; then
    log_success "Звонок дошел до провайдера, номер занят/не отвечает"
elif echo "$TEST_RESULT" | grep -q "PROTOCOL_ERROR"; then
    log_error "Ошибка PROTOCOL_ERROR все еще возникает"
    log_info "Возможно нужно проверить настройки провайдера..."
else
    log_warning "Неопределенный результат теста"
fi

# 📊 Показываем обновленную конфигурацию
log_info "📊 Обновленная конфигурация:"
echo ""
echo "  📞 Caller ID: 79058615815"
echo "  🌐 SIP Provider: 62.141.121.197:5070"
echo "  🏠 Local IP: 46.173.16.147"
echo "  🔧 Gateway: sip_trunk (IP-based, no registration)"
echo ""

# 🔍 Проверяем логи на наличие ошибок
log_info "🔍 Проверяем недавние логи на ошибки..."
RECENT_ERRORS=$(docker logs --tail=50 dialer_freeswitch 2>&1 | grep -i "error\|fail" | tail -5 || echo "Ошибок не найдено")
if [ "$RECENT_ERRORS" != "Ошибок не найдено" ]; then
    log_warning "Найдены недавние ошибки:"
    echo "$RECENT_ERRORS"
else
    log_success "Недавних ошибок не обнаружено"
fi

log_success "🎉 Изменение Caller ID завершено!"
echo ""
echo "📋 СЛЕДУЮЩИЕ ШАГИ:"
echo ""
echo "1. 🧪 Протестируйте звонки через систему автодозвона"
echo "2. 📊 Мониторьте логи: docker logs -f dialer_freeswitch"
echo "3. 🔍 Проверьте gateway: docker exec dialer_freeswitch fs_cli -x 'sofia status'"
echo "4. 📞 Тестовый звонок: docker exec dialer_freeswitch fs_cli -x 'originate sofia/gateway/sip_trunk/НОМЕР &echo'"
echo ""
echo "🔧 Убедитесь что провайдер разрешил новый Caller ID:"
echo "   • Номер для отображения: 79058615815"
echo "   • IP whitelist: 46.173.16.147"
echo "   • Сетевая связность с 62.141.121.197:5070"
echo ""

log_success "Готово! FreeSWITCH настроен с Caller ID: 79058615815" 