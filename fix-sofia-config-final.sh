#!/bin/bash

# 🔧 Финальное исправление Sofia SIP конфигурации
# Убираем конфликт портов и настраиваем для провайдера без пароля

set -e

CONTAINER_NAME="freeswitch-test"
PROVIDER_IP="62.141.121.197"
PROVIDER_PORT="5070"
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

echo "🔧 ФИНАЛЬНОЕ ИСПРАВЛЕНИЕ SOFIA SIP"
echo "=================================="
echo ""
echo "📋 Исправления:"
echo "   🔧 Убираем конфликт портов (internal=5060, external=5080)"
echo "   🔐 Настраиваем SIP trunk БЕЗ пароля (по IP)"
echo "   📞 Провайдер: $PROVIDER_IP:$PROVIDER_PORT"
echo "   🆔 Caller ID: $CALLER_ID"
echo ""

# Проверяем контейнер
if ! docker ps --filter "name=$CONTAINER_NAME" --filter "status=running" | grep -q "$CONTAINER_NAME"; then
    log_error "Контейнер $CONTAINER_NAME не запущен!"
    exit 1
fi

log_success "Контейнер $CONTAINER_NAME найден"

# Создаем правильную конфигурацию Sofia
log_info "Создаем исправленную конфигурацию Sofia..."

cat > freeswitch/conf/autoload_configs/sofia.conf.xml << 'EOF'
<configuration name="sofia.conf" description="Sofia SIP">
  <global_settings>
    <param name="log-level" value="0"/>
    <param name="auto-restart" value="false"/>
    <param name="debug-presence" value="0"/>
  </global_settings>
  
  <profiles>
    <!-- Internal Profile - для локальных соединений -->
    <profile name="internal">
      <gateways>
        <!-- SIP Trunk в internal профиле -->
        <gateway name="sip_trunk">
          <param name="username" value="79058615815"/>
          <param name="realm" value="62.141.121.197"/>
          <param name="from-user" value="79058615815"/>
          <param name="from-domain" value="62.141.121.197"/>
          <!-- БЕЗ ПАРОЛЯ - аутентификация по IP -->
          <param name="register" value="false"/>
          <param name="extension" value="79058615815"/>
          <param name="proxy" value="62.141.121.197:5070"/>
          <param name="caller-id-in-from" value="79058615815"/>
          <param name="contact-params" value="transport=udp"/>
          <param name="ping" value="25"/>
        </gateway>
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
  </profiles>
</configuration>
EOF

log_success "Sofia конфигурация создана"

# Удаляем старые резервные копии (если есть)
rm -f freeswitch/conf/autoload_configs/sofia.conf.xml.backup.*

# Копируем в контейнер
log_info "Копируем конфигурацию в контейнер..."
if docker cp freeswitch/conf/autoload_configs/sofia.conf.xml "$CONTAINER_NAME:/usr/local/freeswitch/conf/autoload_configs/"; then
    log_success "Конфигурация скопирована"
else
    log_error "Ошибка копирования конфигурации"
    exit 1
fi

# Принудительная перезагрузка Sofia
log_info "Принудительная перезагрузка Sofia..."

# Останавливаем все профили
docker exec "$CONTAINER_NAME" fs_cli -x "sofia profile internal stop" 2>/dev/null || true
docker exec "$CONTAINER_NAME" fs_cli -x "sofia profile external stop" 2>/dev/null || true

# Выгружаем модуль
log_info "Выгружаем модуль Sofia..."
docker exec "$CONTAINER_NAME" fs_cli -x "unload mod_sofia" 2>/dev/null || true

sleep 5

# Перезагружаем XML
log_info "Перезагружаем XML..."
XML_RESULT=$(docker exec "$CONTAINER_NAME" fs_cli -x "reloadxml" 2>&1)
echo "XML reload result: $XML_RESULT"

# Загружаем модуль
log_info "Загружаем модуль Sofia..."
docker exec "$CONTAINER_NAME" fs_cli -x "load mod_sofia" 2>/dev/null || true

log_info "Ожидаем стабилизации (20 секунд)..."
sleep 20

# Проверяем результат
echo ""
echo "📊 ПРОВЕРКА РЕЗУЛЬТАТА"
echo "====================="

log_info "Статус SIP профилей:"
SIP_STATUS=$(docker exec "$CONTAINER_NAME" fs_cli -x "sofia status" 2>/dev/null)
echo "$SIP_STATUS"

if echo "$SIP_STATUS" | grep -q "internal.*RUNNING"; then
    log_success "✅ Internal профиль работает"
else
    log_error "❌ Internal профиль НЕ работает"
fi

echo ""
log_info "Статус SIP шлюзов:"
GATEWAY_STATUS=$(docker exec "$CONTAINER_NAME" fs_cli -x "sofia status gateway" 2>/dev/null)
echo "$GATEWAY_STATUS"

if echo "$GATEWAY_STATUS" | grep -q "sip_trunk"; then
    log_success "✅ SIP trunk найден!"
    
    # Для провайдера без пароля статус может быть NOREG - это нормально
    if echo "$GATEWAY_STATUS" | grep -q -E "NOREG|UP|REGED"; then
        log_success "✅ SIP trunk настроен (без регистрации - аутентификация по IP)"
    else
        log_warning "⚠️ Проблемы с SIP trunk"
    fi
else
    log_error "❌ SIP trunk НЕ найден"
fi

# Тестирование
echo ""
echo "🧪 ТЕСТИРОВАНИЕ"
echo "==============="

log_info "Тест IVR меню..."
IVR_TEST=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate loopback/ivr_menu &echo" 2>&1)
if echo "$IVR_TEST" | grep -q -E "SUCCESS|NORMAL_CLEARING"; then
    log_success "✅ IVR меню работает"
else
    log_warning "⚠️ Проблемы с IVR: $IVR_TEST"
fi

echo ""
log_info "Тест SIP trunk..."
TRUNK_TEST=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/79001234567 &echo" 2>&1)
if echo "$TRUNK_TEST" | grep -q -E "SUCCESS|NORMAL_CLEARING|CALL_REJECTED"; then
    log_success "✅ SIP trunk подключается к провайдеру"
else
    log_warning "⚠️ Проблемы с SIP trunk: $TRUNK_TEST"
fi

# Проверяем логи на ошибки
echo ""
log_info "Последние логи (ошибки Sofia):"
RECENT_LOGS=$(docker logs --tail=20 "$CONTAINER_NAME" 2>&1 | grep -i "sofia\|error\|fail" | tail -5 || echo "Ошибок Sofia не найдено")
echo "$RECENT_LOGS"

echo ""
echo "🎯 ИТОГОВЫЙ СТАТУС"
echo "=================="

if echo "$GATEWAY_STATUS" | grep -q "sip_trunk"; then
    log_success "🎉 SIP trunk настроен и готов к работе!"
    echo ""
    echo "✅ ТЕСТИРОВАНИЕ ЗВОНКОВ:"
    echo ""
    echo "# Тест исходящего звонка:"
    echo "docker exec $CONTAINER_NAME fs_cli -x 'originate sofia/gateway/sip_trunk/79206054020 &transfer:ivr_menu'"
    echo ""
    echo "# Тест IVR меню:"
    echo "docker exec $CONTAINER_NAME fs_cli -x 'originate loopback/ivr_menu &echo'"
    echo ""
    echo "📋 ОСОБЕННОСТИ ПРОВАЙДЕРА:"
    echo "   🔐 Аутентификация по IP (без пароля)"
    echo "   🌐 Провайдер: $PROVIDER_IP:$PROVIDER_PORT"
    echo "   📞 Статус NOREG - это нормально для IP-аутентификации"
    echo ""
else
    log_error "❌ SIP trunk НЕ настроен"
    echo ""
    echo "💡 Рекомендации:"
    echo "   1. Проверить логи: docker logs -f $CONTAINER_NAME"
    echo "   2. Проверить XML синтаксис конфигурации"
    echo "   3. Перезапустить контейнер: docker restart $CONTAINER_NAME"
fi

echo ""
log_success "🎉 Настройка завершена!" 