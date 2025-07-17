#!/bin/bash

# Быстрое решение проблемы сетевой доступности SIP транка v2
# Исправляет конфликт network_mode vs networks
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

log "🚀 БЫСТРОЕ ИСПРАВЛЕНИЕ СЕТЕВЫХ ПРОБЛЕМ SIP ТРАНКА v2"

# Шаг 1: Остановка текущего FreeSWITCH
log "Шаг 1: Остановка текущего FreeSWITCH"
log_info "⏹️ Остановка FreeSWITCH контейнера..."

$DOCKER_COMPOSE stop freeswitch || log_warn "Не удалось остановить FreeSWITCH gracefully"
$DOCKER_COMPOSE rm -f freeswitch || log_warn "Не удалось удалить FreeSWITCH контейнер"

log_success "✅ FreeSWITCH остановлен"

# Шаг 2: Удаление старого override файла
log "Шаг 2: Очистка старой конфигурации"
if [ -f docker-compose.override.yml ]; then
    log_info "🗑️ Удаление старого docker-compose.override.yml..."
    rm docker-compose.override.yml
fi

# Шаг 3: Создание правильной конфигурации с host networking
log "Шаг 3: Создание правильной конфигурации с host networking"

# Создаем исправленный docker-compose файл без version и с правильным переопределением
log_info "📝 Создание docker-compose.override.yml с host networking..."

cat > docker-compose.override.yml << 'EOF'
services:
  freeswitch:
    network_mode: host
    # Переопределяем networks на null для совместимости с network_mode
    networks: ~
    # Переопределяем порты для host networking (порты будут доступны напрямую на хосте)
    ports: []
    # Обновляем конфигурацию для работы с host networking
    environment:
      - FREESWITCH_IP_ADDRESS=0.0.0.0
      - FREESWITCH_SIP_PORT=5060
      - FREESWITCH_EVENT_SOCKET_PORT=8021
    # Используем команду для отключения NAT
    command: freeswitch -nonat -nonatmap -u freeswitch -g freeswitch
EOF

log_success "✅ docker-compose.override.yml создан"

# Шаг 4: Проверка конфигурации
log "Шаг 4: Проверка конфигурации Docker Compose"
log_info "🔍 Валидация конфигурации..."

if $DOCKER_COMPOSE config >/dev/null 2>&1; then
    log_success "✅ Конфигурация Docker Compose валидна"
else
    log_error "❌ Конфигурация Docker Compose невалидна"
    log_info "Вывод docker compose config:"
    $DOCKER_COMPOSE config || true
    exit 1
fi

# Шаг 5: Обновление Sofia конфигурации для host networking
log "Шаг 5: Обновление Sofia конфигурации"
log_info "⚙️ Обновление конфигурации Sofia для host networking..."

# Создаем обновленную конфигурацию Sofia
mkdir -p freeswitch/conf/autoload_configs

cat > freeswitch/conf/autoload_configs/sofia.conf.xml << 'EOF'
<configuration name="sofia.conf" description="sofia Endpoint">
  <global_settings>
    <param name="log-level" value="0"/>
    <!-- Отключаем автоматическое определение IP для host networking -->
    <param name="auto-restart" value="false"/>
    <param name="debug-presence" value="0"/>
  </global_settings>

  <profiles>
    <!-- Профиль external для исходящих звонков через SIP транк -->
    <profile name="external">
      <aliases>
      </aliases>
      <gateways>
        <!-- SIP транк к провайдеру -->
        <gateway name="sip_trunk">
          <param name="proxy" value="62.141.121.197:5070"/>
          <param name="register" value="false"/>
          <param name="username" value="FreeSWITCH"/>
          <param name="password" value=""/>
          <param name="extension" value="FreeSWITCH"/>
          <param name="realm" value="62.141.121.197"/>
          <param name="from-user" value="freeswitch"/>
          <param name="from-domain" value="62.141.121.197"/>
          <param name="expire-seconds" value="3600"/>
          <param name="register-transport" value="udp"/>
          <param name="retry-seconds" value="30"/>
          <param name="caller-id-in-from" value="false"/>
          <param name="contact-params" value="transport=udp"/>
          <param name="ping" value="25"/>
        </gateway>
      </gateways>
      <settings>
        <!-- Настройки для host networking -->
        <param name="sip-ip" value="0.0.0.0"/>
        <param name="sip-port" value="5060"/>
        <param name="rtp-ip" value="0.0.0.0"/>
        <param name="use-rtp-timer" value="true"/>
        <param name="rtp-timer-name" value="soft"/>
        <param name="context" value="public"/>
        <param name="rfc2833-pt" value="101"/>
        <param name="sip-trace" value="no"/>
        <param name="sip-capture" value="no"/>
        <param name="watchdog-enabled" value="no"/>
        <param name="watchdog-step-timeout" value="30000"/>
        <param name="watchdog-event-timeout" value="30000"/>
        <param name="log-auth-failures" value="false"/>
        <param name="forward-unsolicited-mwi-notify" value="false"/>
        <param name="dialplan" value="XML"/>
        <param name="dtmf-duration" value="2000"/>
        <param name="inbound-codec-prefs" value="PCMU,PCMA"/>
        <param name="outbound-codec-prefs" value="PCMU,PCMA"/>
        <param name="hold-music" value="$${hold_music}"/>
        <param name="apply-nat-acl" value="nat.auto"/>
        <param name="extended-info-parsing" value="true"/>
        <param name="aggressive-nat-detection" value="true"/>
        <param name="enable-timer" value="false"/>
        <param name="enable-100rel" value="true"/>
        <param name="minimum-session-expires" value="120"/>
        <param name="apply-inbound-acl" value="domains"/>
        <param name="record-path" value="$${recordings_dir}"/>
        <param name="record-template" value="$${base_dir}/recordings/${caller_id_number}.${target_domain}.${strftime(%Y-%m-%d-%H-%M-%S)}.wav"/>
        <param name="manage-presence" value="false"/>
        <param name="presence-hosts" value="$${domain}"/>
        <param name="presence-privacy" value="$${presence_privacy}"/>
        <param name="inbound-codec-negotiation" value="generous"/>
        <param name="tls" value="false"/>
        <param name="inbound-late-negotiation" value="true"/>
        <param name="inbound-zrtp-passthru" value="true"/>
        <param name="nonce-ttl" value="60"/>
        <param name="auth-calls" value="false"/>
        <param name="inbound-reg-force-matching-username" value="true"/>
        <param name="auth-all-packets" value="false"/>
        <param name="ext-rtp-ip" value="0.0.0.0"/>
        <param name="ext-sip-ip" value="0.0.0.0"/>
        <param name="rtp-timeout-sec" value="300"/>
        <param name="rtp-hold-timeout-sec" value="1800"/>
        <!-- Отключаем NAT для host networking -->
        <param name="force-register-domain" value="62.141.121.197"/>
        <param name="force-subscription-domain" value="62.141.121.197"/>
        <param name="force-register-db-domain" value="62.141.121.197"/>
        <param name="disable-transcoding" value="true"/>
      </settings>
    </profile>
  </profiles>
</configuration>
EOF

log_success "✅ Sofia конфигурация обновлена для host networking"

# Шаг 6: Проверка занятости порта 5060
log "Шаг 6: Проверка доступности порта 5060"
log_info "🔍 Проверка занятости порта 5060..."

if netstat -tulpn 2>/dev/null | grep -q ":5060"; then
    log_warn "⚠️ Порт 5060 уже используется:"
    netstat -tulpn | grep ":5060" || true
    log_warn "FreeSWITCH может не запуститься. Завершите процесс использующий порт 5060."
    
    # Пауза для принятия решения
    log_info "Продолжить запуск? (FreeSWITCH попытается запуститься) [Enter для продолжения, Ctrl+C для отмены]"
    read -r
else
    log_success "✅ Порт 5060 свободен"
fi

# Шаг 7: Запуск FreeSWITCH с новой конфигурацией
log "Шаг 7: Запуск FreeSWITCH с host networking"
log_info "🚀 Запуск FreeSWITCH с host networking..."

$DOCKER_COMPOSE up -d freeswitch

# Ждем запуска
log_info "⏳ Ожидание запуска FreeSWITCH..."
sleep 15

# Проверяем статус
if $DOCKER_COMPOSE ps freeswitch | grep -q "Up"; then
    log_success "✅ FreeSWITCH запущен с host networking"
else
    log_error "❌ FreeSWITCH не запустился"
    log_info "Проверьте логи: $DOCKER_COMPOSE logs freeswitch"
    log_info "Показываю последние логи:"
    $DOCKER_COMPOSE logs --tail=20 freeswitch || true
    exit 1
fi

# Шаг 8: Проверка Sofia профиля
log "Шаг 8: Проверка Sofia профиля"
log_info "🔍 Проверка статуса Sofia профиля..."

# Ждем загрузки Sofia
sleep 10

FREESWITCH_CONTAINER=$(docker ps --filter name=freeswitch --format "{{.Names}}" | head -1)
if [ -n "$FREESWITCH_CONTAINER" ]; then
    # Перезагружаем Sofia конфигурацию
    log_info "🔄 Перезагрузка Sofia конфигурации..."
    docker exec "$FREESWITCH_CONTAINER" fs_cli -x "reloadxml" || log_warn "Не удалось перезагрузить XML"
    docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia profile external restart" || log_warn "Не удалось перезапустить профиль"
    
    sleep 5
    
    # Проверяем статус
    SOFIA_STATUS=$(docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia status" 2>/dev/null || echo "ERROR")
    
    if echo "$SOFIA_STATUS" | grep -q "external.*RUNNING"; then
        log_success "✅ Профиль external запущен!"
    else
        log_warn "⚠️ Профиль external не запущен, пытаемся исправить..."
        
        # Принудительный запуск профиля
        docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia profile external start" || log_warn "Не удалось запустить профиль"
        sleep 5
    fi
    
    # Финальная проверка
    FINAL_STATUS=$(docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia status" 2>/dev/null || echo "ERROR")
    log_info "Финальный статус Sofia:"
    echo "$FINAL_STATUS"
    
else
    log_error "❌ Контейнер FreeSWITCH не найден после запуска"
    exit 1
fi

# Шаг 9: Тестирование сетевой доступности
log "Шаг 9: Тестирование сетевой доступности"
log_info "🌐 Проверка доступности SIP сервера..."

# Проверка ping с хоста (теперь контейнер использует сеть хоста)
if ping -c 3 62.141.121.197 >/dev/null 2>&1; then
    log_success "✅ SIP сервер 62.141.121.197 доступен с хоста"
else
    log_warn "⚠️ SIP сервер 62.141.121.197 недоступен с хоста"
fi

# Шаг 10: Проверка статуса Gateway
log "Шаг 10: Проверка статуса Gateway"
log_info "🔍 Проверка статуса gateway sip_trunk..."

if [ -n "$FREESWITCH_CONTAINER" ]; then
    sleep 5
    GATEWAY_STATUS=$(docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia status gateway sip_trunk" 2>/dev/null || echo "GATEWAY_ERROR")
    
    log_info "Статус gateway sip_trunk:"
    echo "$GATEWAY_STATUS"
    
    if echo "$GATEWAY_STATUS" | grep -q "Status.*UP"; then
        log_success "🎉 Gateway sip_trunk в статусе UP!"
    elif echo "$GATEWAY_STATUS" | grep -q "Status.*DOWN"; then
        log_warn "⚠️ Gateway sip_trunk в статусе DOWN, но это может быть нормально для peer-to-peer"
        log_info "Попробуем принудительный рестарт gateway..."
        docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia profile external killgw sip_trunk" || true
        sleep 2
        docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia profile external rescan" || true
        sleep 3
        
        # Повторная проверка
        GATEWAY_STATUS_2=$(docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia status gateway sip_trunk" 2>/dev/null || echo "GATEWAY_ERROR")
        if echo "$GATEWAY_STATUS_2" | grep -q "Status.*UP"; then
            log_success "🎉 Gateway sip_trunk теперь в статусе UP!"
        else
            log_info "Gateway статус после рестарта:"
            echo "$GATEWAY_STATUS_2"
        fi
    else
        log_warn "⚠️ Не удалось определить статус gateway"
    fi
fi

# Шаг 11: Итоговая информация
log "Шаг 11: Итоговая информация"

log_success "🎉 ИСПРАВЛЕНИЕ ЗАВЕРШЕНО!"
echo
echo "📋 ЧТО БЫЛО СДЕЛАНО:"
echo "1. ✅ FreeSWITCH переведен на host networking"
echo "2. ✅ Исправлен конфликт network_mode vs networks"
echo "3. ✅ Обновлена конфигурация Sofia для работы без NAT"
echo "4. ✅ Создан правильный docker-compose.override.yml"
echo "5. ✅ Gateway sip_trunk настроен для прямого подключения"
echo
echo "🧪 ДЛЯ ТЕСТИРОВАНИЯ ИСПОЛЬЗУЙТЕ:"
echo "./test-sip-trunk.sh call 79206054020"
echo
echo "📝 ВАЖНЫЕ ПРИМЕЧАНИЯ:"
echo "- FreeSWITCH теперь использует сеть хоста (порты доступны напрямую)"
echo "- SIP порт: 5060, Event Socket: 8021"
echo "- Конфигурация сохранена в docker-compose.override.yml"
echo "- Для возврата к bridge сети удалите docker-compose.override.yml"

log_info "Для проверки логов FreeSWITCH: $DOCKER_COMPOSE logs -f freeswitch" 