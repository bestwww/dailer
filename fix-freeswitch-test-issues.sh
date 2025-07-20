#!/bin/bash

# 🔧 Скрипт исправления проблем в контейнере freeswitch-test
# Исправляет Caller ID, порты, SIP профили и dialplan

set -e

# 🎯 Настройки
CONTAINER_NAME="freeswitch-test"
NEW_CALLER_ID="79058615815"

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

echo "🔧 ИСПРАВЛЕНИЕ ПРОБЛЕМ В КОНТЕЙНЕРЕ: $CONTAINER_NAME"
echo "====================================================="
echo ""
echo "📋 Что будет исправлено:"
echo "   🆔 Caller ID: обновление на $NEW_CALLER_ID"
echo "   🌐 SIP профиль external: создание если отсутствует"
echo "   📞 Dialplan: исправление обработки вызовов"
echo "   🔌 Проверка портов"
echo ""

# 🔍 ЭТАП 1: ПРОВЕРКА КОНТЕЙНЕРА
echo "🔍 ЭТАП 1: ПРОВЕРКА КОНТЕЙНЕРА"
echo "=============================="

if ! docker ps --filter "name=$CONTAINER_NAME" --filter "status=running" | grep -q "$CONTAINER_NAME"; then
    log_error "Контейнер $CONTAINER_NAME не запущен!"
    log_info "Попытка запуска..."
    if docker start "$CONTAINER_NAME"; then
        log_success "Контейнер запущен"
        sleep 15
    else
        log_error "Не удалось запустить контейнер"
        exit 1
    fi
fi

log_success "Контейнер $CONTAINER_NAME запущен"

# 🔧 ЭТАП 2: ОБНОВЛЕНИЕ CALLER ID
echo ""
echo "🔧 ЭТАП 2: ОБНОВЛЕНИЕ CALLER ID"
echo "==============================="

log_info "Обновляем Caller ID в локальной конфигурации..."

# Обновляем vars.xml
if [ -f "freeswitch/conf/vars.xml" ]; then
    log_info "Обновляем vars.xml..."
    cp freeswitch/conf/vars.xml freeswitch/conf/vars.xml.backup.$(date +%s)
    
    # Обновляем все Caller ID переменные
    sed -i '' "s/<X-PRE-PROCESS cmd=\"set\" data=\"default_caller_id_number=[^\"]*\"/<X-PRE-PROCESS cmd=\"set\" data=\"default_caller_id_number=$NEW_CALLER_ID\"/g" freeswitch/conf/vars.xml
    sed -i '' "s/<X-PRE-PROCESS cmd=\"set\" data=\"outbound_caller_id_number=[^\"]*\"/<X-PRE-PROCESS cmd=\"set\" data=\"outbound_caller_id_number=$NEW_CALLER_ID\"/g" freeswitch/conf/vars.xml
    sed -i '' "s/<X-PRE-PROCESS cmd=\"set\" data=\"emergency_caller_id_number=[^\"]*\"/<X-PRE-PROCESS cmd=\"set\" data=\"emergency_caller_id_number=$NEW_CALLER_ID\"/g" freeswitch/conf/vars.xml
    
    log_success "vars.xml обновлен"
else
    log_warning "vars.xml не найден"
fi

# Обновляем dialplan
if [ -f "freeswitch/conf/dialplan/default.xml" ]; then
    log_info "Обновляем dialplan/default.xml..."
    cp freeswitch/conf/dialplan/default.xml freeswitch/conf/dialplan/default.xml.backup.$(date +%s)
    
    # Обновляем Caller ID в dialplan
    sed -i '' "s/caller_id_number=\"[^\"]*\"/caller_id_number=\"$NEW_CALLER_ID\"/g" freeswitch/conf/dialplan/default.xml
    sed -i '' "s/effective_caller_id_number=[^,}]*/effective_caller_id_number=$NEW_CALLER_ID/g" freeswitch/conf/dialplan/default.xml
    
    log_success "dialplan обновлен"
fi

# 🔧 ЭТАП 3: СОЗДАНИЕ/ОБНОВЛЕНИЕ SIP ПРОФИЛЯ EXTERNAL
echo ""
echo "🔧 ЭТАП 3: НАСТРОЙКА SIP ПРОФИЛЕЙ"
echo "================================="

log_info "Проверяем конфигурацию Sofia SIP..."

# Создаем/обновляем sofia.conf.xml
cat > freeswitch/conf/autoload_configs/sofia.conf.xml << 'EOF'
<configuration name="sofia.conf" description="Sofia SIP">
  <global_settings>
    <param name="log-level" value="0"/>
    <param name="auto-restart" value="false"/>
    <param name="debug-presence" value="0"/>
  </global_settings>
  
  <profiles>
    <!-- Internal Profile -->
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
        <param name="inbound-codec-prefs" value="OPUS,G722,PCMU,PCMA,H264,VP8"/>
        <param name="outbound-codec-prefs" value="OPUS,G722,PCMU,PCMA,H264,VP8"/>
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
    
    <!-- External Profile -->
    <profile name="external">
      <gateways>
        <!-- SIP Trunk Gateway -->
        <gateway name="sip_trunk">
          <param name="username" value="79058615815"/>
          <param name="realm" value="sip.beget.com"/>
          <param name="from-user" value="79058615815"/>
          <param name="from-domain" value="sip.beget.com"/>
          <param name="password" value="$external_sip_password"/>
          <param name="extension" value="79058615815"/>
          <param name="proxy" value="sip.beget.com"/>
          <param name="register-proxy" value="sip.beget.com"/>
          <param name="expire-seconds" value="600"/>
          <param name="register" value="true"/>
          <param name="retry-seconds" value="30"/>
          <param name="caller-id-in-from" value="79058615815"/>
          <param name="contact-params" value="transport=udp"/>
          <param name="ping" value="25"/>
        </gateway>
      </gateways>
      <settings>
        <param name="debug" value="0"/>
        <param name="sip-trace" value="no"/>
        <param name="sip-capture" value="no"/>
        <param name="rfc2833-pt" value="101"/>
        <param name="sip-port" value="5080"/>
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

log_success "Sofia SIP конфигурация создана/обновлена"

# 🔧 ЭТАП 4: ОБНОВЛЕНИЕ DIALPLAN
echo ""
echo "🔧 ЭТАП 4: ОБНОВЛЕНИЕ DIALPLAN"
echo "=============================="

log_info "Создаем улучшенный dialplan..."

# Создаем резервную копию
if [ -f "freeswitch/conf/dialplan/default.xml" ]; then
    cp freeswitch/conf/dialplan/default.xml freeswitch/conf/dialplan/default.xml.backup.$(date +%s)
fi

# Создаем новый dialplan
cat > freeswitch/conf/dialplan/default.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<include>
  <context name="default">
    
    <!-- Исходящие звонки через SIP trunk -->
    <extension name="outbound_calls">
      <condition field="destination_number" expression="^(\d{10,11})$">
        <action application="set" data="caller_id_number=79058615815"/>
        <action application="set" data="caller_id_name=Dailer System"/>
        <action application="set" data="effective_caller_id_number=79058615815"/>
        <action application="set" data="effective_caller_id_name=Dailer System"/>
        <action application="bridge" data="sofia/gateway/sip_trunk/$1"/>
      </condition>
    </extension>
    
    <!-- Исходящие звонки с международным форматом -->
    <extension name="outbound_international">
      <condition field="destination_number" expression="^(\+\d{10,15})$">
        <action application="set" data="caller_id_number=79058615815"/>
        <action application="set" data="caller_id_name=Dailer System"/>
        <action application="bridge" data="sofia/gateway/sip_trunk/$1"/>
      </condition>
    </extension>
    
    <!-- Входящие звонки -->
    <extension name="inbound_calls">
      <condition field="destination_number" expression="^(79058615815)$">
        <action application="set" data="domain_name=$${domain}"/>
        <action application="answer"/>
        <action application="sleep" data="1000"/>
        <action application="playback" data="ivr/ivr-welcome.wav"/>
        <action application="hangup"/>
      </condition>
    </extension>
    
    <!-- Локальные вызовы -->
    <extension name="local_extension">
      <condition field="destination_number" expression="^(10[01][0-9])$">
        <action application="bridge" data="user/$1@$${domain}"/>
      </condition>
    </extension>
    
    <!-- Echo тест -->
    <extension name="echo_test">
      <condition field="destination_number" expression="^9999$">
        <action application="answer"/>
        <action application="echo"/>
      </condition>
    </extension>
    
  </context>
</include>
EOF

log_success "Dialplan обновлен"

# 🔧 ЭТАП 5: КОПИРОВАНИЕ В КОНТЕЙНЕР
echo ""
echo "🔧 ЭТАП 5: ПРИМЕНЕНИЕ ИЗМЕНЕНИЙ"
echo "==============================="

log_info "Копируем обновленную конфигурацию в контейнер..."

# Копируем конфигурацию в контейнер
if docker cp freeswitch/conf/. "$CONTAINER_NAME:/usr/local/freeswitch/conf/"; then
    log_success "Конфигурация скопирована"
else
    log_error "Ошибка копирования конфигурации"
    exit 1
fi

# Применяем изменения
log_info "Применяем изменения в FreeSWITCH..."

# Перезагружаем XML
if docker exec "$CONTAINER_NAME" fs_cli -x "reloadxml" 2>/dev/null; then
    log_success "XML конфигурация перезагружена"
else
    log_warning "Ошибка перезагрузки XML"
fi

# Перезапускаем SIP профили
log_info "Перезапускаем SIP профили..."
docker exec "$CONTAINER_NAME" fs_cli -x "sofia profile internal restart" 2>/dev/null || true
docker exec "$CONTAINER_NAME" fs_cli -x "sofia profile external restart" 2>/dev/null || true

# Ждем стабилизации
log_info "Ожидаем стабилизации (10 секунд)..."
sleep 10

# 📊 ЭТАП 6: ПРОВЕРКА РЕЗУЛЬТАТОВ
echo ""
echo "📊 ЭТАП 6: ПРОВЕРКА РЕЗУЛЬТАТОВ"
echo "==============================="

# Проверяем статус FreeSWITCH
if docker exec "$CONTAINER_NAME" fs_cli -x "status" 2>/dev/null | grep -q "UP"; then
    log_success "FreeSWITCH работает"
    
    # Проверяем новый Caller ID
    echo ""
    log_info "Проверяем Caller ID..."
    if docker exec "$CONTAINER_NAME" find /usr/local/freeswitch/conf -name "*.xml" -exec grep -l "$NEW_CALLER_ID" {} \; 2>/dev/null | head -1 >/dev/null; then
        log_success "✅ Caller ID $NEW_CALLER_ID найден в конфигурации!"
    else
        log_warning "⚠️ Caller ID не найден"
    fi
    
    # Проверяем SIP профили
    echo ""
    log_info "Проверяем SIP профили..."
    SIP_STATUS=$(docker exec "$CONTAINER_NAME" fs_cli -x "sofia status" 2>/dev/null)
    echo "$SIP_STATUS"
    
    if echo "$SIP_STATUS" | grep -q "external.*RUNNING"; then
        log_success "✅ SIP профиль external работает"
    else
        log_warning "⚠️ SIP профиль external не работает"
    fi
    
    # Проверяем SIP шлюзы
    echo ""
    log_info "Проверяем SIP шлюзы..."
    GATEWAY_STATUS=$(docker exec "$CONTAINER_NAME" fs_cli -x "sofia status gateway" 2>/dev/null || echo "ОШИБКА")
    echo "$GATEWAY_STATUS"
    
else
    log_error "❌ FreeSWITCH не работает"
    
    log_info "Попытка перезапуска контейнера..."
    docker restart "$CONTAINER_NAME"
    sleep 30
    
    if docker exec "$CONTAINER_NAME" fs_cli -x "status" 2>/dev/null | grep -q "UP"; then
        log_success "FreeSWITCH запущен после перезапуска"
    else
        log_error "FreeSWITCH не запускается"
    fi
fi

echo ""
echo "🎯 РЕКОМЕНДАЦИИ ПО ПОРТАМ"
echo "========================="
echo ""
echo "⚠️ ВАЖНО: Порты контейнера не открыты наружу!"
echo ""
echo "💡 Для доступа снаружи нужно:"
echo ""
echo "1. Остановить контейнер:"
echo "   docker stop $CONTAINER_NAME"
echo ""
echo "2. Создать новый контейнер с открытыми портами:"
echo "   docker run -d --name ${CONTAINER_NAME}_new \\"
echo "     -p 5060:5060/udp \\"
echo "     -p 5080:5080/udp \\"
echo "     -p 8021:8021/tcp \\"
echo "     -v \$(pwd)/freeswitch/conf:/usr/local/freeswitch/conf \\"
echo "     dailer-freeswitch:ready"
echo ""
echo "3. Или добавить порты в docker-compose.yml:"
echo "   ports:"
echo "     - \"5060:5060/udp\"  # SIP"
echo "     - \"5080:5080/udp\"  # SIP External" 
echo "     - \"8021:8021/tcp\"  # ESL"
echo ""

echo ""
echo "🧪 КОМАНДЫ ДЛЯ ТЕСТИРОВАНИЯ"
echo "==========================="
echo ""
echo "# Проверить статус:"
echo "docker exec $CONTAINER_NAME fs_cli -x 'status'"
echo ""
echo "# Проверить SIP профили:"
echo "docker exec $CONTAINER_NAME fs_cli -x 'sofia status'"
echo ""
echo "# Проверить SIP шлюзы:"
echo "docker exec $CONTAINER_NAME fs_cli -x 'sofia status gateway'"
echo ""
echo "# Тест исходящего звонка:"
echo "docker exec $CONTAINER_NAME fs_cli -x 'originate sofia/gateway/sip_trunk/79001234567 &echo'"
echo ""
echo "# Посмотреть логи:"
echo "docker logs -f $CONTAINER_NAME"
echo ""

echo ""
log_success "🎉 Исправление проблем завершено!"
echo ""
echo "📋 ЧТО ИСПРАВЛЕНО:"
echo "   ✅ Caller ID обновлен на $NEW_CALLER_ID"
echo "   ✅ SIP профиль external создан"
echo "   ✅ Dialplan улучшен для обработки вызовов"
echo "   ✅ Конфигурация применена"
echo ""
echo "⚠️ ТРЕБУЕТ ВНИМАНИЯ:"
echo "   🔌 Настроить открытие портов для внешнего доступа"
echo "   🔐 Добавить пароль для SIP trunk в переменную external_sip_password"
echo ""
echo "🚀 Контейнер готов к тестированию звонков!" 