#!/bin/bash
# Скрипт для проверки внешнего IP и диагностики SIP соединения

echo "🌐 ПРОВЕРКА IP АДРЕСА И SIP ДИАГНОСТИКА"
echo "======================================"

# Функция логирования
log() {
    echo "[$(date '+%H:%M:%S')] $1: $2"
}

# Получение внешнего IP
log "INFO" "🔍 Определение внешнего IP адреса сервера..."
EXTERNAL_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || curl -s icanhazip.com 2>/dev/null)

if [ -n "$EXTERNAL_IP" ]; then
    log "SUCCESS" "✅ Внешний IP сервера: $EXTERNAL_IP"
else
    log "ERROR" "❌ Не удалось определить внешний IP"
    exit 1
fi

# Проверка локального IP
LOCAL_IP=$(ip route get 8.8.8.8 | awk '{print $7; exit}')
log "INFO" "🏠 Локальный IP сервера: $LOCAL_IP"

# Проверка состояния контейнера
log "INFO" "🐳 Проверка состояния FreeSWITCH контейнера..."
if docker ps --format "table {{.Names}}" | grep -q "dialer_freeswitch_host"; then
    log "SUCCESS" "✅ Контейнер dialer_freeswitch_host запущен"
else
    log "ERROR" "❌ Контейнер dialer_freeswitch_host не найден"
    echo "Запустите: ./manage-freeswitch-host.sh start"
    exit 1
fi

# Проверка статуса gateway
log "INFO" "📡 Проверка статуса SIP gateway..."
GATEWAY_STATUS=$(docker exec dialer_freeswitch_host fs_cli -x "sofia status gateway sip_trunk" 2>/dev/null | grep "State:" | awk '{print $2}')

if [ "$GATEWAY_STATUS" = "REGED" ] || [ "$GATEWAY_STATUS" = "UP" ]; then
    log "SUCCESS" "✅ Gateway статус: $GATEWAY_STATUS"
else
    log "WARN" "⚠️ Gateway статус: ${GATEWAY_STATUS:-UNKNOWN}"
fi

# Получение детальных SIP логов
log "INFO" "📝 Включение детального SIP логирования..."
docker exec dialer_freeswitch_host fs_cli -x "sofia loglevel all 9" >/dev/null 2>&1

# Тестовый звонок с логированием
log "INFO" "📞 Выполнение тестового звонка с детальным логированием..."
TEST_NUMBER="+79206054020"

echo ""
echo "🔍 ДЕТАЛЬНЫЕ SIP ЛОГИ:"
echo "====================="

# Выполняем звонок и захватываем логи
CALL_RESULT=$(docker exec dialer_freeswitch_host fs_cli -x "originate sofia/external/$TEST_NUMBER@sip_trunk &echo()" 2>&1)

echo "$CALL_RESULT"

echo ""
echo "📊 ПОСЛЕДНИЕ SIP СООБЩЕНИЯ:"
echo "=========================="

# Получаем последние SIP сообщения из логов
docker exec dialer_freeswitch_host tail -n 50 /usr/local/freeswitch/log/freeswitch.log | grep -E "(INVITE|100|180|200|4[0-9][0-9]|5[0-9][0-9]|6[0-9][0-9]|BYE|CANCEL)" || echo "SIP сообщения не найдены в логах"

echo ""
echo "🔧 РЕКОМЕНДАЦИИ:"
echo "==============="
echo "1. Сообщите провайдеру SIP ваш внешний IP: $EXTERNAL_IP"
echo "2. Попросите добавить этот IP в whitelist"
echo "3. IP должен быть добавлен для порта 5060 (SIP)"
echo ""
echo "📞 КОНТАКТ ПРОВАЙДЕРА: 62.141.121.197:5070"
echo "💬 СООБЩИТЕ: \"Добавьте IP $EXTERNAL_IP в whitelist для SIP подключения\"" 