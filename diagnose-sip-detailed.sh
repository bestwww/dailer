#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Без цвета

echo "=========================================="
echo "  ДЕТАЛЬНАЯ SIP ДИАГНОСТИКА"
echo "=========================================="

# Функция логирования с временными метками
log_info() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO: ${NC}🔍 $1"
}

log_success() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] SUCCESS: ${NC}✅ $1"
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARN: ${NC}⚠️ $1"
}

log_error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ERROR: ${NC}❌ $1"
}

# 1. Проверка сетевых настроек
log_info "Определение IP адресов сервера..."
EXTERNAL_IP=$(curl -s http://ipv4.icanhazip.com/ || curl -s http://checkip.amazonaws.com/)
LOCAL_IP=$(hostname -I | awk '{print $1}')
DOCKER_NETWORK=$(docker network inspect bridge --format='{{(index .IPAM.Config 0).Gateway}}' 2>/dev/null)

if [ -n "$EXTERNAL_IP" ]; then
    log_success "Внешний IP сервера: $EXTERNAL_IP"
else
    log_error "Не удалось определить внешний IP"
fi

log_info "Локальный IP сервера: $LOCAL_IP"
log_info "Docker gateway: $DOCKER_NETWORK"

# 2. Проверка Docker контейнеров
log_info "Проверка состояния FreeSWITCH контейнера..."
if docker ps | grep -q "dialer_freeswitch_host"; then
    log_success "Контейнер dialer_freeswitch_host запущен"
    
    # Получаем IP контейнера
    CONTAINER_IP=$(docker inspect dialer_freeswitch_host --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null)
    log_info "IP контейнера FreeSWITCH: $CONTAINER_IP"
else
    log_error "Контейнер dialer_freeswitch_host не запущен"
    exit 1
fi

# 3. Проверка портов
log_info "Проверка доступности портов..."
check_port() {
    local port=$1
    local description=$2
    if netstat -tuln | grep -q ":$port "; then
        log_success "Порт $port ($description) открыт"
    else
        log_warn "Порт $port ($description) не прослушивается"
    fi
}

check_port 5060 "SIP"
check_port 8021 "ESL"

# 4. Проверка SIP провайдера
log_info "Проверка доступности SIP провайдера..."
SIP_PROVIDER="62.141.121.197"
SIP_PORT="5070"

if ping -c 3 $SIP_PROVIDER >/dev/null 2>&1; then
    log_success "SIP провайдер $SIP_PROVIDER доступен (ping)"
else
    log_warn "SIP провайдер $SIP_PROVIDER недоступен (ping)"
fi

# Проверка UDP порта провайдера
if timeout 5 nc -u -z $SIP_PROVIDER $SIP_PORT 2>/dev/null; then
    log_success "UDP порт $SIP_PORT на $SIP_PROVIDER доступен"
else
    log_warn "UDP порт $SIP_PORT на $SIP_PROVIDER недоступен или заблокирован"
fi

# 5. Анализ FreeSWITCH
log_info "Проверка статуса FreeSWITCH..."

# Проверка общего статуса
FS_STATUS=$(docker exec dialer_freeswitch_host fs_cli -x "status" 2>/dev/null | head -1)
if echo "$FS_STATUS" | grep -q "UP"; then
    log_success "FreeSWITCH запущен: $FS_STATUS"
else
    log_error "FreeSWITCH не отвечает или имеет проблемы"
fi

# 6. Детальная проверка SIP gateway
log_info "Анализ SIP gateway конфигурации..."

# Проверка статуса gateway
GATEWAY_STATUS=$(docker exec dialer_freeswitch_host fs_cli -x "sofia status gateway sip_trunk" 2>/dev/null)
echo "$GATEWAY_STATUS"

if echo "$GATEWAY_STATUS" | grep -q "REGED"; then
    log_success "SIP gateway зарегистрирован"
elif echo "$GATEWAY_STATUS" | grep -q "TRYING"; then
    log_warn "SIP gateway пытается зарегистрироваться"
elif echo "$GATEWAY_STATUS" | grep -q "FAIL"; then
    log_error "SIP gateway не смог зарегистрироваться"
else
    log_warn "SIP gateway в неизвестном состоянии или не найден"
fi

# 7. Проверка Sofia SIP профилей
log_info "Проверка Sofia SIP профилей..."
SOFIA_STATUS=$(docker exec dialer_freeswitch_host fs_cli -x "sofia status" 2>/dev/null)
echo "Sofia Status:"
echo "$SOFIA_STATUS"

# 8. Анализ последних логов
log_info "Анализ последних SIP логов..."
RECENT_LOGS=$(docker exec dialer_freeswitch_host fs_cli -x "console loglevel 7" 2>/dev/null)
SIP_LOGS=$(docker logs dialer_freeswitch_host 2>&1 | grep -i "sip\|sofia" | tail -10)

if [ -n "$SIP_LOGS" ]; then
    echo ""
    echo "🔍 ПОСЛЕДНИЕ SIP ЛОГИ:"
    echo "====================="
    echo "$SIP_LOGS"
else
    log_warn "SIP логи не найдены"
fi

# 9. Тестовый звонок с детальным логированием
log_info "Выполнение тестового SIP звонка..."

# Включаем детальное SIP логирование
docker exec dialer_freeswitch_host fs_cli -x "sofia loglevel all 9" >/dev/null 2>&1
docker exec dialer_freeswitch_host fs_cli -x "sofia tracelevel info" >/dev/null 2>&1

# Тестовый звонок
TEST_NUMBER="+79206054020"
CALL_RESULT=$(docker exec dialer_freeswitch_host fs_cli -x "originate sofia/gateway/sip_trunk/$TEST_NUMBER &echo" 2>&1)
echo ""
echo "🔍 РЕЗУЛЬТАТ ТЕСТОВОГО ЗВОНКА:"
echo "=============================="
echo "$CALL_RESULT"

# Получаем детальные SIP сообщения
sleep 2
DETAILED_LOGS=$(docker logs dialer_freeswitch_host 2>&1 | grep -A 10 -B 10 "NORMAL_TEMPORARY_FAILURE\|sofia.*sip_trunk" | tail -20)
if [ -n "$DETAILED_LOGS" ]; then
    echo ""
    echo "📊 ДЕТАЛЬНЫЕ SIP СООБЩЕНИЯ:"
    echo "==========================="
    echo "$DETAILED_LOGS"
fi

# 10. Рекомендации по исправлению
echo ""
echo "🔧 РЕКОМЕНДАЦИИ ПО ИСПРАВЛЕНИЮ:"
echo "==============================="

# Анализ ошибок и рекомендации
if echo "$CALL_RESULT" | grep -q "NORMAL_TEMPORARY_FAILURE"; then
    echo "❌ Ошибка: NORMAL_TEMPORARY_FAILURE"
    echo "   Причины:"
    echo "   1. IP адрес $EXTERNAL_IP не в whitelist провайдера"
    echo "   2. Неверные учетные данные SIP (username/password)"
    echo "   3. Провайдер блокирует подключения"
    echo ""
    echo "   Действия:"
    echo "   ✅ Свяжитесь с провайдером: 62.141.121.197:5070"
    echo "   ✅ Сообщите: 'Добавьте IP $EXTERNAL_IP в whitelist для SIP'"
    echo "   ✅ Запросите правильные учетные данные (username/password)"
    echo "   ✅ Уточните требования к Caller ID (+79058615815)"
fi

if echo "$GATEWAY_STATUS" | grep -q "UNKNOWN\|FAIL"; then
    echo "❌ Gateway не зарегистрирован"
    echo "   Действия:"
    echo "   ✅ Проверьте username/password в sofia.conf.xml"
    echo "   ✅ Убедитесь что register='true'"
    echo "   ✅ Проверьте realm и proxy настройки"
fi

echo ""
echo "📞 КОНТАКТ ПРОВАЙДЕРА:"
echo "====================="
echo "🔗 IP: 62.141.121.197:5070"
echo "💬 Сообщите: 'Добавьте IP $EXTERNAL_IP в whitelist для SIP подключения на порт 5060'"
echo "📋 Запросите: username, password, realm для SIP аутентификации"
echo "📞 Уточните: разрешенные Caller ID номера"

echo ""
echo "⚙️  ФАЙЛЫ ДЛЯ РЕДАКТИРОВАНИЯ:"
echo "============================="
echo "📝 freeswitch/conf/autoload_configs/sofia.conf.xml"
echo "📝 freeswitch/conf/vars.xml (для Caller ID)"

echo ""
log_success "Диагностика завершена!" 