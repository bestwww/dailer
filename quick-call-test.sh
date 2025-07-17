#!/bin/bash

# Быстрый тест звонка после принудительного ping gateway
# Автор: AI Assistant
# Дата: 2025-07-17

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')] INFO:${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] SUCCESS:${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ERROR:${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARN:${NC} $1"
}

PHONE_NUMBER="${1:-79206054020}"
FREESWITCH_CONTAINER="dialer_freeswitch_host"

echo "📞 БЫСТРЫЙ ТЕСТ ЗВОНКА ПОСЛЕ PING GATEWAY"
echo "Номер: $PHONE_NUMBER"
echo

# Проверка контейнера
if ! docker ps --filter "name=$FREESWITCH_CONTAINER" --filter "status=running" | grep -q "$FREESWITCH_CONTAINER"; then
    log_error "Контейнер $FREESWITCH_CONTAINER не найден"
    exit 1
fi

log_info "✅ Контейнер найден: $FREESWITCH_CONTAINER"

# Шаг 1: Принудительный ping gateway
log_info "🔄 Принудительный ping gateway..."
docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia profile external killgw sip_trunk" >/dev/null 2>&1 || true
sleep 1
docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia profile external rescan" >/dev/null 2>&1 || true
sleep 2

# Проверка статуса
log_info "🔍 Проверка статуса gateway..."
GATEWAY_STATUS=$(docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia status gateway sip_trunk" 2>/dev/null | grep "Status" | awk '{print $2}' || echo "UNKNOWN")
log_info "Статус gateway: $GATEWAY_STATUS"

if [ "$GATEWAY_STATUS" = "UP" ]; then
    log_success "✅ Gateway в статусе UP!"
    
    # Немедленный тест звонка
    log_info "📞 НЕМЕДЛЕННЫЙ тест звонка (пока gateway UP)..."
    CALL_RESULT=$(docker exec "$FREESWITCH_CONTAINER" fs_cli -x "originate {call_timeout=10,hangup_after_bridge=true}sofia/gateway/sip_trunk/$PHONE_NUMBER &echo" 2>&1)
    
    echo "Результат звонка:"
    echo "$CALL_RESULT"
    
    if echo "$CALL_RESULT" | grep -q "SUCCESS"; then
        log_success "🎉 ЗВОНОК ПРОШЕЛ УСПЕШНО!"
    elif echo "$CALL_RESULT" | grep -q "GATEWAY_DOWN"; then
        log_error "❌ Gateway упал в DOWN при звонке"
        log_info "Проверим статус после звонка..."
        GATEWAY_STATUS_AFTER=$(docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia status gateway sip_trunk" 2>/dev/null | grep "Status" | awk '{print $2}' || echo "UNKNOWN")
        log_info "Статус после звонка: $GATEWAY_STATUS_AFTER"
    elif echo "$CALL_RESULT" | grep -q "USER_BUSY\|CALL_REJECTED\|NORMAL_CLEARING"; then
        log_success "🎉 SIP связь работает! (номер недоступен, но это нормально)"
    elif echo "$CALL_RESULT" | grep -q "AUTHENTICATION_FAILURE\|FORBIDDEN"; then
        log_warn "⚠️ Требуется аутентификация у провайдера SIP"
    else
        log_warn "⚠️ Неопределенный результат звонка"
    fi
    
else
    log_warn "⚠️ Gateway не поднялся в UP после ping (Status: $GATEWAY_STATUS)"
    log_info "Попробуем более агрессивный перезапуск..."
    
    # Агрессивный перезапуск
    docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia profile external stop" >/dev/null 2>&1 || true
    sleep 2
    docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia profile external start" >/dev/null 2>&1 || true
    sleep 3
    
    GATEWAY_STATUS_RETRY=$(docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia status gateway sip_trunk" 2>/dev/null | grep "Status" | awk '{print $2}' || echo "UNKNOWN")
    log_info "Статус после перезапуска профиля: $GATEWAY_STATUS_RETRY"
    
    if [ "$GATEWAY_STATUS_RETRY" = "UP" ]; then
        log_success "✅ Gateway поднялся после перезапуска профиля!"
        
        # Тест звонка
        log_info "📞 Тест звонка после перезапуска профиля..."
        CALL_RESULT_RETRY=$(docker exec "$FREESWITCH_CONTAINER" fs_cli -x "originate {call_timeout=10,hangup_after_bridge=true}sofia/gateway/sip_trunk/$PHONE_NUMBER &echo" 2>&1)
        
        echo "Результат звонка:"
        echo "$CALL_RESULT_RETRY"
    fi
fi

# Финальный статус
log_info "🔍 Финальная проверка gateway..."
FINAL_GATEWAY_STATUS=$(docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia status gateway sip_trunk" 2>/dev/null | grep "Status" | awk '{print $2}' || echo "UNKNOWN")
log_info "Финальный статус: $FINAL_GATEWAY_STATUS"

echo
echo "📋 ЗАКЛЮЧЕНИЕ:"
if [ "$FINAL_GATEWAY_STATUS" = "UP" ]; then
    echo "✅ Gateway стабильно в статусе UP"
    echo "✅ Техническая связь с SIP сервером работает"
    echo "ℹ️  Для работы звонков может потребоваться настройка аутентификации"
elif [ "$GATEWAY_STATUS" = "UP" ] && [ "$FINAL_GATEWAY_STATUS" = "DOWN" ]; then
    echo "⚠️ Gateway поднимается, но падает при звонках"
    echo "⚠️ SIP сервер может требовать аутентификацию или отклонять анонимные звонки"
    echo "📞 Обратитесь к провайдеру SIP для уточнения настроек"
else
    echo "❌ Gateway не удается поднять в UP"
    echo "❌ Возможны проблемы с доступностью SIP сервера"
fi

echo
echo "📞 РЕКОМЕНДАЦИИ:"
echo "1. Если gateway периодически UP - связь работает технически"
echo "2. Уточните у провайдера SIP: нужна ли аутентификация?"
echo "3. Возможно нужны логин/пароль для gateway"
echo "4. Проверьте логи FreeSWITCH: ./manage-freeswitch-host.sh logs" 