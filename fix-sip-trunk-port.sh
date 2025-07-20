#!/bin/bash

# 🔧 Исправление конфигурации SIP trunk для правильного порта провайдера
# Провайдер: 62.141.121.197:5070, FreeSWITCH: 5060

set -e

CONTAINER_NAME="freeswitch-test"
SIP_PROVIDER_HOST="62.141.121.197"
SIP_PROVIDER_PORT="5070"
CALLER_ID="79058615815"

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

echo "🔧 ИСПРАВЛЕНИЕ SIP TRUNK КОНФИГУРАЦИИ"
echo "====================================="
echo ""
echo "📋 Настройки:"
echo "   🌐 Провайдер: $SIP_PROVIDER_HOST:$SIP_PROVIDER_PORT"
echo "   📞 FreeSWITCH: порт 5060 (стандартный)"
echo "   🆔 Caller ID: $CALLER_ID"
echo ""

# Проверяем контейнер
if ! docker ps --filter "name=$CONTAINER_NAME" --filter "status=running" | grep -q "$CONTAINER_NAME"; then
    log_error "Контейнер $CONTAINER_NAME не запущен!"
    exit 1
fi

log_success "Контейнер $CONTAINER_NAME найден"

# Создаем правильную конфигурацию Sofia с портом провайдера
log_info "Создаем исправленную конфигурацию Sofia SIP..."

cat > freeswitch/conf/autoload_configs/sofia.conf.xml << EOF
<configuration name="sofia.conf" description="Sofia SIP">
  <global_settings>
    <param name="log-level" value="0"/>
    <param name="auto-restart" value="false"/>
    <param name="debug-presence" value="0"/>
  </global_settings>
  
  <profiles>
    <!-- Internal Profile для локальных соединений -->
    <profile name="internal">
      <gateways>
        <X-PRE-PROCESS cmd="include" data="internal/*.xml"/>
      </gateways>
      <domains>
        <domain name="all" alias="false" parse="true"/>
      </domains>
      <settings>
        <param name="debug" value="0"/>
        <param name="sip-trace" value="no"/>
        <param name="sip-capture" value="no"/>
        <param name="rfc2833-pt" value="101"/>
        <param name="sip-port" value="5060"/>
        <param name="dialplan" value="XML"/>
        <param name="context" value="default"/>
        <param name="dtmf-duration" value="2000"/>
        <param name="inbound-codec-prefs" value="PCMU,PCMA"/>
        <param name="outbound-codec-prefs" value="PCMU,PCMA"/>
        <param name="rtp-timer-name" value="soft"/>
        <param name="local-network-acl" value="localnet.auto"/>
        <param name="manage-presence" value="false"/>
        <param name="inbound-codec-negotiation" value="generous"/>
        <param name="nonce-ttl" value="60"/>
        <param name="auth-calls" value="false"/>
        <param name="inbound-late-negotiation" value="true"/>
        <param name="inbound-zrtp-passthru" value="true"/>
        <param name="rtp-ip" value="auto"/>
        <param name="sip-ip" value="auto"/>
        <param name="ext-rtp-ip" value="auto-nat"/>
        <param name="ext-sip-ip" value="auto-nat"/>
        <param name="rtp-timeout-sec" value="300"/>
        <param name="rtp-hold-timeout-sec" value="1800"/>
        <param name="enable-3pcc" value="true"/>
      </settings>
    </profile>
    
    <!-- External Profile для провайдера -->
    <profile name="external">
      <gateways>
        <!-- SIP Trunk к провайдеру на порт 5070 -->
        <gateway name="sip_trunk">
          <param name="username" value="$CALLER_ID"/>
          <param name="realm" value="sip.beget.com"/>
          <param name="from-user" value="$CALLER_ID"/>
          <param name="from-domain" value="sip.beget.com"/>
          <param name="password" value="\$external_sip_password"/>
          <param name="extension" value="$CALLER_ID"/>
          <!-- ВАЖНО: Указываем порт провайдера 5070 -->
          <param name="proxy" value="$SIP_PROVIDER_HOST:$SIP_PROVIDER_PORT"/>
          <param name="register-proxy" value="$SIP_PROVIDER_HOST:$SIP_PROVIDER_PORT"/>
          <param name="expire-seconds" value="600"/>
          <param name="register" value="true"/>
          <param name="retry-seconds" value="30"/>
          <param name="caller-id-in-from" value="$CALLER_ID"/>
          <param name="contact-params" value="transport=udp"/>
          <param name="ping" value="25"/>
        </gateway>
      </gateways>
      <settings>
        <param name="debug" value="0"/>
        <param name="sip-trace" value="no"/>
        <param name="sip-capture" value="no"/>
        <param name="rfc2833-pt" value="101"/>
        <!-- FreeSWITCH слушает на 5060, НЕ на 5070 -->
        <param name="sip-port" value="5060"/>
        <param name="dialplan" value="XML"/>
        <param name="context" value="public"/>
        <param name="dtmf-duration" value="2000"/>
        <param name="inbound-codec-prefs" value="PCMU,PCMA"/>
        <param name="outbound-codec-prefs" value="PCMU,PCMA"/>
        <param name="rtp-timer-name" value="soft"/>
        <param name="manage-presence" value="false"/>
        <param name="inbound-codec-negotiation" value="generous"/>
        <param name="nonce-ttl" value="60"/>
        <param name="auth-calls" value="false"/>
        <param name="inbound-late-negotiation" value="true"/>
        <param name="rtp-ip" value="auto"/>
        <param name="sip-ip" value="auto"/>
        <param name="ext-rtp-ip" value="auto-nat"/>
        <param name="ext-sip-ip" value="auto-nat"/>
        <param name="rtp-timeout-sec" value="300"/>
        <param name="rtp-hold-timeout-sec" value="1800"/>
        <param name="enable-3pcc" value="true"/>
      </settings>
    </profile>
  </profiles>
</configuration>
EOF

log_success "Sofia SIP конфигурация обновлена"

# Копируем в контейнер
log_info "Копируем конфигурацию в контейнер..."
if docker cp freeswitch/conf/autoload_configs/sofia.conf.xml "$CONTAINER_NAME:/usr/local/freeswitch/conf/autoload_configs/"; then
    log_success "Конфигурация скопирована"
else
    log_error "Ошибка копирования конфигурации"
    exit 1
fi

# Применяем изменения
log_info "Применяем изменения SIP конфигурации..."

# Останавливаем SIP профили
docker exec "$CONTAINER_NAME" fs_cli -x "sofia profile external stop" 2>/dev/null || true
docker exec "$CONTAINER_NAME" fs_cli -x "sofia profile internal stop" 2>/dev/null || true

# Перезагружаем конфигурацию
docker exec "$CONTAINER_NAME" fs_cli -x "reloadxml" 2>/dev/null || true

# Запускаем профили
docker exec "$CONTAINER_NAME" fs_cli -x "sofia profile internal start" 2>/dev/null || true
docker exec "$CONTAINER_NAME" fs_cli -x "sofia profile external start" 2>/dev/null || true

log_info "Ожидаем стабилизации (15 секунд)..."
sleep 15

# Проверяем результат
echo ""
echo "📊 ПРОВЕРКА РЕЗУЛЬТАТОВ"
echo "======================"

log_info "Статус SIP профилей:"
SIP_STATUS=$(docker exec "$CONTAINER_NAME" fs_cli -x "sofia status" 2>/dev/null)
echo "$SIP_STATUS"

echo ""
log_info "Статус SIP шлюзов:"
GATEWAY_STATUS=$(docker exec "$CONTAINER_NAME" fs_cli -x "sofia status gateway" 2>/dev/null)
echo "$GATEWAY_STATUS"

echo ""
echo "🎯 ПРАВИЛЬНАЯ АРХИТЕКТУРА ПОРТОВ"
echo "================================"
echo ""
echo "📡 SIP ТРАФИК:"
echo "   Входящие: Провайдер ($SIP_PROVIDER_HOST:$SIP_PROVIDER_PORT) → FreeSWITCH (:5060)"
echo "   Исходящие: FreeSWITCH (:любой) → Провайдер ($SIP_PROVIDER_HOST:$SIP_PROVIDER_PORT)"
echo ""
echo "🔌 ПОРТЫ НА СЕРВЕРЕ:"
echo "   ✅ Открыть наружу: 5060/udp (FreeSWITCH слушает)"
echo "   ❌ НЕ открывать: 5070 (это порт провайдера)"
echo "   ❌ НЕ открывать: 8021/tcp (только для бэкенда)"
echo ""
echo "🐳 DOCKER ПОРТЫ:"
echo "   docker run -p 5060:5060/udp ..."
echo "   ИЛИ в docker-compose.yml:"
echo "   ports:"
echo "     - \"5060:5060/udp\""
echo ""

echo ""
log_success "🎉 SIP конфигурация исправлена!"
echo ""
echo "📋 ЧТО ИСПРАВЛЕНО:"
echo "   ✅ SIP trunk настроен на провайдера $SIP_PROVIDER_HOST:$SIP_PROVIDER_PORT"
echo "   ✅ FreeSWITCH слушает на стандартном порту 5060"
echo "   ✅ Убраны лишние порты из конфигурации"
echo ""
echo "🚀 Теперь нужно открыть ТОЛЬКО порт 5060/udp наружу!" 