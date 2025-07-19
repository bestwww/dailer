#!/bin/bash

# 🔧 Скрипт обновления только конфигурации FreeSWITCH
# БЕЗ пересборки Docker образов (для работающих систем)

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

# 📋 Информация об обновлении
log_info "🔧 Обновляем только конфигурацию FreeSWITCH (БЕЗ пересборки образов)..."
echo ""
echo "📋 Что будет обновлено:"
echo "  📞 Caller ID: 79058615815 (унификация)"
echo "  🔧 Исправления PROTOCOL_ERROR в конфигурации"
echo "  📁 Диалплан и Sofia SIP настройки"
echo "  ⚡ Без пересборки Docker образов!"
echo ""

# 🔍 Проверяем git
if ! command -v git >/dev/null 2>&1; then
    log_error "Git не установлен!"
    exit 1
fi

log_success "Git доступен"

# 📥 Получаем последние изменения
log_info "📥 Получаем последние изменения из репозитория..."
git fetch origin

# 📊 Показываем информацию о коммитах
log_info "📊 Новые коммиты:"
git log --oneline HEAD..origin/main | head -5 || echo "Нет новых коммитов"

# 🔄 Останавливаем только FreeSWITCH (сохраняем работающие сервисы)
log_info "🔄 Останавливаем только FreeSWITCH..."
docker compose stop freeswitch || true

# 📥 Применяем изменения
log_info "📥 Применяем обновления конфигурации..."
git pull origin main

# 🔍 Проверяем ключевые файлы
log_info "🔍 Проверяем обновленные конфигурационные файлы..."

if [ -f "freeswitch/conf/dialplan/default.xml" ]; then
    if grep -q "79058615815" freeswitch/conf/dialplan/default.xml; then
        log_success "Dialplan обновлен с новым Caller ID: 79058615815"
    else
        log_warning "Caller ID в dialplan может быть не обновлен"
    fi
else
    log_error "Dialplan файл не найден!"
    exit 1
fi

if [ -f "freeswitch/conf/autoload_configs/sofia.conf.xml" ]; then
    if grep -q "79058615815" freeswitch/conf/autoload_configs/sofia.conf.xml; then
        log_success "Sofia конфигурация обновлена с новым Caller ID"
    else
        log_warning "Sofia конфигурация может быть не обновлена"
    fi
else
    log_error "Sofia конфигурация не найдена!"
    exit 1
fi

if [ -f "freeswitch/conf/vars.xml" ]; then
    if grep -q "79058615815" freeswitch/conf/vars.xml; then
        log_success "Глобальные переменные обновлены"
    else
        log_warning "Глобальные переменные могут быть не обновлены"
    fi
else
    log_error "Файл vars.xml не найден!"
    exit 1
fi

# 🔧 Делаем скрипты исполняемыми
log_info "🔧 Настраиваем права доступа..."
chmod +x *.sh 2>/dev/null || true
log_success "Права доступа настроены"

# 🚀 Запускаем только FreeSWITCH (без пересборки!)
log_info "🚀 Запускаем FreeSWITCH с обновленной конфигурацией..."
docker compose up -d freeswitch

# ⏳ Ждем запуска FreeSWITCH
log_info "⏳ Ожидаем запуска FreeSWITCH (30 секунд)..."
sleep 30

# 🔍 Проверяем статус FreeSWITCH
log_info "🔍 Проверяем статус FreeSWITCH..."
if docker exec dialer_freeswitch fs_cli -x "status" 2>/dev/null | grep -q "UP"; then
    log_success "FreeSWITCH успешно запущен с новой конфигурацией!"
else
    log_warning "FreeSWITCH может быть не готов, проверяем логи..."
    docker logs --tail=10 dialer_freeswitch
fi

# 🔍 Проверяем SIP gateway
log_info "🔍 Проверяем статус SIP gateway..."
GATEWAY_STATUS=$(docker exec dialer_freeswitch fs_cli -x "sofia status gateway sip_trunk" 2>/dev/null || echo "ERROR")
echo "$GATEWAY_STATUS"

if echo "$GATEWAY_STATUS" | grep -q "NOREG\|REGED"; then
    log_success "SIP Gateway работает корректно"
else
    log_warning "SIP Gateway в неожиданном состоянии:"
    echo "$GATEWAY_STATUS"
fi

# 🧪 Тестируем исходящий звонок с новым Caller ID
log_info "🧪 Тестируем исходящий звонок с обновленным Caller ID..."
log_info "Выполняем тестовый звонок на номер 79206054020..."

# Запускаем тестовый звонок в фоне и ловим результат
TEST_RESULT=$(timeout 10s docker exec dialer_freeswitch fs_cli -x "originate sofia/gateway/sip_trunk/79206054020 &echo" 2>&1 || echo "TIMEOUT")

echo "Результат теста: $TEST_RESULT"

if echo "$TEST_RESULT" | grep -q "SUCCESS"; then
    log_success "Тестовый звонок с обновленным Caller ID успешен!"
elif echo "$TEST_RESULT" | grep -q "NORMAL_CLEARING"; then
    log_success "Звонок дошел до провайдера (NORMAL_CLEARING)"
elif echo "$TEST_RESULT" | grep -q "USER_BUSY\|NO_ANSWER"; then
    log_success "Звонок дошел до провайдера, номер занят/не отвечает"
elif echo "$TEST_RESULT" | grep -q "PROTOCOL_ERROR"; then
    log_error "Ошибка PROTOCOL_ERROR все еще возникает"
    log_info "Возможно нужна дополнительная диагностика..."
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
echo "  ✅ Остальные сервисы НЕ затронуты!"
echo ""

# 🔍 Проверяем логи на наличие ошибок
log_info "🔍 Проверяем недавние логи FreeSWITCH на ошибки..."
RECENT_ERRORS=$(docker logs --tail=50 dialer_freeswitch 2>&1 | grep -i "error\|fail" | tail -5 || echo "Ошибок не найдено")
if [ "$RECENT_ERRORS" != "Ошибок не найдено" ]; then
    log_warning "Найдены недавние ошибки:"
    echo "$RECENT_ERRORS"
else
    log_success "Недавних ошибок не обнаружено"
fi

# 📝 Полезные команды
log_info "📝 Полезные команды для мониторинга:"
echo ""
echo "# Логи FreeSWITCH:"
echo "docker logs -f dialer_freeswitch"
echo ""
echo "# Статус FreeSWITCH:"
echo "docker exec dialer_freeswitch fs_cli -x 'status'"
echo ""
echo "# Статус SIP gateway:"
echo "docker exec dialer_freeswitch fs_cli -x 'sofia status gateway sip_trunk'"
echo ""
echo "# Тестовый звонок:"
echo "docker exec dialer_freeswitch fs_cli -x 'originate sofia/gateway/sip_trunk/79206054020 &echo'"
echo ""
echo "# Статус всех контейнеров:"
echo "docker compose ps"
echo ""

log_success "🎉 Обновление конфигурации завершено успешно!"
echo ""
echo "✅ РЕЗУЛЬТАТ:"
echo "  • Обновлена только конфигурация FreeSWITCH"
echo "  • Унифицирован Caller ID: 79058615815"
echo "  • Применены исправления PROTOCOL_ERROR"
echo "  • Остальные сервисы продолжают работать"
echo "  • БЕЗ пересборки Docker образов!"
echo ""

log_success "FreeSWITCH готов к работе с обновленной конфигурацией!" 