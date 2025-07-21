#!/bin/bash

# 🎵⚡ Быстрое исправление и тест аудио
# Простое решение проблемы с воспроизведением аудиофайла

echo "🎵⚡ === БЫСТРОЕ ИСПРАВЛЕНИЕ АУДИО ==="
echo

# Получаем ID контейнера FreeSWITCH
CONTAINER_ID=$(docker ps | grep freeswitch | awk '{print $1}' | head -1)

if [[ -z "$CONTAINER_ID" ]]; then
    echo "❌ FreeSWITCH контейнер не найден!"
    echo "🚀 Перезапускаем FreeSWITCH..."
    docker compose restart freeswitch
    sleep 20
    CONTAINER_ID=$(docker ps | grep freeswitch | awk '{print $1}' | head -1)
fi

echo "🐳 FreeSWITCH: $CONTAINER_ID"

# 1. КОПИРУЕМ АУДИОФАЙЛ ЕСЛИ НУЖНО
echo "📂 Проверяем аудиофайл..."
if ! docker exec $CONTAINER_ID test -f /usr/local/freeswitch/sounds/custom/example_1.mp3; then
    echo "📥 Копируем аудиофайл..."
    docker exec $CONTAINER_ID mkdir -p /usr/local/freeswitch/sounds/custom
    
    if [[ -f "audio/example_1.mp3" ]]; then
        docker cp audio/example_1.mp3 $CONTAINER_ID:/usr/local/freeswitch/sounds/custom/
        echo "✅ Скопирован audio/example_1.mp3"
    elif [[ -f "1.mp3" ]]; then
        docker cp 1.mp3 $CONTAINER_ID:/usr/local/freeswitch/sounds/custom/example_1.mp3
        echo "✅ Скопирован 1.mp3"
    fi
fi

# 2. ПЕРЕЗАГРУЖАЕМ МОДУЛИ
echo "🔄 Перезагружаем модули..."
docker exec $CONTAINER_ID fs_cli -x "reload mod_sofia"
docker exec $CONTAINER_ID fs_cli -x "reload mod_sndfile"

# 3. ПРОВЕРЯЕМ SIP ТРАНК
echo "🌐 Проверяем SIP транк..."
docker exec $CONTAINER_ID fs_cli -x "sofia status gateway sip_trunk"

echo ""
echo "🎯 === ИСПРАВЛЕННЫЕ КОМАНДЫ ДЛЯ ЗВОНКА ==="
echo ""

# ПРАВИЛЬНЫЕ КОМАНДЫ
echo "✅ СПОСОБ 1 (рекомендуется) - bgapi originate:"
echo "docker exec $CONTAINER_ID fs_cli -x \"bgapi originate sofia/gateway/sip_trunk/79206054020 &playback(/usr/local/freeswitch/sounds/custom/example_1.mp3)\""

echo ""
echo "✅ СПОСОБ 2 - execute_on_answer:"
echo "docker exec $CONTAINER_ID fs_cli -x \"originate {execute_on_answer='playback /usr/local/freeswitch/sounds/custom/example_1.mp3'}sofia/gateway/sip_trunk/79206054020 &park\""

echo ""
echo "✅ СПОСОБ 3 - uuid_broadcast (наиболее надежный):"
echo "UUID=\$(docker exec $CONTAINER_ID fs_cli -x \"create_uuid\")"
echo "docker exec $CONTAINER_ID fs_cli -x \"bgapi originate {origination_uuid=\$UUID}sofia/gateway/sip_trunk/79206054020 &park\""
echo "sleep 3"
echo "docker exec $CONTAINER_ID fs_cli -x \"uuid_broadcast \$UUID /usr/local/freeswitch/sounds/custom/example_1.mp3 aleg\""

echo ""
read -p "🚀 Попробовать СПОСОБ 1 сейчас? (y/N): " test_way1

if [[ $test_way1 == [yY] ]]; then
    echo ""
    echo "📞 ВНИМАНИЕ! Звоним на 79206054020 с аудио!"
    echo "📱 Приготовьтесь ответить..."
    echo ""
    
    echo "⏳ Запуск через 3 секунды..."
    sleep 3
    
    echo "📞 Выполняем звонок..."
    RESULT=$(docker exec $CONTAINER_ID fs_cli -x "bgapi originate sofia/gateway/sip_trunk/79206054020 &playback(/usr/local/freeswitch/sounds/custom/example_1.mp3)")
    echo "Результат: $RESULT"
    
    echo ""
    echo "✅ Звонок запущен! Ответьте на телефон и должны услышать аудио."
fi

echo ""
read -p "🔊 Попробовать СПОСОБ 3 (самый надежный)? (y/N): " test_way3

if [[ $test_way3 == [yY] ]]; then
    echo ""
    echo "📞 СПОСОБ 3: UUID + Broadcast"
    echo "📱 Приготовьтесь ответить на 79206054020..."
    echo ""
    
    echo "⏳ Запуск через 3 секунды..."
    sleep 3
    
    echo "1️⃣ Создаем UUID..."
    UUID=$(docker exec $CONTAINER_ID fs_cli -x "create_uuid")
    echo "UUID: $UUID"
    
    echo "2️⃣ Звоним..."
    docker exec $CONTAINER_ID fs_cli -x "bgapi originate {origination_uuid=$UUID}sofia/gateway/sip_trunk/79206054020 &park"
    
    echo "3️⃣ Ждем ответа (5 сек)..."
    sleep 5
    
    echo "4️⃣ Проигрываем аудио..."
    docker exec $CONTAINER_ID fs_cli -x "uuid_broadcast $UUID /usr/local/freeswitch/sounds/custom/example_1.mp3 aleg"
    
    echo "✅ Аудио должно проигрываться прямо сейчас!"
    
    sleep 10
    echo "5️⃣ Завершаем звонок..."
    docker exec $CONTAINER_ID fs_cli -x "uuid_kill $UUID"
fi

echo ""
echo "🎯 БЫСТРОЕ ИСПРАВЛЕНИЕ ЗАВЕРШЕНО!"
echo ""
echo "💡 ЕСЛИ АУДИО ВСЕ ЕЩЕ НЕ СЛЫШНО:"
echo "1. Используйте СПОСОБ 3 (uuid_broadcast)"
echo "2. Попробуйте WAV файл вместо MP3"
echo "3. Проверьте что телефон поддерживает кодеки PCMU/PCMA" 