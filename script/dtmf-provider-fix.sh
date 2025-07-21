#!/bin/bash

# 📞 ИСПРАВЛЕНИЕ DTMF НАСТРОЕК ПРОВАЙДЕРА
# Проблема: Провайдер не передает DTMF сигналы в FreeSWITCH

CONTAINER_NAME="freeswitch-test"

echo "📞 ИСПРАВЛЕНИЕ DTMF НАСТРОЕК ПРОВАЙДЕРА"
echo "======================================"
echo ""

echo "❌ ПРОБЛЕМА: FreeSWITCH не получает DTMF от провайдера"
echo "💡 РЕШЕНИЕ: Попробовать разные типы DTMF передачи"
echo ""

# ЭТАП 1: Диагностика текущих настроек
echo "📋 ЭТАП 1: ДИАГНОСТИКА ТЕКУЩИХ НАСТРОЕК"
echo "======================================"

echo ""
echo "1. 📄 Проверяем текущие настройки gateway..."
if docker exec "$CONTAINER_NAME" test -f /usr/local/freeswitch/conf/sip_profiles/external/sip_trunk.xml; then
    echo "Gateway конфигурация:"
    docker exec "$CONTAINER_NAME" cat /usr/local/freeswitch/conf/sip_profiles/external/sip_trunk.xml
else
    echo "❌ Gateway файл не найден"
fi

echo ""
echo "2. 📊 Проверяем Sofia статус..."
SOFIA_STATUS=$(docker exec "$CONTAINER_NAME" fs_cli -x "sofia status")
echo "Sofia статус: $SOFIA_STATUS"

# ЭТАП 2: Создание альтернативных gateway с разными DTMF настройками
echo ""
echo "📋 ЭТАП 2: АЛЬТЕРНАТИВНЫЕ DTMF НАСТРОЙКИ"
echo "======================================="

echo ""
echo "1. 📄 Создаем gateway с inband DTMF..."

# Gateway с inband DTMF
cat > /tmp/sip_trunk_inband.xml << 'EOF'
<include>
  <gateway name="sip_trunk_inband">
    <param name="realm" value="sip.beeline.ru"/>
    <param name="username" value="79206054020"/>
    <param name="password" value="79206054020"/>
    <param name="proxy" value="sip.beeline.ru"/>
    <param name="register" value="true"/>
    <param name="register-transport" value="udp"/>
    <param name="retry-seconds" value="30"/>
    <param name="caller-id-in-from" value="true"/>
    <param name="ping" value="30"/>
    
    <!-- INBAND DTMF настройки -->
    <param name="dtmf-type" value="inband"/>
    <param name="inbound-late-negotiation" value="true"/>
    <param name="rtp-timer-name" value="soft"/>
    
    <!-- Кодеки для лучшего DTMF -->
    <param name="codec-prefs" value="PCMU,PCMA,G722"/>
    <param name="inbound-codec-prefs" value="PCMU,PCMA,G722"/>
    <param name="outbound-codec-prefs" value="PCMU,PCMA,G722"/>
    
  </gateway>
</include>
EOF

echo ""
echo "2. 📄 Создаем gateway с SIP INFO DTMF..."

# Gateway с SIP INFO DTMF
cat > /tmp/sip_trunk_info.xml << 'EOF'
<include>
  <gateway name="sip_trunk_info">
    <param name="realm" value="sip.beeline.ru"/>
    <param name="username" value="79206054020"/>
    <param name="password" value="79206054020"/>
    <param name="proxy" value="sip.beeline.ru"/>
    <param name="register" value="true"/>
    <param name="register-transport" value="udp"/>
    <param name="retry-seconds" value="30"/>
    <param name="caller-id-in-from" value="true"/>
    <param name="ping" value="30"/>
    
    <!-- SIP INFO DTMF настройки -->
    <param name="dtmf-type" value="info"/>
    <param name="liberal-dtmf" value="true"/>
    <param name="rtp-timer-name" value="soft"/>
    
    <!-- Кодеки -->
    <param name="codec-prefs" value="PCMU,PCMA"/>
    <param name="inbound-codec-prefs" value="PCMU,PCMA"/>
    <param name="outbound-codec-prefs" value="PCMU,PCMA"/>
    
  </gateway>
</include>
EOF

echo ""
echo "3. 📄 Создаем gateway с улучшенным RFC2833..."

# Gateway с улучшенным RFC2833
cat > /tmp/sip_trunk_rfc2833_enhanced.xml << 'EOF'
<include>
  <gateway name="sip_trunk_rfc2833_enhanced">
    <param name="realm" value="sip.beeline.ru"/>
    <param name="username" value="79206054020"/>
    <param name="password" value="79206054020"/>
    <param name="proxy" value="sip.beeline.ru"/>
    <param name="register" value="true"/>
    <param name="register-transport" value="udp"/>
    <param name="retry-seconds" value="30"/>
    <param name="caller-id-in-from" value="true"/>
    <param name="ping" value="30"/>
    
    <!-- Улучшенный RFC2833 DTMF -->
    <param name="dtmf-type" value="rfc2833"/>
    <param name="dtmf-duration" value="2000"/>
    <param name="liberal-dtmf" value="true"/>
    <param name="rtp-timer-name" value="soft"/>
    <param name="rtp-autoflush-during-bridge" value="false"/>
    
    <!-- Только G.711 для лучшего DTMF -->
    <param name="codec-prefs" value="PCMU@20i,PCMA@20i"/>
    <param name="inbound-codec-prefs" value="PCMU@20i,PCMA@20i"/>
    <param name="outbound-codec-prefs" value="PCMU@20i,PCMA@20i"/>
    
  </gateway>
</include>
EOF

echo "✅ Альтернативные gateway созданы"

# ЭТАП 3: Установка альтернативных gateway
echo ""
echo "📋 ЭТАП 3: УСТАНОВКА АЛЬТЕРНАТИВНЫХ GATEWAY"
echo "=========================================="

echo ""
echo "1. 📄 Устанавливаем inband gateway..."
docker cp /tmp/sip_trunk_inband.xml "$CONTAINER_NAME:/usr/local/freeswitch/conf/sip_profiles/external/sip_trunk_inband.xml"

echo ""
echo "2. 📄 Устанавливаем SIP INFO gateway..."
docker cp /tmp/sip_trunk_info.xml "$CONTAINER_NAME:/usr/local/freeswitch/conf/sip_profiles/external/sip_trunk_info.xml"

echo ""
echo "3. 📄 Устанавливаем улучшенный RFC2833 gateway..."
docker cp /tmp/sip_trunk_rfc2833_enhanced.xml "$CONTAINER_NAME:/usr/local/freeswitch/conf/sip_profiles/external/sip_trunk_rfc2833_enhanced.xml"

echo ""
echo "4. 🔄 Перезагружаем Sofia profile..."
docker exec "$CONTAINER_NAME" fs_cli -x "reloadxml"
docker exec "$CONTAINER_NAME" fs_cli -x "sofia profile external restart"

echo ""
echo "⏰ Ждем перезагрузки (10 секунд)..."
sleep 10

echo ""
echo "5. 📊 Проверяем новые gateway..."
GATEWAY_STATUS=$(docker exec "$CONTAINER_NAME" fs_cli -x "sofia status gateway")
echo "Статус gateway:"
echo "$GATEWAY_STATUS"

# ЭТАП 4: Тестовые команды для разных типов DTMF
echo ""
echo "📋 ЭТАП 4: КОМАНДЫ ДЛЯ ТЕСТИРОВАНИЯ"
echo "=================================="

echo ""
echo "🧪 КОМАНДЫ ДЛЯ ТЕСТИРОВАНИЯ РАЗНЫХ DTMF:"
echo ""
echo "1️⃣ ТЕСТ INBAND DTMF:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"originate sofia/gateway/sip_trunk_inband/79206054020 1201 XML default\""
echo ""
echo "2️⃣ ТЕСТ SIP INFO DTMF:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"originate sofia/gateway/sip_trunk_info/79206054020 1201 XML default\""
echo ""
echo "3️⃣ ТЕСТ УЛУЧШЕННОГО RFC2833:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"originate sofia/gateway/sip_trunk_rfc2833_enhanced/79206054020 1201 XML default\""
echo ""
echo "4️⃣ ТЕСТ ОРИГИНАЛЬНОГО:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"originate sofia/gateway/sip_trunk/79206054020 1201 XML default\""

# ЭТАП 5: Создание диалплана для всех типов DTMF
echo ""
echo "📋 ЭТАП 5: УНИВЕРСАЛЬНЫЙ ДИАЛПЛАН ДЛЯ DTMF"
echo "========================================"

echo ""
echo "1. 📄 Создаем диалплан с поддержкой всех типов DTMF..."

cat > /tmp/universal_dtmf_dialplan.xml << 'EOF'
<include>
  
  <!-- УНИВЕРСАЛЬНЫЙ DTMF ТЕСТ для всех типов -->
  <extension name="universal_dtmf_test">
    <condition field="destination_number" expression="^(1202)$">
      
      <action application="log" data="CRIT ================================"/>
      <action application="log" data="CRIT === УНИВЕРСАЛЬНЫЙ DTMF ТЕСТ ==="/>
      <action application="log" data="CRIT ================================"/>
      
      <!-- Отвечаем -->
      <action application="answer"/>
      <action application="log" data="CRIT === ЗВОНОК ОТВЕЧЕН ==="/>
      
      <!-- Защита -->
      <action application="sched_hangup" data="+60 ALLOTTED_TIMEOUT"/>
      
      <!-- НАСТРОЙКИ ДЛЯ ВСЕХ ТИПОВ DTMF -->
      <action application="set" data="drop_dtmf=false"/>
      <action application="set" data="dtmf_type=rfc2833"/>
      <action application="set" data="liberal_dtmf=true"/>
      <action application="set" data="rtp_timer_name=soft"/>
      <action application="log" data="CRIT === УНИВЕРСАЛЬНЫЕ DTMF НАСТРОЙКИ ==="/>
      
      <!-- Приветствие -->
      <action application="sleep" data="1000"/>
      <action application="playback" data="tone_stream://%(800,200,440)"/>
      <action application="log" data="CRIT === ГОТОВ К DTMF ==="/>
      
      <!-- МНОЖЕСТВЕННЫЕ ПОПЫТКИ СБОРА DTMF -->
      <action application="log" data="CRIT === ПОПЫТКА 1: RFC2833 ==="/>
      <action application="set" data="dtmf_type=rfc2833"/>
      <action application="read" data="dtmf1,1,3,tone_stream://%(100,50,400),timeout,5000"/>
      <action application="log" data="CRIT ПОПЫТКА 1 РЕЗУЛЬТАТ: ${dtmf1}"/>
      
      <action application="log" data="CRIT === ПОПЫТКА 2: INBAND ==="/>
      <action application="set" data="dtmf_type=inband"/>
      <action application="read" data="dtmf2,1,3,tone_stream://%(100,50,600),timeout,5000"/>
      <action application="log" data="CRIT ПОПЫТКА 2 РЕЗУЛЬТАТ: ${dtmf2}"/>
      
      <action application="log" data="CRIT === ПОПЫТКА 3: INFO ==="/>
      <action application="set" data="dtmf_type=info"/>
      <action application="read" data="dtmf3,1,3,tone_stream://%(100,50,800),timeout,5000"/>
      <action application="log" data="CRIT ПОПЫТКА 3 РЕЗУЛЬТАТ: ${dtmf3}"/>
      
      <!-- Анализ результатов -->
      <action application="log" data="CRIT ================================"/>
      <action application="log" data="CRIT === АНАЛИЗ РЕЗУЛЬТАТОВ ==="/>
      <action application="log" data="CRIT RFC2833: ${dtmf1}"/>
      <action application="log" data="CRIT INBAND: ${dtmf2}"/>
      <action application="log" data="CRIT INFO: ${dtmf3}"/>
      <action application="log" data="CRIT ================================"/>
      
      <!-- Определяем лучший метод -->
      <action application="set" data="best_dtmf=${dtmf1}${dtmf2}${dtmf3}"/>
      <action application="log" data="CRIT ЛУЧШИЙ РЕЗУЛЬТАТ: ${best_dtmf}"/>
      
      <action application="playback" data="tone_stream://%(1000,0,800,400,200)"/>
      <action application="hangup"/>
      
    </condition>
  </extension>
  
</include>
EOF

echo ""
echo "2. 📄 Устанавливаем универсальный диалплан..."
docker cp /tmp/universal_dtmf_dialplan.xml "$CONTAINER_NAME:/usr/local/freeswitch/conf/dialplan/default/universal_dtmf.xml"

echo ""
echo "3. 🔄 Перезагружаем конфигурацию..."
docker exec "$CONTAINER_NAME" fs_cli -x "reloadxml"

echo ""
echo "📞 ИСПРАВЛЕНИЕ DTMF ПРОВАЙДЕРА ЗАВЕРШЕНО!"
echo "========================================"

echo ""
echo "🧪 ТЕСТЫ ДЛЯ ЗАПУСКА:"
echo ""
echo "🔧 БЕЗОПАСНЫЙ ТЕСТ (без зацикливания):"
echo "docker exec $CONTAINER_NAME fs_cli -x \"originate sofia/gateway/sip_trunk/79206054020 1201 XML default\""
echo ""
echo "🔧 УНИВЕРСАЛЬНЫЙ DTMF ТЕСТ (номер 1202):"
echo "docker exec $CONTAINER_NAME fs_cli -x \"originate sofia/gateway/sip_trunk/79206054020 1202 XML default\""
echo ""
echo "💡 СЛЕДУЮЩИЕ ШАГИ:"
echo "1. Запустить безопасный тест и убедиться что зацикливания нет"
echo "2. Запустить универсальный DTMF тест для определения рабочего типа"
echo "3. Выбрать лучший gateway по результатам"
echo "4. Настроить реальные вебхуки" 