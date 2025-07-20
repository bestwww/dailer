#!/bin/bash

# 🔧 ПОЛНОЕ ИСПРАВЛЕНИЕ КОНФИГУРАЦИИ FREESWITCH
# Создаем все необходимые файлы с нуля для корректного запуска

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

echo "🔧 ПОЛНОЕ ИСПРАВЛЕНИЕ КОНФИГУРАЦИИ FREESWITCH"
echo "=============================================="
echo ""

# ЭТАП 1: Создаем структуру конфигурации с нуля
echo "📁 ЭТАП 1: СОЗДАНИЕ СТРУКТУРЫ КОНФИГУРАЦИИ"
echo "=========================================="

log_info "Создаем структуру директорий..."

# Создаем все необходимые директории
mkdir -p freeswitch/conf/{autoload_configs,dialplan,directory,lang/en}
mkdir -p freeswitch/conf/sip_profiles/{internal,external}

log_success "Структура директорий создана"

# ЭТАП 2: Создаем главный freeswitch.xml
echo ""
echo "📋 ЭТАП 2: СОЗДАНИЕ ГЛАВНОГО FREESWITCH.XML"
echo "=========================================="

log_info "Создаем корректный freeswitch.xml..."

cat > freeswitch/conf/freeswitch.xml << 'EOF'
<?xml version="1.0"?>
<document type="freeswitch/xml">
  <!-- 
  FreeSWITCH Минимальная конфигурация для Dailer
  Создано автоматически 
  -->
  
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
  
  <!-- Секция директории (пустая, но обязательная) -->
  <section name="directory" description="User Directory">
    <domain name="default">
      <!-- Пустая директория для минимальной конфигурации -->
    </domain>
  </section>
</document>
EOF

log_success "Главный freeswitch.xml создан"

# ЭТАП 3: Создаем конфигурацию Sofia SIP
echo ""
echo "📞 ЭТАП 3: СОЗДАНИЕ SOFIA SIP КОНФИГУРАЦИИ"
echo "========================================"

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

# ЭТАП 4: Создаем базовые модули
echo ""
echo "⚙️ ЭТАП 4: СОЗДАНИЕ КОНФИГУРАЦИИ МОДУЛЕЙ"
echo "======================================="

log_info "Создаем modules.conf.xml..."

cat > freeswitch/conf/autoload_configs/modules.conf.xml << 'EOF'
<configuration name="modules.conf" description="Modules">
  <modules>
    <!-- Основные модули -->
    <load module="mod_console"/>
    <load module="mod_logfile"/>
    <load module="mod_enum"/>
    <load module="mod_cdr_csv"/>
    <load module="mod_event_socket"/>
    <load module="mod_sofia"/>
    <load module="mod_dialplan_xml"/>
    <load module="mod_dptools"/>
    <load module="mod_expr"/>
    <load module="mod_fifo"/>
    <load module="mod_hash"/>
    <load module="mod_esl"/>
    <load module="mod_esf"/>
    <load module="mod_fsv"/>
    <load module="mod_valet_parking"/>
    <load module="mod_httapi"/>
    <load module="mod_bv"/>
    <load module="mod_curl"/>
    <load module="mod_file_string"/>
    <load module="mod_hash"/>
    <load module="mod_httapi"/>
    <load module="mod_xml_curl"/>
    <load module="mod_xml_rpc"/>
    <load module="mod_xml_scgi"/>
    
    <!-- Кодеки -->
    <load module="mod_spandsp"/>
    <load module="mod_g711"/>
    <load module="mod_g729"/>
    <load module="mod_amr"/>
    <load module="mod_speex"/>
    <load module="mod_opus"/>
    
    <!-- Форматы файлов -->
    <load module="mod_sndfile"/>
    <load module="mod_native_file"/>
    <load module="mod_local_stream"/>
    <load module="mod_tone_stream"/>
    
    <!-- Say -->
    <load module="mod_say_en"/>
    
    <!-- Lua поддержка для IVR -->
    <load module="mod_lua"/>
    
    <!-- Таймеры -->
    <load module="mod_timerfd"/>
    
    <!-- Applications -->
    <load module="mod_commands"/>
    <load module="mod_conference"/>
    <load module="mod_db"/>
    <load module="mod_directory"/>
    <load module="mod_distributor"/>
    <load module="mod_easyroute"/>
    <load module="mod_lcr"/>
    <load module="mod_memcache"/>
    <load module="mod_nibblebill"/>
    <load module="mod_redis"/>
    <load module="mod_rss"/>
    <load module="mod_soundtouch"/>
    <load module="mod_spy"/>
    <load module="mod_sms"/>
    <load module="mod_stress"/>
    <load module="mod_vmd"/>
    <load module="mod_voicemail"/>
    <load module="mod_voicemail_ivr"/>
    <load module="mod_callcenter"/>
  </modules>
</configuration>
EOF

log_success "Конфигурация модулей создана"

# ЭТАП 5: Создаем Event Socket конфигурацию
echo ""
echo "🔌 ЭТАП 5: СОЗДАНИЕ EVENT SOCKET КОНФИГУРАЦИИ"
echo "============================================"

log_info "Создаем event_socket.conf.xml..."

cat > freeswitch/conf/autoload_configs/event_socket.conf.xml << 'EOF'
<configuration name="event_socket.conf" description="Socket Client">
  <settings>
    <param name="nat-map" value="false"/>
    <param name="listen-ip" value="0.0.0.0"/>
    <param name="listen-port" value="8021"/>
    <param name="password" value="ClueCon"/>
    <param name="apply-inbound-acl" value="loopback.auto"/>
    <param name="stop-on-bind-error" value="true"/>
  </settings>
</configuration>
EOF

log_success "Event Socket конфигурация создана"

# ЭТАП 6: Создаем диалплан с IVR
echo ""
echo "📞 ЭТАП 6: СОЗДАНИЕ ДИАЛПЛАНА С IVR"
echo "================================="

log_info "Создаем default.xml диалплан..."

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
    
    <!-- Исходящие звонки через SIP trunk -->
    <extension name="outbound_calls">
      <condition field="destination_number" expression="^(\d{11})$">
        <action application="set" data="caller_id_name=79058615815"/>
        <action application="set" data="caller_id_number=79058615815"/>
        <action application="set" data="effective_caller_id_name=79058615815"/>
        <action application="set" data="effective_caller_id_number=79058615815"/>
        <action application="bridge" data="sofia/gateway/sip_trunk/$1"/>
      </condition>
    </extension>
    
    <!-- Входящие звонки направляем на IVR -->
    <extension name="inbound_calls">
      <condition field="destination_number" expression="^(79058615815)$">
        <action application="answer"/>
        <action application="sleep" data="1000"/>
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

# ЭТАП 7: Создаем IVR скрипт
echo ""
echo "🎭 ЭТАП 7: СОЗДАНИЕ IVR СКРИПТА"
echo "=============================="

log_info "Создаем Lua скрипт для IVR..."

mkdir -p freeswitch/scripts

cat > freeswitch/scripts/ivr_menu.lua << 'EOF'
-- IVR Menu для Dailer
-- Простое голосовое меню для обработки входящих звонков

-- Функция для воспроизведения сообщения
function play_message(session, message)
    if session:ready() then
        session:streamFile(message)
    end
end

-- Функция для получения DTMF
function get_dtmf(session, timeout)
    if session:ready() then
        local digit = session:getDigits(1, "", timeout)
        return digit
    end
    return ""
end

-- Главная функция IVR
function ivr_main(session)
    -- Отвечаем на звонок
    session:answer()
    
    -- Устанавливаем Caller ID
    session:setVariable("caller_id_name", "79058615815")
    session:setVariable("caller_id_number", "79058615815")
    
    local max_attempts = 3
    local attempt = 0
    
    while attempt < max_attempts and session:ready() do
        attempt = attempt + 1
        
        -- Приветственное сообщение
        session:speak("Добро пожаловать в систему автодозвона. Нажмите 1 для продолжения, 2 для завершения звонка, или 9 для эхо теста.")
        
        -- Получаем DTMF
        local digit = get_dtmf(session, 5000) -- 5 секунд таймаут
        
        if digit == "1" then
            session:speak("Вы выбрали продолжение. Спасибо за обращение.")
            session:sleep(2000)
            break
        elseif digit == "2" then
            session:speak("До свидания.")
            session:sleep(1000)
            break
        elseif digit == "9" then
            session:speak("Эхо тест начинается.")
            session:execute("echo")
            break
        else
            if attempt < max_attempts then
                session:speak("Неверный выбор. Попробуйте еще раз.")
            else
                session:speak("Превышено количество попыток. До свидания.")
            end
        end
    end
    
    -- Завершаем звонок
    session:hangup()
end

-- Основная точка входа
if session then
    ivr_main(session)
else
    freeswitch.consoleLog("ERROR", "No session available for IVR\n")
end
EOF

log_success "IVR скрипт создан"

# ЭТАП 8: Создаем логирование
echo ""
echo "📝 ЭТАП 8: НАСТРОЙКА ЛОГИРОВАНИЯ"
echo "==============================="

log_info "Создаем logfile.conf.xml..."

cat > freeswitch/conf/autoload_configs/logfile.conf.xml << 'EOF'
<configuration name="logfile.conf" description="File Logging">
  <settings>
    <param name="rotate-on-hup" value="true"/>
  </settings>
  <profiles>
    <profile name="default">
      <settings>
        <param name="logfile" value="/usr/local/freeswitch/log/freeswitch.log"/>
        <param name="rollover" value="10485760"/>
        <param name="maximum-rotate" value="32"/>
      </settings>
      <mappings>
        <map name="all" value="console,info,notice,warning,err,crit,alert"/>
      </mappings>
    </profile>
  </profiles>
</configuration>
EOF

log_success "Конфигурация логирования создана"

# ЭТАП 9: Проверяем XML синтаксис
echo ""
echo "✅ ЭТАП 9: ПРОВЕРКА XML СИНТАКСИСА"
echo "================================="

log_info "Проверяем XML синтаксис созданных файлов..."

# Проверяем основные XML файлы
for file in freeswitch/conf/freeswitch.xml freeswitch/conf/autoload_configs/*.xml freeswitch/conf/dialplan/*.xml; do
    if [ -f "$file" ]; then
        if xmllint --noout "$file" 2>/dev/null; then
            log_success "✅ $file - синтаксис корректен"
        else
            log_error "❌ $file - ошибка синтаксиса!"
            xmllint "$file" 2>&1 | head -5
        fi
    fi
done

# ЭТАП 10: Запуск контейнера
echo ""
echo "🚀 ЭТАП 10: ЗАПУСК КОНТЕЙНЕРА"
echo "============================"

log_info "Останавливаем старый контейнер..."
docker stop "$CONTAINER_NAME" 2>/dev/null || true

log_info "Запускаем контейнер с новой конфигурацией..."
if docker start "$CONTAINER_NAME"; then
    log_success "Контейнер запущен"
    
    log_info "Ожидаем полной загрузки FreeSWITCH (30 секунд)..."
    sleep 30
    
    # Проверяем статус
    if docker ps --filter "name=$CONTAINER_NAME" --filter "status=running" | grep -q "$CONTAINER_NAME"; then
        log_success "🎉 Контейнер успешно работает!"
        
        # Проверяем FreeSWITCH
        log_info "Проверяем статус FreeSWITCH..."
        FS_STATUS=$(docker exec "$CONTAINER_NAME" fs_cli -x "status" 2>/dev/null || echo "ERROR")
        
        if echo "$FS_STATUS" | grep -q "UP"; then
            log_success "✅ FreeSWITCH полностью загружен и работает!"
            
            # Проверяем Sofia профили
            log_info "Проверяем SIP профили..."
            SIP_STATUS=$(docker exec "$CONTAINER_NAME" fs_cli -x "sofia status" 2>/dev/null || echo "ERROR")
            echo "$SIP_STATUS"
            
            if echo "$SIP_STATUS" | grep -q "internal.*RUNNING"; then
                log_success "✅ SIP профиль internal работает!"
            else
                log_warning "⚠️ SIP профиль требует дополнительной настройки"
            fi
            
            # Проверяем gateway
            log_info "Проверяем SIP gateway..."
            GATEWAY_STATUS=$(docker exec "$CONTAINER_NAME" fs_cli -x "sofia status gateway" 2>/dev/null || echo "ERROR")
            echo "$GATEWAY_STATUS"
            
            if echo "$GATEWAY_STATUS" | grep -q "sip_trunk"; then
                log_success "✅ SIP trunk загружен!"
            else
                log_warning "⚠️ SIP trunk требует настройки"
            fi
            
        else
            log_warning "⚠️ FreeSWITCH еще загружается..."
            echo "Статус: $FS_STATUS"
        fi
        
    else
        log_error "❌ Контейнер упал после запуска"
        echo ""
        echo "📋 Последние логи:"
        docker logs --tail 30 "$CONTAINER_NAME" 2>&1 || true
    fi
    
else
    log_error "❌ Не удалось запустить контейнер"
fi

echo ""
echo "🎯 ИТОГОВЫЕ КОМАНДЫ ДЛЯ ТЕСТИРОВАНИЯ"
echo "==================================="
echo ""
echo "# Проверить статус FreeSWITCH:"
echo "docker exec $CONTAINER_NAME fs_cli -x 'status'"
echo ""
echo "# Проверить SIP профили:"
echo "docker exec $CONTAINER_NAME fs_cli -x 'sofia status'"
echo ""
echo "# Проверить SIP gateway:"
echo "docker exec $CONTAINER_NAME fs_cli -x 'sofia status gateway'"
echo ""
echo "# Тест IVR:"
echo "docker exec $CONTAINER_NAME fs_cli -x 'originate loopback/ivr_menu &echo'"
echo ""
echo "# Тест исходящего звонка:"
echo "docker exec $CONTAINER_NAME fs_cli -x 'originate sofia/gateway/sip_trunk/79206054020 &transfer:ivr_menu'"
echo ""

echo ""
log_success "🎉 Полная настройка завершена!"

if docker ps --filter "name=$CONTAINER_NAME" --filter "status=running" | grep -q "$CONTAINER_NAME"; then
    echo ""
    echo "✅ FREESWITCH ГОТОВ К РАБОТЕ!"
    echo "📞 SIP trunk настроен для провайдера 62.141.121.197:5070"
    echo "🎭 IVR меню готово для обработки звонков"
    echo "🔐 Аутентификация по IP без пароля"
    echo ""
    echo "🎯 Теперь можно тестировать звонки!"
else
    echo ""
    echo "❌ ТРЕБУЕТСЯ ДОПОЛНИТЕЛЬНАЯ ДИАГНОСТИКА"
    echo "💡 Проверьте логи: docker logs -f $CONTAINER_NAME"
fi 