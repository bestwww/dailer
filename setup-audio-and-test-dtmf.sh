#!/bin/bash

# 🎵📞 Настройка аудиофайлов и тестирование DTMF
# Перемещает аудиофайлы в правильные директории и тестирует нажатия кнопок

set -e

echo "🎵📞 === НАСТРОЙКА АУДИО И ТЕСТИРОВАНИЕ DTMF ==="
echo

# Функция для логирования
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [AUDIO] $1"
}

# Получаем ID контейнера FreeSWITCH
CONTAINER_ID=$(docker ps | grep freeswitch | awk '{print $1}' | head -1)

if [[ -z "$CONTAINER_ID" ]]; then
    log "❌ FreeSWITCH контейнер не найден!"
    log "🚀 Запускаем FreeSWITCH..."
    docker compose up -d freeswitch
    sleep 15
    CONTAINER_ID=$(docker ps | grep freeswitch | awk '{print $1}' | head -1)
fi

log "🐳 FreeSWITCH контейнер: $CONTAINER_ID"

# 1. НАСТРОЙКА АУДИОФАЙЛОВ
log "📁 Настраиваем структуру директорий для аудиофайлов..."

# Создаем директории
log "📂 Создаем директории в контейнере..."
docker exec $CONTAINER_ID mkdir -p /usr/local/freeswitch/sounds/custom
docker exec $CONTAINER_ID mkdir -p /usr/local/freeswitch/sounds/test

# Проверяем доступные аудиофайлы
log "🔍 Проверяем доступные аудиофайлы..."
echo "Найденные аудиофайлы в контейнере:"
docker exec $CONTAINER_ID find /usr/local/freeswitch/sounds -name "*.mp3" -o -name "*.wav"

# Перемещаем example_1.mp3 в custom
log "🔄 Перемещаем example_1.mp3 в директорию custom..."
if docker exec $CONTAINER_ID test -f /usr/local/freeswitch/sounds/example_1.mp3; then
    docker exec $CONTAINER_ID cp /usr/local/freeswitch/sounds/example_1.mp3 /usr/local/freeswitch/sounds/custom/
    log "✅ example_1.mp3 скопирован в custom/"
else
    log "⚠️ example_1.mp3 не найден, используем другой файл..."
    # Используем первый найденный mp3
    FIRST_MP3=$(docker exec $CONTAINER_ID find /usr/local/freeswitch/sounds -name "*.mp3" | head -1)
    if [[ -n "$FIRST_MP3" ]]; then
        log "📄 Используем файл: $FIRST_MP3"
        docker exec $CONTAINER_ID cp "$FIRST_MP3" /usr/local/freeswitch/sounds/custom/test_audio.mp3
        log "✅ Аудиофайл скопирован как test_audio.mp3"
    fi
fi

# 2. СОЗДАНИЕ ТЕСТОВОГО ДИАЛПЛАНА ДЛЯ DTMF
log "📞 Создаем тестовый диалплан для DTMF..."

cat << 'EOF' > /tmp/dtmf_test_dialplan.xml
<!-- Тестовый диалплан для проверки DTMF -->
<extension name="dtmf_test_with_audio">
  <condition field="destination_number" expression="^1299$">
    
    <!-- Логирование начала теста -->
    <action application="log" data="INFO === DTMF TEST STARTED === Номер: 1299"/>
    
    <!-- Отвечаем на звонок -->
    <action application="answer"/>
    <action application="sleep" data="1000"/>
    
    <!-- Проигрываем аудиофайл -->
    <action application="log" data="INFO Проигрываем аудиофайл..."/>
    <action application="playback" data="/usr/local/freeswitch/sounds/custom/example_1.mp3"/>
    
    <!-- Ждем DTMF ввод -->
    <action application="log" data="INFO Ожидаем DTMF ввод от пользователя..."/>
    <action application="playback" data="tone_stream://%(1000,500,800);loops=1"/>
    <action application="sleep" data="500"/>
    
    <!-- Читаем DTMF (1 цифра, максимум 10 секунд ожидания) -->
    <action application="read" data="user_dtmf 1 1 tone_stream://%(500,500,400) user_dtmf 10000 #"/>
    
    <!-- Логируем полученный DTMF -->
    <action application="log" data="INFO DTMF RECEIVED: ${user_dtmf}"/>
    
    <!-- Обрабатываем разные варианты DTMF -->
    <action application="execute_extension" data="process_dtmf_result XML default"/>
    
  </condition>
</extension>

<!-- Обработка результатов DTMF -->
<extension name="process_dtmf_result">
  <condition field="destination_number" expression="^process_dtmf_result$">
    
    <!-- Проверяем нажатие "1" -->
    <condition field="${user_dtmf}" expression="^1$">
      <action application="log" data="SUCCESS DTMF=1: Пользователь нажал 1 (заинтересован)"/>
      <action application="playback" data="tone_stream://%(2000,500,600,700);loops=2"/>
      <action application="sleep" data="1000"/>
      <action application="hangup" data="NORMAL_CLEARING"/>
    </condition>
    
    <!-- Проверяем нажатие "2" -->
    <condition field="${user_dtmf}" expression="^2$">
      <action application="log" data="SUCCESS DTMF=2: Пользователь нажал 2 (не заинтересован)"/>
      <action application="playback" data="tone_stream://%(1000,500,400);loops=1"/>
      <action application="sleep" data="1000"/>
      <action application="hangup" data="NORMAL_CLEARING"/>
    </condition>
    
    <!-- Проверяем нажатие "*" -->
    <condition field="${user_dtmf}" expression="^\*$">
      <action application="log" data="SUCCESS DTMF=*: Пользователь нажал * (повтор)"/>
      <action application="playback" data="tone_stream://%(500,200,800);loops=3"/>
      <action application="transfer" data="1299 XML default"/>
    </condition>
    
    <!-- Любая другая цифра -->
    <action application="log" data="WARNING DTMF=${user_dtmf}: Неизвестная цифра или timeout"/>
    <action application="playback" data="tone_stream://%(3000,1000,200,300);loops=1"/>
    <action application="sleep" data="1000"/>
    <action application="hangup" data="NORMAL_CLEARING"/>
    
  </condition>
</extension>
EOF

# Копируем диалплан в контейнер
log "📋 Добавляем тестовый диалплан в FreeSWITCH..."
docker cp /tmp/dtmf_test_dialplan.xml $CONTAINER_ID:/tmp/
docker exec $CONTAINER_ID mkdir -p /usr/local/freeswitch/conf/dialplan/test
docker exec $CONTAINER_ID mv /tmp/dtmf_test_dialplan.xml /usr/local/freeswitch/conf/dialplan/test/

# Включаем тестовый диалплан в основной
log "🔗 Включаем тестовый диалплан в основной default.xml..."
docker exec $CONTAINER_ID sed -i '/<\/context>/i \    <!-- Тестовый DTMF диалплан -->\n    <X-PRE-PROCESS cmd="include" data="test/*.xml"/>' /usr/local/freeswitch/conf/dialplan/default.xml

# 3. ПЕРЕЗАГРУЖАЕМ ДИАЛПЛАН
log "🔄 Перезагружаем диалплан FreeSWITCH..."
docker exec $CONTAINER_ID fs_cli -x "reloadxml"
sleep 2

# 4. ПРОВЕРКА НАСТРОЕК
log "📊 Проверяем настройки..."

echo ""
echo "🎵 АУДИОФАЙЛЫ В КОНТЕЙНЕРЕ:"
docker exec $CONTAINER_ID ls -la /usr/local/freeswitch/sounds/custom/ 2>/dev/null || echo "Директория custom не найдена"

echo ""
echo "📞 ТЕСТОВЫЕ НОМЕРА ДЛЯ DTMF:"
echo "  1299 - Тест с аудиофайлом + DTMF"
echo "  1204 - Имитация человека (заинтересован)"
echo "  1205 - Имитация автоответчика"
echo "  1206 - Недоступный номер"

echo ""
echo "🎯 КАК ТЕСТИРОВАТЬ DTMF:"
echo "  1. Позвоните на 1299"
echo "  2. Прослушайте аудиофайл"
echo "  3. Нажмите цифру:"
echo "     - 1 = Заинтересован"
echo "     - 2 = Не заинтересован"  
echo "     - * = Повтор сообщения"
echo "     - Любая другая = Неизвестно"

echo ""
echo "📋 КОМАНДЫ ДЛЯ ТЕСТИРОВАНИЯ:"
echo "  # Звонок через FreeSWITCH CLI"
echo "  docker exec $CONTAINER_ID fs_cli -x \"originate user/1299 &echo\""
echo ""
echo "  # Звонок с мониторингом логов"
echo "  docker logs -f $CONTAINER_ID | grep -E '(DTMF|SUCCESS|WARNING|INFO)'"

echo ""
log "✅ Настройка завершена! Теперь можно тестировать DTMF."

# 5. АВТОМАТИЧЕСКИЙ ТЕСТ
echo ""
read -p "Хотите запустить автоматический тест DTMF? (y/N): " auto_test

if [[ $auto_test == [yY] ]]; then
    log "🚀 Запускаем автоматический тест номера 1299..."
    
    echo ""
    echo "📱 Следите за логами FreeSWITCH:"
    timeout 30 docker logs -f $CONTAINER_ID | grep -E "(DTMF|SUCCESS|WARNING|INFO.*1299)" &
    LOGS_PID=$!
    
    sleep 2
    log "📞 Выполняем звонок на 1299..."
    docker exec $CONTAINER_ID fs_cli -x "originate user/1299 &echo"
    
    sleep 10
    kill $LOGS_PID 2>/dev/null || true
    
    log "✅ Автоматический тест завершен. Проверьте логи выше."
fi

echo ""
log "🎯 ГОТОВО! Используйте номер 1299 для тестирования DTMF с аудиофайлом." 