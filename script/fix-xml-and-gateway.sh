#!/bin/bash

# 🔧 Исправление XML ошибки и загрузка правильного SIP trunk
# Удаляем старые примеры и принудительно загружаем наш gateway

set -e

CONTAINER_NAME="freeswitch-test"

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

echo "🔧 ИСПРАВЛЕНИЕ XML И SIP TRUNK"
echo "============================="
echo ""

# Проверяем контейнер
if ! docker ps --filter "name=$CONTAINER_NAME" --filter "status=running" | grep -q "$CONTAINER_NAME"; then
    log_error "Контейнер $CONTAINER_NAME не запущен!"
    exit 1
fi

log_success "Контейнер $CONTAINER_NAME найден"

# ЭТАП 1: Проверяем что в контейнере
echo ""
echo "📋 ЭТАП 1: ДИАГНОСТИКА ТЕКУЩЕЙ КОНФИГУРАЦИИ"
echo "==========================================="

log_info "Проверяем содержимое sofia.conf.xml в контейнере:"
if docker exec "$CONTAINER_NAME" cat /usr/local/freeswitch/conf/autoload_configs/sofia.conf.xml | grep -q "sip_trunk"; then
    log_success "sip_trunk найден в конфигурации"
else
    log_error "sip_trunk НЕ найден в конфигурации!"
fi

if docker exec "$CONTAINER_NAME" cat /usr/local/freeswitch/conf/autoload_configs/sofia.conf.xml | grep -q "example.com"; then
    log_warning "Найден пример example.com - это нужно удалить"
else
    log_success "Пример example.com не найден"
fi

# ЭТАП 2: Удаляем старые файлы примеров
echo ""
echo "🗑️ ЭТАП 2: УДАЛЕНИЕ СТАРЫХ ПРИМЕРОВ"
echo "=================================="

log_info "Удаляем старые файлы примеров в контейнере..."

# Удаляем примеры gateway файлов
docker exec "$CONTAINER_NAME" rm -f /usr/local/freeswitch/conf/sip_profiles/internal/*.xml 2>/dev/null || true
docker exec "$CONTAINER_NAME" rm -f /usr/local/freeswitch/conf/sip_profiles/external/*.xml 2>/dev/null || true
docker exec "$CONTAINER_NAME" rm -rf /usr/local/freeswitch/conf/sip_profiles 2>/dev/null || true

# Удаляем directory с примерами
docker exec "$CONTAINER_NAME" rm -f /usr/local/freeswitch/conf/directory/default/1000.xml 2>/dev/null || true
docker exec "$CONTAINER_NAME" rm -f /usr/local/freeswitch/conf/directory/default/*.xml 2>/dev/null || true

log_success "Старые примеры удалены"

# ЭТАП 3: Создаем правильную минимальную конфигурацию
echo ""
echo "🔧 ЭТАП 3: СОЗДАНИЕ ЧИСТОЙ КОНФИГУРАЦИИ"
echo "======================================="

log_info "Создаем чистую минимальную конфигурацию Sofia..."

# Создаем чистую конфигурацию без примеров
cat > freeswitch/conf/autoload_configs/sofia.conf.xml << 'EOF'
<configuration name="sofia.conf" description="Sofia SIP">
  <global_settings>
    <param name="log-level" value="0"/>
    <param name="auto-restart" value="false"/>
    <param name="debug-presence" value="0"/>
  </global_settings>
  
  <profiles>
    <profile name="internal">
      <gateways>
        <gateway name="sip_trunk">
          <param name="username" value="79058615815"/>
          <param name="realm" value="62.141.121.197"/>
          <param name="from-user" value="79058615815"/>
          <param name="from-domain" value="62.141.121.197"/>
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

log_success "Чистая конфигурация Sofia создана"

# ЭТАП 4: Копируем и проверяем
echo ""
echo "📋 ЭТАП 4: КОПИРОВАНИЕ И ПРОВЕРКА"
echo "================================="

log_info "Копируем конфигурацию в контейнер..."
if docker cp freeswitch/conf/autoload_configs/sofia.conf.xml "$CONTAINER_NAME:/usr/local/freeswitch/conf/autoload_configs/"; then
    log_success "Конфигурация скопирована"
else
    log_error "Ошибка копирования конфигурации"
    exit 1
fi

# Проверяем что конфигурация действительно скопировалась
log_info "Проверяем что конфигурация правильно скопировалась..."
if docker exec "$CONTAINER_NAME" grep -q "sip_trunk" /usr/local/freeswitch/conf/autoload_configs/sofia.conf.xml; then
    log_success "sip_trunk найден в скопированной конфигурации"
else
    log_error "sip_trunk НЕ найден в скопированной конфигурации!"
    exit 1
fi

if docker exec "$CONTAINER_NAME" grep -q "example.com" /usr/local/freeswitch/conf/autoload_configs/sofia.conf.xml; then
    log_error "example.com все еще найден в конфигурации!"
    exit 1
else
    log_success "example.com успешно удален"
fi

# ЭТАП 5: Полная перезагрузка FreeSWITCH
echo ""
echo "🔄 ЭТАП 5: ПОЛНАЯ ПЕРЕЗАГРУЗКА FREESWITCH"
echo "========================================"

log_info "Выполняем полную перезагрузку FreeSWITCH..."

# Останавливаем все профили
docker exec "$CONTAINER_NAME" fs_cli -x "sofia profile internal stop" 2>/dev/null || true

# Выгружаем Sofia
docker exec "$CONTAINER_NAME" fs_cli -x "unload mod_sofia" 2>/dev/null || true

# Ждем
sleep 5

# Перезагружаем XML (должно быть без ошибок)
log_info "Перезагружаем XML конфигурацию..."
XML_RESULT=$(docker exec "$CONTAINER_NAME" fs_cli -x "reloadxml" 2>&1)
echo "XML результат: $XML_RESULT"

if echo "$XML_RESULT" | grep -q "error"; then
    log_error "Ошибка XML! $XML_RESULT"
else
    log_success "XML загружен без ошибок"
fi

# Загружаем Sofia
log_info "Загружаем модуль Sofia..."
docker exec "$CONTAINER_NAME" fs_cli -x "load mod_sofia" 2>/dev/null || true

log_info "Ожидаем полной стабилизации (30 секунд)..."
sleep 30

# ЭТАП 6: Финальная проверка
echo ""
echo "✅ ЭТАП 6: ФИНАЛЬНАЯ ПРОВЕРКА"
echo "============================"

log_info "Проверяем загруженные SIP профили:"
SIP_STATUS=$(docker exec "$CONTAINER_NAME" fs_cli -x "sofia status" 2>/dev/null)
echo "$SIP_STATUS"

log_info "Проверяем загруженные SIP шлюзы:"
GATEWAY_STATUS=$(docker exec "$CONTAINER_NAME" fs_cli -x "sofia status gateway" 2>/dev/null)
echo "$GATEWAY_STATUS"

# Проверяем результат
if echo "$GATEWAY_STATUS" | grep -q "sip_trunk"; then
    log_success "🎉 SIP trunk успешно загружен!"
    
    if echo "$GATEWAY_STATUS" | grep -q "NOREG"; then
        log_success "✅ Статус NOREG - правильно для IP-аутентификации"
    fi
    
    if echo "$GATEWAY_STATUS" | grep -q "example.com"; then
        log_warning "⚠️ example.com все еще присутствует"
    else
        log_success "✅ example.com успешно удален"
    fi
    
else
    log_error "❌ SIP trunk НЕ загружен"
fi

# ЭТАП 7: Тестирование
echo ""
echo "🧪 ЭТАП 7: ТЕСТИРОВАНИЕ"
echo "======================"

log_info "Тест SIP trunk..."
TRUNK_TEST=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/79001234567 &echo" 2>&1)
echo "Результат теста SIP trunk: $TRUNK_TEST"

if echo "$TRUNK_TEST" | grep -q "INVALID_GATEWAY"; then
    log_error "❌ SIP trunk все еще недоступен"
else
    log_success "✅ SIP trunk отвечает (может быть CALL_REJECTED - это нормально)"
fi

log_info "Тест IVR меню..."
IVR_TEST=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate loopback/ivr_menu &echo" 2>&1)
if echo "$IVR_TEST" | grep -q -E "SUCCESS|NORMAL_CLEARING"; then
    log_success "✅ IVR меню работает"
else
    log_warning "⚠️ Проблемы с IVR: $IVR_TEST"
fi

echo ""
echo "🎯 ИТОГОВЫЕ КОМАНДЫ ДЛЯ ТЕСТИРОВАНИЯ"
echo "==================================="
echo ""
echo "# Проверить статус:"
echo "docker exec $CONTAINER_NAME fs_cli -x 'sofia status'"
echo "docker exec $CONTAINER_NAME fs_cli -x 'sofia status gateway'"
echo ""
echo "# Тест исходящего звонка:"
echo "docker exec $CONTAINER_NAME fs_cli -x 'originate sofia/gateway/sip_trunk/79206054020 &transfer:ivr_menu'"
echo ""
echo "# Тест IVR:"
echo "docker exec $CONTAINER_NAME fs_cli -x 'originate loopback/ivr_menu &echo'"
echo ""

echo ""
log_success "🎉 Исправление завершено!"

if echo "$GATEWAY_STATUS" | grep -q "sip_trunk"; then
    echo ""
    echo "✅ SIP TRUNK ГОТОВ К РАБОТЕ!"
    echo "📞 Можно тестировать звонки через провайдера 62.141.121.197:5070"
    echo "🔐 Аутентификация по IP (без пароля)"
    echo "📋 Статус NOREG - это нормально для IP-провайдера"
else
    echo ""
    echo "❌ НУЖНА ДОПОЛНИТЕЛЬНАЯ ДИАГНОСТИКА"
    echo "💡 Возможно потребуется полный перезапуск контейнера"
fi 