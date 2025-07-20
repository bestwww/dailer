#!/bin/bash

# 🔧 ИСПРАВЛЕНИЕ ROUTING ПРОБЛЕМЫ
# Критическая проблема: custom extensions не доходят до телефона

CONTAINER_NAME="freeswitch-test"
PHONE_NUMBER="79206054020"

echo "🔧 ИСПРАВЛЕНИЕ ROUTING ПРОБЛЕМЫ"
echo "=============================="
echo ""

echo "🚨 КРИТИЧЕСКАЯ ПРОБЛЕМА НАЙДЕНА:"
echo "- ❌ НИ ОДИН custom extension НЕ работает"
echo "- ✅ FreeSWITCH считает звонки успешными (статистика лжет)"
echo "- 🎯 Проблема в маршрутизации звонков"
echo ""

echo "📋 ДИАГНОЗ:"
echo "- &echo работает (прямое приложение)"
echo "- custom extensions НЕ работают (обрабатываются внутри FS)"
echo "- originate создает сессию, но НЕ звонит на телефон"
echo ""

# ЭТАП 1: Проверка текущего состояния
echo "📋 ЭТАП 1: ПРОВЕРКА ТЕКУЩЕГО СОСТОЯНИЯ"
echo "====================================="

echo ""
echo "1. 🧪 Тест: &echo все еще работает?"
echo "----------------------------------"
echo "Тестируем прямое приложение echo..."

ECHO_TEST=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/$PHONE_NUMBER &echo" 2>&1)
echo "Результат echo: $ECHO_TEST"

sleep 5

echo ""
echo "❓ ПОЛУЧИЛИ ЛИ ECHO ЗВОНОК НА МОБИЛЬНЫЙ?"
read -p "Введите да/нет: " ECHO_RESULT

if [[ "$ECHO_RESULT" =~ ^[ДдYy] ]]; then
    echo "✅ Echo работает - SIP trunk ОК"
    ECHO_WORKS=true
else
    echo "❌ Echo тоже НЕ работает - проблема глубже"
    ECHO_WORKS=false
fi

# ЭТАП 2: Проверка контекста диалплана
echo ""
echo "📋 ЭТАП 2: ДИАГНОСТИКА КОНТЕКСТА"
echo "==============================="

echo ""
echo "1. 🔍 Проверка SIP профиля context:"
echo "-----------------------------------"
SIP_CONTEXT=$(docker exec "$CONTAINER_NAME" grep -A5 -B5 "context.*default" /usr/local/freeswitch/conf/autoload_configs/sofia.conf.xml 2>/dev/null || echo "Не найден")
echo "SIP context: $SIP_CONTEXT"

echo ""
echo "2. 🔍 Проверка gateway context:"
echo "------------------------------"
GATEWAY_CONTEXT=$(docker exec "$CONTAINER_NAME" fs_cli -x "sofia status gateway internal::sip_trunk" | grep -i context)
echo "Gateway context: $GATEWAY_CONTEXT"

# ЭТАП 3: Альтернативные подходы
echo ""
echo "📋 ЭТАП 3: АЛЬТЕРНАТИВНЫЕ ПОДХОДЫ"
echo "==============================="

echo ""
echo "Создаем НОВЫЙ подход - прямой bridge..."

# Создаем диалплан с прямым bridge
cat > /tmp/bridge_dialplan.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<!--
  ИСПРАВЛЕННЫЙ диалплан с прямым bridge
  Проблема: originate не устанавливает соединение с телефоном
  Решение: Использовать bridge для принудительного соединения
-->
<include>
  <!-- РАБОТАЮЩИЙ echo тест -->
  <extension name="echo">
    <condition field="destination_number" expression="^(echo|9196)$">
      <action application="answer"/>
      <action application="echo"/>
    </condition>
  </extension>

  <!-- НОВЫЙ ПОДХОД: IVR через bridge -->
  <extension name="ivr_bridge">
    <condition field="destination_number" expression="^(ivr_bridge)$">
      <!-- НЕ отвечаем сразу, сначала устанавливаем соединение -->
      <action application="set" data="caller_id_name=79058615815"/>
      <action application="set" data="caller_id_number=79058615815"/>
      
      <!-- Прямой bridge к телефону -->
      <action application="bridge" data="sofia/gateway/sip_trunk/79206054020"/>
      
      <!-- После соединения - IVR логика -->
      <action application="answer"/>
      <action application="sleep" data="1000"/>
      <action application="playback" data="tone_stream://%(1000,500,800)"/>
      <action application="sleep" data="3000"/>
      <action application="hangup"/>
    </condition>
  </extension>

  <!-- ТЕСТ: Простой bridge -->
  <extension name="simple_bridge">
    <condition field="destination_number" expression="^(simple_bridge)$">
      <action application="set" data="caller_id_name=79058615815"/>
      <action application="set" data="caller_id_number=79058615815"/>
      <action application="bridge" data="sofia/gateway/sip_trunk/79206054020"/>
    </condition>
  </extension>

  <!-- Исходящие звонки (ОРИГИНАЛ) -->
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

echo "✅ Bridge диалплан создан"

echo ""
echo "Устанавливаем bridge диалплан..."
docker cp /tmp/bridge_dialplan.xml "$CONTAINER_NAME:/usr/local/freeswitch/conf/dialplan/default.xml"

echo "Перезагружаем конфигурацию..."
RELOAD_RESULT=$(docker exec "$CONTAINER_NAME" fs_cli -x "reloadxml" 2>&1)
echo "Результат: $RELOAD_RESULT"

# ЭТАП 4: Тестирование bridge подхода
echo ""
echo "🧪 ЭТАП 4: ТЕСТИРОВАНИЕ BRIDGE ПОДХОДА"
echo "===================================="

echo ""
echo "Тест 1: Простой bridge"
echo "----------------------"
echo "Команда: originate loopback/simple_bridge/default"

BRIDGE_TEST=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate loopback/simple_bridge/default &park" 2>&1)
echo "Результат: $BRIDGE_TEST"

sleep 8

echo ""
echo "❓ ПОЛУЧИЛИ ЛИ BRIDGE ЗВОНОК НА МОБИЛЬНЫЙ?"
read -p "Введите да/нет: " BRIDGE_RESULT

if [[ "$BRIDGE_RESULT" =~ ^[ДдYy] ]]; then
    echo "🎉 BRIDGE РАБОТАЕТ!"
    BRIDGE_WORKS=true
else
    echo "❌ Bridge тоже не работает"
    BRIDGE_WORKS=false
fi

# ЭТАП 5: Альтернативный прямой подход
echo ""
echo "📋 ЭТАП 5: ПРЯМОЙ ПОДХОД БЕЗ ДИАЛПЛАНА"
echo "===================================="

echo ""
echo "Тест 2: Прямой originate с inline applications"
echo "----------------------------------------------"

INLINE_TEST=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/$PHONE_NUMBER '&answer,&sleep:2000,&playback:tone_stream://%(1000,500,800),&sleep:3000'" 2>&1)
echo "Результат inline: $INLINE_TEST"

sleep 10

echo ""
echo "❓ ПОЛУЧИЛИ ЛИ INLINE ЗВОНОК НА МОБИЛЬНЫЙ?"
read -p "Введите да/нет: " INLINE_RESULT

if [[ "$INLINE_RESULT" =~ ^[ДдYy] ]]; then
    echo "🎉 INLINE ПОДХОД РАБОТАЕТ!"
    INLINE_WORKS=true
else
    echo "❌ Inline тоже не работает"
    INLINE_WORKS=false
fi

# ЭТАП 6: Финальный анализ
echo ""
echo "📊 ЭТАП 6: ФИНАЛЬНЫЙ АНАЛИЗ"
echo "=========================="

echo ""
echo "📊 Статистика всех тестов:"
FINAL_STATS=$(docker exec "$CONTAINER_NAME" fs_cli -x "sofia status gateway internal::sip_trunk" | grep -E "(CallsOUT|FailedCallsOUT)")
echo "$FINAL_STATS"

echo ""
echo "💡 ДИАГНОЗ И РЕШЕНИЕ"
echo "=================="

echo ""
echo "🔍 РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ:"
echo ""

if [ "$ECHO_WORKS" = true ]; then
    echo "✅ Echo работает - SIP trunk исправен"
else
    echo "❌ Echo НЕ работает - SIP trunk проблема"
fi

if [ "$BRIDGE_WORKS" = true ]; then
    echo "✅ Bridge работает - можно использовать bridge подход"
elif [ "$INLINE_WORKS" = true ]; then
    echo "✅ Inline работает - можно использовать inline applications"
else
    echo "❌ Все подходы НЕ работают - критическая проблема"
fi

echo ""
echo "🎯 РЕКОМЕНДУЕМОЕ РЕШЕНИЕ:"
echo ""

if [ "$INLINE_WORKS" = true ]; then
    echo "🚀 ИСПОЛЬЗУЙТЕ INLINE ПОДХОД:"
    echo "docker exec $CONTAINER_NAME fs_cli -x \"originate sofia/gateway/sip_trunk/$PHONE_NUMBER '&answer,&sleep:2000,&playbook:your_audio.wav'\""
    echo ""
    echo "Преимущества:"
    echo "- Обходит диалплан полностью"
    echo "- Прямое выполнение приложений"
    echo "- Максимальная совместимость с провайдером"
    
elif [ "$BRIDGE_WORKS" = true ]; then
    echo "🔧 ИСПОЛЬЗУЙТЕ BRIDGE ПОДХОД:"
    echo "- Создать extension с bridge"
    echo "- IVR логика после установки соединения"
    
elif [ "$ECHO_WORKS" = true ]; then
    echo "🎭 ОГРАНИЧЕННЫЙ РЕЖИМ:"
    echo "- Только встроенные приложения (&echo)"
    echo "- Кастомные extensions не поддерживаются провайдером"
    
else
    echo "💀 КРИТИЧЕСКАЯ ПРОБЛЕМА:"
    echo "- Возможно проблема в конфигурации SIP trunk"
    echo "- Проверить настройки провайдера"
    echo "- Связаться с технической поддержкой"
fi

echo ""
echo "📋 КОМАНДЫ ДЛЯ ДАЛЬНЕЙШЕГО ИСПОЛЬЗОВАНИЯ:"
echo "========================================"

echo ""
echo "# Рабочий IVR (если inline работает):"
echo "docker exec $CONTAINER_NAME fs_cli -x \"originate sofia/gateway/sip_trunk/$PHONE_NUMBER '&answer,&sleep:2000,&playback:tone_stream://%(1000,500,800)'\""
echo ""
echo "# Восстановить диалплан:"
echo "docker exec $CONTAINER_NAME cp /usr/local/freeswitch/conf/dialplan/default.xml.backup /usr/local/freeswitch/conf/dialplan/default.xml"
echo ""
echo "# Проверка echo:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"originate sofia/gateway/sip_trunk/$PHONE_NUMBER &echo\""

echo ""
echo "✅ Диагностика routing проблемы завершена!" 