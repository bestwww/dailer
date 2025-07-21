#!/bin/bash

# 🎵🔧 Исправление проблем с воспроизведением аудио
# Диагностика и настройка аудиофайлов для FreeSWITCH

set -e

echo "🎵🔧 === ДИАГНОСТИКА И ИСПРАВЛЕНИЕ АУДИО ==="
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

# 1. ПРОВЕРЯЕМ СТАТУС FREESWITCH
log "📊 Проверяем статус FreeSWITCH..."
echo ""
echo "=== СТАТУС FREESWITCH ==="
docker exec $CONTAINER_ID fs_cli -x "status" || log "⚠️ Проблемы с fs_cli"

echo ""
echo "=== МОДУЛИ ==="
docker exec $CONTAINER_ID fs_cli -x "show modules" | grep -E "(sofia|sndfile|playback)" || log "⚠️ Проблемы с модулями"

# 2. ПРОВЕРЯЕМ АУДИОФАЙЛЫ
log "🎵 Проверяем аудиофайлы..."
echo ""
echo "=== ПОИСК АУДИОФАЙЛОВ ==="
docker exec $CONTAINER_ID find /usr/local/freeswitch/sounds -name "*.mp3" -o -name "*.wav" | head -10

echo ""
echo "=== ПРОВЕРЯЕМ EXAMPLE_1.MP3 ==="
if docker exec $CONTAINER_ID test -f /usr/local/freeswitch/sounds/custom/example_1.mp3; then
    log "✅ Найден: /usr/local/freeswitch/sounds/custom/example_1.mp3"
    docker exec $CONTAINER_ID ls -la /usr/local/freeswitch/sounds/custom/example_1.mp3
    AUDIO_FILE="/usr/local/freeswitch/sounds/custom/example_1.mp3"
elif docker exec $CONTAINER_ID test -f /usr/local/freeswitch/sounds/example_1.mp3; then
    log "✅ Найден: /usr/local/freeswitch/sounds/example_1.mp3"
    docker exec $CONTAINER_ID ls -la /usr/local/freeswitch/sounds/example_1.mp3
    AUDIO_FILE="/usr/local/freeswitch/sounds/example_1.mp3"
else
    log "❌ example_1.mp3 не найден! Копируем заново..."
    
    # Копируем аудиофайл заново
    if [[ -f "audio/example_1.mp3" ]]; then
        docker exec $CONTAINER_ID mkdir -p /usr/local/freeswitch/sounds/custom
        docker cp audio/example_1.mp3 $CONTAINER_ID:/usr/local/freeswitch/sounds/custom/
        log "✅ Скопирован в custom/"
        AUDIO_FILE="/usr/local/freeswitch/sounds/custom/example_1.mp3"
    elif [[ -f "1.mp3" ]]; then
        docker exec $CONTAINER_ID mkdir -p /usr/local/freeswitch/sounds/custom
        docker cp 1.mp3 $CONTAINER_ID:/usr/local/freeswitch/sounds/custom/example_1.mp3
        log "✅ Скопирован 1.mp3 как example_1.mp3"
        AUDIO_FILE="/usr/local/freeswitch/sounds/custom/example_1.mp3"
    else
        log "❌ Аудиофайл не найден локально!"
        AUDIO_FILE="/usr/local/freeswitch/sounds/music/8000/suite-espanola-op-47-leyenda.wav"
        log "📄 Используем тестовый файл: $AUDIO_FILE"
    fi
fi

# 3. ТЕСТИРУЕМ ВОСПРОИЗВЕДЕНИЕ АУДИО
log "🎵 Тестируем воспроизведение аудио..."
echo ""
echo "=== ТЕСТ PLAYBACK В FREESWITCH ==="

# Тест 1: Простой playback
log "Тест 1: Простой playback файла"
docker exec $CONTAINER_ID fs_cli -x "originate null/null &playback($AUDIO_FILE)" && log "✅ Тест 1 успешен" || log "❌ Тест 1 не прошел"

sleep 2

# Тест 2: Проверяем кодеки
log "Тест 2: Проверяем кодеки"
docker exec $CONTAINER_ID fs_cli -x "show codecs" | grep -E "(PCMU|PCMA|G722)" || log "⚠️ Проблемы с кодеками"

# 4. ПРОВЕРЯЕМ SIP-ТРАНК
log "🌐 Проверяем SIP-транк..."
echo ""
echo "=== SIP ТРАНК ==="
docker exec $CONTAINER_ID fs_cli -x "sofia status" | grep -E "(internal|external|sip_trunk)"
docker exec $CONTAINER_ID fs_cli -x "sofia status gateway sip_trunk" || log "⚠️ Проблемы с SIP транком"

# 5. СОЗДАЕМ ПРАВИЛЬНУЮ КОМАНДУ ORIGINATE
log "📞 Создаем правильную команду для звонка с аудио..."

echo ""
echo "=== РЕКОМЕНДОВАННЫЕ КОМАНДЫ ==="
echo ""

echo "🎯 СПОСОБ 1 - Originate с inline playback:"
echo "docker exec $CONTAINER_ID fs_cli -x \"originate {execute_on_answer='playback $AUDIO_FILE'}sofia/gateway/sip_trunk/79206054020 &echo\""

echo ""
echo "🎯 СПОСОБ 2 - Bridge с execute_on_answer:"
echo "docker exec $CONTAINER_ID fs_cli -x \"originate {execute_on_answer='playback $AUDIO_FILE',hangup_after_bridge=false}sofia/gateway/sip_trunk/79206054020 &park\""

echo ""
echo "🎯 СПОСОБ 3 - Через UUID и play после answer:"
echo "UUID=\$(docker exec $CONTAINER_ID fs_cli -x \"create_uuid\")"
echo "docker exec $CONTAINER_ID fs_cli -x \"originate {origination_uuid=\$UUID}sofia/gateway/sip_trunk/79206054020 &park\""
echo "docker exec $CONTAINER_ID fs_cli -x \"uuid_broadcast \$UUID $AUDIO_FILE aleg\""

echo ""
echo "🎯 СПОСОБ 4 - Простой способ (рекомендуется):"
echo "docker exec $CONTAINER_ID fs_cli -x \"bgapi originate sofia/gateway/sip_trunk/79206054020 &playback($AUDIO_FILE)\""

# 6. АВТОМАТИЧЕСКИЙ ТЕСТ
echo ""
read -p "🧪 Хотите протестировать Способ 4 сейчас? (y/N): " test_now

if [[ $test_now == [yY] ]]; then
    log "📞 Тестируем Способ 4..."
    log "📱 Приготовьтесь к звонку на 79206054020!"
    
    echo ""
    echo "⏳ Запуск через 3 секунды..."
    sleep 3
    
    # Запускаем мониторинг
    log "📊 Запускаем мониторинг..."
    timeout 30 docker logs -f $CONTAINER_ID | grep -E "(79206054020|playback|AUDIO)" &
    LOGS_PID=$!
    
    sleep 1
    
    # Выполняем звонок
    log "📞 Выполняем тестовый звонок..."
    RESULT=$(docker exec $CONTAINER_ID fs_cli -x "bgapi originate sofia/gateway/sip_trunk/79206054020 &playback($AUDIO_FILE)")
    echo "Результат: $RESULT"
    
    sleep 15
    kill $LOGS_PID 2>/dev/null || true
    
    log "✅ Тест завершен!"
    
    echo ""
    echo "📋 Что должно было произойти:"
    echo "1. 📞 Звонок на 79206054020"
    echo "2. 📱 Вы отвечаете"
    echo "3. 🎵 Проигрывается аудиофайл $AUDIO_FILE"
fi

echo ""
log "🎯 ДИАГНОСТИКА ЗАВЕРШЕНА!"

echo ""
echo "📋 === ИТОГИ ==="
echo "• Аудиофайл: $AUDIO_FILE"
echo "• Рекомендуемая команда: bgapi originate"
echo "• Проверьте статус SIP-транка"
echo ""
echo "💡 ЕСЛИ АУДИО ВСЕ ЕЩЕ НЕ РАБОТАЕТ:"
echo "1. Перезапустите FreeSWITCH: docker compose restart freeswitch"
echo "2. Проверьте формат аудиофайла (должен быть WAV или MP3)"
echo "3. Используйте команду bgapi вместо обычного originate" 