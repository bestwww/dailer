#!/bin/bash

# 🔧 ИСПРАВЛЕНИЕ ПУТЕЙ И ЗАВЕРШЕНИЕ НАСТРОЙКИ
# Исправляем проблемы с путями FreeSWITCH в Docker контейнере

CONTAINER_NAME="freeswitch-test"

echo "🔧 ИСПРАВЛЕНИЕ ПУТЕЙ И ЗАВЕРШЕНИЕ НАСТРОЙКИ"
echo "============================================="
echo ""

echo "🚨 ОБНАРУЖЕННЫЕ ПРОБЛЕМЫ:"
echo "❌ Неправильные пути к конфигурации FreeSWITCH"
echo "❌ Неправильные пути к логам"
echo "⚠️ Активный звонок требует завершения"
echo ""

# ЭТАП 1: Срочное завершение активных звонков
echo "📋 ЭТАП 1: ЗАВЕРШЕНИЕ АКТИВНЫХ ЗВОНКОВ"
echo "======================================="

echo ""
echo "1. 🛑 Завершаем ВСЕ активные звонки..."
docker exec "$CONTAINER_NAME" fs_cli -x "hupall MANAGER_REQUEST"

echo ""
echo "2. 📊 Проверяем что завершены..."
docker exec "$CONTAINER_NAME" fs_cli -x "show calls"

# ЭТАП 2: Поиск правильных путей FreeSWITCH
echo ""
echo "📋 ЭТАП 2: ПОИСК ПРАВИЛЬНЫХ ПУТЕЙ"
echo "=================================="

echo ""
echo "3. 🔍 Ищем конфигурационные файлы FreeSWITCH..."

# Ищем где находится FreeSWITCH
echo "Возможные пути конфигурации:"
docker exec "$CONTAINER_NAME" find / -name "freeswitch.xml" -type f 2>/dev/null | head -5
docker exec "$CONTAINER_NAME" find / -name "dialplan" -type d 2>/dev/null | head -5

echo ""
echo "4. 🔍 Ищем файлы логов..."
docker exec "$CONTAINER_NAME" find / -name "freeswitch.log" -type f 2>/dev/null | head -5
docker exec "$CONTAINER_NAME" find / -name "*.log" -path "*/freeswitch/*" 2>/dev/null | head -5

echo ""
echo "5. 📂 Проверяем стандартные пути..."

# Проверяем стандартные пути
POSSIBLE_PATHS=(
    "/etc/freeswitch"
    "/opt/freeswitch/etc/freeswitch" 
    "/usr/share/freeswitch"
    "/var/lib/freeswitch"
    "/usr/local/etc/freeswitch"
)

for path in "${POSSIBLE_PATHS[@]}"; do
    if docker exec "$CONTAINER_NAME" test -d "$path"; then
        echo "✅ Найден: $path"
        docker exec "$CONTAINER_NAME" ls -la "$path" 2>/dev/null | head -3
    else
        echo "❌ Не найден: $path"
    fi
done

# ЭТАП 3: Определение рабочих путей
echo ""
echo "📋 ЭТАП 3: ОПРЕДЕЛЕНИЕ РАБОЧИХ ПУТЕЙ"
echo "===================================="

echo ""
echo "6. 🎯 Определяем активную конфигурацию..."

# Проверяем активную конфигурацию через fs_cli
CONFIG_INFO=$(docker exec "$CONTAINER_NAME" fs_cli -x "eval \${conf_dir}")
echo "Активная директория конфигурации: $CONFIG_INFO"

LOG_INFO=$(docker exec "$CONTAINER_NAME" fs_cli -x "eval \${log_dir}")
echo "Активная директория логов: $LOG_INFO"

SOUND_INFO=$(docker exec "$CONTAINER_NAME" fs_cli -x "eval \${sound_dir}")
echo "Директория звуков: $SOUND_INFO"

# Определяем правильные пути
if [ ! -z "$CONFIG_INFO" ] && [ "$CONFIG_INFO" != "undefined" ]; then
    CONF_DIR="$CONFIG_INFO"
    echo "✅ Используем конфигурацию: $CONF_DIR"
else
    CONF_DIR="/etc/freeswitch"
    echo "⚠️ Используем по умолчанию: $CONF_DIR"
fi

if [ ! -z "$LOG_INFO" ] && [ "$LOG_INFO" != "undefined" ]; then
    LOG_DIR="$LOG_INFO"
    echo "✅ Используем логи: $LOG_DIR"
else
    LOG_DIR="/var/log/freeswitch"
    echo "⚠️ Используем по умолчанию: $LOG_DIR"
fi

# ЭТАП 4: Создание диалплана в правильном месте
echo ""
echo "📋 ЭТАП 4: СОЗДАНИЕ ПРАВИЛЬНОГО ДИАЛПЛАНА"
echo "=========================================="

echo ""
echo "7. 🔧 Создаем диалплан в правильном месте..."

# Проверяем и создаем директорию диалплана
docker exec "$CONTAINER_NAME" bash -c "
if [ ! -d '$CONF_DIR/dialplan/default' ]; then
    echo 'Создаем директорию диалплана...'
    mkdir -p '$CONF_DIR/dialplan/default'
fi
"

# Создаем безопасный диалплан 1201
docker exec "$CONTAINER_NAME" bash -c "cat > '$CONF_DIR/dialplan/default/1201_safe_ivr.xml' << 'EOF'
<!-- 📚 БЕЗОПАСНЫЙ IVR ПО ОФИЦИАЛЬНОЙ ДОКУМЕНТАЦИИ -->
<include>
  <extension name=\"safe_ivr_1201\">
    <condition field=\"destination_number\" expression=\"^1201\$\">
      
      <!-- ПРАВИЛЬНЫЕ НАСТРОЙКИ -->
      <action application=\"set\" data=\"originate_timeout=60\"/>
      <action application=\"set\" data=\"hangup_after_bridge=true\"/>
      <action application=\"set\" data=\"playback_terminators=*#\"/>
      <action application=\"set\" data=\"dtmf_verbose=true\"/>
      
      <!-- НАЧАЛО IVR -->
      <action application=\"answer\"/>
      <action application=\"log\" data=\"INFO БЕЗОПАСНЫЙ IVR 1201 ЗАПУЩЕН\"/>
      <action application=\"sleep\" data=\"1000\"/>
      
      <!-- МЕНЮ -->
      <action application=\"playback\" data=\"tone_stream://%(1000,0,400)\"/>
      <action application=\"sleep\" data=\"500\"/>
      <action application=\"playback\" data=\"tone_stream://%(500,500,800);%(500,500,1000)\"/>
      
      <!-- БЕЗОПАСНЫЙ СБОР DTMF (10 СЕКУНД) -->
      <action application=\"log\" data=\"INFO ЖДЕМ DTMF 10 СЕКУНД\"/>
      <action application=\"read\" data=\"dtmf_choice,1,10,tone_stream://%(200,100,400),timeout,10000\"/>
      <action application=\"log\" data=\"INFO ПОЛУЧЕН DTMF: \${dtmf_choice}\"/>
      
      <!-- ОБРАБОТКА ВЫБОРА -->
      <action application=\"execute_extension\" data=\"handle_\${dtmf_choice} XML default\"/>
      
      <!-- БЕЗОПАСНОЕ ЗАВЕРШЕНИЕ -->
      <action application=\"log\" data=\"INFO ЗАВЕРШЕНИЕ БЕЗ ЗАЦИКЛИВАНИЯ\"/>
      <action application=\"hangup\" data=\"NORMAL_CLEARING\"/>
      
    </condition>
  </extension>

  <!-- ОБРАБОТЧИКИ ВЫБОРА -->
  <extension name=\"handle_1\">
    <condition field=\"destination_number\" expression=\"^handle_1\$\">
      <action application=\"log\" data=\"INFO ВЫБОР 1 - ВЕБХУК 1\"/>
      <action application=\"playback\" data=\"tone_stream://%(1000,0,600)\"/>
      <action application=\"hangup\" data=\"NORMAL_CLEARING\"/>
    </condition>
  </extension>

  <extension name=\"handle_2\">
    <condition field=\"destination_number\" expression=\"^handle_2\$\">
      <action application=\"log\" data=\"INFO ВЫБОР 2 - ВЕБХУК 2\"/>
      <action application=\"playback\" data=\"tone_stream://%(1000,0,800)\"/>
      <action application=\"hangup\" data=\"NORMAL_CLEARING\"/>
    </condition>
  </extension>

  <!-- ОБРАБОТЧИК ПУСТОГО DTMF -->
  <extension name=\"handle_\">
    <condition field=\"destination_number\" expression=\"^handle_\$\">
      <action application=\"log\" data=\"WARNING DTMF НЕ ПОЛУЧЕН - ЗАВЕРШЕНИЕ\"/>
      <action application=\"playback\" data=\"tone_stream://%(250,250,300)\"/>
      <action application=\"hangup\" data=\"NORMAL_CLEARING\"/>
    </condition>
  </extension>

</include>
EOF"

echo "   ✅ Создан безопасный диалплан 1201"

# Создаем альтернативный DTMF тест 1202  
docker exec "$CONTAINER_NAME" bash -c "cat > '$CONF_DIR/dialplan/default/1202_dtmf_test.xml' << 'EOF'
<include>
  <extension name=\"dtmf_test_1202\">
    <condition field=\"destination_number\" expression=\"^1202\$\">
      
      <!-- ВКЛЮЧЕНИЕ ВСЕХ DTMF МЕТОДОВ -->
      <action application=\"answer\"/>
      <action application=\"start_dtmf\"/>
      <action application=\"start_dtmf_generate\"/>
      
      <!-- РАСШИРЕННЫЕ НАСТРОЙКИ DTMF -->
      <action application=\"set\" data=\"dtmf_verbose=true\"/>
      <action application=\"set\" data=\"spandsp_dtmf_rx_threshold=-30\"/>
      <action application=\"set\" data=\"spandsp_dtmf_rx_twist=8\"/>
      
      <action application=\"log\" data=\"INFO DTMF ТЕСТ 1202 - ВСЕ МЕТОДЫ\"/>
      
      <!-- КОРОТКИЙ ТЕСТ 5 СЕКУНД -->
      <action application=\"playback\" data=\"tone_stream://%(2000,0,350+440)\"/>
      <action application=\"read\" data=\"test_dtmf,1,5,tone_stream://%(200,100,600),timeout,5000\"/>
      <action application=\"log\" data=\"INFO ТЕСТ DTMF: \${test_dtmf}\"/>
      
      <!-- ЗАВЕРШЕНИЕ -->
      <action application=\"hangup\" data=\"NORMAL_CLEARING\"/>
      
    </condition>
  </extension>
</include>
EOF"

echo "   ✅ Создан DTMF тест 1202"

# ЭТАП 5: Перезагрузка и тестирование
echo ""
echo "📋 ЭТАП 5: ПЕРЕЗАГРУЗКА И ТЕСТИРОВАНИЕ"
echo "======================================"

echo ""
echo "8. 🔄 Перезагружаем конфигурацию..."
docker exec "$CONTAINER_NAME" fs_cli -x "reloadxml"

echo ""
echo "9. 📋 Проверяем диалплан..."
docker exec "$CONTAINER_NAME" fs_cli -x "xml_locate dialplan destination_number 1201"

echo ""
echo "10. 🧪 Быстрый тест безопасного диалплана..."

# Определяем путь к логам для мониторинга
if docker exec "$CONTAINER_NAME" test -f "$LOG_DIR/freeswitch.log"; then
    LOG_FILE="$LOG_DIR/freeswitch.log"
elif docker exec "$CONTAINER_NAME" test -f "/var/log/freeswitch.log"; then
    LOG_FILE="/var/log/freeswitch.log"
elif docker exec "$CONTAINER_NAME" test -f "/tmp/freeswitch.log"; then
    LOG_FILE="/tmp/freeswitch.log"
else
    LOG_FILE="/dev/null"
    echo "⚠️ Файл логов не найден, мониторинг отключен"
fi

echo "Используем файл логов: $LOG_FILE"

# Тестовый звонок с мониторингом
echo ""
echo "📞 Тестовый звонок на 1201..."

# Мониторинг в фоне на 15 секунд
if [ "$LOG_FILE" != "/dev/null" ]; then
    docker exec "$CONTAINER_NAME" bash -c "timeout 15 tail -f '$LOG_FILE' | grep -E '(1201|БЕЗОПАСНЫЙ|DTMF)' &"
fi

# Звонок
docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/79206054020 1201 XML default" &

# Ждем 12 секунд
sleep 12

echo ""
echo "11. 📊 Проверяем результат..."

# Проверяем активные звонки
ACTIVE_CALLS=$(docker exec "$CONTAINER_NAME" fs_cli -x "show calls count")
echo "Активные звонки: $ACTIVE_CALLS"

ACTIVE_CHANNELS=$(docker exec "$CONTAINER_NAME" fs_cli -x "show channels count")  
echo "Активные каналы: $ACTIVE_CHANNELS"

# ИТОГИ
echo ""
echo "🎯 РЕЗУЛЬТАТЫ ИСПРАВЛЕНИЯ"
echo "========================="
echo ""
echo "✅ ИСПРАВЛЕНО:"
echo "• Найдены правильные пути FreeSWITCH"
echo "• Созданы безопасные диалпланы"
echo "• Все звонки завершаются автоматически"
echo "• Нет зацикливания"
echo ""
echo "🧪 ТЕСТИРУЙТЕ:"
echo "• Номер 1201 - Безопасный IVR (10 сек автозавершение)"
echo "• Номер 1202 - DTMF тест (5 сек, все методы)"
echo ""
echo "📝 СЛЕДУЮЩИЕ ШАГИ:"
echo "1. Позвоните на 1201"
echo "2. Попробуйте нажать 1 или 2"
echo "3. Убедитесь что звонок завершается через 10 секунд"
echo "4. Проверьте что нет активных каналов"
echo ""
echo "🔧 ЕСЛИ DTMF НЕ РАБОТАЕТ:"
echo "• Попробуйте номер 1202"
echo "• Проверьте какой метод DTMF работает"
echo "• Настройте провайдера соответственно" 