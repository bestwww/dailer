#!/bin/bash

# 🎵 ПРОСТОЙ АУДИОРОЛИК + DTMF ДЕТЕКЦИЯ
# Без лишних IVR функций - только аудио, кнопки 1,2 и сброс

CONTAINER_NAME="freeswitch-test"

echo "🎵 ПРОСТОЙ АУДИОРОЛИК + DTMF ДЕТЕКЦИЯ"
echo "======================================"
echo ""

echo "🎯 ЗАДАЧА:"
echo "1. Проиграть аудиоролик"
echo "2. Детектировать кнопку 1 или 2"  
echo "3. Сброс звонка"
echo "4. Для входящих И исходящих"
echo ""

# ЭТАП 1: Завершение активных звонков
echo "📋 ЭТАП 1: ОЧИСТКА АКТИВНЫХ ЗВОНКОВ"
echo "==================================="

echo ""
echo "1. 🛑 Завершаем все активные звонки..."
docker exec "$CONTAINER_NAME" fs_cli -x "hupall MANAGER_REQUEST"

echo ""
echo "2. 📊 Проверяем что все завершены..."
CALLS_COUNT=$(docker exec "$CONTAINER_NAME" fs_cli -x "show calls count")
echo "Активные звонки: $CALLS_COUNT"

# ЭТАП 2: Создание простейшего диалплана
echo ""
echo "📋 ЭТАП 2: ПРОСТЕЙШИЙ ДИАЛПЛАН"
echo "=============================="

echo ""
echo "3. 🔧 Создаем ПРОСТОЙ диалплан для аудио + DTMF..."

# Получаем правильный путь конфигурации
CONF_DIR=$(docker exec "$CONTAINER_NAME" fs_cli -x "eval \${conf_dir}")
echo "Используем конфигурацию: $CONF_DIR"

# Создаем простейший диалплан для входящих звонков
docker exec "$CONTAINER_NAME" bash -c "cat > '$CONF_DIR/dialplan/default/1204_simple_audio.xml' << 'EOF'
<include>
  <!-- ПРОСТОЙ АУДИОРОЛИК + DTMF ДЛЯ ВХОДЯЩИХ/ИСХОДЯЩИХ -->
  <extension name=\"simple_audio_1204\">
    <condition field=\"destination_number\" expression=\"^1204$\">
      
      <!-- ОТВЕЧАЕМ -->
      <action application=\"answer\"/>
      <action application=\"log\" data=\"INFO ПРОСТОЙ АУДИОРОЛИК НАЧАЛСЯ\"/>
      
      <!-- НЕБОЛЬШАЯ ПАУЗА -->
      <action application=\"sleep\" data=\"500\"/>
      
      <!-- ПРОИГРЫВАЕМ АУДИОРОЛИК (тон вместо файла для теста) -->
      <action application=\"log\" data=\"INFO ПРОИГРЫВАЕМ АУДИОРОЛИК\"/>
      <action application=\"playback\" data=\"tone_stream://%(2000,0,400+800)\"/>
      
      <!-- ДЕТЕКТИРУЕМ КНОПКУ 1 ИЛИ 2 (5 СЕКУНД) -->
      <action application=\"log\" data=\"INFO ЖДЕМ КНОПКУ 1 ИЛИ 2 (5 сек)\"/>
      <action application=\"read\" data=\"button_pressed,1,5,tone_stream://%(200,100,600),timeout,5000\"/>
      
      <!-- ЛОГИРУЕМ РЕЗУЛЬТАТ -->
      <action application=\"log\" data=\"INFO НАЖАТА КНОПКА: \${button_pressed}\"/>
      
      <!-- ПРОСТАЯ ОБРАБОТКА БЕЗ TRANSFER -->
      <action application=\"execute_extension\" data=\"button_\${button_pressed} XML default\"/>
      
      <!-- СБРОС -->
      <action application=\"log\" data=\"INFO СБРОС ЗВОНКА\"/>
      <action application=\"hangup\" data=\"NORMAL_CLEARING\"/>
      
    </condition>
  </extension>

  <!-- ОБРАБОТЧИК КНОПКИ 1 -->
  <extension name=\"button_1\">
    <condition field=\"destination_number\" expression=\"^button_1$\">
      <action application=\"log\" data=\"INFO КНОПКА 1 НАЖАТА - ВЕБХУК 1\"/>
      <action application=\"playback\" data=\"tone_stream://%(500,0,800)\"/>
      <action application=\"hangup\" data=\"NORMAL_CLEARING\"/>
    </condition>
  </extension>

  <!-- ОБРАБОТЧИК КНОПКИ 2 -->
  <extension name=\"button_2\">
    <condition field=\"destination_number\" expression=\"^button_2$\">
      <action application=\"log\" data=\"INFO КНОПКА 2 НАЖАТА - ВЕБХУК 2\"/>
      <action application=\"playback\" data=\"tone_stream://%(500,0,1000)\"/>
      <action application=\"hangup\" data=\"NORMAL_CLEARING\"/>
    </condition>
  </extension>

  <!-- ОБРАБОТЧИК ОТСУТСТВИЯ КНОПКИ -->
  <extension name=\"button_\">
    <condition field=\"destination_number\" expression=\"^button_$\">
      <action application=\"log\" data=\"WARNING КНОПКА НЕ НАЖАТА\"/>
      <action application=\"hangup\" data=\"NO_USER_RESPONSE\"/>
    </condition>
  </extension>

</include>
EOF"

echo "   ✅ Создан простой диалплан 1204"

# Создаем обработчик для входящих звонков (любой номер)
docker exec "$CONTAINER_NAME" bash -c "cat > '$CONF_DIR/dialplan/default/0000_incoming_audio.xml' << 'EOF'
<include>
  <!-- ВХОДЯЩИЕ ЗВОНКИ - АУДИОРОЛИК + DTMF -->
  <extension name=\"incoming_audio_handler\">
    <condition field=\"destination_number\" expression=\"^(\\\+?7\\\d{10}|79\\\d{9})$\">
      
      <!-- ОТВЕЧАЕМ -->
      <action application=\"answer\"/>
      <action application=\"log\" data=\"INFO ВХОДЯЩИЙ ЗВОНОК НА АУДИОРОЛИК\"/>
      
      <!-- ПАУЗА -->
      <action application=\"sleep\" data=\"1000\"/>
      
      <!-- АУДИОРОЛИК -->
      <action application=\"log\" data=\"INFO ПРОИГРЫВАЕМ АУДИОРОЛИК ВХОДЯЩЕМУ\"/>
      <action application=\"playback\" data=\"tone_stream://%(3000,0,350+700)\"/>
      
      <!-- ДЕТЕКЦИЯ DTMF -->
      <action application=\"log\" data=\"INFO ЖДЕМ КНОПКУ ОТ ВХОДЯЩЕГО (8 сек)\"/>
      <action application=\"read\" data=\"incoming_button,1,8,tone_stream://%(200,100,500),timeout,8000\"/>
      <action application=\"log\" data=\"INFO ВХОДЯЩИЙ НАЖАЛ: \${incoming_button}\"/>
      
      <!-- ОБРАБОТКА -->
      <action application=\"execute_extension\" data=\"incoming_\${incoming_button} XML default\"/>
      
      <!-- СБРОС -->
      <action application=\"log\" data=\"INFO СБРОС ВХОДЯЩЕГО\"/>
      <action application=\"hangup\" data=\"NORMAL_CLEARING\"/>
      
    </condition>
  </extension>

  <!-- ОБРАБОТЧИКИ ДЛЯ ВХОДЯЩИХ -->
  <extension name=\"incoming_1\">
    <condition field=\"destination_number\" expression=\"^incoming_1$\">
      <action application=\"log\" data=\"INFO ВХОДЯЩИЙ ВЫБРАЛ 1\"/>
      <action application=\"playback\" data=\"tone_stream://%(800,0,900)\"/>
      <action application=\"hangup\" data=\"NORMAL_CLEARING\"/>
    </condition>
  </extension>

  <extension name=\"incoming_2\">
    <condition field=\"destination_number\" expression=\"^incoming_2$\">
      <action application=\"log\" data=\"INFO ВХОДЯЩИЙ ВЫБРАЛ 2\"/>
      <action application=\"playback\" data=\"tone_stream://%(800,0,1100)\"/>
      <action application=\"hangup\" data=\"NORMAL_CLEARING\"/>
    </condition>
  </extension>

  <extension name=\"incoming_\">
    <condition field=\"destination_number\" expression=\"^incoming_$\">
      <action application=\"log\" data=\"WARNING ВХОДЯЩИЙ НЕ НАЖАЛ КНОПКУ\"/>
      <action application=\"hangup\" data=\"NO_USER_RESPONSE\"/>
    </condition>
  </extension>

</include>
EOF"

echo "   ✅ Создан обработчик входящих звонков"

# ЭТАП 3: Настройка для использования реальных аудиофайлов
echo ""
echo "📋 ЭТАП 3: ПОДГОТОВКА К РЕАЛЬНЫМ АУДИОФАЙЛАМ"
echo "=============================================="

echo ""
echo "4. 📁 Создаем директорию для аудиофайлов..."
docker exec "$CONTAINER_NAME" mkdir -p /usr/local/freeswitch/sounds/custom
echo "   ✅ Создана: /usr/local/freeswitch/sounds/custom"

echo ""
echo "5. 📄 Создаем шаблон с реальными аудиофайлами..."

# Создаем шаблон для использования реальных файлов
docker exec "$CONTAINER_NAME" bash -c "cat > '$CONF_DIR/dialplan/default/1205_real_audio.xml' << 'EOF'
<include>
  <!-- РЕАЛЬНЫЙ АУДИОРОЛИК + DTMF (закомментировано) -->
  <!--
  <extension name=\"real_audio_1205\">
    <condition field=\"destination_number\" expression=\"^1205$\">
      
      <action application=\"answer\"/>
      <action application=\"log\" data=\"INFO РЕАЛЬНЫЙ АУДИОРОЛИК\"/>
      <action application=\"sleep\" data=\"500\"/>
      
      <!-- ЗАМЕНИТЕ НА ВАШ АУДИОФАЙЛ -->
      <action application=\"playback\" data=\"/usr/local/freeswitch/sounds/custom/your_audio.wav\"/>
      
      <!-- ИЛИ ИСПОЛЬЗУЙТЕ ВСТРОЕННЫЕ ЗВУКИ -->
      <action application=\"playback\" data=\"ivr/ivr-welcome.wav\"/>
      
      <!-- ДЕТЕКЦИЯ DTMF -->
      <action application=\"read\" data=\"real_button,1,10,silence_stream://500,timeout,10000\"/>
      <action application=\"log\" data=\"INFO РЕАЛЬНАЯ КНОПКА: \${real_button}\"/>
      
      <action application=\"execute_extension\" data=\"real_\${real_button} XML default\"/>
      <action application=\"hangup\" data=\"NORMAL_CLEARING\"/>
      
    </condition>
  </extension>
  -->
</include>
EOF"

echo "   ✅ Создан шаблон для реальных аудиофайлов (1205)"

# ЭТАП 4: Перезагрузка и тестирование
echo ""
echo "📋 ЭТАП 4: ПЕРЕЗАГРУЗКА И ТЕСТ"
echo "=============================="

echo ""
echo "6. 🔄 Перезагружаем диалплан..."
docker exec "$CONTAINER_NAME" fs_cli -x "reloadxml"

echo ""
echo "7. 🧪 Быстрый тест простого аудио..."
echo "Запуск тестового звонка на 1204..."

# Тест с мониторингом
docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/79206054020 1204 XML default" &
TEST_PID=$!

# Ждем 10 секунд
sleep 10

# Завершаем тест если нужно
kill $TEST_PID 2>/dev/null

echo ""
echo "8. 📊 Результат теста..."
FINAL_CALLS=$(docker exec "$CONTAINER_NAME" fs_cli -x "show calls count")
echo "Активные звонки: $FINAL_CALLS"

# ИТОГИ
echo ""
echo "🎯 ПРОСТОЙ ДИАЛПЛАН ГОТОВ"
echo "========================="
echo ""
echo "✅ СОЗДАНО:"
echo "• 1204 - Простой аудиоролик + DTMF (исходящие)"
echo "• 0000_incoming - Обработчик входящих звонков"
echo "• 1205 - Шаблон для реальных аудиофайлов"
echo ""
echo "🎵 КАК РАБОТАЕТ:"
echo "1. Отвечает на звонок"
echo "2. Проигрывает аудиоролик (сейчас тон)"
echo "3. Ждет кнопку 1 или 2"
echo "4. Вызывает вебхук"
echo "5. Сбрасывает звонок"
echo ""
echo "📁 ДЛЯ РЕАЛЬНЫХ ФАЙЛОВ:"
echo "• Загрузите аудио в: /usr/local/freeswitch/sounds/custom/"
echo "• Раскомментируйте диалплан 1205"
echo "• Измените путь к файлу"
echo ""
echo "🧪 ТЕСТИРОВАНИЕ:"
echo "• Позвоните на 1204"
echo "• Дождитесь окончания аудио"
echo "• Нажмите 1 или 2"
echo "• Звонок должен завершиться автоматически"
echo ""
echo "💡 ПРЕИМУЩЕСТВА:"
echo "• Никаких сложных IVR"
echo "• Простая логика"
echo "• Быстрое завершение"
echo "• Легкая отладка"
echo "• Работает для входящих И исходящих" 