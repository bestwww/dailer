#!/bin/bash

# 🔍 МОНИТОРИНГ DTMF НАЖАТИЙ В IVR
# Показывает все нажатые цифры и их обработку

CONTAINER_NAME="freeswitch-test"
PHONE_NUMBER="79206054020"

echo "🔍 МОНИТОРИНГ DTMF НАЖАТИЙ В IVR"
echo "=============================="
echo ""

echo "📋 ЧТО БУДЕМ ОТСЛЕЖИВАТЬ:"
echo "- Все нажатые DTMF цифры"
echo "- Обработку в диалплане"
echo "- Переходы между extensions"
echo "- Логи в реальном времени"
echo "- Подготовка к вебхукам"
echo ""

# ЭТАП 1: Настройка детального логирования
echo "📋 ЭТАП 1: НАСТРОЙКА ДЕТАЛЬНОГО ЛОГИРОВАНИЯ"
echo "==========================================="

echo ""
echo "1. 🔧 Включаем детальное DTMF логирование..."

# Включаем детальное логирование DTMF
docker exec "$CONTAINER_NAME" fs_cli -x "console loglevel debug"
docker exec "$CONTAINER_NAME" fs_cli -x "sofia loglevel all 9"

echo ""
echo "2. 📝 Создаем улучшенный диалплан с логированием DTMF..."

# Создаем диалплан с детальным логированием DTMF
cat > /tmp/dtmf_logging_dialplan.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<!--
  IVR ДИАЛПЛАН С ДЕТАЛЬНЫМ ЛОГИРОВАНИЕМ DTMF
  Показывает все нажатые цифры и их обработку
-->
<include>
  <context name="default">
    
    <!-- Echo тест с DTMF логированием -->
    <extension name="echo_test">
      <condition field="destination_number" expression="^(echo|9196)$">
        <action application="answer"/>
        <action application="log" data="INFO ===== ECHO TEST ЗАПУЩЕН ====="/>
        <action application="set" data="call_timeout=300"/>
        <action application="set" data="hangup_after_bridge=true"/>
        <action application="sched_hangup" data="+300 ALLOTTED_TIMEOUT"/>
        <action application="echo"/>
      </condition>
    </extension>

    <!-- IVR с детальным DTMF логированием -->
    <extension name="dtmf_monitored_ivr">
      <condition field="destination_number" expression="^(1201)$">
        <action application="answer"/>
        <action application="log" data="INFO ===== IVR DTMF МОНИТОРИНГ ЗАПУЩЕН ====="/>
        <action application="log" data="INFO UUID звонка: ${uuid}"/>
        <action application="log" data="INFO Caller ID: ${caller_id_number}"/>
        
        <!-- Глобальные настройки для мониторинга -->
        <action application="set" data="call_timeout=600"/>
        <action application="set" data="hangup_after_bridge=true"/>
        <action application="sched_hangup" data="+600 ALLOTTED_TIMEOUT"/>
        
        <!-- Включаем детальное логирование DTMF -->
        <action application="set" data="drop_dtmf=false"/>
        <action application="set" data="dtmf_type=rfc2833"/>
        
        <!-- Пауза для поднятия трубки -->
        <action application="sleep" data="3000"/>
        <action application="log" data="INFO Пауза завершена, начинаем IVR меню"/>
        
        <!-- Приветственное сообщение -->
        <action application="log" data="INFO Проигрываем приветственный тон"/>
        <action application="playback" data="tone_stream://%(2000,500,800)"/>
        <action application="sleep" data="1000"/>
        
        <!-- Объяснение меню тонами -->
        <action application="log" data="INFO Объясняем меню тонами"/>
        <action application="playback" data="tone_stream://%(500,200,1000)"/>
        <action application="sleep" data="500"/>
        <action application="playback" data="tone_stream://%(500,200,500)"/>
        <action application="sleep" data="500"/>
        <action application="playback" data="tone_stream://%(500,200,300)"/>
        <action application="sleep" data="1000"/>
        
        <!-- КРИТИЧЕСКИ ВАЖНО: Детальный сбор DTMF -->
        <action application="log" data="INFO Начинаем сбор DTMF, ждем 30 секунд"/>
        <action application="read" data="dtmf_choice,1,3,tone_stream://%(200,100,400),invalid_choice,30000"/>
        <action application="log" data="INFO DTMF получен: ${dtmf_choice}"/>
        <action application="log" data="INFO Длина DTMF: ${dtmf_choice:strlen}"/>
        
        <!-- Обработка полученного DTMF -->
        <action application="execute_extension" data="process_dtmf_${dtmf_choice} XML default"/>
        
        <!-- Если не обработано - возврат в меню -->
        <action application="log" data="INFO DTMF не обработан, возврат в меню"/>
        <action application="transfer" data="1201 XML default"/>
      </condition>
    </extension>

    <!-- ДЕТАЛЬНАЯ обработка DTMF опций -->
    
    <!-- Опция 1: Информация -->
    <extension name="process_dtmf_1">
      <condition field="destination_number" expression="^process_dtmf_1$">
        <action application="log" data="INFO ===== НАЖАТА ЦИФРА 1 - ИНФОРМАЦИЯ ====="/>
        <action application="log" data="INFO UUID: ${uuid}, Caller: ${caller_id_number}"/>
        <action application="log" data="INFO Время: ${strftime()}"/>
        <action application="set" data="dtmf_pressed=1"/>
        <action application="set" data="menu_option=information"/>
        
        <!-- Здесь будет вебхук в будущем -->
        <action application="log" data="INFO [ВЕБХУК] DTMF=1, Action=information, UUID=${uuid}"/>
        
        <!-- Информационное сообщение -->
        <action application="playback" data="tone_stream://%(3000,500,1000)"/>
        <action application="sleep" data="2000"/>
        <action application="playback" data="tone_stream://%(1000,200,800)"/>
        <action application="sleep" data="1000"/>
        <action application="playback" data="tone_stream://%(1000,200,600)"/>
        <action application="sleep" data="2000"/>
        
        <action application="log" data="INFO Опция 1 завершена, возврат в главное меню"/>
        <action application="transfer" data="1201 XML default"/>
      </condition>
    </extension>

    <!-- Опция 2: Поддержка -->
    <extension name="process_dtmf_2">
      <condition field="destination_number" expression="^process_dtmf_2$">
        <action application="log" data="INFO ===== НАЖАТА ЦИФРА 2 - ПОДДЕРЖКА ====="/>
        <action application="log" data="INFO UUID: ${uuid}, Caller: ${caller_id_number}"/>
        <action application="log" data="INFO Время: ${strftime()}"/>
        <action application="set" data="dtmf_pressed=2"/>
        <action application="set" data="menu_option=support"/>
        
        <!-- Здесь будет вебхук в будущем -->
        <action application="log" data="INFO [ВЕБХУК] DTMF=2, Action=support, UUID=${uuid}"/>
        
        <!-- Сообщение поддержки -->
        <action application="playback" data="tone_stream://%(2000,500,500)"/>
        <action application="sleep" data="1000"/>
        <action application="playback" data="tone_stream://%(1000,300,400)"/>
        <action application="sleep" data="2000"/>
        
        <action application="log" data="INFO Опция 2 завершена, возврат в главное меню"/>
        <action application="transfer" data="1201 XML default"/>
      </condition>
    </extension>

    <!-- Опция 9: Эхо тест -->
    <extension name="process_dtmf_9">
      <condition field="destination_number" expression="^process_dtmf_9$">
        <action application="log" data="INFO ===== НАЖАТА ЦИФРА 9 - ЭХО ТЕСТ ====="/>
        <action application="log" data="INFO UUID: ${uuid}, Caller: ${caller_id_number}"/>
        <action application="set" data="dtmf_pressed=9"/>
        <action application="set" data="menu_option=echo_test"/>
        
        <!-- Здесь будет вебхук в будущем -->
        <action application="log" data="INFO [ВЕБХУК] DTMF=9, Action=echo_test, UUID=${uuid}"/>
        
        <action application="sched_hangup" data="+180 ALLOTTED_TIMEOUT"/>
        <action application="playback" data="tone_stream://%(1000,200,600)"/>
        <action application="sleep" data="1000"/>
        <action application="echo"/>
      </condition>
    </extension>

    <!-- Опция 0: Завершение -->
    <extension name="process_dtmf_0">
      <condition field="destination_number" expression="^process_dtmf_0$">
        <action application="log" data="INFO ===== НАЖАТА ЦИФРА 0 - ЗАВЕРШЕНИЕ ====="/>
        <action application="log" data="INFO UUID: ${uuid}, Caller: ${caller_id_number}"/>
        <action application="set" data="dtmf_pressed=0"/>
        <action application="set" data="menu_option=hangup"/>
        
        <!-- Здесь будет вебхук в будущем -->
        <action application="log" data="INFO [ВЕБХУК] DTMF=0, Action=hangup, UUID=${uuid}"/>
        
        <action application="playback" data="tone_stream://%(1000,500,300)"/>
        <action application="sleep" data="1000"/>
        <action application="hangup" data="NORMAL_CLEARING"/>
      </condition>
    </extension>

    <!-- Обработка неверного выбора -->
    <extension name="process_dtmf_invalid_choice">
      <condition field="destination_number" expression="^process_dtmf_invalid_choice$">
        <action application="log" data="INFO ===== НЕВЕРНЫЙ ВЫБОР ИЛИ ТАЙМ-АУТ ====="/>
        <action application="log" data="INFO UUID: ${uuid}, Получено: ${dtmf_choice}"/>
        <action application="set" data="dtmf_pressed=invalid"/>
        
        <!-- Здесь будет вебхук в будущем -->
        <action application="log" data="INFO [ВЕБХУК] DTMF=invalid, Action=retry, UUID=${uuid}"/>
        
        <action application="playback" data="tone_stream://%(500,200,200)"/>
        <action application="sleep" data="1000"/>
        <action application="log" data="INFO Возврат в главное меню"/>
        <action application="transfer" data="1201 XML default"/>
      </condition>
    </extension>

    <!-- Пустой выбор (тайм-аут) -->
    <extension name="process_dtmf_">
      <condition field="destination_number" expression="^process_dtmf_$">
        <action application="log" data="INFO ===== ТАЙМ-АУТ: DTMF НЕ ПОЛУЧЕН ====="/>
        <action application="log" data="INFO UUID: ${uuid}, Тайм-аут после 30 секунд"/>
        <action application="set" data="dtmf_pressed=timeout"/>
        
        <!-- Здесь будет вебхук в будущем -->
        <action application="log" data="INFO [ВЕБХУК] DTMF=timeout, Action=retry, UUID=${uuid}"/>
        
        <action application="playback" data="tone_stream://%(500,200,200)"/>
        <action application="sleep" data="1000"/>
        <action application="log" data="INFO Возврат в главное меню после тайм-аута"/>
        <action application="transfer" data="1201 XML default"/>
      </condition>
    </extension>

    <!-- Исходящие звонки -->
    <extension name="outbound_calls">
      <condition field="destination_number" expression="^(\d{11})$">
        <action application="set" data="caller_id_name=79058615815"/>
        <action application="set" data="caller_id_number=79058615815"/>
        <action application="set" data="call_timeout=300"/>
        <action application="set" data="hangup_after_bridge=true"/>
        <action application="set" data="bridge_answer_timeout=60"/>
        <action application="bridge" data="sofia/gateway/sip_trunk/$1"/>
        <action application="hangup" data="NO_ROUTE_DESTINATION"/>
      </condition>
    </extension>

  </context>
</include>
EOF

echo "✅ Диалплан с DTMF мониторингом создан"

# ЭТАП 2: Установка мониторинга
echo ""
echo "📋 ЭТАП 2: УСТАНОВКА DTMF МОНИТОРИНГА"
echo "===================================="

echo ""
echo "1. 📄 Устанавливаем диалплан с мониторингом..."
docker cp /tmp/dtmf_logging_dialplan.xml "$CONTAINER_NAME:/usr/local/freeswitch/conf/dialplan/default.xml"

echo ""
echo "2. 🔄 Перезагружаем конфигурацию..."
RELOAD_RESULT=$(docker exec "$CONTAINER_NAME" fs_cli -x "reloadxml" 2>&1)
echo "Результат: $RELOAD_RESULT"

# ЭТАП 3: Интерактивное тестирование с мониторингом
echo ""
echo "🧪 ЭТАП 3: ИНТЕРАКТИВНОЕ ТЕСТИРОВАНИЕ"
echo "=================================="

echo ""
echo "🔍 ПОДГОТОВКА К МОНИТОРИНГУ:"
echo "1. Открываем логи в реальном времени"
echo "2. Запускаем тестовый звонок"
echo "3. Отслеживаем все DTMF нажатия"
echo ""

echo "📱 ИНСТРУКЦИИ ДЛЯ ТЕСТИРОВАНИЯ:"
echo "- Поднимите трубку через 3 секунды"
echo "- Послушайте приветственные тоны"
echo "- Нажмите разные цифры: 1, 2, 9, 0"
echo "- Попробуйте неверные цифры: 3, 4, 5"
echo "- Попробуйте не нажимать ничего (тайм-аут)"
echo ""

read -p "Готовы к тестированию? Нажмите Enter..."

echo ""
echo "1. 🚀 Запускаем тестовый звонок..."
TEST_CALL=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/$PHONE_NUMBER 1201 XML default" 2>&1)
echo "Звонок запущен: $TEST_CALL"

# Извлекаем UUID для мониторинга
UUID=$(echo "$TEST_CALL" | grep -o '+OK [a-f0-9-]\{36\}' | cut -d' ' -f2)
echo "UUID звонка: $UUID"

echo ""
echo "2. 📊 МОНИТОРИНГ ЛОГОВ В РЕАЛЬНОМ ВРЕМЕНИ..."
echo "=========================================="
echo ""
echo "🔍 Отслеживаем все события:"

# Мониторим логи в реальном времени
timeout 120 docker exec "$CONTAINER_NAME" fs_cli -x "console loglevel debug" &

echo ""
echo "📋 Следите за логами выше, они покажут:"
echo "- ===== IVR DTMF МОНИТОРИНГ ЗАПУЩЕН ====="
echo "- INFO DTMF получен: [ваша цифра]"
echo "- ===== НАЖАТА ЦИФРА [X] - [ДЕЙСТВИЕ] ====="
echo "- INFO [ВЕБХУК] DTMF=[X], Action=[action], UUID=[uuid]"
echo ""

sleep 30

# ЭТАП 4: Анализ результатов
echo ""
echo "📋 ЭТАП 4: АНАЛИЗ DTMF СОБЫТИЙ"
echo "============================="

echo ""
echo "3. 📊 Проверяем состояние звонка..."
CALL_STATUS=$(docker exec "$CONTAINER_NAME" fs_cli -x "show calls" 2>&1)
echo "Статус звонков: $CALL_STATUS"

echo ""
echo "4. 📝 Извлекаем DTMF события из логов..."

# Получаем последние логи с DTMF событиями
DTMF_LOGS=$(docker exec "$CONTAINER_NAME" fs_cli -x "show logs" 2>&1 | grep -E "(DTMF|НАЖАТА|ВЕБХУК)" | tail -20)
echo "DTMF события:"
echo "$DTMF_LOGS"

echo ""
echo "❓ РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ DTMF:"
echo "1. Видите ли логи с нажатыми цифрами?"
echo "2. Работают ли переходы между меню?"
echo "3. Отображаются ли [ВЕБХУК] сообщения?"
read -p "Введите да/нет: " DTMF_RESULT

# ЭТАП 5: Рекомендации для вебхуков
echo ""
echo "📋 ЭТАП 5: ПОДГОТОВКА К ВЕБХУКАМ"
echo "==============================="

if [[ "$DTMF_RESULT" =~ ^[ДдYy] ]]; then
    echo ""
    echo "🎉 ОТЛИЧНО! DTMF МОНИТОРИНГ РАБОТАЕТ!"
    echo ""
    echo "✅ ЧТО ОТСЛЕЖИВАЕТСЯ:"
    echo "- Все нажатые DTMF цифры"
    echo "- UUID каждого звонка"
    echo "- Время каждого действия"
    echo "- Переходы между меню"
    echo "- Таймауты и ошибки"
    echo ""
    echo "🔗 ГОТОВНОСТЬ К ВЕБХУКАМ:"
    echo "В логах видны строки [ВЕБХУК] - это места для интеграции"
    echo ""
    echo "📡 БУДУЩИЕ ВЕБХУКИ БУДУТ ОТПРАВЛЯТЬ:"
    echo "{"
    echo "  \"event\": \"dtmf_pressed\","
    echo "  \"uuid\": \"${UUID}\","
    echo "  \"caller_id\": \"79206054020\","
    echo "  \"dtmf\": \"1\","
    echo "  \"action\": \"information\","
    echo "  \"timestamp\": \"$(date)\""
    echo "}"
    
else
    echo ""
    echo "🔧 НУЖНА НАСТРОЙКА ЛОГИРОВАНИЯ"
    echo ""
    echo "Попробуйте:"
    echo "1. Увеличить уровень логирования"
    echo "2. Проверить работу DTMF на провайдере"
    echo "3. Тестировать с другими цифрами"
fi

echo ""
echo "📋 КОМАНДЫ ДЛЯ МОНИТОРИНГА DTMF:"
echo "==============================="
echo ""
echo "# Мониторинг логов в реальном времени:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"console loglevel debug\""
echo ""
echo "# Тест с DTMF мониторингом:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"originate sofia/gateway/sip_trunk/$PHONE_NUMBER 1201 XML default\""
echo ""
echo "# Поиск DTMF событий в логах:"
echo "docker exec $CONTAINER_NAME grep -i \"dtmf\\|нажата\\|вебхук\" /usr/local/freeswitch/log/freeswitch.log | tail -10"
echo ""
echo "# Показать активные звонки с переменными:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"show channels as xml\" | grep -E \"(uuid|dtmf|menu)\""

echo ""
echo "🔍 DTMF МОНИТОРИНГ НАСТРОЕН!"
echo "=========================="
echo ""
echo "💡 ТЕПЕРЬ ВЫ ВИДИТЕ ВСЕ НАЖАТЫЕ ЦИФРЫ!"
echo "📡 ГОТОВО К ИНТЕГРАЦИИ С ВЕБХУКАМИ!" 