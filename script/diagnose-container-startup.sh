#!/bin/bash

# 🔍 Диагностика проблем запуска контейнера FreeSWITCH
# Проверяем логи и исправляем конфигурацию

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

echo "🔍 ДИАГНОСТИКА ЗАПУСКА FREESWITCH КОНТЕЙНЕРА"
echo "============================================="
echo ""

# ЭТАП 1: Проверяем статус контейнера
echo "📋 ЭТАП 1: СТАТУС КОНТЕЙНЕРА"
echo "============================"

log_info "Проверяем статус контейнера..."
CONTAINER_STATUS=$(docker ps -a --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}")
echo "$CONTAINER_STATUS"

if docker ps --filter "name=$CONTAINER_NAME" --filter "status=running" | grep -q "$CONTAINER_NAME"; then
    log_success "Контейнер запущен"
    exit 0
else
    log_warning "Контейнер НЕ запущен"
fi

# ЭТАП 2: Смотрим логи контейнера
echo ""
echo "📋 ЭТАП 2: ЛОГИ КОНТЕЙНЕРА"
echo "========================="

log_info "Последние логи контейнера:"
echo "----------------------------------------"
docker logs --tail 50 "$CONTAINER_NAME" 2>&1 || true
echo "----------------------------------------"

# ЭТАП 3: Проверяем конфигурацию внутри контейнера
echo ""
echo "📋 ЭТАП 3: ПРОВЕРКА КОНФИГУРАЦИИ"
echo "==============================="

log_info "Проверяем основные конфигурационные файлы..."

# Проверяем основной файл конфигурации
if docker exec "$CONTAINER_NAME" test -f /usr/local/freeswitch/conf/freeswitch.xml 2>/dev/null; then
    log_success "freeswitch.xml найден"
else
    log_error "freeswitch.xml НЕ найден!"
fi

# Проверяем sofia.conf.xml
if docker exec "$CONTAINER_NAME" test -f /usr/local/freeswitch/conf/autoload_configs/sofia.conf.xml 2>/dev/null; then
    log_success "sofia.conf.xml найден"
    
    # Проверяем на синтаксические ошибки
    log_info "Проверяем XML синтаксис sofia.conf.xml..."
    if docker exec "$CONTAINER_NAME" xmllint --noout /usr/local/freeswitch/conf/autoload_configs/sofia.conf.xml 2>/dev/null; then
        log_success "XML синтаксис корректен"
    else
        log_error "XML синтаксис НЕКОРРЕКТЕН!"
        echo "Содержимое файла:"
        docker exec "$CONTAINER_NAME" cat /usr/local/freeswitch/conf/autoload_configs/sofia.conf.xml || true
    fi
else
    log_error "sofia.conf.xml НЕ найден!"
fi

# ЭТАП 4: Попытка запуска FreeSWITCH в debug режиме
echo ""
echo "📋 ЭТАП 4: DEBUG ЗАПУСК"
echo "======================"

log_info "Пытаемся запустить FreeSWITCH в debug режиме..."

# Останавливаем контейнер если он запущен
docker stop "$CONTAINER_NAME" 2>/dev/null || true

# Пытаемся запустить в интерактивном режиме для диагностики
log_info "Запускаем контейнер в debug режиме (10 секунд)..."
timeout 10 docker run --rm --name "${CONTAINER_NAME}-debug" \
    -v "$(pwd)/freeswitch/conf:/usr/local/freeswitch/conf" \
    -v "$(pwd)/audio:/usr/local/freeswitch/sounds" \
    dailer-freeswitch:ready \
    /usr/local/freeswitch/bin/freeswitch -nonat -nonatmap -nf 2>&1 | head -50 || true

# ЭТАП 5: Исправляем базовую конфигурацию
echo ""
echo "🔧 ЭТАП 5: ИСПРАВЛЕНИЕ БАЗОВОЙ КОНФИГУРАЦИИ"
echo "==========================================="

log_info "Создаем минимальную рабочую конфигурацию..."

# Создаем минимальную sofia конфигурацию
cat > freeswitch/conf/autoload_configs/sofia.conf.xml << 'EOF'
<configuration name="sofia.conf" description="Sofia SIP">
  <global_settings>
    <param name="log-level" value="0"/>
    <param name="auto-restart" value="false"/>
    <param name="debug-presence" value="0"/>
  </global_settings>
  
  <profiles>
    <profile name="internal">
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

log_success "Минимальная конфигурация Sofia создана"

# Проверяем что остальные конфигурации на месте
if [ ! -f "freeswitch/conf/freeswitch.xml" ]; then
    log_warning "freeswitch.xml отсутствует, создаем базовый..."
    
    # Создаем базовый freeswitch.xml
    cp docker/freeswitch/conf/freeswitch.xml freeswitch/conf/ 2>/dev/null || \
    cat > freeswitch/conf/freeswitch.xml << 'EOF'
<?xml version="1.0"?>
<document type="freeswitch/xml">
  <X-PRE-PROCESS cmd="set" data="default_password=1234"/>
  <X-PRE-PROCESS cmd="set" data="sound_prefix=/usr/local/freeswitch/sounds/en/us/callie"/>
  
  <section name="configuration" description="Various Configuration">
    <X-PRE-PROCESS cmd="include" data="autoload_configs/*.xml"/>
  </section>
  
  <section name="dialplan" description="Regex/XML Dialplan">
    <X-PRE-PROCESS cmd="include" data="dialplan/*.xml"/>
  </section>
  
  <section name="directory" description="User Directory">
    <X-PRE-PROCESS cmd="include" data="directory/*.xml"/>
  </section>
</document>
EOF
    
    log_success "Базовый freeswitch.xml создан"
fi

# ЭТАП 6: Попытка запуска исправленного контейнера
echo ""
echo "🚀 ЭТАП 6: ЗАПУСК ИСПРАВЛЕННОГО КОНТЕЙНЕРА"
echo "========================================="

log_info "Запускаем контейнер с исправленной конфигурацией..."

# Запускаем контейнер
if docker start "$CONTAINER_NAME"; then
    log_success "Контейнер запущен"
    
    # Ждем стабилизации
    log_info "Ожидаем стабилизации (15 секунд)..."
    sleep 15
    
    # Проверяем статус
    if docker ps --filter "name=$CONTAINER_NAME" --filter "status=running" | grep -q "$CONTAINER_NAME"; then
        log_success "🎉 Контейнер успешно запущен и работает!"
        
        # Проверяем FreeSWITCH
        log_info "Проверяем статус FreeSWITCH..."
        if docker exec "$CONTAINER_NAME" fs_cli -x "status" 2>/dev/null | grep -q "UP"; then
            log_success "✅ FreeSWITCH работает!"
        else
            log_warning "⚠️ FreeSWITCH может еще загружаться..."
        fi
        
        echo ""
        echo "🎯 КОНТЕЙНЕР ГОТОВ!"
        echo "=================="
        echo "Теперь можно выполнить: ./fix-xml-and-gateway.sh"
        
    else
        log_error "Контейнер снова упал"
        echo ""
        echo "📋 Последние логи:"
        docker logs --tail 20 "$CONTAINER_NAME" 2>&1 || true
    fi
    
else
    log_error "Не удалось запустить контейнер"
fi

echo ""
log_success "🎉 Диагностика завершена!" 