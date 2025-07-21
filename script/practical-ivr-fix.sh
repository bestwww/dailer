#!/bin/bash

# 🎯 ПРАКТИЧНЫЙ IVR С РЕАЛЬНЫМИ ТАЙМАУТАМИ
# Исправление проблемы слишком быстрого завершения

CONTAINER_NAME="freeswitch-test"
PHONE_NUMBER="79206054020"

echo "🎯 ПРАКТИЧНЫЙ IVR С РЕАЛЬНЫМИ ТАЙМАУТАМИ"
echo "======================================"
echo ""

echo "🔍 ПРОБЛЕМА ОБНАРУЖЕНА:"
echo "- Звонок завершается через 2-3 секунды"
echo "- Слишком агрессивные таймауты"
echo "- Нет времени поднять трубку"
echo "- Нужны ПРАКТИЧНЫЕ настройки"
echo ""

# ЭТАП 1: Создание практичного диалплана
echo "📋 ЭТАП 1: ПРАКТИЧНЫЙ ДИАЛПЛАН"
echo "============================="

echo ""
echo "Создаем диалплан с реальными таймаутами для пользователей..."

# Создаем практичный диалплан
cat > /tmp/practical_dialplan.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<!--
  ПРАКТИЧНЫЙ IVR ДИАЛПЛАН ДЛЯ РЕАЛЬНОГО ИСПОЛЬЗОВАНИЯ
  Достаточно времени для поднятия трубки и взаимодействия
-->
<include>
  <context name="default">
    
    <!-- Echo тест с разумным таймаутом -->
    <extension name="echo_test">
      <condition field="destination_number" expression="^(echo|9196)$">
        <action application="answer"/>
        <action application="set" data="call_timeout=300"/>
        <action application="set" data="hangup_after_bridge=true"/>
        <!-- 5 минут для echo теста -->
        <action application="sched_hangup" data="+300 ALLOTTED_TIMEOUT"/>
        <action application="echo"/>
      </condition>
    </extension>

    <!-- ПРАКТИЧНЫЙ IVR для реального использования -->
    <extension name="practical_ivr">
      <condition field="destination_number" expression="^(1201)$">
        <action application="answer"/>
        <action application="log" data="INFO === ПРАКТИЧНЫЙ IVR ЗАПУЩЕН ==="/>
        
        <!-- РАЗУМНЫЕ таймауты -->
        <action application="set" data="call_timeout=600"/>
        <action application="set" data="hangup_after_bridge=true"/>
        <!-- 10 минут максимум для полного взаимодействия -->
        <action application="sched_hangup" data="+600 ALLOTTED_TIMEOUT"/>
        
        <!-- Пауза для поднятия трубки -->
        <action application="sleep" data="3000"/>
        
        <!-- Приветственное сообщение -->
        <action application="playback" data="tone_stream://%(2000,500,800)"/>
        <action application="sleep" data="1000"/>
        
        <!-- Объяснение меню -->
        <action application="playback" data="tone_stream://%(500,200,1000)"/>
        <action application="sleep" data="500"/>
        <action application="playback" data="tone_stream://%(500,200,500)"/>
        <action application="sleep" data="500"/>
        <action application="playback" data="tone_stream://%(500,200,300)"/>
        <action application="sleep" data="1000"/>
        
        <!-- Сбор DTMF с ДЛИТЕЛЬНЫМ таймаутом -->
        <action application="read" data="choice,1,3,tone_stream://%(200,100,400),choice,30000"/>
        <action application="log" data="INFO Выбор пользователя: ${choice}"/>
        
        <!-- Проверка выбора -->
        <action application="execute_extension" data="choice_${choice} XML default"/>
        
        <!-- Если нет выбора - повтор меню -->
        <action application="transfer" data="1201 XML default"/>
      </condition>
    </extension>

    <!-- Опция 1: Информация -->
    <extension name="choice_1">
      <condition field="destination_number" expression="^choice_1$">
        <action application="log" data="INFO Выбрана опция 1 - Информация"/>
        <action application="set" data="hangup_after_bridge=true"/>
        
        <!-- Длинное информационное сообщение -->
        <action application="playback" data="tone_stream://%(3000,500,1000)"/>
        <action application="sleep" data="2000"/>
        <action application="playback" data="tone_stream://%(1000,200,800)"/>
        <action application="sleep" data="1000"/>
        <action application="playback" data="tone_stream://%(1000,200,600)"/>
        <action application="sleep" data="2000"/>
        
        <!-- Возврат в главное меню -->
        <action application="transfer" data="1201 XML default"/>
      </condition>
    </extension>

    <!-- Опция 2: Поддержка -->
    <extension name="choice_2">
      <condition field="destination_number" expression="^choice_2$">
        <action application="log" data="INFO Выбрана опция 2 - Поддержка"/>
        <action application="set" data="hangup_after_bridge=true"/>
        
        <!-- Сообщение поддержки -->
        <action application="playback" data="tone_stream://%(2000,500,500)"/>
        <action application="sleep" data="1000"/>
        <action application="playback" data="tone_stream://%(1000,300,400)"/>
        <action application="sleep" data="2000"/>
        
        <!-- Можно добавить перевод на оператора -->
        <action application="transfer" data="1201 XML default"/>
      </condition>
    </extension>

    <!-- Опция 9: Эхо тест -->
    <extension name="choice_9">
      <condition field="destination_number" expression="^choice_9$">
        <action application="log" data="INFO Выбрана опция 9 - Эхо тест"/>
        <action application="set" data="hangup_after_bridge=true"/>
        <!-- 3 минуты для эхо теста -->
        <action application="sched_hangup" data="+180 ALLOTTED_TIMEOUT"/>
        
        <!-- Объяснение эхо теста -->
        <action application="playbook" data="tone_stream://%(1000,200,600)"/>
        <action application="sleep" data="1000"/>
        <action application="echo"/>
      </condition>
    </extension>

    <!-- Опция 0: Завершение звонка -->
    <extension name="choice_0">
      <condition field="destination_number" expression="^choice_0$">
        <action application="log" data="INFO Выбрана опция 0 - Завершение"/>
        <action application="playback" data="tone_stream://%(1000,500,300)"/>
        <action application="sleep" data="1000"/>
        <action application="hangup" data="NORMAL_CLEARING"/>
      </condition>
    </extension>

    <!-- Обработка неверного выбора -->
    <extension name="choice_">
      <condition field="destination_number" expression="^choice_$">
        <action application="log" data="INFO Неверный выбор или тайм-аут"/>
        <action application="playback" data="tone_stream://%(500,200,200)"/>
        <action application="sleep" data="1000"/>
        <!-- Возврат в главное меню -->
        <action application="transfer" data="1201 XML default"/>
      </condition>
    </extension>

    <!-- БЕЗОПАСНЫЕ исходящие звонки -->
    <extension name="outbound_calls">
      <condition field="destination_number" expression="^(\d{11})$">
        <action application="set" data="caller_id_name=79058615815"/>
        <action application="set" data="caller_id_number=79058615815"/>
        
        <!-- ПРАКТИЧНЫЕ таймауты -->
        <action application="set" data="call_timeout=300"/>
        <action application="set" data="hangup_after_bridge=true"/>
        <action application="set" data="bridge_answer_timeout=60"/>
        
        <action application="bridge" data="sofia/gateway/sip_trunk/$1"/>
        
        <!-- Завершение если bridge не удался -->
        <action application="hangup" data="NO_ROUTE_DESTINATION"/>
      </condition>
    </extension>

  </context>
</include>
EOF

echo "✅ Практичный диалплан создан"

# ЭТАП 2: Установка практичного диалплана
echo ""
echo "📋 ЭТАП 2: УСТАНОВКА ПРАКТИЧНОГО ДИАЛПЛАНА"
echo "========================================"

echo ""
echo "1. 📄 Устанавливаем практичный диалплан..."
docker cp /tmp/practical_dialplan.xml "$CONTAINER_NAME:/usr/local/freeswitch/conf/dialplan/default.xml"

echo ""
echo "2. 🔄 Перезагружаем конфигурацию..."
RELOAD_RESULT=$(docker exec "$CONTAINER_NAME" fs_cli -x "reloadxml" 2>&1)
echo "Результат: $RELOAD_RESULT"

# ЭТАП 3: Тестирование практичного IVR
echo ""
echo "🧪 ЭТАП 3: ТЕСТИРОВАНИЕ ПРАКТИЧНОГО IVR"
echo "====================================="

echo ""
echo "1. 🔍 Проверка отсутствия активных звонков..."
CALLS_CHECK=$(docker exec "$CONTAINER_NAME" fs_cli -x "show calls count" 2>&1)
echo "Активных звонков: $CALLS_CHECK"

echo ""
echo "2. 🧪 Тест практичного IVR..."
echo "⏰ Теперь у вас будет достаточно времени:"
echo "- 3 секунды на поднятие трубки"
echo "- 30 секунд на выбор опции"
echo "- 10 минут максимальное время звонка"
echo ""

PRACTICAL_TEST=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/$PHONE_NUMBER 1201 XML default" 2>&1)
echo "Тест практичного IVR: $PRACTICAL_TEST"

echo ""
echo "⏰ ВРЕМЯ ДЛЯ ТЕСТИРОВАНИЯ:"
echo "- Поднимите трубку (есть 3 сек)"
echo "- Послушайте приветственные тоны"
echo "- Нажмите 1, 2, 9 или 0"
echo "- Проверьте навигацию по меню"
echo ""

sleep 60

echo ""
echo "3. 📊 Проверка состояния после теста..."
CALLS_AFTER_TEST=$(docker exec "$CONTAINER_NAME" fs_cli -x "show calls count" 2>&1)
echo "Звонков после теста: $CALLS_AFTER_TEST"

echo ""
echo "❓ КАК ПРОШЛО ТЕСТИРОВАНИЕ ПРАКТИЧНОГО IVR?"
echo "1. Успели поднять трубку?"
echo "2. Слышали тоны меню?"
echo "3. Смогли выбрать опции?"
echo "4. Работала навигация?"
read -p "Введите да/нет: " PRACTICAL_RESULT

# ЭТАП 4: Результаты и рекомендации
echo ""
echo "📋 ЭТАП 4: РЕЗУЛЬТАТЫ И РЕКОМЕНДАЦИИ"
echo "=================================="

if [[ "$PRACTICAL_RESULT" =~ ^[ДдYy] ]]; then
    echo ""
    echo "🎉 ОТЛИЧНО! ПРАКТИЧНЫЙ IVR РАБОТАЕТ!"
    echo ""
    echo "✅ ИСПРАВЛЕНИЯ ПРИМЕНЕНЫ:"
    echo "- Увеличено время поднятия трубки: 3 секунды"
    echo "- Время выбора опции: 30 секунд"
    echo "- Максимальное время звонка: 10 минут"
    echo "- Возврат в меню при неверном выборе"
    echo "- Практичные таймауты для реального использования"
    echo ""
    echo "🎯 СТРУКТУРА МЕНЮ:"
    echo "1 - Информация (с возвратом в меню)"
    echo "2 - Поддержка (с возвратом в меню)"
    echo "9 - Эхо тест (3 минуты)"
    echo "0 - Завершить звонок"
    echo "Нет ввода - повтор меню"
    echo ""
    echo "💻 КОМАНДЫ ДЛЯ BACKEND:"
    echo ""
    echo "// ПРАКТИЧНЫЙ Node.js код:"
    echo "const callResult = await executeCommand("
    echo "    'docker exec freeswitch-test fs_cli -x \"originate sofia/gateway/sip_trunk/' + phoneNumber + ' 1201 XML default\"'"
    echo ");"
    echo ""
    echo "// Мониторинг (проверка через 5 минут):"
    echo "if (callResult.includes('+OK')) {"
    echo "    console.log('Практичный IVR звонок запущен');"
    echo "    setTimeout(() => {"
    echo "        checkCallStatus(callResult.match(/[a-f0-9-]{36}/)[0]);"
    echo "    }, 300000); // Проверка через 5 минут"
    echo "}"
    
else
    echo ""
    echo "🔧 ДОПОЛНИТЕЛЬНАЯ НАСТРОЙКА НУЖНА"
    echo ""
    echo "Возможные проблемы:"
    echo "1. Нужно больше времени на поднятие трубки"
    echo "2. Тоны слишком быстрые/короткие"
    echo "3. Провайдер имеет другие ограничения"
    echo ""
    echo "Попробуйте:"
    echo "1. Увеличить начальную паузу до 5-10 секунд"
    echo "2. Сделать тоны длиннее"
    echo "3. Добавить голосовые сообщения вместо тонов"
fi

echo ""
echo "📋 КОМАНДЫ ДЛЯ УПРАВЛЕНИЯ:"
echo "========================"
echo ""
echo "# Тест практичного IVR:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"originate sofia/gateway/sip_trunk/$PHONE_NUMBER 1201 XML default\""
echo ""
echo "# Проверка активных звонков:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"show calls count\""
echo ""
echo "# Завершение конкретного звонка:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"uuid_kill <UUID>\""
echo ""
echo "# Завершение всех звонков (экстренно):"
echo "docker exec $CONTAINER_NAME fs_cli -x \"hupall MANAGER_REQUEST\""

echo ""
echo "⏰ НОВЫЕ ТАЙМАУТЫ:"
echo "================="
echo ""
echo "✅ ПРАКТИЧНЫЕ настройки:"
echo "- Поднятие трубки: 3 секунды паузы"
echo "- Выбор опции: 30 секунд"
echo "- Эхо тест: 3 минуты"
echo "- Максимальный звонок: 10 минут"
echo "- Информационные сообщения: достаточное время"
echo "- Автоматический возврат в меню"

echo ""
echo "🎯 ПРАКТИЧНЫЙ IVR НАСТРОЕН!"
echo "==========================" 