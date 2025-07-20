#!/bin/bash

# 🔧 ПОЛНОЕ ПЕРЕСОЗДАНИЕ FREESWITCH КОНТЕЙНЕРА
# Удаляем старый контейнер и создаем новый с чистой конфигурацией

set -e

CONTAINER_NAME="freeswitch-test"
IMAGE_NAME="dailer-freeswitch:ready"

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

echo "🔧 ПОЛНОЕ ПЕРЕСОЗДАНИЕ FREESWITCH КОНТЕЙНЕРА"
echo "============================================="
echo ""

# ЭТАП 1: Полная очистка старого контейнера
echo "🗑️ ЭТАП 1: УДАЛЕНИЕ СТАРОГО КОНТЕЙНЕРА"
echo "====================================="

log_info "Останавливаем старый контейнер..."
docker stop "$CONTAINER_NAME" 2>/dev/null || true

log_info "Удаляем старый контейнер..."
docker rm "$CONTAINER_NAME" 2>/dev/null || true

log_success "Старый контейнер удален"

# ЭТАП 2: Очистка старых файлов конфигурации
echo ""
echo "🧹 ЭТАП 2: ОЧИСТКА СТАРЫХ КОНФИГУРАЦИЙ"
echo "====================================="

log_info "Удаляем старые конфигурационные файлы..."
rm -rf freeswitch/conf/* 2>/dev/null || true
rm -rf freeswitch/scripts/* 2>/dev/null || true

log_success "Старая конфигурация очищена"

# ЭТАП 3: Создание минимальной структуры конфигурации
echo ""
echo "📁 ЭТАП 3: СОЗДАНИЕ ЧИСТОЙ СТРУКТУРЫ"
echo "==================================="

log_info "Создаем структуру директорий..."

# Создаем все необходимые директории
mkdir -p freeswitch/conf/{autoload_configs,dialplan,directory,lang/en}
mkdir -p freeswitch/scripts

log_success "Структура директорий создана"

# ЭТАП 4: Создание МИНИМАЛЬНОГО freeswitch.xml
echo ""
echo "📋 ЭТАП 4: СОЗДАНИЕ МИНИМАЛЬНОГО FREESWITCH.XML"
echo "=============================================="

log_info "Создаем минимальный freeswitch.xml..."

cat > freeswitch/conf/freeswitch.xml << 'EOF'
<?xml version="1.0"?>
<document type="freeswitch/xml">
  <!-- Минимальная конфигурация FreeSWITCH для Dailer -->
  
  <!-- Глобальные переменные -->
  <X-PRE-PROCESS cmd="set" data="default_password=1234"/>
  <X-PRE-PROCESS cmd="set" data="sound_prefix=/usr/local/freeswitch/sounds/en/us/callie"/>
  <X-PRE-PROCESS cmd="set" data="caller_id=79058615815"/>
  
  <!-- Секция конфигурации -->
  <section name="configuration" description="Various Configuration">
    <X-PRE-PROCESS cmd="include" data="autoload_configs/*.xml"/>
  </section>
  
  <!-- Секция диалплана -->
  <section name="dialplan" description="Regex/XML Dialplan">
    <X-PRE-PROCESS cmd="include" data="dialplan/*.xml"/>
  </section>
  
  <!-- Пустая секция директории -->
  <section name="directory" description="User Directory">
    <domain name="default">
      <!-- Пустая директория -->
    </domain>
  </section>
</document>
EOF

log_success "Минимальный freeswitch.xml создан"

# ЭТАП 5: Создание ТОЛЬКО САМЫХ НЕОБХОДИМЫХ модулей
echo ""
echo "⚙️ ЭТАП 5: СОЗДАНИЕ МИНИМАЛЬНОЙ КОНФИГУРАЦИИ МОДУЛЕЙ"
echo "================================================="

log_info "Создаем минимальный modules.conf.xml..."

cat > freeswitch/conf/autoload_configs/modules.conf.xml << 'EOF'
<configuration name="modules.conf" description="Modules">
  <modules>
    <!-- Базовые модули -->
    <load module="mod_console"/>
    <load module="mod_logfile"/>
    <load module="mod_event_socket"/>
    <load module="mod_sofia"/>
    <load module="mod_dialplan_xml"/>
    <load module="mod_dptools"/>
    
    <!-- Кодеки -->
    <load module="mod_g711"/>
    
    <!-- Форматы файлов -->
    <load module="mod_sndfile"/>
    <load module="mod_native_file"/>
    <load module="mod_tone_stream"/>
    
    <!-- Say -->
    <load module="mod_say_en"/>
    
    <!-- Lua для IVR -->
    <load module="mod_lua"/>
    
    <!-- Таймеры -->
    <load module="mod_timerfd"/>
    
    <!-- Applications -->
    <load module="mod_commands"/>
  </modules>
</configuration>
EOF

log_success "Минимальная конфигурация модулей создана"

# ЭТАП 6: Создание Sofia с SIP trunk
echo ""
echo "📞 ЭТАП 6: СОЗДАНИЕ SOFIA SIP"
echo "============================"

log_info "Создаем sofia.conf.xml..."

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
        <param name="sip-port" value="5060"/>
        <param name="dialplan" value="XML"/>
        <param name="context" value="default"/>
        <param name="inbound-codec-prefs" value="PCMU,PCMA"/>
        <param name="outbound-codec-prefs" value="PCMU,PCMA"/>
        <param name="rtp-timer-name" value="soft"/>
        <param name="local-network-acl" value="localnet.auto"/>
        <param name="manage-presence" value="false"/>
        <param name="auth-calls" value="false"/>
        <param name="rtp-ip" value="auto"/>
        <param name="sip-ip" value="auto"/>
        <param name="ext-rtp-ip" value="auto-nat"/>
        <param name="ext-sip-ip" value="auto-nat"/>
      </settings>
    </profile>
  </profiles>
</configuration>
EOF

log_success "Sofia конфигурация создана"

# ЭТАП 7: Event Socket
echo ""
echo "🔌 ЭТАП 7: EVENT SOCKET"
echo "======================"

log_info "Создаем event_socket.conf.xml..."

cat > freeswitch/conf/autoload_configs/event_socket.conf.xml << 'EOF'
<configuration name="event_socket.conf" description="Socket Client">
  <settings>
    <param name="nat-map" value="false"/>
    <param name="listen-ip" value="0.0.0.0"/>
    <param name="listen-port" value="8021"/>
    <param name="password" value="ClueCon"/>
    <param name="apply-inbound-acl" value="loopback.auto"/>
  </settings>
</configuration>
EOF

log_success "Event Socket создан"

# ЭТАП 8: Диалплан
echo ""
echo "📞 ЭТАП 8: ДИАЛПЛАН"
echo "=================="

log_info "Создаем диалплан..."

cat > freeswitch/conf/dialplan/default.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<include>
  <context name="default">
    
    <!-- IVR Menu -->
    <extension name="ivr_menu">
      <condition field="destination_number" expression="^(ivr_menu)$">
        <action application="answer"/>
        <action application="sleep" data="1000"/>
        <action application="lua" data="ivr_menu.lua"/>
      </condition>
    </extension>
    
    <!-- Исходящие звонки -->
    <extension name="outbound_calls">
      <condition field="destination_number" expression="^(\d{11})$">
        <action application="set" data="caller_id_name=79058615815"/>
        <action application="set" data="caller_id_number=79058615815"/>
        <action application="bridge" data="sofia/gateway/sip_trunk/$1"/>
      </condition>
    </extension>
    
    <!-- Входящие звонки -->
    <extension name="inbound_calls">
      <condition field="destination_number" expression="^(79058615815)$">
        <action application="answer"/>
        <action application="transfer" data="ivr_menu"/>
      </condition>
    </extension>
    
    <!-- Echo test -->
    <extension name="echo">
      <condition field="destination_number" expression="^(echo|9196)$">
        <action application="answer"/>
        <action application="echo"/>
      </condition>
    </extension>
    
  </context>
</include>
EOF

log_success "Диалплан создан"

# ЭТАП 9: IVR скрипт
echo ""
echo "🎭 ЭТАП 9: IVR СКРИПТ"
echo "==================="

log_info "Создаем IVR скрипт..."

cat > freeswitch/scripts/ivr_menu.lua << 'EOF'
-- Простое IVR меню
freeswitch.consoleLog("INFO", "IVR Menu запущен\n")

if session and session:ready() then
    session:answer()
    session:setVariable("caller_id_name", "79058615815")
    session:setVariable("caller_id_number", "79058615815")
    
    -- Простое меню
    session:speak("Добро пожаловать. Нажмите 1 для продолжения или 2 для завершения.")
    
    local digit = session:getDigits(1, "", 5000)
    
    if digit == "1" then
        session:speak("Спасибо за обращение.")
        session:sleep(2000)
    elseif digit == "2" then
        session:speak("До свидания.")
        session:sleep(1000)
    else
        session:speak("Неверный выбор. До свидания.")
        session:sleep(1000)
    end
    
    session:hangup()
else
    freeswitch.consoleLog("ERROR", "Нет активной сессии\n")
end
EOF

log_success "IVR скрипт создан"

# ЭТАП 10: Проверка XML
echo ""
echo "✅ ЭТАП 10: ПРОВЕРКА XML"
echo "======================="

log_info "Проверяем XML синтаксис..."

XML_VALID=true
for file in freeswitch/conf/freeswitch.xml freeswitch/conf/autoload_configs/*.xml freeswitch/conf/dialplan/*.xml; do
    if [ -f "$file" ]; then
        if xmllint --noout "$file" 2>/dev/null; then
            log_success "✅ $(basename $file) - корректен"
        else
            log_error "❌ $(basename $file) - ошибка!"
            XML_VALID=false
        fi
    fi
done

if [ "$XML_VALID" = false ]; then
    log_error "XML ошибки найдены! Прерываем выполнение."
    exit 1
fi

log_success "Все XML файлы корректны"

# ЭТАП 11: Создание нового контейнера
echo ""
echo "🚀 ЭТАП 11: СОЗДАНИЕ НОВОГО КОНТЕЙНЕРА"
echo "====================================="

log_info "Создаем новый контейнер FreeSWITCH..."

# Создаем новый контейнер с чистой конфигурацией
if docker run -d --name "$CONTAINER_NAME" \
    -p 5060:5060/udp \
    -p 8021:8021 \
    -v "$(pwd)/freeswitch/conf:/usr/local/freeswitch/conf" \
    -v "$(pwd)/freeswitch/scripts:/usr/local/freeswitch/scripts" \
    -v "$(pwd)/audio:/usr/local/freeswitch/sounds" \
    --restart unless-stopped \
    "$IMAGE_NAME"; then
    
    log_success "Новый контейнер создан"
    
    log_info "Ожидаем запуска FreeSWITCH (45 секунд)..."
    sleep 45
    
    # Проверяем статус
    if docker ps --filter "name=$CONTAINER_NAME" --filter "status=running" | grep -q "$CONTAINER_NAME"; then
        log_success "🎉 Контейнер успешно запущен!"
        
        # Проверяем FreeSWITCH
        log_info "Проверяем статус FreeSWITCH..."
        FS_STATUS=$(docker exec "$CONTAINER_NAME" fs_cli -x "status" 2>/dev/null || echo "TIMEOUT")
        
        if echo "$FS_STATUS" | grep -q "UP"; then
            log_success "✅ FreeSWITCH работает!"
            
            # Проверяем Sofia
            log_info "Проверяем SIP профили..."
            SIP_STATUS=$(docker exec "$CONTAINER_NAME" fs_cli -x "sofia status" 2>/dev/null || echo "ERROR")
            echo "$SIP_STATUS"
            
            if echo "$SIP_STATUS" | grep -q "internal.*RUNNING"; then
                log_success "✅ SIP профиль работает!"
            fi
            
            # Проверяем gateway
            log_info "Проверяем SIP gateway..."
            GATEWAY_STATUS=$(docker exec "$CONTAINER_NAME" fs_cli -x "sofia status gateway" 2>/dev/null || echo "ERROR")
            echo "$GATEWAY_STATUS"
            
            if echo "$GATEWAY_STATUS" | grep -q "sip_trunk"; then
                log_success "✅ SIP trunk загружен!"
            fi
            
        else
            log_warning "⚠️ FreeSWITCH еще загружается или есть проблемы"
            echo "Ответ: $FS_STATUS"
        fi
        
    else
        log_error "❌ Контейнер упал"
        echo ""
        echo "📋 Логи контейнера:"
        docker logs --tail 50 "$CONTAINER_NAME" 2>&1 || true
    fi
    
else
    log_error "❌ Не удалось создать контейнер"
    exit 1
fi

echo ""
echo "🎯 КОМАНДЫ ДЛЯ ТЕСТИРОВАНИЯ"
echo "=========================="
echo ""
echo "# Проверить статус:"
echo "docker exec $CONTAINER_NAME fs_cli -x 'status'"
echo ""
echo "# Проверить SIP:"
echo "docker exec $CONTAINER_NAME fs_cli -x 'sofia status'"
echo ""
echo "# Тест IVR:"
echo "docker exec $CONTAINER_NAME fs_cli -x 'originate loopback/ivr_menu &echo'"
echo ""
echo "# Тест звонка:"
echo "docker exec $CONTAINER_NAME fs_cli -x 'originate sofia/gateway/sip_trunk/79206054020 &transfer:ivr_menu'"
echo ""

echo ""
log_success "🎉 Пересоздание завершено!"

if docker ps --filter "name=$CONTAINER_NAME" --filter "status=running" | grep -q "$CONTAINER_NAME"; then
    echo ""
    echo "✅ НОВЫЙ FREESWITCH КОНТЕЙНЕР ГОТОВ!"
    echo "🧹 Старая поврежденная конфигурация удалена"
    echo "📁 Создана чистая минимальная конфигурация"
    echo "📞 SIP trunk настроен для провайдера"
    echo "🎭 IVR готово для тестирования"
    echo ""
    echo "🎯 МОЖНО ТЕСТИРОВАТЬ ЗВОНКИ!"
else
    echo ""
    echo "❌ ПРОБЛЕМЫ С НОВЫМ КОНТЕЙНЕРОМ"
    echo "💡 Проверьте логи: docker logs -f $CONTAINER_NAME"
fi 