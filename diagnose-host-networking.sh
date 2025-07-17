#!/bin/bash

# Диагностика host networking FreeSWITCH
# Проверяет действительно ли работает host networking и почему Gateway DOWN
# Автор: AI Assistant
# Дата: 2025-07-17

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция логирования
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_error() {
    log "${RED}ERROR: $1${NC}"
}

log_warn() {
    log "${YELLOW}WARN: $1${NC}"
}

log_info() {
    log "${BLUE}INFO: $1${NC}"
}

log_success() {
    log "${GREEN}SUCCESS: $1${NC}"
}

SIP_HOST="62.141.121.197"
SIP_PORT="5070"

log "🔍 ДИАГНОСТИКА HOST NETWORKING FREESWITCH"

# Шаг 1: Поиск контейнера FreeSWITCH
log "Шаг 1: Поиск контейнера FreeSWITCH"

FREESWITCH_HOST_CONTAINER=$(docker ps --filter "name=dialer_freeswitch_host" --filter "status=running" --format "{{.Names}}" | head -1)
FREESWITCH_BRIDGE_CONTAINER=$(docker ps --filter "name=dialer_freeswitch" --filter "status=running" --format "{{.Names}}" | head -1)

if [ -n "$FREESWITCH_HOST_CONTAINER" ]; then
    log_success "✅ Host networking контейнер найден: $FREESWITCH_HOST_CONTAINER"
    FREESWITCH_CONTAINER="$FREESWITCH_HOST_CONTAINER"
    NETWORK_MODE="host"
elif [ -n "$FREESWITCH_BRIDGE_CONTAINER" ]; then
    log_info "Bridge networking контейнер найден: $FREESWITCH_BRIDGE_CONTAINER"
    FREESWITCH_CONTAINER="$FREESWITCH_BRIDGE_CONTAINER"
    NETWORK_MODE="bridge"
else
    log_error "❌ FreeSWITCH контейнер не найден"
    exit 1
fi

# Шаг 2: Проверка настроек контейнера
log "Шаг 2: Проверка настроек контейнера"
log_info "🔍 Анализ network mode контейнера..."

CONTAINER_NETWORK_MODE=$(docker inspect "$FREESWITCH_CONTAINER" | jq -r '.[0].HostConfig.NetworkMode')
log_info "Network Mode: $CONTAINER_NETWORK_MODE"

if [ "$CONTAINER_NETWORK_MODE" = "host" ]; then
    log_success "✅ Контейнер действительно использует host networking"
else
    log_warn "⚠️ Контейнер НЕ использует host networking: $CONTAINER_NETWORK_MODE"
fi

# Шаг 3: Проверка сетевых интерфейсов
log "Шаг 3: Сравнение сетевых интерфейсов"

log_info "🌐 Сетевые интерфейсы на хосте:"
ip addr show | grep -E "^[0-9]|inet " | head -10

log_info "🐳 Сетевые интерфейсы в контейнере:"
docker exec "$FREESWITCH_CONTAINER" ip addr show 2>/dev/null | grep -E "^[0-9]|inet " | head -10 || log_warn "Не удалось получить интерфейсы из контейнера"

# Шаг 4: Установка сетевых утилит в контейнер
log "Шаг 4: Установка сетевых утилит"
log_info "📦 Установка ping, telnet, nc в контейнер..."

docker exec "$FREESWITCH_CONTAINER" bash -c "
    apt-get update -qq >/dev/null 2>&1 || true
    apt-get install -y iputils-ping telnet netcat-openbsd curl dnsutils traceroute >/dev/null 2>&1 || true
    echo 'Утилиты установлены'
" || log_warn "Некоторые утилиты не установились"

# Шаг 5: Сравнение доступности с хоста и из контейнера
log "Шаг 5: Сравнение сетевой доступности"

# Ping с хоста
log_info "🏠 Ping $SIP_HOST с хоста:"
if ping -c 3 "$SIP_HOST" >/dev/null 2>&1; then
    log_success "✅ Ping с хоста успешен"
    ping -c 3 "$SIP_HOST" | tail -2
else
    log_error "❌ Ping с хоста неуспешен"
fi

# Ping из контейнера
log_info "🐳 Ping $SIP_HOST из контейнера:"
if docker exec "$FREESWITCH_CONTAINER" ping -c 3 "$SIP_HOST" >/dev/null 2>&1; then
    log_success "✅ Ping из контейнера успешен"
    docker exec "$FREESWITCH_CONTAINER" ping -c 3 "$SIP_HOST" | tail -2
else
    log_error "❌ Ping из контейнера неуспешен"
fi

# TCP порт с хоста
log_info "🏠 TCP $SIP_HOST:$SIP_PORT с хоста:"
if timeout 5 bash -c "</dev/tcp/$SIP_HOST/$SIP_PORT" 2>/dev/null; then
    log_success "✅ TCP подключение с хоста успешно"
else
    log_warn "⚠️ TCP подключение с хоста неуспешно (может быть нормально для SIP)"
fi

# TCP порт из контейнера
log_info "🐳 TCP $SIP_HOST:$SIP_PORT из контейнера:"
if docker exec "$FREESWITCH_CONTAINER" timeout 5 bash -c "echo > /dev/tcp/$SIP_HOST/$SIP_PORT" 2>/dev/null; then
    log_success "✅ TCP подключение из контейнера успешно"
else
    log_warn "⚠️ TCP подключение из контейнера неуспешно"
fi

# Шаг 6: Проверка маршрутизации
log "Шаг 6: Проверка маршрутизации"

log_info "🏠 Маршруты на хосте:"
ip route | grep default

log_info "🐳 Маршруты в контейнере:"
docker exec "$FREESWITCH_CONTAINER" ip route 2>/dev/null | grep default || log_warn "Не удалось получить маршруты из контейнера"

# Traceroute сравнение
log_info "🏠 Traceroute $SIP_HOST с хоста:"
timeout 30 traceroute "$SIP_HOST" 2>/dev/null | head -5 || log_warn "Traceroute с хоста неуспешен"

log_info "🐳 Traceroute $SIP_HOST из контейнера:"
docker exec "$FREESWITCH_CONTAINER" timeout 30 traceroute "$SIP_HOST" 2>/dev/null | head -5 || log_warn "Traceroute из контейнера неуспешен"

# Шаг 7: Проверка DNS
log "Шаг 7: Проверка DNS"

log_info "🏠 DNS резолюция $SIP_HOST на хосте:"
nslookup "$SIP_HOST" 2>/dev/null | grep -A2 "Non-authoritative" || log_warn "DNS резолюция на хосте проблемная"

log_info "🐳 DNS резолюция $SIP_HOST в контейнере:"
docker exec "$FREESWITCH_CONTAINER" nslookup "$SIP_HOST" 2>/dev/null | grep -A2 "Non-authoritative" || log_warn "DNS резолюция в контейнере проблемная"

# Шаг 8: Проверка портов FreeSWITCH
log "Шаг 8: Проверка портов FreeSWITCH"

log_info "🔍 Активные порты на хосте (FreeSWITCH):"
netstat -tulpn 2>/dev/null | grep -E ":5060|:8021" || log_warn "FreeSWITCH порты не найдены на хосте"

# Шаг 9: Проверка статуса Gateway в реальном времени
log "Шаг 9: Проверка Gateway в реальном времени"

log_info "🔍 Текущий статус gateway sip_trunk:"
GATEWAY_STATUS=$(docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia status gateway sip_trunk" 2>/dev/null || echo "ERROR")
echo "$GATEWAY_STATUS"

# Попытка принудительного пинга gateway
log_info "📡 Принудительный ping gateway..."
docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia profile external killgw sip_trunk" >/dev/null 2>&1 || true
sleep 2
docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia profile external rescan" >/dev/null 2>&1 || true
sleep 5

log_info "🔍 Статус gateway после принудительного ping:"
GATEWAY_STATUS_AFTER=$(docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia status gateway sip_trunk" 2>/dev/null || echo "ERROR")
echo "$GATEWAY_STATUS_AFTER"

# Шаг 10: Анализ и рекомендации
log "Шаг 10: Анализ и рекомендации"

log_success "🎯 АНАЛИЗ ЗАВЕРШЕН!"
echo
echo "📋 РЕКОМЕНДАЦИИ:"

if [ "$CONTAINER_NETWORK_MODE" != "host" ]; then
    echo "❌ КРИТИЧНО: Контейнер НЕ использует host networking!"
    echo "   Решение: ./quick-fix-sip-network-v3.sh"
fi

if echo "$GATEWAY_STATUS_AFTER" | grep -q "Status.*UP"; then
    echo "✅ Gateway sip_trunk в статусе UP после принудительного ping"
elif echo "$GATEWAY_STATUS_AFTER" | grep -q "Status.*DOWN"; then
    echo "⚠️ Gateway sip_trunk остается в статусе DOWN"
    echo "   Возможные причины:"
    echo "   1. SIP сервер действительно недоступен на порту 5070"
    echo "   2. Firewall блокирует подключения"
    echo "   3. SIP сервер отвечает только на определенные запросы"
    echo "   4. Проблема с сетевой маршрутизацией"
fi

echo
echo "🧪 ДЛЯ ДАЛЬНЕЙШЕГО ТЕСТИРОВАНИЯ:"
echo "1. Попробуйте тестовый звонок: ./test-sip-trunk.sh call 79206054020"
echo "2. Проверьте логи FreeSWITCH: ./manage-freeswitch-host.sh logs"
echo "3. Обратитесь к провайдеру SIP для проверки доступности сервера"

log_info "Диагностика завершена" 