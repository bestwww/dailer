#!/bin/bash

# 📞🎵 Настройка реального звонка с аудиофайлом
# Звонок на реальный номер 79206054020 с проигрыванием example_1.mp3

set -e

echo "📞🎵 === НАСТРОЙКА РЕАЛЬНОГО ЗВОНКА С АУДИОФАЙЛОМ ==="
echo

# Функция для логирования
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [CALL] $1"
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

# 1. ПРОВЕРЯЕМ АУДИОФАЙЛ
log "🎵 Проверяем наличие аудиофайла..."
if docker exec $CONTAINER_ID test -f /usr/local/freeswitch/sounds/custom/example_1.mp3; then
    log "✅ Аудиофайл example_1.mp3 найден в custom/"
    AUDIO_FILE="/usr/local/freeswitch/sounds/custom/example_1.mp3"
elif docker exec $CONTAINER_ID test -f /usr/local/freeswitch/sounds/example_1.mp3; then
    log "✅ Аудиофайл example_1.mp3 найден в sounds/"
    AUDIO_FILE="/usr/local/freeswitch/sounds/example_1.mp3"
else
    log "⚠️ example_1.mp3 не найден, ищем любой MP3..."
    AUDIO_FILE=$(docker exec $CONTAINER_ID find /usr/local/freeswitch/sounds -name "*.mp3" | head -1)
    if [[ -n "$AUDIO_FILE" ]]; then
        log "📄 Используем файл: $AUDIO_FILE"
    else
        log "❌ Аудиофайлы не найдены!"
        exit 1
    fi
fi

# 2. СОЗДАЕМ СПЕЦИАЛЬНЫЙ ДИАЛПЛАН
log "📞 Создаем диалплан для реального звонка с аудио..."

cat << EOF > /tmp/real_call_with_audio.xml
<!-- Диалплан для реального звонка с аудиофайлом -->
<extension name="real_call_with_audio_79206054020">
  <condition field="destination_number" expression="^test_real_79206054020\$">
    
    <!-- Логирование начала реального звонка -->
    <action application="log" data="INFO === REAL CALL WITH AUDIO STARTED === Target: 79206054020"/>
    
    <!-- Настройки для реального звонка -->
    <action application="set" data="effective_caller_id_name=Dailer_Test"/>
    <action application="set" data="effective_caller_id_number=79058615815"/>
    <action application="set" data="sip_from_user=79058615815"/>
    <action application="set" data="sip_from_host=46.173.16.147"/>
    
    <!-- Переменные для звонка -->
    <action application="set" data="hangup_after_bridge=false"/>
    <action application="set" data="continue_on_fail=true"/>
    <action application="set" data="call_timeout=30"/>
    <action application="set" data="progress_timeout=6"/>
    
    <!-- Устанавливаем переменную с аудиофайлом -->
    <action application="set" data="playback_file=$AUDIO_FILE"/>
    
    <!-- Выполняем звонок через SIP транк -->
    <action application="log" data="INFO Звоним на 79206054020 через SIP транк..."/>
    <action application="bridge" data="{execute_on_answer='playback \${playback_file}'}sofia/gateway/sip_trunk/79206054020"/>
    
    <!-- Обработка результата -->
    <action application="log" data="INFO Результат звонка: \${hangup_cause}"/>
    
    <!-- Если звонок не прошел, логируем -->
    <action application="hangup" data="\${hangup_cause}"/>
    
  </condition>
</extension>

<!-- Альтернативный способ - прямой originate с аудио -->
<extension name="originate_with_audio">
  <condition field="destination_number" expression="^call_79206054020_with_audio\$">
    
    <action application="log" data="INFO Прямой originate на 79206054020 с аудиофайлом"/>
    
    <!-- Выполняем originate с проигрыванием аудио -->
    <action application="originate" data="sofia/gateway/sip_trunk/79206054020 &playback($AUDIO_FILE)"/>
    
    <action application="hangup" data="NORMAL_CLEARING"/>
    
  </condition>
</extension>
EOF

# Копируем диалплан в контейнер
log "📋 Добавляем диалплан для реального звонка..."
docker cp /tmp/real_call_with_audio.xml $CONTAINER_ID:/tmp/
docker exec $CONTAINER_ID mkdir -p /usr/local/freeswitch/conf/dialplan/real_call
docker exec $CONTAINER_ID mv /tmp/real_call_with_audio.xml /usr/local/freeswitch/conf/dialplan/real_call/

# Включаем диалплан в основной
log "🔗 Включаем диалплан реального звонка..."
docker exec $CONTAINER_ID sed -i '/<\/context>/i \    <!-- Реальный звонок с аудио -->\n    <X-PRE-PROCESS cmd="include" data="real_call/*.xml"/>' /usr/local/freeswitch/conf/dialplan/default.xml

# 3. ПЕРЕЗАГРУЖАЕМ ДИАЛПЛАН
log "🔄 Перезагружаем диалплан FreeSWITCH..."
docker exec $CONTAINER_ID fs_cli -x "reloadxml"
sleep 2

# 4. ПРОВЕРЯЕМ НАСТРОЙКИ SIP
log "🔗 Проверяем SIP транк..."
echo ""
echo "📊 Статус Sofia профилей:"
docker exec $CONTAINER_ID fs_cli -x "sofia status"

echo ""
echo "🌐 Состояние SIP транка:"
docker exec $CONTAINER_ID fs_cli -x "sofia status gateway sip_trunk"

# 5. ИНФОРМАЦИЯ О ТЕСТИРОВАНИИ
echo ""
echo "📞 === КОМАНДЫ ДЛЯ РЕАЛЬНОГО ЗВОНКА С АУДИО ==="
echo ""
echo "🎯 СПОСОБ 1 - Через диалплан (рекомендуется):"
echo "  docker exec $CONTAINER_ID fs_cli -x \"originate user/test_real_79206054020 &echo\""
echo ""
echo "🎯 СПОСОБ 2 - Прямой originate:"
echo "  docker exec $CONTAINER_ID fs_cli -x \"originate sofia/gateway/sip_trunk/79206054020 &playback($AUDIO_FILE)\""
echo ""
echo "🎯 СПОСОБ 3 - Через второй диалплан:"
echo "  docker exec $CONTAINER_ID fs_cli -x \"originate user/call_79206054020_with_audio &echo\""

echo ""
echo "📱 === ЧТО ПРОИЗОЙДЕТ ==="
echo "1. 📞 FreeSWITCH позвонит на ваш номер 79206054020"
echo "2. 📱 На вашем телефоне будет отображаться номер 79058615815"
echo "3. 📞 Когда вы ответите, услышите аудиофайл example_1.mp3"
echo "4. 📊 Все действия будут записаны в логи FreeSWITCH"

echo ""
echo "🔍 === МОНИТОРИНГ ЗВОНКА ==="
echo "  # Логи в реальном времени"
echo "  docker logs -f $CONTAINER_ID | grep -E '(79206054020|REAL CALL|AUDIO|sofia/gateway)'"
echo ""
echo "  # Активные звонки"
echo "  docker exec $CONTAINER_ID fs_cli -x \"show calls\""

echo ""
log "✅ Настройка завершена!"

# 6. АВТОМАТИЧЕСКИЙ ТЕСТ
echo ""
read -p "🚀 Хотите сразу позвонить на ваш номер 79206054020? (y/N): " make_call

if [[ $make_call == [yY] ]]; then
    log "📞 ВНИМАНИЕ! Сейчас будет реальный звонок на ваш телефон!"
    log "📱 Приготовьтесь ответить на звонок с номера 79058615815"
    
    echo ""
    echo "⏳ Запуск через 5 секунд..."
    sleep 5
    
    # Запускаем мониторинг логов
    log "📊 Запускаем мониторинг логов..."
    timeout 60 docker logs -f $CONTAINER_ID | grep -E "(79206054020|REAL CALL|AUDIO|sofia|gateway|playback)" &
    LOGS_PID=$!
    
    sleep 2
    
    # Выполняем звонок
    log "📞 Выполняем реальный звонок..."
    docker exec $CONTAINER_ID fs_cli -x "originate sofia/gateway/sip_trunk/79206054020 &playback($AUDIO_FILE)"
    
    sleep 10
    kill $LOGS_PID 2>/dev/null || true
    
    log "✅ Звонок выполнен! Проверьте ваш телефон."
fi

echo ""
log "🎯 ГОТОВО! Теперь можете звонить на свой номер с аудиофайлом." 