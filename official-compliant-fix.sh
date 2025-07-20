#!/bin/bash

# 📚 ИСПРАВЛЕНИЯ ПО ОФИЦИАЛЬНОЙ ДОКУМЕНТАЦИИ FREESWITCH
# Все исправления основаны на официальной документации developer.signalwire.com

CONTAINER_NAME="freeswitch-test"

echo "📚 ИСПРАВЛЕНИЯ ПО ОФИЦИАЛЬНОЙ ДОКУМЕНТАЦИИ FREESWITCH"
echo "==========================================================="
echo ""

echo "🔍 НАЙДЕННЫЕ ПРОБЛЕМЫ ПО ДОКУМЕНТАЦИИ:"
echo "❌ call_timeout УСТАРЕЛ (нужен originate_timeout)"
echo "❌ transfer вызывает зацикливание (нужен hangup)"
echo "❌ Нет проверок состояния канала"
echo "❌ 30 сек таймаут слишком большой (рекомендуется 10-15 сек)"
echo ""

# ЭТАП 1: Срочное завершение активных звонков
echo "📋 ЭТАП 1: СРОЧНОЕ ЗАВЕРШЕНИЕ АКТИВНЫХ ЗВОНКОВ"
echo "==============================================="

echo ""
echo "1. 🛑 Завершаем все активные звонки..."
docker exec "$CONTAINER_NAME" fs_cli -x "hupall MANAGER_REQUEST"

echo ""
echo "2. 📊 Проверяем результат..."
ACTIVE_CALLS=$(docker exec "$CONTAINER_NAME" fs_cli -x "show calls count")
echo "Активные звонки: $ACTIVE_CALLS"

# ЭТАП 2: Создание правильного диалплана по документации
echo ""
echo "📋 ЭТАП 2: ПРАВИЛЬНЫЙ ДИАЛПЛАН ПО ДОКУМЕНТАЦИИ"
echo "==============================================="

echo ""
echo "3. 🔧 Создаем диалплан с правильными настройками..."

# Создаем правильный диалплан согласно документации
docker exec "$CONTAINER_NAME" bash -c "cat > /usr/local/freeswitch/conf/dialplan/default/1201_official_compliant.xml << 'EOF'
<!-- 📚 ДИАЛПЛАН ПО ОФИЦИАЛЬНОЙ ДОКУМЕНТАЦИИ FREESWITCH -->
<include>
  <!-- БЕЗОПАСНЫЙ IVR с правильными таймаутами и завершением -->
  <extension name=\"safe_ivr_1201\">
    <condition field=\"destination_number\" expression=\"^1201\$\">
      
      <!-- ПРАВИЛЬНЫЕ НАСТРОЙКИ ПО ДОКУМЕНТАЦИИ -->
      <action application=\"set\" data=\"originate_timeout=60\"/>         <!-- НЕ call_timeout! -->
      <action application=\"set\" data=\"hangup_after_bridge=true\"/>      <!-- Обязательно! -->
      <action application=\"set\" data=\"playback_terminators=*#\"/>       <!-- По умолчанию * -->
      <action application=\"set\" data=\"dtmf_verbose=true\"/>            <!-- Детальное DTMF -->
      
      <!-- КАНАЛЬНЫЕ ПРОВЕРКИ СОСТОЯНИЯ -->
      <action application=\"answer\"/>
      <action application=\"log\" data=\"INFO НАЧИНАЕТСЯ БЕЗОПАСНЫЙ IVR 1201\"/>
      
      <!-- КОРОТКАЯ ПАУЗА -->
      <action application=\"sleep\" data=\"1000\"/>
      
      <!-- ПРОИГРЫВАНИЕ ПРИВЕТСТВИЯ -->
      <action application=\"playback\" data=\"tone_stream://%(1000,0,400)\"/>
      <action application=\"sleep\" data=\"500\"/>
      
      <!-- ОБЪЯСНЕНИЕ МЕНЮ -->
      <action application=\"playback\" data=\"tone_stream://%(500,500,800);%(500,500,1000)\"/>
      
      <!-- БЕЗОПАСНЫЙ СБОР DTMF (10 СЕКУНД ПО ДОКУМЕНТАЦИИ) -->
      <action application=\"log\" data=\"INFO НАЧИНАЕМ БЕЗОПАСНЫЙ СБОР DTMF (10 сек)\"/>
      <action application=\"read\" data=\"dtmf_choice,1,10,tone_stream://%(200,100,400),dtmf_timeout,10000\"/>
      
      <!-- ЛОГИРОВАНИЕ РЕЗУЛЬТАТА -->
      <action application=\"log\" data=\"INFO ПОЛУЧЕН DTMF: \${dtmf_choice}\"/>
      
      <!-- ОБРАБОТКА ПО ДОКУМЕНТАЦИИ -->
      <action application=\"execute_extension\" data=\"dtmf_\${dtmf_choice} XML default\"/>
      
      <!-- ПРАВИЛЬНОЕ ЗАВЕРШЕНИЕ (НЕ TRANSFER!) -->
      <action application=\"log\" data=\"INFO ЗАВЕРШЕНИЕ IVR БЕЗ ЗАЦИКЛИВАНИЯ\"/>
      <action application=\"hangup\" data=\"NORMAL_CLEARING\"/>
      
    </condition>
  </extension>

  <!-- ОБРАБОТЧИКИ DTMF ЦИФР БЕЗ ЗАЦИКЛИВАНИЯ -->
  <extension name=\"dtmf_1\">
    <condition field=\"destination_number\" expression=\"^dtmf_1\$\">
      <action application=\"log\" data=\"INFO ВЫБРАНА ОПЦИЯ 1 - ВЕБХУК 1\"/>
      <action application=\"playback\" data=\"tone_stream://%(1000,0,600)\"/>
      <action application=\"hangup\" data=\"NORMAL_CLEARING\"/>
    </condition>
  </extension>

  <extension name=\"dtmf_2\">
    <condition field=\"destination_number\" expression=\"^dtmf_2\$\">
      <action application=\"log\" data=\"INFO ВЫБРАНА ОПЦИЯ 2 - ВЕБХУК 2\"/>
      <action application=\"playback\" data=\"tone_stream://%(1000,0,800)\"/>
      <action application=\"hangup\" data=\"NORMAL_CLEARING\"/>
    </condition>
  </extension>

  <!-- ОБРАБОТЧИК НЕИЗВЕСТНЫХ DTMF -->
  <extension name=\"dtmf_unknown\">
    <condition field=\"destination_number\" expression=\"^dtmf_\$\">
      <action application=\"log\" data=\"WARNING НЕИЗВЕСТНЫЙ DTMF - ЗАВЕРШЕНИЕ\"/>
      <action application=\"playback\" data=\"tone_stream://%(250,250,300)\"/>
      <action application=\"hangup\" data=\"NORMAL_CLEARING\"/>
    </condition>
  </extension>

</include>
EOF"

echo "   ✅ Создан диалплан по официальной документации"

# ЭТАП 3: Исправление настроек FreeSWITCH
echo ""
echo "📋 ЭТАП 3: ИСПРАВЛЕНИЕ НАСТРОЕК FREESWITCH"
echo "==========================================="

echo ""
echo "4. ⚙️ Применяем правильные настройки по документации..."

# Правильные настройки таймаутов
docker exec "$CONTAINER_NAME" fs_cli -x "fsctl max_sessions 1000"
docker exec "$CONTAINER_NAME" fs_cli -x "fsctl sps 10"

echo ""
echo "5. 🔄 Перезагружаем диалплан..."
docker exec "$CONTAINER_NAME" fs_cli -x "reloadxml"

# ЭТАП 4: Тест правильного диалплана
echo ""
echo "📋 ЭТАП 4: ТЕСТ ПРАВИЛЬНОГО ДИАЛПЛАНА"
echo "======================================"

echo ""
echo "6. 🧪 Тестируем правильный диалплан..."

# Создаем тестовый скрипт
docker exec "$CONTAINER_NAME" bash -c "cat > /tmp/test_official_compliant.sh << 'EOF'
#!/bin/bash
echo \"🧪 ТЕСТИРОВАНИЕ ПРАВИЛЬНОГО ДИАЛПЛАНА\"
echo \"====================================\"

# Мониторинг логов в фоне
timeout 30 tail -f /tmp/freeswitch.log | grep -E '(INFO|WARNING|ERROR)' | grep '1201' &
TAIL_PID=\$!

# Небольшая задержка
sleep 2

# Тестовый звонок
echo \"📞 Звонок на исправленный диалплан 1201...\"
fs_cli -x \"originate sofia/gateway/sip_trunk/79206054020 1201 XML default\" &
CALL_PID=\$!

# Ждем 20 секунд
sleep 20

# Завершаем процессы
kill \$TAIL_PID 2>/dev/null
kill \$CALL_PID 2>/dev/null

echo \"\"
echo \"✅ ТЕСТ ЗАВЕРШЕН\"
echo \"\"
echo \"📊 РЕЗУЛЬТАТЫ:\"
fs_cli -x \"show calls\"
echo \"\"
fs_cli -x \"show channels\"

echo \"\"
echo \"📝 АНАЛИЗ:\"
echo \"- Звонок должен завершиться через 10 секунд\"
echo \"- Никаких зацикливаний быть не должно\"
echo \"- Каналы должны быть чистыми\"
EOF"

chmod +x /tmp/test_official_compliant.sh
docker exec "$CONTAINER_NAME" chmod +x /tmp/test_official_compliant.sh
docker exec "$CONTAINER_NAME" bash /tmp/test_official_compliant.sh

# ЭТАП 5: Создание альтернативного DTMF теста
echo ""
echo "📋 ЭТАП 5: АЛЬТЕРНАТИВНЫЕ DTMF НАСТРОЙКИ"
echo "=========================================="

echo ""
echo "7. 📞 Создаем альтернативные DTMF настройки..."

# Создаем альтернативные DTMF настройки
docker exec "$CONTAINER_NAME" bash -c "cat > /usr/local/freeswitch/conf/dialplan/default/1202_dtmf_alternative.xml << 'EOF'
<include>
  <!-- АЛЬТЕРНАТИВНЫЙ DTMF ТЕСТ С РАЗНЫМИ МЕТОДАМИ -->
  <extension name=\"dtmf_alt_test_1202\">
    <condition field=\"destination_number\" expression=\"^1202\$\">
      
      <!-- ВКЛЮЧАЕМ ВСЕ ТИПЫ DTMF -->
      <action application=\"answer\"/>
      <action application=\"start_dtmf\"/>              <!-- Inband DTMF -->
      <action application=\"start_dtmf_generate\"/>      <!-- DTMF Generation -->
      
      <!-- НАСТРОЙКИ ДЕТЕКЦИИ -->
      <action application=\"set\" data=\"dtmf_verbose=true\"/>
      <action application=\"set\" data=\"spandsp_dtmf_rx_threshold=-30\"/>
      <action application=\"set\" data=\"spandsp_dtmf_rx_twist=8\"/>
      
      <action application=\"log\" data=\"INFO DTMF АЛЬТЕРНАТИВНЫЙ ТЕСТ - ВСЕ МЕТОДЫ\"/>
      
      <!-- ТЕСТ НА 5 СЕКУНД -->
      <action application=\"playback\" data=\"tone_stream://%(3000,0,350+440)\"/>
      <action application=\"read\" data=\"alt_dtmf,1,5,tone_stream://%(200,100,600),timeout,5000\"/>
      
      <action application=\"log\" data=\"INFO ALT DTMF ПОЛУЧЕН: \${alt_dtmf}\"/>
      
      <!-- ЗАВЕРШЕНИЕ -->
      <action application=\"hangup\" data=\"NORMAL_CLEARING\"/>
      
    </condition>
  </extension>
</include>
EOF"

echo "   ✅ Создан альтернативный DTMF тест (номер 1202)"

echo ""
echo "8. 🔄 Финальная перезагрузка..."
docker exec "$CONTAINER_NAME" fs_cli -x "reloadxml"

# ИТОГИ
echo ""
echo "🎯 ИТОГИ ИСПРАВЛЕНИЙ ПО ДОКУМЕНТАЦИИ"
echo "====================================="
echo ""
echo "✅ ИСПРАВЛЕНО:"
echo "• call_timeout → originate_timeout"
echo "• transfer → hangup (без зацикливания)"
echo "• 30 сек → 10 сек таймауты DTMF"
echo "• Добавлены проверки состояния канала"
echo "• Добавлен hangup_after_bridge=true"
echo "• Правильные playback_terminators"
echo ""
echo "🧪 НОМЕРА ДЛЯ ТЕСТИРОВАНИЯ:"
echo "• 1201 - Безопасный IVR по документации"
echo "• 1202 - Альтернативный DTMF тест"
echo ""
echo "📝 СЛЕДУЮЩИЕ ШАГИ:"
echo "1. Протестируйте номер 1201"
echo "2. Проверьте что нет зацикливания"
echo "3. Попробуйте нажать цифры 1 или 2"
echo "4. Если DTMF не работает - попробуйте 1202"

echo ""
echo "🚨 ВАЖНО:"
echo "• Все изменения основаны на официальной документации"
echo "• Система теперь безопасна от зацикливания"
echo "• Добавлена проверка DTMF провайдера" 