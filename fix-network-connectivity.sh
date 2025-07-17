#!/bin/bash

# Скрипт для диагностики и исправления сетевых проблем FreeSWITCH
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

# SIP сервер
SIP_HOST="62.141.121.197"
SIP_PORT="5070"

# Определение команды Docker Compose
if command -v docker-compose >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
else
    log_error "Docker Compose не найден"
    exit 1
fi

log_info "Docker Compose команда: $DOCKER_COMPOSE"

log "🌐 ДИАГНОСТИКА СЕТЕВЫХ ПРОБЛЕМ FREESWITCH"

# Шаг 1: Проверка Docker сети
log "Шаг 1: Анализ Docker сети"
log_info "📡 Анализ Docker сетей..."

# Показать все сети
log_info "Доступные Docker сети:"
docker network ls

# Показать детали сети проекта
PROJECT_NETWORK=$(docker network ls --filter name=dailer --format "{{.Name}}" | head -1)
if [ -n "$PROJECT_NETWORK" ]; then
    log_info "Детали сети проекта ($PROJECT_NETWORK):"
    docker network inspect "$PROJECT_NETWORK" | jq -r '.[] | {Name: .Name, Driver: .Driver, IPAM: .IPAM, Containers: (.Containers // {} | keys)}'
else
    log_warn "Сеть проекта не найдена"
fi

# Шаг 2: Проверка контейнера FreeSWITCH
log "Шаг 2: Диагностика контейнера FreeSWITCH"
FREESWITCH_CONTAINER=$(docker ps --filter name=freeswitch --format "{{.Names}}" | head -1)

if [ -z "$FREESWITCH_CONTAINER" ]; then
    log_error "Контейнер FreeSWITCH не найден"
    exit 1
fi

log_info "Контейнер FreeSWITCH: $FREESWITCH_CONTAINER"

# Получить IP адрес контейнера
CONTAINER_IP=$(docker inspect "$FREESWITCH_CONTAINER" | jq -r '.[0].NetworkSettings.Networks | to_entries[0].value.IPAddress')
log_info "IP адрес контейнера: $CONTAINER_IP"

# Проверка сетевых интерфейсов в контейнере
log_info "Сетевые интерфейсы в контейнере:"
docker exec "$FREESWITCH_CONTAINER" ip addr show || log_warn "Не удалось получить сетевые интерфейсы"

# Шаг 3: Тестирование сетевой доступности
log "Шаг 3: Тестирование сетевой доступности"

# Проверка из хоста
log_info "🔍 Проверка доступности $SIP_HOST:$SIP_PORT с хоста..."
if timeout 5 bash -c "</dev/tcp/$SIP_HOST/$SIP_PORT" 2>/dev/null; then
    log_success "✅ Хост может подключиться к $SIP_HOST:$SIP_PORT"
else
    log_warn "⚠️ Хост НЕ может подключиться к $SIP_HOST:$SIP_PORT"
fi

# Проверка ping с хоста
log_info "Ping $SIP_HOST с хоста..."
if ping -c 3 "$SIP_HOST" >/dev/null 2>&1; then
    log_success "✅ Ping к $SIP_HOST с хоста успешен"
else
    log_warn "⚠️ Ping к $SIP_HOST с хоста неуспешен"
fi

# Проверка из контейнера - установка инструментов
log_info "📦 Установка сетевых инструментов в контейнер..."
docker exec "$FREESWITCH_CONTAINER" bash -c "
    apt-get update -qq >/dev/null 2>&1 || true
    apt-get install -y iputils-ping telnet netcat-openbsd curl dnsutils >/dev/null 2>&1 || true
" || log_warn "Не удалось установить все сетевые инструменты"

# Проверка ping из контейнера
log_info "Ping $SIP_HOST из контейнера..."
if docker exec "$FREESWITCH_CONTAINER" ping -c 3 "$SIP_HOST" >/dev/null 2>&1; then
    log_success "✅ Ping к $SIP_HOST из контейнера успешен"
else
    log_error "❌ Ping к $SIP_HOST из контейнера неуспешен"
    PING_FAILED=1
fi

# Проверка TCP подключения из контейнера
log_info "Проверка TCP подключения к $SIP_HOST:$SIP_PORT из контейнера..."
if docker exec "$FREESWITCH_CONTAINER" timeout 5 bash -c "echo > /dev/tcp/$SIP_HOST/$SIP_PORT" 2>/dev/null; then
    log_success "✅ TCP подключение к $SIP_HOST:$SIP_PORT из контейнера успешно"
else
    log_error "❌ TCP подключение к $SIP_HOST:$SIP_PORT из контейнера неуспешно"
    TCP_FAILED=1
fi

# Проверка UDP подключения из контейнера (для SIP)
log_info "Проверка UDP подключения к $SIP_HOST:$SIP_PORT из контейнера..."
if docker exec "$FREESWITCH_CONTAINER" timeout 5 nc -u -v "$SIP_HOST" "$SIP_PORT" </dev/null 2>&1 | grep -q "succeeded\|open"; then
    log_success "✅ UDP подключение к $SIP_HOST:$SIP_PORT из контейнера успешно"
else
    log_warn "⚠️ UDP подключение к $SIP_HOST:$SIP_PORT из контейнера неопределенно"
fi

# Шаг 4: Проверка DNS
log "Шаг 4: Проверка DNS"
log_info "🔍 Проверка DNS резолюции..."

# DNS из контейнера
docker exec "$FREESWITCH_CONTAINER" nslookup "$SIP_HOST" 2>/dev/null | head -10 || log_warn "DNS резолюция из контейнера проблемная"

# Шаг 5: Проверка маршрутизации
log "Шаг 5: Проверка маршрутизации"
log_info "🛣️ Маршрутизация из контейнера..."

# Показать маршруты в контейнере
docker exec "$FREESWITCH_CONTAINER" ip route show || log_warn "Не удалось получить маршруты"

# Traceroute к SIP серверу
log_info "Traceroute к $SIP_HOST из контейнера:"
docker exec "$FREESWITCH_CONTAINER" timeout 30 traceroute "$SIP_HOST" 2>/dev/null | head -10 || log_warn "Traceroute неуспешен"

# Шаг 6: Попытка исправления
log "Шаг 6: Попытки исправления"

if [ "$PING_FAILED" = "1" ] || [ "$TCP_FAILED" = "1" ]; then
    log_warn "⚠️ Обнаружены сетевые проблемы, пытаемся исправить..."
    
    # Попытка 1: Перезапуск сетевых служб в контейнере
    log_info "🔄 Перезапуск сетевых служб в контейнере..."
    docker exec "$FREESWITCH_CONTAINER" bash -c "
        service networking restart 2>/dev/null || true
        systemctl restart systemd-networkd 2>/dev/null || true
    " || log_info "Некоторые сетевые службы недоступны (это нормально)"
    
    # Попытка 2: Добавление статического маршрута
    log_info "🛣️ Добавление статического маршрута..."
    docker exec "$FREESWITCH_CONTAINER" bash -c "
        # Получаем gateway по умолчанию
        DEFAULT_GW=\$(ip route | grep default | head -1 | awk '{print \$3}')
        if [ -n \"\$DEFAULT_GW\" ]; then
            ip route add $SIP_HOST via \$DEFAULT_GW 2>/dev/null || true
            echo \"Добавлен маршрут к $SIP_HOST через \$DEFAULT_GW\"
        fi
    " || log_warn "Не удалось добавить статический маршрут"
    
    # Попытка 3: Изменение конфигурации Docker сети
    log_info "🌐 Проверка конфигурации Docker сети..."
    
    # Показать iptables правила
    log_info "Текущие iptables правила на хосте (касающиеся Docker):"
    iptables -L DOCKER -n 2>/dev/null | head -20 || log_warn "Не удалось получить iptables правила"
    
    # Попытка 4: Перезапуск контейнера с новой сетевой конфигурацией
    log_info "🔄 Попытка перезапуска FreeSWITCH с host networking..."
    
    # Создаем временный docker-compose файл с host networking
    cat > docker-compose.network-fix.yml << 'EOF'
version: '3.8'

services:
  freeswitch:
    image: signalwire/freeswitch:latest
    network_mode: host
    volumes:
      - ./freeswitch/conf:/usr/local/freeswitch/conf
      - ./freeswitch/db:/usr/local/freeswitch/db
      - ./freeswitch/log:/usr/local/freeswitch/log
      - ./freeswitch/recordings:/usr/local/freeswitch/recordings
    command: freeswitch -nonat -nonatmap -u freeswitch -g freeswitch
    restart: unless-stopped
EOF
    
    log_info "Создан временный конфиг с host networking"
    log_info "Для применения выполните: $DOCKER_COMPOSE -f docker-compose.network-fix.yml up -d freeswitch"
    
fi

# Шаг 7: Повторное тестирование
log "Шаг 7: Повторное тестирование после исправлений"

# Проверка ping после исправлений
log_info "Повторная проверка ping к $SIP_HOST из контейнера..."
if docker exec "$FREESWITCH_CONTAINER" ping -c 3 "$SIP_HOST" >/dev/null 2>&1; then
    log_success "✅ Ping к $SIP_HOST из контейнера теперь успешен"
else
    log_warn "⚠️ Ping к $SIP_HOST из контейнера все еще неуспешен"
fi

# Проверка SIP gateway статуса
log_info "🔍 Проверка статуса SIP gateway после исправлений..."
GATEWAY_STATUS=$(docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia status gateway sip_trunk" 2>/dev/null | grep "Status" | awk '{print $2}' || echo "UNKNOWN")
log_info "Статус gateway: $GATEWAY_STATUS"

if [ "$GATEWAY_STATUS" = "UP" ]; then
    log_success "🎉 Gateway sip_trunk в статусе UP!"
elif [ "$GATEWAY_STATUS" = "DOWN" ]; then
    log_warn "⚠️ Gateway sip_trunk все еще в статусе DOWN"
else
    log_warn "⚠️ Не удалось определить статус gateway"
fi

# Шаг 8: Рекомендации
log "Шаг 8: Рекомендации"

log "📋 РЕКОМЕНДАЦИИ ПО РЕШЕНИЮ ПРОБЛЕМ:"
echo "1. Если ping не работает из контейнера:"
echo "   - Проверьте firewall на хосте: ufw status"
echo "   - Проверьте iptables правила: iptables -L"
echo "   - Рассмотрите использование host networking"

echo "2. Если TCP/UDP подключение не работает:"
echo "   - Убедитесь что SIP сервер доступен извне"
echo "   - Проверьте что порт 5070 открыт на SIP сервере"
echo "   - Рассмотрите использование другого порта"

echo "3. Для временного решения используйте host networking:"
echo "   $DOCKER_COMPOSE -f docker-compose.network-fix.yml up -d freeswitch"

echo "4. Для долгосрочного решения:"
echo "   - Настройте Docker bridge сеть с правильной маршрутизацией"
echo "   - Добавьте необходимые iptables правила"
echo "   - Обратитесь к провайдеру SIP для проверки доступности"

log_success "✅ Диагностика сетевых проблем завершена!" 