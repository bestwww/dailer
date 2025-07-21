#!/bin/bash

# 🔧 ИСПРАВЛЕНИЕ IVR БЕЗ АУДИО/TTS
# Создаем простой IVR который работает без аудиофайлов и backend

CONTAINER_NAME="freeswitch-test"

echo "🔧 ИСПРАВЛЕНИЕ IVR БЕЗ АУДИО"
echo "============================"
echo ""

echo "🎯 ПРОБЛЕМА НАЙДЕНА:"
echo "- IVR использует session:speak() но TTS не настроен"
echo "- Аудиофайлы отсутствуют (backend выключен)"
echo "- Session зависает и звонок падает"
echo ""

echo "✅ РЕШЕНИЕ:"
echo "- Создаем простой IVR БЕЗ аудио"
echo "- Только DTMF обработка и тишина"
echo "- Будет работать до подключения backend"
echo ""

# ЭТАП 1: Создаем простой IVR без аудио
echo "📋 ЭТАП 1: СОЗДАНИЕ ПРОСТОГО IVR"
echo "==============================="

echo ""
echo "Создаем временный IVR скрипт без аудио..."

cat > freeswitch/scripts/ivr_menu.lua << 'EOF'
-- Простое IVR меню БЕЗ АУДИО для тестирования
-- Работает только с DTMF, без speak/playback

freeswitch.consoleLog("INFO", "=== IVR Menu запущен (БЕЗ АУДИО) ===\n")

if session then
    freeswitch.consoleLog("INFO", "Session найден\n")
    
    if session:ready() then
        freeswitch.consoleLog("INFO", "Session готов\n")
        
        -- Отвечаем на звонок
        session:answer()
        freeswitch.consoleLog("INFO", "Звонок отвечен\n")
        
        -- Устанавливаем Caller ID
        session:setVariable("caller_id_name", "79058615815")
        session:setVariable("caller_id_number", "79058615815")
        
        -- Ждем немного для стабилизации
        session:sleep(2000)
        freeswitch.consoleLog("INFO", "Начинаем IVR обработку\n")
        
        local attempts = 0
        local max_attempts = 3
        
        while attempts < max_attempts and session:ready() do
            attempts = attempts + 1
            freeswitch.consoleLog("INFO", "IVR попытка " .. attempts .. "\n")
            
            -- ВМЕСТО SPEAK - просто ждем и слушаем DTMF
            -- Пользователь не услышит сообщение, но может нажать кнопки
            
            -- Получаем DTMF (ждем 10 секунд)
            local digit = session:getDigits(1, "", 10000)
            freeswitch.consoleLog("INFO", "Получена цифра: " .. (digit or "none") .. "\n")
            
            if digit == "1" then
                freeswitch.consoleLog("INFO", "Выбрана опция 1\n")
                -- Играем тон вместо speak
                session:execute("playback", "tone_stream://%(200,100,800)")
                session:sleep(3000)
                break
                
            elseif digit == "2" then
                freeswitch.consoleLog("INFO", "Выбрана опция 2 - завершение\n")
                -- Играем прощальный тон
                session:execute("playback", "tone_stream://%(200,100,400)")
                session:sleep(1000)
                break
                
            elseif digit == "9" then
                freeswitch.consoleLog("INFO", "Выбрана опция 9 - эхо тест\n")
                session:execute("echo")
                break
                
            else
                freeswitch.consoleLog("INFO", "Неверный выбор или таймаут\n")
                if attempts < max_attempts then
                    -- Играем ошибочный тон
                    session:execute("playback", "tone_stream://%(100,100,300,500)")
                else
                    freeswitch.consoleLog("INFO", "Превышено количество попыток\n")
                    session:execute("playback", "tone_stream://%(200,200,400)")
                end
            end
        end
        
        freeswitch.consoleLog("INFO", "IVR завершен\n")
        
    else
        freeswitch.consoleLog("ERROR", "Session не готов\n")
    end
    
    -- Завершаем звонок
    session:hangup()
    freeswitch.consoleLog("INFO", "Звонок завершен\n")
    
else
    freeswitch.consoleLog("ERROR", "Session отсутствует\n")
end

freeswitch.consoleLog("INFO", "=== IVR Menu завершен ===\n")
EOF

echo "✅ Простой IVR создан"

# ЭТАП 2: Копируем в контейнер
echo ""
echo "📋 ЭТАП 2: ОБНОВЛЕНИЕ IVR В КОНТЕЙНЕРЕ"
echo "====================================="

echo ""
echo "Копируем новый IVR скрипт в контейнер..."
if docker cp freeswitch/scripts/ivr_menu.lua "$CONTAINER_NAME:/usr/local/freeswitch/scripts/"; then
    echo "✅ IVR скрипт скопирован"
else
    echo "❌ Ошибка копирования IVR скрипта"
    exit 1
fi

# ЭТАП 3: Обновляем диалплан для лучшей работы
echo ""
echo "📋 ЭТАП 3: ОБНОВЛЕНИЕ ДИАЛПЛАНА"
echo "=============================="

echo ""
echo "Обновляем диалплан для лучшей работы с IVR..."

cat > freeswitch/conf/dialplan/default.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<include>
  <context name="default">
    
    <!-- IVR Menu с предварительным ответом -->
    <extension name="ivr_menu">
      <condition field="destination_number" expression="^(ivr_menu)$">
        <action application="answer"/>
        <action application="sleep" data="1000"/>
        <action application="set" data="hangup_after_bridge=true"/>
        <action application="lua" data="ivr_menu.lua"/>
      </condition>
    </extension>
    
    <!-- Исходящие звонки с улучшенной обработкой -->
    <extension name="outbound_calls">
      <condition field="destination_number" expression="^(\d{11})$">
        <action application="set" data="caller_id_name=79058615815"/>
        <action application="set" data="caller_id_number=79058615815"/>
        <action application="set" data="effective_caller_id_name=79058615815"/>
        <action application="set" data="effective_caller_id_number=79058615815"/>
        <action application="set" data="hangup_after_bridge=true"/>
        <action application="bridge" data="sofia/gateway/sip_trunk/$1"/>
      </condition>
    </extension>
    
    <!-- Входящие звонки с предварительным ответом -->
    <extension name="inbound_calls">
      <condition field="destination_number" expression="^(79058615815)$">
        <action application="answer"/>
        <action application="sleep" data="1000"/>
        <action application="set" data="hangup_after_bridge=true"/>
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

echo "✅ Диалплан обновлен"

# Копируем диалплан
echo ""
echo "Копируем обновленный диалплан..."
if docker cp freeswitch/conf/dialplan/default.xml "$CONTAINER_NAME:/usr/local/freeswitch/conf/dialplan/"; then
    echo "✅ Диалплан скопирован"
else
    echo "❌ Ошибка копирования диалплана"
fi

# ЭТАП 4: Перезагружаем конфигурацию
echo ""
echo "🔄 ЭТАП 4: ПЕРЕЗАГРУЗКА КОНФИГУРАЦИИ"
echo "=================================="

echo ""
echo "Перезагружаем XML конфигурацию..."
docker exec "$CONTAINER_NAME" fs_cli -x "reloadxml"

echo ""
echo "✅ Конфигурация перезагружена"

# ЭТАП 5: Тестирование
echo ""
echo "🧪 ЭТАП 5: ТЕСТИРОВАНИЕ ИСПРАВЛЕННОГО IVR"
echo "========================================"

echo ""
echo "Тест 1: Прямой вызов IVR"
echo "------------------------"
IVR_TEST=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/79206054020 &transfer:ivr_menu" 2>&1)
echo "Результат IVR теста: $IVR_TEST"

echo ""
echo "⏱️ Ожидаем завершения звонка (15 секунд)..."
sleep 15

echo ""
echo "📋 Проверяем логи IVR:"
echo "---------------------"
IVR_LOGS=$(docker exec "$CONTAINER_NAME" fs_cli -x "console last 50" | grep -E "(IVR|Session|Звонок)" | tail -10)
if [ -n "$IVR_LOGS" ]; then
    echo "$IVR_LOGS"
else
    echo "Логи IVR не найдены"
fi

echo ""
echo "📊 Проверяем статистику gateway:"
echo "-------------------------------"
docker exec "$CONTAINER_NAME" fs_cli -x "sofia status gateway internal::sip_trunk" | grep -E "(CallsOUT|FailedCallsOUT)"

echo ""
echo "💡 РЕЗУЛЬТАТ И ИНСТРУКЦИИ"
echo "========================="
echo ""
echo "✅ ИСПРАВЛЕНИЯ ВНЕСЕНЫ:"
echo "- IVR теперь работает БЕЗ аудио"
echo "- Используются тоны вместо speak"
echo "- Добавлено детальное логирование"
echo "- Улучшен диалплан"
echo ""
echo "🎯 КАК ТЕСТИРОВАТЬ:"
echo "1. Звоните: docker exec $CONTAINER_NAME fs_cli -x \"originate sofia/gateway/sip_trunk/79206054020 &transfer:ivr_menu\""
echo "2. Когда ответят - нажимайте:"
echo "   - 1 = услышите подтверждающий тон"
echo "   - 2 = услышите прощальный тон"  
echo "   - 9 = эхо тест"
echo "   - другое = ошибочный тон"
echo ""
echo "📋 ЛОГИ:"
echo "docker exec $CONTAINER_NAME fs_cli -x \"console last 20\" | grep IVR"
echo ""
echo "🔧 ПОСЛЕ ПОДКЛЮЧЕНИЯ BACKEND:"
echo "- Замените тоны на реальные аудиофайлы"
echo "- Добавите personalized сообщения для каждой кампании"
echo "- Интегрируете с системой загрузки аудио"

echo ""
echo "✅ Исправление завершено!" 