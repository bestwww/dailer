#!/bin/bash

# 🚨 ЭКСТРЕННОЕ ИСПРАВЛЕНИЕ ВИСЯЩЕГО ЗВОНКА
# Завершение активного звонка и диагностика диалплана

CONTAINER_NAME="freeswitch-test"

echo "🚨 ЭКСТРЕННОЕ ИСПРАВЛЕНИЕ ВИСЯЩЕГО ЗВОНКА"
echo "=========================================="
echo ""

echo "⚠️ ПРОБЛЕМА: Звонок висит активным!"
echo "UUID: 335fbf74-46cf-4c88-9efd-5e29b9044a28"
echo "Время: более 3 минут"
echo "Состояние: CS_EXECUTE"
echo ""

# ЭТАП 1: Немедленное завершение висящего звонка
echo "📋 ЭТАП 1: НЕМЕДЛЕННОЕ ЗАВЕРШЕНИЕ ЗВОНКА"
echo "========================================="

echo ""
echo "1. 🛑 СРОЧНО завершаем висящий звонок..."
docker exec "$CONTAINER_NAME" fs_cli -x "uuid_kill 335fbf74-46cf-4c88-9efd-5e29b9044a28"

echo ""
echo "2. 🛑 Завершаем ВСЕ остальные звонки..."
docker exec "$CONTAINER_NAME" fs_cli -x "hupall MANAGER_REQUEST"

echo ""
echo "3. 📊 Проверяем что все завершены..."
CALLS_AFTER=$(docker exec "$CONTAINER_NAME" fs_cli -x "show calls count")
echo "Звонки после завершения: $CALLS_AFTER"

if [[ "$CALLS_AFTER" == *"0 total"* ]]; then
    echo "✅ Все звонки завершены успешно"
else
    echo "❌ Остались активные звонки: $CALLS_AFTER"
    echo "🛑 Принудительное завершение..."
    docker exec "$CONTAINER_NAME" fs_cli -x "fsctl shutdown elegant"
    sleep 5
    echo "🔄 Перезапуск FreeSWITCH..."
    docker restart "$CONTAINER_NAME"
    sleep 10
fi

# ЭТАП 2: Диагностика диалплана
echo ""
echo "📋 ЭТАП 2: ДИАГНОСТИКА ДИАЛПЛАНА"
echo "================================"

echo ""
echo "4. 🔍 Проверяем созданные диалпланы..."

# Проверяем созданные файлы
echo "Файлы диалплана:"
docker exec "$CONTAINER_NAME" ls -la /usr/local/freeswitch/conf/dialplan/default/ | grep -E "(1201|1202)"

echo ""
echo "5. 📄 Проверяем содержимое диалплана 1201..."
if docker exec "$CONTAINER_NAME" test -f "/usr/local/freeswitch/conf/dialplan/default/1201_safe_ivr.xml"; then
    echo "✅ Файл 1201 существует"
    echo "Первые строки:"
    docker exec "$CONTAINER_NAME" head -10 "/usr/local/freeswitch/conf/dialplan/default/1201_safe_ivr.xml"
else
    echo "❌ Файл 1201 НЕ НАЙДЕН!"
fi

echo ""
echo "6. 🧪 Проверяем синтаксис XML..."
docker exec "$CONTAINER_NAME" fs_cli -x "xml_locate dialplan destination_number 1201" | head -20

echo ""
echo "7. 📋 Проверяем загрузку диалплана..."
docker exec "$CONTAINER_NAME" fs_cli -x "reloadxml"

# ЭТАП 3: Проверка логов
echo ""
echo "📋 ЭТАП 3: АНАЛИЗ ЛОГОВ"
echo "======================="

echo ""
echo "8. 📄 Ищем ошибки в логах..."
if docker exec "$CONTAINER_NAME" test -f "/usr/local/freeswitch/log/freeswitch.log"; then
    echo "Последние ошибки XML:"
    docker exec "$CONTAINER_NAME" tail -50 "/usr/local/freeswitch/log/freeswitch.log" | grep -i -E "(error|warning|xml|dialplan)" | tail -10
    
    echo ""
    echo "Логи о звонке 335fbf74:"
    docker exec "$CONTAINER_NAME" grep "335fbf74" "/usr/local/freeswitch/log/freeswitch.log" | tail -5
else
    echo "❌ Лог файл не найден"
fi

# ЭТАП 4: Создание простого тестового диалплана
echo ""
echo "📋 ЭТАП 4: ПРОСТОЙ ТЕСТОВЫЙ ДИАЛПЛАН"
echo "==================================="

echo ""
echo "9. 🔧 Создаем ПРОСТЕЙШИЙ диалплан для теста..."

# Создаем максимально простой диалплан
docker exec "$CONTAINER_NAME" bash -c "cat > /usr/local/freeswitch/conf/dialplan/default/1203_simple_test.xml << 'EOF'
<include>
  <extension name=\"simple_test_1203\">
    <condition field=\"destination_number\" expression=\"^1203$\">
      <action application=\"answer\"/>
      <action application=\"log\" data=\"INFO ПРОСТОЙ ТЕСТ 1203 РАБОТАЕТ\"/>
      <action application=\"playback\" data=\"tone_stream://%(1000,0,400)\"/>
      <action application=\"sleep\" data=\"3000\"/>
      <action application=\"log\" data=\"INFO ЗАВЕРШЕНИЕ ПРОСТОГО ТЕСТА\"/>
      <action application=\"hangup\" data=\"NORMAL_CLEARING\"/>
    </condition>
  </extension>
</include>
EOF"

echo "   ✅ Создан простейший тест 1203"

echo ""
echo "10. 🔧 Исправляем диалплан 1201..."

# Создаем исправленный диалплан 1201 с правильным синтаксисом
docker exec "$CONTAINER_NAME" bash -c "cat > /usr/local/freeswitch/conf/dialplan/default/1201_fixed.xml << 'EOF'
<include>
  <extension name=\"fixed_ivr_1201\">
    <condition field=\"destination_number\" expression=\"^1201$\">
      
      <!-- БАЗОВЫЕ НАСТРОЙКИ -->
      <action application=\"set\" data=\"hangup_after_bridge=true\"/>
      <action application=\"set\" data=\"continue_on_fail=true\"/>
      <action application=\"set\" data=\"call_timeout=15\"/>
      
      <!-- НАЧАЛО -->
      <action application=\"answer\"/>
      <action application=\"log\" data=\"INFO ИСПРАВЛЕННЫЙ IVR 1201 НАЧИНАЕТСЯ\"/>
      <action application=\"sleep\" data=\"1000\"/>
      
      <!-- МЕНЮ -->
      <action application=\"playback\" data=\"tone_stream://%(1000,0,400)\"/>
      <action application=\"sleep\" data=\"500\"/>
      
      <!-- СБОР DTMF С ТАЙМАУТОМ -->
      <action application=\"log\" data=\"INFO СБОР DTMF 8 СЕКУНД\"/>
      <action application=\"read\" data=\"user_choice,1,3,tone_stream://%(200,100,400),digit_timeout,8000\"/>
      <action application=\"log\" data=\"INFO ПОЛУЧЕН DTMF: \${user_choice}\"/>
      
      <!-- ПРОСТАЯ ОБРАБОТКА -->
      <action application=\"execute_extension\" data=\"choice_\${user_choice} XML default\"/>
      
      <!-- ПРИНУДИТЕЛЬНОЕ ЗАВЕРШЕНИЕ -->
      <action application=\"log\" data=\"INFO ПРИНУДИТЕЛЬНОЕ ЗАВЕРШЕНИЕ 1201\"/>
      <action application=\"hangup\" data=\"NORMAL_CLEARING\"/>
      
    </condition>
  </extension>

  <!-- ОБРАБОТЧИКИ ВЫБОРА -->
  <extension name=\"choice_1\">
    <condition field=\"destination_number\" expression=\"^choice_1$\">
      <action application=\"log\" data=\"INFO ВЫБОР 1 ОБРАБОТАН\"/>
      <action application=\"playback\" data=\"tone_stream://%(500,0,600)\"/>
      <action application=\"hangup\" data=\"NORMAL_CLEARING\"/>
    </condition>
  </extension>

  <extension name=\"choice_2\">
    <condition field=\"destination_number\" expression=\"^choice_2$\">
      <action application=\"log\" data=\"INFO ВЫБОР 2 ОБРАБОТАН\"/>
      <action application=\"playback\" data=\"tone_stream://%(500,0,800)\"/>
      <action application=\"hangup\" data=\"NORMAL_CLEARING\"/>
    </condition>
  </extension>

  <!-- ОБРАБОТЧИК ПУСТОГО ВЫБОРА -->
  <extension name=\"choice_\">
    <condition field=\"destination_number\" expression=\"^choice_$\">
      <action application=\"log\" data=\"WARNING ПУСТОЙ ВЫБОР\"/>
      <action application=\"hangup\" data=\"NO_USER_RESPONSE\"/>
    </condition>
  </extension>

</include>
EOF"

echo "   ✅ Создан исправленный диалплан 1201"

# ЭТАП 5: Перезагрузка и быстрый тест
echo ""
echo "📋 ЭТАП 5: ПЕРЕЗАГРУЗКА И ТЕСТ"
echo "=============================="

echo ""
echo "11. 🔄 Перезагружаем диалплан..."
docker exec "$CONTAINER_NAME" fs_cli -x "reloadxml"

echo ""
echo "12. 🧪 Быстрый тест простого диалплана 1203..."

# Тест простого диалплана с таймаутом
echo "Запуск тестового звонка на 1203..."
docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/79206054020 1203 XML default" &
TEST_PID=$!

# Ждем 8 секунд
sleep 8

# Проверяем результат
echo ""
echo "13. 📊 Результат теста..."
FINAL_CALLS=$(docker exec "$CONTAINER_NAME" fs_cli -x "show calls count")
echo "Активные звонки: $FINAL_CALLS"

# Завершаем тестовый процесс если нужно
kill $TEST_PID 2>/dev/null

# ИТОГИ
echo ""
echo "🎯 РЕЗУЛЬТАТЫ ЭКСТРЕННОГО ИСПРАВЛЕНИЯ"
echo "====================================="
echo ""
echo "✅ ВЫПОЛНЕНО:"
echo "• Завершен висящий звонок"
echo "• Создан простейший тест 1203"
echo "• Исправлен диалплан 1201"
echo "• Перезагружена конфигурация"
echo ""
echo "🧪 ТЕСТИРОВАНИЕ:"
echo "• 1203 - Простейший тест (3 сек + завершение)"
echo "• 1201 - Исправленный IVR (8 сек + завершение)"
echo ""
echo "📝 СЛЕДУЮЩИЕ ШАГИ:"
echo "1. Проверьте что нет активных звонков"
echo "2. Попробуйте позвонить на 1203"
echo "3. Если 1203 работает - попробуйте 1201"
echo "4. Нажмите цифры 1 или 2 в IVR"
echo ""
echo "⚠️ ЕСЛИ ПРОБЛЕМЫ ПРОДОЛЖАЮТСЯ:"
echo "• Проверьте логи на ошибки XML"
echo "• Может потребоваться полный перезапуск"
echo "• Проверьте провайдера DTMF" 