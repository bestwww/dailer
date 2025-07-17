#!/bin/bash

# Настройка Caller ID для SIP транка
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

echo "📞 НАСТРОЙКА CALLER ID ДЛЯ SIP ТРАНКА"
echo

# Параметры
CALLER_ID_NUMBER="${1}"
CALLER_ID_NAME="${2:-AutoDialer}"

if [ -z "$CALLER_ID_NUMBER" ]; then
    echo "📋 ИСПОЛЬЗОВАНИЕ:"
    echo "  $0 <номер> [имя]"
    echo
    echo "📞 ПРИМЕРЫ:"
    echo "  $0 +79001234567 \"Company Name\""
    echo "  $0 79001234567"
    echo "  $0 +79001234567"
    echo
    echo "ℹ️  ВАЖНО: Используйте номер, выделенный вам SIP провайдером!"
    echo
    echo "📋 ТЕКУЩАЯ КОНФИГУРАЦИЯ:"
    if [ -f "freeswitch/conf/vars.xml" ]; then
        echo "Текущий Caller ID Number:"
        grep "outbound_caller_id_number" freeswitch/conf/vars.xml || echo "  (не найден)"
        echo "Текущий Caller ID Name:"
        grep "outbound_caller_id_name" freeswitch/conf/vars.xml || echo "  (не найден)"
    fi
    exit 1
fi

# Нормализация номера
NORMALIZED_NUMBER="$CALLER_ID_NUMBER"
if [[ ! "$NORMALIZED_NUMBER" =~ ^\+ ]]; then
    if [[ "$NORMALIZED_NUMBER" =~ ^7[0-9]{10}$ ]]; then
        NORMALIZED_NUMBER="+$NORMALIZED_NUMBER"
    elif [[ "$NORMALIZED_NUMBER" =~ ^8[0-9]{10}$ ]]; then
        NORMALIZED_NUMBER="+7${NORMALIZED_NUMBER:1}"
    fi
fi

log_info "📞 Настройка Caller ID:"
log_info "  Номер: $NORMALIZED_NUMBER"
log_info "  Имя: $CALLER_ID_NAME"

# Шаг 1: Резервная копия
log_info "💾 Создание резервной копии..."
if [ -f "freeswitch/conf/vars.xml" ]; then
    cp "freeswitch/conf/vars.xml" "freeswitch/conf/vars.xml.backup.$(date +%s)"
    log_success "✅ Резервная копия создана"
fi

# Шаг 2: Обновление vars.xml
log_info "📝 Обновление freeswitch/conf/vars.xml..."

# Замена или добавление настроек Caller ID
if [ -f "freeswitch/conf/vars.xml" ]; then
    # Замена существующих настроек
    sed -i.tmp "s|<X-PRE-PROCESS cmd=\"set\" data=\"outbound_caller_id_number=.*\"/>|<X-PRE-PROCESS cmd=\"set\" data=\"outbound_caller_id_number=$NORMALIZED_NUMBER\"/>|g" freeswitch/conf/vars.xml
    sed -i.tmp "s|<X-PRE-PROCESS cmd=\"set\" data=\"outbound_caller_id_name=.*\"/>|<X-PRE-PROCESS cmd=\"set\" data=\"outbound_caller_id_name=$CALLER_ID_NAME\"/>|g" freeswitch/conf/vars.xml
    rm -f freeswitch/conf/vars.xml.tmp
else
    log_error "❌ Файл vars.xml не найден"
    exit 1
fi

log_success "✅ vars.xml обновлен"

# Шаг 3: Обновление sofia.conf.xml для корректной передачи Caller ID
log_info "📝 Обновление sofia.conf.xml для правильной передачи Caller ID..."

# Создание обновленной конфигурации Sofia с правильным Caller ID
cat > freeswitch/conf/autoload_configs/sofia.conf.xml << EOF
<configuration name="sofia.conf" description="sofia Endpoint">
  <global_settings>
    <param name="log-level" value="0"/>
    <param name="auto-restart" value="false"/>
    <param name="debug-presence" value="0"/>
  </global_settings>

  <profiles>
    <!-- Профиль external для исходящих звонков через SIP транк -->
    <profile name="external">
      <aliases>
      </aliases>
      <gateways>
        <!-- SIP транк к провайдеру с правильным Caller ID -->
        <gateway name="sip_trunk">
          <param name="proxy" value="62.141.121.197:5070"/>
          <param name="register" value="false"/>
          <param name="username" value="FreeSWITCH"/>
          <param name="password" value=""/>
          <param name="extension" value="FreeSWITCH"/>
          <param name="realm" value="62.141.121.197"/>
          <!-- Настройки Caller ID -->
          <param name="from-user" value="$NORMALIZED_NUMBER"/>
          <param name="from-domain" value="62.141.121.197"/>
          <param name="caller-id-in-from" value="true"/>
          <param name="expire-seconds" value="3600"/>
          <param name="register-transport" value="udp"/>
          <param name="retry-seconds" value="30"/>
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
        <param name="hold-music" value="\$\${hold_music}"/>
        <param name="apply-nat-acl" value="nat.auto"/>
        <param name="extended-info-parsing" value="true"/>
        <param name="aggressive-nat-detection" value="true"/>
        <param name="enable-timer" value="false"/>
        <param name="enable-100rel" value="true"/>
        <param name="minimum-session-expires" value="120"/>
        <param name="apply-inbound-acl" value="domains"/>
        <param name="record-path" value="\$\${recordings_dir}"/>
        <param name="record-template" value="\$\${base_dir}/recordings/\${caller_id_number}.\${target_domain}.\${strftime(%Y-%m-%d-%H-%M-%S)}.wav"/>
        <param name="manage-presence" value="false"/>
        <param name="presence-hosts" value="\$\${domain}"/>
        <param name="presence-privacy" value="\$\${presence_privacy}"/>
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

log_success "✅ sofia.conf.xml обновлен"

# Шаг 4: Проверка контейнера и перезапуск
FREESWITCH_CONTAINER="dialer_freeswitch_host"

if docker ps --filter "name=$FREESWITCH_CONTAINER" --filter "status=running" | grep -q "$FREESWITCH_CONTAINER"; then
    log_info "🔄 Перезапуск FreeSWITCH для применения изменений..."
    
    # Перезагрузка конфигурации
    docker exec "$FREESWITCH_CONTAINER" fs_cli -x "reloadxml" >/dev/null 2>&1 || true
    docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia profile external restart" >/dev/null 2>&1 || true
    
    sleep 5
    
    # Проверка статуса
    GATEWAY_STATUS=$(docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia status gateway sip_trunk" 2>/dev/null | grep "Status" | awk '{print $2}' || echo "UNKNOWN")
    log_info "Статус gateway после обновления: $GATEWAY_STATUS"
    
    log_success "✅ FreeSWITCH перезапущен"
else
    log_warn "⚠️ FreeSWITCH контейнер не запущен"
    log_info "Для применения изменений запустите: ./manage-freeswitch-host.sh restart"
fi

# Шаг 5: Итоговая информация
echo
echo "📋 НАСТРОЙКА ЗАВЕРШЕНА!"
echo "📞 Caller ID Number: $NORMALIZED_NUMBER"
echo "📝 Caller ID Name: $CALLER_ID_NAME"
echo
echo "🧪 ДЛЯ ТЕСТИРОВАНИЯ:"
echo "  ./quick-call-test.sh номер"
echo "  ./test-sip-trunk.sh call номер"
echo
echo "ℹ️  ВАЖНО:"
echo "  Убедитесь что номер $NORMALIZED_NUMBER выделен вам SIP провайдером!"
echo "  Если звонки все еще не проходят, обратитесь к провайдеру для:"
echo "  - Подтверждения авторизации номера"
echo "  - Получения логина/пароля (если требуется)"
echo "  - Уточнения формата номера"
echo
echo "📞 Для проверки настроек Caller ID:"
echo "  grep caller_id freeswitch/conf/vars.xml" 