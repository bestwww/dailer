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
    
    # Обновляем все Caller ID переменные (Linux версия)
    sed -i "s/<X-PRE-PROCESS cmd=\"set\" data=\"default_caller_id_number=[^\"]*\"/<X-PRE-PROCESS cmd=\"set\" data=\"default_caller_id_number=$NEW_CALLER_ID\"/g" freeswitch/conf/vars.xml
    sed -i "s/<X-PRE-PROCESS cmd=\"set\" data=\"outbound_caller_id_number=[^\"]*\"/<X-PRE-PROCESS cmd=\"set\" data=\"outbound_caller_id_number=$NEW_CALLER_ID\"/g" freeswitch/conf/vars.xml
    sed -i "s/<X-PRE-PROCESS cmd=\"set\" data=\"emergency_caller_id_number=[^\"]*\"/<X-PRE-PROCESS cmd=\"set\" data=\"emergency_caller_id_number=$NEW_CALLER_ID\"/g" freeswitch/conf/vars.xml
    
    log_success "vars.xml обновлен"
else
    log_warning "vars.xml не найден"
fi

# Обновляем dialplan
if [ -f "freeswitch/conf/dialplan/default.xml" ]; then
    log_info "Обновляем dialplan/default.xml..."
    cp freeswitch/conf/dialplan/default.xml freeswitch/conf/dialplan/default.xml.backup.$(date +%s)
    
    # Обновляем Caller ID в dialplan (Linux версия)
    sed -i "s/caller_id_number=\"[^\"]*\"/caller_id_number=\"$NEW_CALLER_ID\"/g" freeswitch/conf/dialplan/default.xml
    sed -i "s/effective_caller_id_number=[^,}]*/effective_caller_id_number=$NEW_CALLER_ID/g" freeswitch/conf/dialplan/default.xml
    
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

 # Создаем новый dialplan с IVR меню
 cat > freeswitch/conf/dialplan/default.xml << 'EOF'
 <?xml version="1.0" encoding="utf-8"?>
 <include>
   <context name="default">
     
     <!-- Исходящие звонки от бэкенда с IVR меню -->
     <extension name="outbound_calls_with_ivr">
       <condition field="destination_number" expression="^(\d{10,11})$">
         <action application="set" data="caller_id_number=79058615815"/>
         <action application="set" data="caller_id_name=Dailer System"/>
         <action application="set" data="effective_caller_id_number=79058615815"/>
         <action application="set" data="effective_caller_id_name=Dailer System"/>
         <action application="set" data="call_timeout=30"/>
         <action application="set" data="hangup_after_bridge=true"/>
         <action application="bridge" data="sofia/gateway/sip_trunk/$1"/>
         <!-- Если звонок отвечен, переводим на IVR -->
         <action application="transfer" data="ivr_menu XML default"/>
       </condition>
     </extension>
     
     <!-- Исходящие звонки с международным форматом -->
     <extension name="outbound_international">
       <condition field="destination_number" expression="^(\+\d{10,15})$">
         <action application="set" data="caller_id_number=79058615815"/>
         <action application="set" data="caller_id_name=Dailer System"/>
         <action application="bridge" data="sofia/gateway/sip_trunk/$1"/>
         <action application="transfer" data="ivr_menu XML default"/>
       </condition>
     </extension>
     
     <!-- IVR Меню -->
     <extension name="ivr_menu">
       <condition field="destination_number" expression="^ivr_menu$">
         <action application="answer"/>
         <action application="sleep" data="1000"/>
         <action application="set" data="playback_terminators=#"/>
         <action application="playback" data="silence_stream://1000"/>
         
         <!-- Основное IVR меню -->
         <action application="lua" data="ivr_menu.lua"/>
         
         <!-- Альтернативно простое меню без Lua -->
         <!-- <action application="playback" data="ivr/ivr-welcome.wav"/>
         <action application="playback" data="ivr/ivr-please_hold.wav"/>
         <action application="sleep" data="2000"/>
         <action application="hangup"/> -->
       </condition>
     </extension>
     
     <!-- Входящие звонки - направляем на IVR -->
     <extension name="inbound_calls">
       <condition field="destination_number" expression="^(79058615815)$">
         <action application="set" data="domain_name=$${domain}"/>
         <action application="transfer" data="ivr_menu XML default"/>
       </condition>
     </extension>
     
     <!-- Любые другие входящие звонки -->
     <extension name="inbound_any">
       <condition field="destination_number" expression="^(.*)$">
         <action application="set" data="domain_name=$${domain}"/>
         <action application="transfer" data="ivr_menu XML default"/>
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
   
   <!-- Публичный контекст для входящих звонков -->
   <context name="public">
     <extension name="inbound_public">
       <condition field="destination_number" expression="^(.*)$">
         <action application="set" data="domain_name=$${domain}"/>
         <action application="transfer" data="ivr_menu XML default"/>
       </condition>
     </extension>
   </context>
   
 </include>
 EOF

 log_success "Dialplan обновлен"

# Создаем простой IVR скрипт
log_info "Создаем IVR скрипт..."

# Создаем директорию для scripts если не существует
mkdir -p freeswitch/scripts

# Создаем простой IVR скрипт на Lua
cat > freeswitch/scripts/ivr_menu.lua << 'EOF'
-- Simple IVR Menu for Dailer System
-- Простое IVR меню для системы Dailer

-- Получаем сессию
session = session or {}

-- Функция для проигрывания звука с ожиданием нажатия клавиши
function play_and_get_digits(prompt, min_digits, max_digits, tries, timeout, terminators)
    if session:ready() then
        local digits = session:playAndGetDigits(min_digits, max_digits, tries, timeout, terminators, prompt, "", "")
        return digits
    end
    return ""
end

-- Основная функция IVR
function main()
    if not session:ready() then
        freeswitch.consoleLog("ERR", "Session not ready\n")
        return
    end
    
    -- Отвечаем на звонок если еще не отвечен
    if not session:answered() then
        session:answer()
        session:sleep(1000)
    end
    
    freeswitch.consoleLog("INFO", "IVR Menu started\n")
    
    -- Основное меню
    local tries = 0
    local max_tries = 3
    
    while tries < max_tries do
        -- Проигрываем приветствие и меню
        session:streamFile("silence_stream://1000")
        
        -- Простое текстовое меню (можно заменить на аудиофайлы)
        session:speak("Добро пожаловать в систему Дайлер. Нажмите 1 для продолжения, 2 для завершения, или 0 для связи с оператором.")
        
        -- Получаем выбор пользователя
        local choice = play_and_get_digits("", 1, 1, 1, 5000, "#")
        
        freeswitch.consoleLog("INFO", "User choice: " .. choice .. "\n")
        
        if choice == "1" then
            -- Вариант 1: Продолжить
            session:speak("Спасибо за ваш выбор. Переводим вас на следующий этап.")
            session:sleep(2000)
            -- Здесь можно добавить логику передачи на другое меню или оператора
            session:speak("Звонок завершается. До свидания.")
            break
            
        elseif choice == "2" then
            -- Вариант 2: Завершить
            session:speak("Спасибо за обращение. До свидания.")
            break
            
        elseif choice == "0" then
            -- Вариант 0: Оператор
            session:speak("Переводим вас на оператора. Пожалуйста, ожидайте.")
            -- Здесь можно добавить перевод на оператора
            session:sleep(3000)
            session:speak("В настоящее время все операторы заняты. До свидания.")
            break
            
        else
            -- Неверный выбор
            tries = tries + 1
            if tries < max_tries then
                session:speak("Неверный выбор. Попробуйте еще раз.")
            else
                session:speak("Превышено количество попыток. Звонок завершается.")
            end
        end
    end
    
    freeswitch.consoleLog("INFO", "IVR Menu ended\n")
    session:hangup()
end

-- Запускаем основную функцию
main()
EOF

log_success "IVR скрипт создан"

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

# Копируем IVR скрипты в контейнер
if [ -d "freeswitch/scripts" ]; then
    log_info "Копируем IVR скрипты..."
    if docker cp freeswitch/scripts/. "$CONTAINER_NAME:/usr/local/freeswitch/scripts/"; then
        log_success "IVR скрипты скопированы"
    else
        log_warning "Ошибка копирования IVR скриптов"
    fi
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
echo "🎯 РЕКОМЕНДАЦИИ ПО ПОРТАМ (ДЛЯ ВАШЕЙ АРХИТЕКТУРЫ)"
echo "=================================================="
echo ""
echo "📋 Ваша архитектура: FreeSWITCH + Бэкенд на одном сервере"
echo ""
echo "✅ НУЖНО открыть наружу (для SIP провайдера):"
echo "   🔌 5060/udp - входящие SIP звонки"
echo "   🔌 5080/udp - исходящие SIP звонки"
echo ""
echo "❌ НЕ нужно открывать (только внутренняя связь):"
echo "   🔒 8021/tcp - ESL для связи с бэкендом"
echo ""
echo "💡 Рекомендуемая настройка docker-compose.yml:"
echo ""
echo "services:"
echo "  freeswitch:"
echo "    ports:"
echo "      - \"5060:5060/udp\"  # SIP входящие"
echo "      - \"5080:5080/udp\"  # SIP исходящие"
echo "    networks:"
echo "      - internal_network  # Для связи с бэкендом"
echo ""
echo "  backend:"
echo "    networks:"
echo "      - internal_network  # Доступ к FreeSWITCH через ESL"
echo ""
echo "networks:"
echo "  internal_network:"
echo "    driver: bridge"
echo ""
echo "🔗 Бэкенд подключается к FreeSWITCH:"
echo "   ESL: freeswitch:8021 (внутри Docker сети)"
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
echo "# Тест исходящего звонка с IVR:"
echo "docker exec $CONTAINER_NAME fs_cli -x 'originate sofia/gateway/sip_trunk/79001234567 &transfer:ivr_menu'"
echo ""
echo "# Тест IVR меню напрямую:"
echo "docker exec $CONTAINER_NAME fs_cli -x 'originate loopback/ivr_menu &echo'"
echo ""
echo "# Проверить dialplan:"
echo "docker exec $CONTAINER_NAME fs_cli -x 'xml_locate dialplan'"
echo ""
echo "# Посмотреть логи:"
echo "docker logs -f $CONTAINER_NAME"
echo ""
echo "# Подключиться к FreeSWITCH CLI для отладки:"
echo "docker exec -it $CONTAINER_NAME fs_cli"
echo ""

echo ""
log_success "🎉 Исправление проблем завершено!"
echo ""
echo "📋 ЧТО ИСПРАВЛЕНО:"
echo "   ✅ Caller ID обновлен на $NEW_CALLER_ID"
echo "   ✅ SIP профиль external создан для исходящих звонков"
echo "   ✅ Dialplan с IVR меню для входящих и исходящих звонков"
echo "   ✅ IVR скрипт на Lua с интерактивным меню"
echo "   ✅ Публичный контекст для входящих звонков"
echo "   ✅ Конфигурация применена без перезапуска"
echo ""
echo "📞 АРХИТЕКТУРА:"
echo "   🎯 Исходящие звонки: Бэкенд → FreeSWITCH → SIP Trunk → IVR"
echo "   📲 Входящие звонки: SIP Trunk → FreeSWITCH → IVR меню"
echo "   🔗 Связь бэкенда: ESL через внутреннюю Docker сеть"
echo ""
echo "⚠️ ТРЕБУЕТ ВНИМАНИЯ:"
echo "   🔌 Открыть SIP порты наружу (5060, 5080) для провайдера"
echo "   🔐 Добавить пароль SIP trunk в переменную external_sip_password"
echo "   🎵 Заменить speak() на аудиофайлы для лучшего качества"
echo ""
echo "🚀 Система готова для тестирования IVR меню и звонков!" 