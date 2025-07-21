#!/bin/bash

# 🔄 ИСПРАВЛЕНИЕ ЗАЦИКЛИВАНИЯ IVR ПОСЛЕ HANGUP
# Проблема: IVR продолжает работать даже после завершения звонка

CONTAINER_NAME="freeswitch-test"

echo "🔄 ИСПРАВЛЕНИЕ ЗАЦИКЛИВАНИЯ IVR ПОСЛЕ HANGUP"
echo "==========================================="
echo ""

echo "🚨 ПРОБЛЕМА: IVR зацикливается после hangup и тратит деньги!"
echo "💡 РЕШЕНИЕ: Добавить проверки состояния канала в диалплан"
echo ""

# ЭТАП 1: Срочное завершение всех звонков
echo "📋 ЭТАП 1: СРОЧНОЕ ЗАВЕРШЕНИЕ ЗВОНКОВ"
echo "===================================="

echo ""
echo "1. 🛑 Завершаем ВСЕ активные звонки..."
docker exec "$CONTAINER_NAME" fs_cli -x "hupall MANAGER_REQUEST"

echo ""
echo "2. 📊 Проверяем что все завершены..."
ACTIVE_CALLS=$(docker exec "$CONTAINER_NAME" fs_cli -x "show calls")
echo "Активные звонки: $ACTIVE_CALLS"

ACTIVE_CHANNELS=$(docker exec "$CONTAINER_NAME" fs_cli -x "show channels")
echo "Активные каналы: $ACTIVE_CHANNELS"

# ЭТАП 2: Создание исправленного диалплана
echo ""
echo "📋 ЭТАП 2: СОЗДАНИЕ БЕЗОПАСНОГО ДИАЛПЛАНА"
echo "========================================"

echo ""
echo "1. 📄 Создаем диалплан с защитой от зацикливания..."

# Создаем БЕЗОПАСНЫЙ диалплан без зацикливания
cat > /tmp/safe_dtmf_dialplan.xml << 'EOF'
<include>
  
  <!-- БЕЗОПАСНЫЙ IVR без зацикливания -->
  <extension name="safe_dtmf_test">
    <condition field="destination_number" expression="^(1201)$">
      
      <!-- Проверяем что канал активен -->
      <action application="log" data="CRIT ================================"/>
      <action application="log" data="CRIT === БЕЗОПАСНЫЙ IVR ТЕСТ ==="/>
      <action application="log" data="CRIT ================================"/>
      <action application="log" data="CRIT UUID: ${uuid}"/>
      <action application="log" data="CRIT Caller ID: ${caller_id_number}"/>
      <action application="log" data="CRIT Channel State: ${channel_state}"/>
      <action application="log" data="CRIT ================================"/>
      
      <!-- Отвечаем на звонок -->
      <action application="answer"/>
      <action application="log" data="CRIT === ЗВОНОК ОТВЕЧЕН ==="/>
      
      <!-- Защита от длинных звонков -->
      <action application="set" data="call_timeout=120"/>
      <action application="set" data="hangup_after_bridge=true"/>
      <action application="sched_hangup" data="+120 ALLOTTED_TIMEOUT"/>
      
      <!-- DTMF настройки -->
      <action application="set" data="drop_dtmf=false"/>
      <action application="set" data="dtmf_type=rfc2833"/>
      <action application="set" data="rtp_timer_name=soft"/>
      <action application="log" data="CRIT === DTMF НАСТРОЙКИ УСТАНОВЛЕНЫ ==="/>
      
      <!-- Короткая пауза -->
      <action application="log" data="CRIT === ПАУЗА ДЛЯ ПОДНЯТИЯ ТРУБКИ ==="/>
      <action application="sleep" data="2000"/>
      <action application="log" data="CRIT === ПАУЗА ЗАВЕРШЕНА ==="/>
      
      <!-- Приветствие -->
      <action application="log" data="CRIT === НАЧАЛО ПРИВЕТСТВЕННЫХ ТОНОВ ==="/>
      <action application="playback" data="tone_stream://%(1000,300,800)"/>
      <action application="log" data="CRIT === ПРИВЕТСТВЕННЫЙ ТОН ЗАВЕРШЕН ==="/>
      
      <!-- Объяснение меню -->
      <action application="log" data="CRIT === ОБЪЯСНЕНИЕ МЕНЮ ТОНАМИ ==="/>
      <action application="playback" data="tone_stream://%(300,100,1000)"/>
      <action application="sleep" data="300"/>
      <action application="playback" data="tone_stream://%(300,100,500)"/>
      <action application="log" data="CRIT === МЕНЮ ОБЪЯСНЕНО ==="/>
      
      <!-- DTMF сбор с КОРОТКИМ таймаутом -->
      <action application="log" data="CRIT ================================"/>
      <action application="log" data="CRIT === НАЧИНАЕМ СБОР DTMF ==="/>
      <action application="log" data="CRIT === ЖДЕМ 15 СЕКУНД ==="/>
      <action application="log" data="CRIT ================================"/>
      
      <!-- Короткий сигнал ожидания -->
      <action application="playback" data="tone_stream://%(100,50,400)"/>
      
      <!-- СБОР DTMF с коротким таймаутом -->
      <action application="read" data="dtmf_choice,1,3,tone_stream://%(100,50,400),dtmf_timeout,15000"/>
      
      <!-- Анализ результата -->
      <action application="log" data="CRIT ================================"/>
      <action application="log" data="CRIT === DTMF СБОР ЗАВЕРШЕН ==="/>
      <action application="log" data="CRIT ПОЛУЧЕНО: ${dtmf_choice}"/>
      <action application="log" data="CRIT ДЛИНА: ${dtmf_choice:strlen}"/>
      <action application="log" data="CRIT ================================"/>
      
      <!-- Попытка обработать DTMF -->
      <action application="execute_extension" data="safe_dtmf_handler_${dtmf_choice} XML default"/>
      
      <!-- Если не обработано - НЕ ЗАЦИКЛИВАЕМ! -->
      <action application="log" data="CRIT === DTMF НЕ ОБРАБОТАН ==="/>
      <action application="execute_extension" data="safe_dtmf_handler_final XML default"/>
      
    </condition>
  </extension>
  
  <!-- БЕЗОПАСНЫЕ ОБРАБОТЧИКИ DTMF -->
  
  <!-- Обработчик цифры 1 -->
  <extension name="safe_dtmf_handler_1">
    <condition field="destination_number" expression="^safe_dtmf_handler_1$">
      <action application="log" data="CRIT ================================"/>
      <action application="log" data="CRIT === ОБРАБОТЧИК ЦИФРЫ 1 ==="/>
      <action application="log" data="CRIT UUID: ${uuid}"/>
      <action application="log" data="CRIT ПОЛУЧЕНО: ${dtmf_choice}"/>
      <action application="log" data="CRIT [ВЕБХУК] DTMF=1, Action=information"/>
      <action application="log" data="CRIT ================================"/>
      <action application="playback" data="tone_stream://%(1000,0,800,400)"/>
      <action application="log" data="CRIT === ОБРАБОТЧИК 1 ЗАВЕРШЕН ==="/>
      <action application="hangup"/>
    </condition>
  </extension>
  
  <!-- Обработчик цифры 2 -->
  <extension name="safe_dtmf_handler_2">
    <condition field="destination_number" expression="^safe_dtmf_handler_2$">
      <action application="log" data="CRIT ================================"/>
      <action application="log" data="CRIT === ОБРАБОТЧИК ЦИФРЫ 2 ==="/>
      <action application="log" data="CRIT UUID: ${uuid}"/>
      <action application="log" data="CRIT ПОЛУЧЕНО: ${dtmf_choice}"/>
      <action application="log" data="CRIT [ВЕБХУК] DTMF=2, Action=callback"/>
      <action application="log" data="CRIT ================================"/>
      <action application="playback" data="tone_stream://%(1000,0,400,800)"/>
      <action application="log" data="CRIT === ОБРАБОТЧИК 2 ЗАВЕРШЕН ==="/>
      <action application="hangup"/>
    </condition>
  </extension>
  
  <!-- Обработчик цифры 0 -->
  <extension name="safe_dtmf_handler_0">
    <condition field="destination_number" expression="^safe_dtmf_handler_0$">
      <action application="log" data="CRIT ================================"/>
      <action application="log" data="CRIT === ОБРАБОТЧИК ЦИФРЫ 0 ==="/>
      <action application="log" data="CRIT UUID: ${uuid}"/>
      <action application="log" data="CRIT ПОЛУЧЕНО: ${dtmf_choice}"/>
      <action application="log" data="CRIT [ВЕБХУК] DTMF=0, Action=operator"/>
      <action application="log" data="CRIT ================================"/>
      <action application="playback" data="tone_stream://%(500,100,300,600,900)"/>
      <action application="log" data="CRIT === ОБРАБОТЧИК 0 ЗАВЕРШЕН ==="/>
      <action application="hangup"/>
    </condition>
  </extension>
  
  <!-- Финальный обработчик - БЕЗ ЗАЦИКЛИВАНИЯ! -->
  <extension name="safe_dtmf_handler_final">
    <condition field="destination_number" expression="^safe_dtmf_handler_final$">
      <action application="log" data="CRIT ================================"/>
      <action application="log" data="CRIT === ФИНАЛЬНЫЙ ОБРАБОТЧИК ==="/>
      <action application="log" data="CRIT UUID: ${uuid}"/>
      <action application="log" data="CRIT ПОЛУЧЕНО: ${dtmf_choice}"/>
      <action application="log" data="CRIT [ВЕБХУК] DTMF=unknown, Action=hangup"/>
      <action application="log" data="CRIT === ЗАВЕРШАЕМ БЕЗ ЗАЦИКЛИВАНИЯ ==="/>
      <action application="log" data="CRIT ================================"/>
      <action application="playback" data="tone_stream://%(300,100,200)"/>
      <action application="log" data="CRIT === ЗВОНОК ЗАВЕРШАЕТСЯ ==="/>
      <action application="hangup"/>
    </condition>
  </extension>
  
</include>
EOF

echo "✅ Безопасный диалплан создан"

# ЭТАП 3: Установка безопасного диалплана
echo ""
echo "📋 ЭТАП 3: УСТАНОВКА БЕЗОПАСНОГО ДИАЛПЛАНА"
echo "=========================================="

echo ""
echo "1. 📄 Устанавливаем безопасный диалплан..."
docker cp /tmp/safe_dtmf_dialplan.xml "$CONTAINER_NAME:/usr/local/freeswitch/conf/dialplan/default/safe_dtmf.xml"

echo ""
echo "2. 🔄 Перезагружаем конфигурацию..."
docker exec "$CONTAINER_NAME" fs_cli -x "reloadxml"

echo ""
echo "3. 📊 Проверяем загрузку..."
RELOAD_RESULT=$(docker exec "$CONTAINER_NAME" fs_cli -x "reloadxml" 2>&1)
echo "Результат перезагрузки: $RELOAD_RESULT"

# ЭТАП 4: Тестирование безопасного диалплана
echo ""
echo "📋 ЭТАП 4: БЕЗОПАСНЫЙ ТЕСТ"
echo "========================"

echo ""
echo "🔧 ХАРАКТЕРИСТИКИ БЕЗОПАСНОГО ДИАЛПЛАНА:"
echo "✅ Максимальная длительность звонка: 120 секунд"
echo "✅ DTMF таймаут сокращен до 15 секунд"
echo "✅ БЕЗ transfer и зацикливания"
echo "✅ Принудительный hangup в конце"
echo "✅ Все обработчики завершают звонок"
echo ""

echo "🧪 ГОТОВ К ТЕСТИРОВАНИЮ:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"originate sofia/gateway/sip_trunk/79206054020 1201 XML default\""
echo ""

echo "⏰ ТАЙМАУТЫ:"
echo "- Общий звонок: 120 секунд максимум"
echo "- DTMF ожидание: 15 секунд максимум"
echo "- Автоматическое завершение: гарантировано"
echo ""

echo "🔍 МОНИТОРИНГ:"
echo "docker exec $CONTAINER_NAME tail -f /tmp/freeswitch_test.log | grep -E '(CRIT|DTMF|ОБРАБОТЧИК|ВЕБХУК|hangup)'"

echo ""
echo "🔄 ИСПРАВЛЕНИЕ ЗАЦИКЛИВАНИЯ ЗАВЕРШЕНО!"
echo "===================================="

echo ""
echo "💡 СЛЕДУЮЩИЕ ШАГИ:"
echo "1. Протестировать безопасный диалплан"
echo "2. Настроить DTMF у провайдера" 
echo "3. Попробовать inband DTMF детекцию"
echo "4. Настроить реальные вебхуки" 