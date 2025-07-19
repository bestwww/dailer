#!/bin/bash

# 🚀 Скрипт развертывания изменений на тестовом сервере
# Обновляет код и применяет исправления PROTOCOL_ERROR + новый Caller ID

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

# 📋 Информация о развертывании
log_info "🚀 Начинаем развертывание на тестовом сервере..."
echo ""
echo "📋 Что будет развернуто:"
echo "  🔧 Исправления PROTOCOL_ERROR в FreeSWITCH"
echo "  📞 Обновленный Caller ID: 79058615815"
echo "  📁 Новые скрипты диагностики и исправления"
echo "  📖 Обновленная документация"
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

# 🔄 Останавливаем сервисы перед обновлением
log_info "🔄 Останавливаем сервисы..."
docker-compose down || true

# 📥 Применяем изменения
log_info "📥 Применяем обновления..."
git pull origin main

# 🔍 Проверяем ключевые файлы
log_info "🔍 Проверяем ключевые файлы..."

if [ -f "freeswitch/conf/dialplan/default.xml" ]; then
    if grep -q "79058615815" freeswitch/conf/dialplan/default.xml; then
        log_success "Dialplan обновлен с новым Caller ID"
    else
        log_warning "Caller ID в dialplan может быть не обновлен"
    fi
else
    log_error "Dialplan файл не найден!"
    exit 1
fi

if [ -f "freeswitch/conf/autoload_configs/sofia.conf.xml" ]; then
    if grep -q "79058615815" freeswitch/conf/autoload_configs/sofia.conf.xml; then
        log_success "Sofia конфигурация обновлена"
    else
        log_warning "Sofia конфигурация может быть не обновлена"
    fi
else
    log_error "Sofia конфигурация не найдена!"
    exit 1
fi

# 🔧 Делаем скрипты исполняемыми
log_info "🔧 Настраиваем права доступа..."
chmod +x fix-freeswitch-protocol-error.sh 2>/dev/null || true
chmod +x apply-caller-id-change.sh 2>/dev/null || true
chmod +x deploy-to-test-server.sh 2>/dev/null || true

log_success "Права доступа настроены"

# 🐳 Пересобираем образы если нужно
log_info "🐳 Проверяем необходимость пересборки образов..."
if [ -f "docker-compose.yml" ]; then
    docker-compose build --pull
    log_success "Образы обновлены"
else
    log_warning "docker-compose.yml не найден, пропускаем пересборку"
fi

# 🚀 Запускаем сервисы
log_info "🚀 Запускаем обновленные сервисы..."
docker-compose up -d

# ⏳ Ждем запуска
log_info "⏳ Ожидаем запуска сервисов (45 секунд)..."
sleep 45

# 🔍 Проверяем статус сервисов
log_info "🔍 Проверяем статус сервисов..."

# Проверка FreeSWITCH
if docker exec dialer_freeswitch fs_cli -x "status" 2>/dev/null | grep -q "UP"; then
    log_success "FreeSWITCH запущен успешно"
else
    log_warning "FreeSWITCH может быть не готов, проверяем логи..."
    docker logs --tail=10 dialer_freeswitch
fi

# Проверка Backend
if docker ps | grep -q "dialer_backend"; then
    log_success "Backend контейнер запущен"
    
    # Проверяем доступность API
    if curl -s -f http://localhost:3000/api/health >/dev/null 2>&1; then
        log_success "Backend API доступен"
    else
        log_warning "Backend API пока недоступен (нормально при первом запуске)"
    fi
else
    log_warning "Backend контейнер не найден"
fi

# Проверка Frontend
if docker ps | grep -q "dialer_frontend"; then
    log_success "Frontend контейнер запущен"
else
    log_warning "Frontend контейнер не найден"
fi

# 🧪 Тестируем FreeSWITCH
log_info "🧪 Тестируем FreeSWITCH конфигурацию..."

# Проверка SIP gateway
GATEWAY_STATUS=$(docker exec dialer_freeswitch fs_cli -x "sofia status gateway sip_trunk" 2>/dev/null || echo "ERROR")
if echo "$GATEWAY_STATUS" | grep -q "NOREG\|REGED"; then
    log_success "SIP Gateway работает корректно"
else
    log_warning "SIP Gateway в неожиданном состоянии:"
    echo "$GATEWAY_STATUS"
fi

# 📊 Показываем итоговую конфигурацию
log_info "📊 Итоговая конфигурация:"
echo ""
echo "  📞 Caller ID: 79058615815"
echo "  🌐 SIP Provider: 62.141.121.197:5070"
echo "  🏠 Local IP: 46.173.16.147"
echo "  🔧 Gateway: sip_trunk (IP-based, no registration)"
echo ""
echo "  🌐 Доступные сервисы:"
echo "    • Frontend: http://СЕРВЕР_IP:8080"
echo "    • Backend API: http://СЕРВЕР_IP:3000"
echo "    • FreeSWITCH Event Socket: СЕРВЕР_IP:8021"
echo ""

# 📝 Полезные команды
log_info "📝 Полезные команды для мониторинга:"
echo ""
echo "# Логи сервисов:"
echo "docker-compose logs -f"
echo ""
echo "# Логи FreeSWITCH:"
echo "docker logs -f dialer_freeswitch"
echo ""
echo "# Статус FreeSWITCH:"
echo "docker exec dialer_freeswitch fs_cli -x 'status'"
echo ""
echo "# Тестовый звонок:"
echo "docker exec dialer_freeswitch fs_cli -x 'originate sofia/gateway/sip_trunk/79206054020 &echo'"
echo ""
echo "# Статус контейнеров:"
echo "docker-compose ps"
echo ""

log_success "🎉 Развертывание завершено успешно!"
echo ""
echo "🔧 Если возникли проблемы:"
echo "  • Проверьте логи: docker-compose logs"
echo "  • Перезапустите сервисы: docker-compose restart"
echo "  • Примените исправления: ./fix-freeswitch-protocol-error.sh"
echo ""

log_success "✅ Система готова к тестированию с исправлениями PROTOCOL_ERROR и новым Caller ID!" 