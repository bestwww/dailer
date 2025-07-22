#!/bin/bash

# 🎵📥 Скачивание и проверка аудиофайлов из FreeSWITCH
# Проверяем содержимое аудиофайлов на предмет пустоты или повреждения

echo "🎵📥 === СКАЧИВАНИЕ И ПРОВЕРКА АУДИОФАЙЛОВ ==="
echo

# Получаем ID контейнера FreeSWITCH
CONTAINER_ID=$(docker ps | grep freeswitch | awk '{print $1}' | head -1)

if [[ -z "$CONTAINER_ID" ]]; then
    echo "❌ FreeSWITCH контейнер не найден!"
    docker compose up -d freeswitch
    sleep 10
    CONTAINER_ID=$(docker ps | grep freeswitch | awk '{print $1}' | head -1)
fi

echo "🐳 FreeSWITCH контейнер: $CONTAINER_ID"

# Создаем папку для скачанных файлов
mkdir -p downloaded_audio
echo "📁 Создана папка downloaded_audio/"

echo ""
echo "🔍 === ПОИСК АУДИОФАЙЛОВ В КОНТЕЙНЕРЕ ==="

# Ищем все аудиофайлы в контейнере
echo "📂 Ищем аудиофайлы..."
docker exec $CONTAINER_ID find /usr/local/freeswitch/sounds -name "*.mp3" -o -name "*.wav" | head -20

echo ""
echo "📥 === СКАЧИВАНИЕ ФАЙЛОВ ==="

# 1. Скачиваем example_1.mp3 если есть
if docker exec $CONTAINER_ID test -f /usr/local/freeswitch/sounds/custom/example_1.mp3; then
    echo "📥 Скачиваем example_1.mp3 из custom/"
    docker cp $CONTAINER_ID:/usr/local/freeswitch/sounds/custom/example_1.mp3 downloaded_audio/
    echo "✅ downloaded_audio/example_1.mp3"
elif docker exec $CONTAINER_ID test -f /usr/local/freeswitch/sounds/example_1.mp3; then
    echo "📥 Скачиваем example_1.mp3 из sounds/"
    docker cp $CONTAINER_ID:/usr/local/freeswitch/sounds/example_1.mp3 downloaded_audio/
    echo "✅ downloaded_audio/example_1.mp3"
else
    echo "⚠️ example_1.mp3 не найден в контейнере"
fi

# 2. Скачиваем несколько тестовых файлов FreeSWITCH
echo ""
echo "📥 Скачиваем стандартные аудиофайлы FreeSWITCH для сравнения..."

# Стандартные файлы FreeSWITCH (если есть)
STANDARD_FILES=(
    "/usr/local/freeswitch/sounds/music/8000/suite-espanola-op-47-leyenda.wav"
    "/usr/local/freeswitch/sounds/en/us/callie/misc/8000/misc-freeswitch_is_state_of_the_art.wav"
    "/usr/local/freeswitch/sounds/en/us/callie/voicemail/8000/vm-hello.wav"
)

for file in "${STANDARD_FILES[@]}"; do
    filename=$(basename "$file")
    if docker exec $CONTAINER_ID test -f "$file"; then
        echo "📥 Скачиваем $filename"
        docker cp $CONTAINER_ID:"$file" downloaded_audio/
        echo "✅ downloaded_audio/$filename"
    else
        echo "⚠️ $filename не найден"
    fi
done

echo ""
echo "📊 === ПРОВЕРКА СКАЧАННЫХ ФАЙЛОВ ==="

# Проверяем размеры файлов
echo "📏 Размеры файлов:"
ls -lh downloaded_audio/ 2>/dev/null || echo "Папка пуста"

echo ""
echo "🔍 === ДЕТАЛЬНАЯ ПРОВЕРКА ==="

for file in downloaded_audio/*; do
    if [[ -f "$file" ]]; then
        filename=$(basename "$file")
        size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
        
        echo ""
        echo "🎵 === $filename ==="
        echo "📏 Размер: $size байт"
        
        if [[ $size -eq 0 ]]; then
            echo "❌ ФАЙЛ ПУСТОЙ!"
        elif [[ $size -lt 1000 ]]; then
            echo "⚠️ Файл очень маленький (меньше 1KB)"
        else
            echo "✅ Файл нормального размера"
        fi
        
        # Проверяем тип файла
        if command -v file > /dev/null; then
            echo "🔍 Тип: $(file "$file")"
        fi
        
        # Если есть ffprobe - показываем информацию об аудио
        if command -v ffprobe > /dev/null 2>&1; then
            echo "🎧 Аудио информация:"
            ffprobe -v quiet -print_format json -show_format -show_streams "$file" 2>/dev/null | grep -E "(duration|codec_name|bit_rate)" || echo "Не удалось получить аудио информацию"
        fi
        
        # Если есть afplay (macOS) - предлагаем прослушать
        if command -v afplay > /dev/null 2>&1; then
            echo ""
            read -p "🔊 Прослушать $filename? (y/N): " play_file
            if [[ $play_file == [yY] ]]; then
                echo "🎵 Проигрываем $filename (нажмите Ctrl+C для остановки)..."
                afplay "$file" &
                PLAY_PID=$!
                read -p "📻 Нажмите Enter для остановки..." 
                kill $PLAY_PID 2>/dev/null || true
            fi
        elif command -v aplay > /dev/null 2>&1; then
            echo ""
            read -p "🔊 Прослушать $filename? (y/N): " play_file
            if [[ $play_file == [yY] ]]; then
                echo "🎵 Проигрываем $filename..."
                aplay "$file" 2>/dev/null || echo "Не удалось проиграть файл"
            fi
        else
            echo "💡 Для прослушивания откройте файл: $file"
        fi
    fi
done

echo ""
echo "📋 === ИТОГИ ПРОВЕРКИ ==="
echo ""

if [[ -f "downloaded_audio/example_1.mp3" ]]; then
    size=$(stat -f%z "downloaded_audio/example_1.mp3" 2>/dev/null || stat -c%s "downloaded_audio/example_1.mp3" 2>/dev/null)
    if [[ $size -eq 0 ]]; then
        echo "❌ ПРОБЛЕМА: example_1.mp3 ПУСТОЙ!"
        echo "🔧 РЕШЕНИЕ: Загрузите новый аудиофайл"
        echo ""
        echo "📥 Способы загрузки нового файла:"
        echo "1. Скопируйте MP3 файл в папку audio/example_1.mp3"
        echo "2. Или замените 1.mp3 в корне проекта"
        echo "3. Перезапустите setup-real-call-with-audio.sh"
    elif [[ $size -lt 10000 ]]; then
        echo "⚠️ ВНИМАНИЕ: example_1.mp3 очень маленький ($size байт)"
        echo "🔧 Возможно файл поврежден или это очень короткий звук"
    else
        echo "✅ example_1.mp3 выглядит нормально ($size байт)"
        echo "🎵 Файл должен проигрываться во время звонка"
    fi
else
    echo "❌ example_1.mp3 не найден!"
    echo "🔧 Нужно загрузить аудиофайл в систему"
fi

echo ""
echo "📂 Все скачанные файлы в папке: downloaded_audio/"
echo "💡 Можете прослушать их любым аудиоплеером"

echo ""
echo "🚀 === СЛЕДУЮЩИЕ ШАГИ ==="
echo ""
echo "ЕСЛИ ФАЙЛ ПУСТОЙ ИЛИ ПОВРЕЖДЕН:"
echo "1. Найдите хороший MP3/WAV файл"
echo "2. Скопируйте как audio/example_1.mp3"  
echo "3. Запустите: ./setup-real-call-with-audio.sh"
echo ""
echo "ЕСЛИ ФАЙЛ НОРМАЛЬНЫЙ:"
echo "1. Проблема в FreeSWITCH конфигурации"
echo "2. Запустите: ./quick-audio-test.sh"
echo "3. Попробуйте СПОСОБ 3 (uuid_broadcast)" 