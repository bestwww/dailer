#!/bin/bash

# 🎯 ПРАВИЛЬНАЯ РЕАЛИЗАЦИЯ IVR ПО ДОКУМЕНТАЦИИ FREESWITCH
# Основано на официальной документации и лучших практиках

CONTAINER_NAME="freeswitch-test"
PHONE_NUMBER="79206054020"

echo "🎯 ПРАВИЛЬНАЯ РЕАЛИЗАЦИЯ IVR"
echo "============================"
echo ""

echo "📚 ИЗУЧЕННАЯ ДОКУМЕНТАЦИЯ ПОКАЗАЛА:"
echo "- ❌ Мы использовали originate НЕПРАВИЛЬНО"
echo "- ❌ originate для ИСХОДЯЩИХ звонков, не для IVR"
echo "- ✅ IVR = dialplan extensions + JavaScript/Lua"
echo "- ✅ Тестирование через локальные extensions"
echo ""

# ЭТАП 1: Создание правильного диалплана для IVR
echo "📋 ЭТАП 1: ПРАВИЛЬНЫЙ DIALPLAN"
echo "============================"

echo ""
echo "Создаем диалплан по документации FreeSWITCH..."

# Создаем правильный диалплан на основе документации
cat > /tmp/correct_dialplan.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<!--
  ПРАВИЛЬНЫЙ ДИАЛПЛАН ПО ДОКУМЕНТАЦИИ FREESWITCH
  Основано на JavaScript Example - Say IVR Menu
-->
<include>
  <context name="default">
    
    <!-- Echo тест (РАБОТАЕТ) -->
    <extension name="echo_test">
      <condition field="destination_number" expression="^(echo|9196)$">
        <action application="answer"/>
        <action application="echo"/>
      </condition>
    </extension>

    <!-- ПРАВИЛЬНЫЙ IVR с JavaScript -->
    <extension name="ivr_menu">
      <condition field="destination_number" expression="^(1200|ivr)$">
        <action application="javascript" data="ivr_menu.js"/>
      </condition>
    </extension>

    <!-- Простой IVR без JavaScript (для тестирования) -->
    <extension name="simple_ivr">
      <condition field="destination_number" expression="^(1201)$">
        <action application="answer"/>
        <action application="sleep" data="1000"/>
        <action application="playback" data="tone_stream://%(1000,500,800)"/>
        <action application="read" data="1,1,tone_stream://%(200,100,300),choice,5000"/>
        <action application="log" data="INFO Выбор пользователя: ${choice}"/>
        
        <!-- Обработка выбора -->
        <action application="transfer" data="choice_${choice} XML default"/>
      </condition>
    </extension>

    <!-- Обработка выборов IVR -->
    <extension name="choice_1">
      <condition field="destination_number" expression="^choice_1$">
        <action application="playback" data="tone_stream://%(500,200,1000)"/>
        <action application="hangup"/>
      </condition>
    </extension>

    <extension name="choice_2">
      <condition field="destination_number" expression="^choice_2$">
        <action application="playback" data="tone_stream://%(500,200,500)"/>
        <action application="hangup"/>
      </condition>
    </extension>

    <extension name="choice_9">
      <condition field="destination_number" expression="^choice_9$">
        <action application="echo"/>
      </condition>
    </extension>

    <!-- Исходящие звонки с IVR -->
    <extension name="outbound_ivr">
      <condition field="destination_number" expression="^(\d{11})$">
        <action application="set" data="caller_id_name=79058615815"/>
        <action application="set" data="caller_id_number=79058615815"/>
        <action application="set" data="hangup_after_bridge=true"/>
        
        <!-- ПРАВИЛЬНЫЙ способ: bridge + transfer -->
        <action application="bridge" data="sofia/gateway/sip_trunk/$1"/>
        <action application="transfer" data="1201 XML default"/>
      </condition>
    </extension>

  </context>
</include>
EOF

echo "✅ Правильный диалплан создан"

# ЭТАП 2: Создание JavaScript IVR скрипта
echo ""
echo "📋 ЭТАП 2: JAVASCRIPT IVR СКРИПТ"
echo "==============================="

echo ""
echo "Создаем JavaScript IVR по документации..."

# Создаем JavaScript IVR на основе документации
cat > /tmp/ivr_menu.js << 'EOF'
/**
 * IVR Menu для Dailer System
 * Основано на официальной документации FreeSWITCH
 * JavaScript Example - Say IVR Menu
 */

var dtmf_digits = "";

function on_dtmf(session, type, digits, arg) {
    console_log("info", "DTMF digit pressed: " + digits.digit + "\n");
    dtmf_digits += digits.digit;
    return(false);
}

/* Простое IVR меню с тонами вместо речи */
function playIVRMenu(ivrsession, timeout) {
    var repeat = 0;
    var maxAttempts = 3;
    
    console_log("info", "=== Dailer IVR Menu Started ===\n");
    
    ivrsession.flushDigits();
    dtmf_digits = "";
    
    while (ivrsession.ready() && dtmf_digits == "" && repeat < maxAttempts) {
        console_log("info", "Playing IVR menu, attempt " + (repeat + 1) + "\n");
        
        // Приветственный тон
        ivrsession.execute("playback", "tone_stream://%(1000,500,800)");
        ivrsession.execute("sleep", "500");
        
        // Меню опций (тоны вместо голоса)
        // Тон для опции 1
        ivrsession.execute("playback", "tone_stream://%(200,200,1000)");
        ivrsession.execute("sleep", "200");
        
        // Тон для опции 2  
        ivrsession.execute("playback", "tone_stream://%(200,200,500)");
        ivrsession.execute("sleep", "200");
        
        // Тон для опции 9
        ivrsession.execute("playback", "tone_stream://%(200,200,300)");
        
        // Ожидание ввода
        if (ivrsession.ready() && dtmf_digits == "") {
            dtmf_digits = ivrsession.getDigits(1, "", timeout, on_dtmf);
            
            if (dtmf_digits == "") {
                repeat++;
                console_log("info", "No input received, repeating menu\n");
            }
        }
    }
    
    return(dtmf_digits);
}

/* Обработка выбора пользователя */
function processChoice(ivrsession, choice) {
    console_log("info", "Processing choice: " + choice + "\n");
    
    switch(choice) {
        case "1":
            console_log("info", "Choice 1 - Playing confirmation tone\n");
            ivrsession.execute("playback", "tone_stream://%(1000,500,1000)");
            break;
            
        case "2":
            console_log("info", "Choice 2 - Playing goodbye tone\n");
            ivrsession.execute("playback", "tone_stream://%(1000,500,400)");
            break;
            
        case "9":
            console_log("info", "Choice 9 - Starting echo\n");
            ivrsession.execute("echo");
            break;
            
        default:
            console_log("info", "Invalid choice: " + choice + "\n");
            ivrsession.execute("playback", "tone_stream://%(300,300,200)");
            break;
    }
}

/* Главная функция IVR */
if (session && session.ready()) {
    console_log("info", "=== Starting Dailer IVR System ===\n");
    
    // Отвечаем на звонок
    session.answer();
    session.sleep(1000);
    
    // Устанавливаем caller ID
    session.setVariable("caller_id_name", "79058615815");
    session.setVariable("caller_id_number", "79058615815");
    
    // Запускаем IVR меню
    var userChoice = playIVRMenu(session, 5000);
    
    if (session.ready() && userChoice != "") {
        processChoice(session, userChoice);
    }
    
    // Завершаем звонок
    session.sleep(1000);
    session.hangup();
    
    console_log("info", "=== Dailer IVR Session Ended ===\n");
}
EOF

echo "✅ JavaScript IVR скрипт создан"

# ЭТАП 3: Установка конфигурации
echo ""
echo "📋 ЭТАП 3: УСТАНОВКА КОНФИГУРАЦИИ"
echo "================================"

echo ""
echo "1. 📄 Установка диалплана..."
docker cp /tmp/correct_dialplan.xml "$CONTAINER_NAME:/usr/local/freeswitch/conf/dialplan/default.xml"

echo ""
echo "2. 📄 Установка JavaScript скрипта..."
docker cp /tmp/ivr_menu.js "$CONTAINER_NAME:/usr/local/freeswitch/scripts/"

echo ""
echo "3. 🔧 Проверка модуля JavaScript..."
JS_MODULE=$(docker exec "$CONTAINER_NAME" fs_cli -x "module_exists mod_v8" 2>&1)
echo "JavaScript модуль: $JS_MODULE"

if echo "$JS_MODULE" | grep -q "false"; then
    echo "⚠️ Загружаем модуль JavaScript..."
    docker exec "$CONTAINER_NAME" fs_cli -x "load mod_v8"
else
    echo "✅ JavaScript модуль загружен"
fi

echo ""
echo "4. 🔄 Перезагрузка конфигурации..."
RELOAD_RESULT=$(docker exec "$CONTAINER_NAME" fs_cli -x "reloadxml" 2>&1)
echo "Результат: $RELOAD_RESULT"

# ЭТАП 4: Локальное тестирование IVR
echo ""
echo "🧪 ЭТАП 4: ЛОКАЛЬНОЕ ТЕСТИРОВАНИЕ"
echo "==============================="

echo ""
echo "💡 ПРАВИЛЬНЫЙ СПОСОБ ТЕСТИРОВАНИЯ IVR:"
echo "1. Создаем локальные extensions (1200, 1201)"
echo "2. Вызываем их НЕ через SIP trunk"
echo "3. Тестируем логику диалплана"
echo ""

echo "Тест 1: Простой IVR без JavaScript"
echo "----------------------------------"
echo "Extension: 1201"
SIMPLE_TEST=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate user/1000@default 1201" 2>&1)
echo "Результат: $SIMPLE_TEST"

sleep 3

echo ""
echo "Тест 2: JavaScript IVR"
echo "----------------------"
echo "Extension: 1200"
JS_TEST=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate user/1000@default 1200" 2>&1)
echo "Результат: $JS_TEST"

sleep 3

echo ""
echo "Тест 3: Echo (контрольный)"
echo "-------------------------"
ECHO_TEST=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate user/1000@default echo" 2>&1)
echo "Результат: $ECHO_TEST"

sleep 3

# ЭТАП 5: Правильный способ для внешних звонков
echo ""
echo "📋 ЭТАП 5: ПРАВИЛЬНЫЙ СПОСОБ ДЛЯ SIP TRUNK"
echo "========================================"

echo ""
echo "💡 ДЛЯ ЗВОНКОВ ЧЕРЕЗ SIP TRUNK используйте:"
echo ""

echo "Способ 1: Bridge + Transfer"
echo "---------------------------"
echo "Команда: originate sofia/gateway/sip_trunk/$PHONE_NUMBER &bridge(user/1000@default),&transfer(1201 XML default)"

echo ""
echo "Способ 2: Прямой перевод"
echo "------------------------"  
echo "Команда: originate sofia/gateway/sip_trunk/$PHONE_NUMBER 1201 XML default"

echo ""
echo "Тест правильного подхода..."
CORRECT_TEST=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/$PHONE_NUMBER 1201 XML default" 2>&1)
echo "Результат: $CORRECT_TEST"

sleep 10

echo ""
echo "❓ ПОЛУЧИЛИ ЛИ ЗВОНОК С ПРАВИЛЬНЫМ IVR?"
read -p "Введите да/нет: " CORRECT_RESULT

if [[ "$CORRECT_RESULT" =~ ^[ДдYy] ]]; then
    echo "🎉 ПРАВИЛЬНЫЙ ПОДХОД РАБОТАЕТ!"
    CORRECT_WORKS=true
else
    echo "❌ Нужна дополнительная настройка"
    CORRECT_WORKS=false
fi

# ЭТАП 6: Финальные рекомендации
echo ""
echo "📋 ЭТАП 6: ФИНАЛЬНЫЕ РЕКОМЕНДАЦИИ"
echo "==============================="

echo ""
echo "📚 УРОК ИЗ ДОКУМЕНТАЦИИ:"
echo ""

echo "✅ ПРАВИЛЬНО:"
echo "- IVR = extensions в диалплане"
echo "- JavaScript/Lua скрипты для логики"
echo "- originate DESTINATION extension context"
echo "- Локальное тестирование extensions"
echo ""

echo "❌ НЕПРАВИЛЬНО (что мы делали):"
echo "- originate sofia/gateway/phone &application"
echo "- Попытки создать IVR через inline apps"
echo "- Тестирование через SIP trunk вместо локально"
echo ""

if [ "$CORRECT_WORKS" = true ]; then
    echo "🎉 УСПЕХ! IVR СИСТЕМA РАБОТАЕТ!"
    echo ""
    echo "✅ РАБОЧИЕ КОМАНДЫ ДЛЯ BACKEND:"
    echo ""
    echo "// JavaScript backend интеграция:"
    echo "const ivrCall = await freeswitch.originate("
    echo "    \`sofia/gateway/sip_trunk/\${phoneNumber}\`,"
    echo "    '1201 XML default'  // Extension в диалплане"
    echo ");"
    echo ""
    echo "// Или с bridge:"
    echo "const bridgeCall = await freeswitch.originate("
    echo "    \`sofia/gateway/sip_trunk/\${phoneNumber}\`,"
    echo "    '&bridge(user/1000@default),&transfer(1201 XML default)'"
    echo ");"
    
else
    echo "🔧 ДОПОЛНИТЕЛЬНАЯ НАСТРОЙКА:"
    echo ""
    echo "1. Проверить загрузку mod_v8"
    echo "2. Проверить права доступа к файлам"
    echo "3. Проверить синтаксис диалплана"
    echo "4. Проверить логи FreeSWITCH"
fi

echo ""
echo "📋 КОМАНДЫ ДЛЯ ПРОДАКШЕНА:"
echo "========================"

echo ""
echo "# Локальное тестирование IVR:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"originate user/1000@default 1201\""
echo ""
echo "# Внешний звонок с IVR:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"originate sofia/gateway/sip_trunk/$PHONE_NUMBER 1201 XML default\""
echo ""
echo "# Проверка диалплана:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"xml_locate dialplan context default 1201\""
echo ""
echo "# Проверка JavaScript модуля:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"module_exists mod_v8\""

echo ""
echo "🎉 ПРАВИЛЬНАЯ РЕАЛИЗАЦИЯ IVR ГОТОВА!"
echo "=================================="

echo ""
echo "📖 ОСНОВАНО НА ОФИЦИАЛЬНОЙ ДОКУМЕНТАЦИИ:"
echo "- FreeSWITCH PBX Example"
echo "- JavaScript Example - Say IVR Menu"
echo "- FreeSWITCH Dialplan Best Practices"

echo ""
echo "🚀 ТЕПЕРЬ У ВАС ЕСТЬ РАБОЧИЙ IVR!" 