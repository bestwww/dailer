#!/bin/bash

# 🔍 МИНИМАЛЬНАЯ ДИАГНОСТИКА IVR
# Проблема: IVR показывает успех в статистике, но звонок не приходит

CONTAINER_NAME="freeswitch-test"
PHONE_NUMBER="79206054020"

echo "🔍 МИНИМАЛЬНАЯ ДИАГНОСТИКА IVR"
echo "============================="
echo ""

echo "🚨 ПРОБЛЕМА:"
echo "- Статистика показывает успех ✅"
echo "- Звонок НЕ приходит на мобильный ❌"
echo "- IVR extension запускается, но падает"
echo ""

# ЭТАП 1: Создание МИНИМАЛЬНОГО IVR без Lua
echo "📋 ЭТАП 1: СОЗДАНИЕ МИНИМАЛЬНОГО IVR"
echo "=================================="

echo ""
echo "Создаем ПРОСТЕЙШИЙ IVR БЕЗ LUA..."

# Создаем минимальный диалплан только с базовыми действиями
cat > /tmp/minimal_dialplan.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<!--
  МИНИМАЛЬНЫЙ диалплан для диагностики IVR
  Убираем ВСЕ сложные элементы, только базовые действия
-->
<include>
  <!-- РАБОТАЮЩИЙ echo тест -->
  <extension name="echo">
    <condition field="destination_number" expression="^(echo|9196)$">
      <action application="answer"/>
      <action application="echo"/>
    </condition>
  </extension>

  <!-- ТЕСТ 1: Простейший IVR - только answer -->
  <extension name="ivr_test1">
    <condition field="destination_number" expression="^(ivr_test1)$">
      <action application="answer"/>
    </condition>
  </extension>

  <!-- ТЕСТ 2: Answer + Sleep -->
  <extension name="ivr_test2">
    <condition field="destination_number" expression="^(ivr_test2)$">
      <action application="answer"/>
      <action application="sleep" data="5000"/>
    </condition>
  </extension>

  <!-- ТЕСТ 3: Answer + Sleep + Hangup -->
  <extension name="ivr_test3">
    <condition field="destination_number" expression="^(ivr_test3)$">
      <action application="answer"/>
      <action application="sleep" data="3000"/>
      <action application="hangup"/>
    </condition>
  </extension>

  <!-- ТЕСТ 4: Answer + Tone -->
  <extension name="ivr_test4">
    <condition field="destination_number" expression="^(ivr_test4)$">
      <action application="answer"/>
      <action application="sleep" data="1000"/>
      <action application="playback" data="tone_stream://%(1000,500,800)"/>
      <action application="sleep" data="2000"/>
      <action application="hangup"/>
    </condition>
  </extension>

  <!-- ТЕСТ 5: Оригинальный IVR menu БЕЗ lua -->
  <extension name="ivr_menu">
    <condition field="destination_number" expression="^(ivr_menu)$">
      <action application="answer"/>
      <action application="sleep" data="2000"/>
      <action application="set" data="caller_id_name=79058615815"/>
      <action application="set" data="caller_id_number=79058615815"/>
      <action application="playback" data="tone_stream://%(1000,500,800)"/>
      <action application="sleep" data="3000"/>
      <action application="hangup"/>
    </condition>
  </extension>

  <!-- Исходящие звонки (БЕЗ ИЗМЕНЕНИЙ) -->
  <extension name="outbound_calls">
    <condition field="destination_number" expression="^(\d{11})$">
      <action application="set" data="caller_id_name=79058615815"/>
      <action application="set" data="caller_id_number=79058615815"/>
      <action application="set" data="hangup_after_bridge=true"/>
      <action application="bridge" data="sofia/gateway/sip_trunk/$1"/>
    </condition>
  </extension>

</include>
EOF

echo "✅ Минимальный диалплан создан"

# ЭТАП 2: Установка минимального диалплана
echo ""
echo "📋 ЭТАП 2: УСТАНОВКА МИНИМАЛЬНОГО ДИАЛПЛАНА"
echo "=========================================="

echo ""
echo "Устанавливаем минимальный диалплан..."
docker cp /tmp/minimal_dialplan.xml "$CONTAINER_NAME:/usr/local/freeswitch/conf/dialplan/default.xml"

echo "Перезагружаем конфигурацию..."
RELOAD_RESULT=$(docker exec "$CONTAINER_NAME" fs_cli -x "reloadxml" 2>&1)
echo "Результат: $RELOAD_RESULT"

# ЭТАП 3: Пошаговое тестирование
echo ""
echo "🧪 ЭТАП 3: ПОШАГОВОЕ ТЕСТИРОВАНИЕ"
echo "==============================="

# Функция для тестирования extension
test_extension() {
    local ext_name="$1"
    local description="$2"
    local wait_time="$3"
    
    echo ""
    echo "Тест: $ext_name - $description"
    echo "$(printf '%.0s-' {1..50})"
    
    # Статистика ДО
    STATS_BEFORE=$(docker exec "$CONTAINER_NAME" fs_cli -x "sofia status gateway internal::sip_trunk" | grep "CallsOUT" | head -1 | awk '{print $2}')
    
    # Выполняем тест
    TEST_RESULT=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/$PHONE_NUMBER $ext_name" 2>&1)
    echo "Результат: $TEST_RESULT"
    
    # Извлекаем UUID
    TEST_UUID=$(echo "$TEST_RESULT" | grep -o '+OK [a-f0-9-]*' | awk '{print $2}')
    echo "UUID: $TEST_UUID"
    
    # Ждем
    echo "Ожидание $wait_time секунд..."
    sleep $wait_time
    
    # Статистика ПОСЛЕ  
    STATS_AFTER=$(docker exec "$CONTAINER_NAME" fs_cli -x "sofia status gateway internal::sip_trunk" | grep "CallsOUT" | head -1 | awk '{print $2}')
    FAILED_AFTER=$(docker exec "$CONTAINER_NAME" fs_cli -x "sofia status gateway internal::sip_trunk" | grep "FailedCallsOUT" | awk '{print $2}')
    
    NEW_CALLS=$((STATS_AFTER - STATS_BEFORE))
    
    echo "📊 Результат:"
    echo "  - Новых звонков: $NEW_CALLS"
    echo "  - Всего провалов: $FAILED_AFTER"
    
    if [ $NEW_CALLS -gt 0 ]; then
        echo "  ✅ Тест ПРОШЕЛ в статистике"
        echo ""
        echo "  ❓ ПОЛУЧИЛИ ЛИ ЗВОНОК НА МОБИЛЬНЫЙ?"
        read -p "  Введите да/нет: " PHONE_RESULT
        
        if [[ "$PHONE_RESULT" =~ ^[ДдYy] ]]; then
            echo "  🎉 ЗВОНОК ПРИШЕЛ! Extension работает!"
            return 0
        else
            echo "  ❌ Звонок НЕ пришел (статистика лжет)"
            return 1
        fi
    else
        echo "  ❌ Тест НЕ прошел (статистика тоже показывает провал)"
        return 1
    fi
}

# Выполняем пошаговое тестирование
echo ""
echo "Начинаем пошаговое тестирование..."
echo "На каждый тест отвечайте получили ли звонок на мобильный"

# Тест 1: Простейший - только answer
test_extension "ivr_test1" "Только answer (без hangup)" 8

# Тест 2: Answer + Sleep  
test_extension "ivr_test2" "Answer + Sleep 5 секунд" 10

# Тест 3: Answer + Sleep + Hangup
test_extension "ivr_test3" "Answer + Sleep + Hangup" 8

# Тест 4: Answer + Tone
test_extension "ivr_test4" "Answer + Tone + Hangup" 10

# Тест 5: Финальный IVR
test_extension "ivr_menu" "Полный IVR БЕЗ Lua" 10

# ЭТАП 4: Анализ результатов
echo ""
echo "📊 ЭТАП 4: ФИНАЛЬНАЯ СТАТИСТИКА"
echo "============================="

echo ""
echo "📊 Общая статистика после тестов:"
FINAL_STATS=$(docker exec "$CONTAINER_NAME" fs_cli -x "sofia status gateway internal::sip_trunk" | grep -E "(CallsOUT|FailedCallsOUT)")
echo "$FINAL_STATS"

echo ""
echo "💡 АНАЛИЗ И ДИАГНОЗ"
echo "=================="

echo ""
echo "🔍 ВОЗМОЖНЫЕ ПРИЧИНЫ ПРОБЛЕМЫ:"
echo ""
echo "1. 📞 ПРОВАЙДЕР БЛОКИРУЕТ:"
echo "   - Некоторые типы звонков проходят (&echo)"
echo "   - Другие блокируются (IVR с длительными операциями)"
echo ""
echo "2. ⏱️ TIMING ПРОБЛЕМЫ:"
echo "   - FreeSWITCH считает звонок успешным"
echo "   - Но провайдер разрывает соединение"
echo ""
echo "3. 🎵 AUDIO ПРОБЛЕМЫ:"
echo "   - Playback операции вызывают разрыв"
echo "   - Некоторые кодеки не поддерживаются"
echo ""
echo "4. 📋 SIP PROTOCOL ПРОБЛЕМЫ:"
echo "   - Неправильная последовательность SIP сообщений"
echo "   - Конфликт с настройками провайдера"

echo ""
echo "🔧 СЛЕДУЮЩИЕ ШАГИ:"
echo ""
echo "1. Если ivr_test1 (только answer) РАБОТАЕТ:"
echo "   - Проблема в дополнительных операциях (sleep/playback)"
echo ""
echo "2. Если НИ ОДИН тест не работает:"
echo "   - Проблема в самом механизме originate"
echo ""
echo "3. Если echo работает, а остальные нет:"
echo "   - Провайдер блокирует определенные типы звонков"

echo ""
echo "📋 КОМАНДЫ ДЛЯ РУЧНОЙ ПРОВЕРКИ:"
echo "=============================="

echo ""
echo "# Повторить минимальный тест:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"originate sofia/gateway/sip_trunk/$PHONE_NUMBER ivr_test1\""
echo ""
echo "# Проверить echo (должен работать):"
echo "docker exec $CONTAINER_NAME fs_cli -x \"originate sofia/gateway/sip_trunk/$PHONE_NUMBER &echo\""
echo ""
echo "# Восстановить диалплан из бэкапа:"
echo "docker exec $CONTAINER_NAME cp /usr/local/freeswitch/conf/dialplan/default.xml.backup /usr/local/freeswitch/conf/dialplan/default.xml"

echo ""
echo "✅ Минимальная диагностика завершена!" 