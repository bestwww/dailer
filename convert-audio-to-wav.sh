#!/bin/bash

# 🎵🔄 Конвертация аудиофайла в WAV для FreeSWITCH
# Конвертируем в телефонное качество: 8kHz, 16-bit, mono

echo "🎵🔄 === КОНВЕРТАЦИЯ АУДИО В WAV ДЛЯ FREESWITCH ==="
echo

# Проверяем наличие ffmpeg
if ! command -v ffmpeg &> /dev/null; then
    echo "❌ ffmpeg не установлен!"
    echo "📦 Установите ffmpeg:"
    echo "   macOS: brew install ffmpeg"
    echo "   Ubuntu: sudo apt install ffmpeg"
    echo "   CentOS: sudo yum install ffmpeg"
    exit 1
fi

# Ищем исходный файл
SOURCE_FILE=""
if [[ -f "1.mp3" ]]; then
    SOURCE_FILE="1.mp3"
    echo "📂 Найден исходный файл: 1.mp3"
elif [[ -f "audio/example_1.mp3" ]]; then
    SOURCE_FILE="audio/example_1.mp3"
    echo "📂 Найден исходный файл: audio/example_1.mp3"
else
    echo "❌ Аудиофайл не найден!"
    echo "🔍 Ищем файлы..."
    find . -name "*.mp3" -o -name "*.wav" -o -name "*.m4a" | head -10
    echo ""
    read -p "📁 Введите путь к аудиофайлу: " SOURCE_FILE
    if [[ ! -f "$SOURCE_FILE" ]]; then
        echo "❌ Файл $SOURCE_FILE не существует!"
        exit 1
    fi
fi

echo "🎧 Исходный файл: $SOURCE_FILE"

# Получаем информацию об исходном файле
echo ""
echo "📊 === ИНФОРМАЦИЯ ОБ ИСХОДНОМ ФАЙЛЕ ==="
ffprobe -v quiet -print_format json -show_format -show_streams "$SOURCE_FILE" 2>/dev/null | grep -E "(duration|codec_name|sample_rate|channels|bit_rate)" || echo "Не удалось получить информацию"

# Создаем папку audio если её нет
mkdir -p audio

# Конвертируем в разные форматы для тестирования
echo ""
echo "🔄 === КОНВЕРТАЦИЯ В WAV ФОРМАТЫ ==="

# 1. Стандартный телефонный формат (8kHz, 16-bit, mono)
echo "📞 1. Конвертация в телефонный формат (8kHz, 16-bit, mono)..."
ffmpeg -i "$SOURCE_FILE" -ar 8000 -ac 1 -sample_fmt s16 -y audio/example_1_8k.wav 2>/dev/null
if [[ $? -eq 0 ]]; then
    echo "✅ audio/example_1_8k.wav (телефонное качество)"
    ls -lh audio/example_1_8k.wav
else
    echo "❌ Ошибка конвертации 8kHz"
fi

# 2. Высокое качество (16kHz, 16-bit, mono) - для G.722
echo "📞 2. Конвертация в HD формат (16kHz, 16-bit, mono)..."
ffmpeg -i "$SOURCE_FILE" -ar 16000 -ac 1 -sample_fmt s16 -y audio/example_1_16k.wav 2>/dev/null
if [[ $? -eq 0 ]]; then
    echo "✅ audio/example_1_16k.wav (HD качество)"
    ls -lh audio/example_1_16k.wav
else
    echo "❌ Ошибка конвертации 16kHz"
fi

# 3. Совместимый формат (8kHz, 16-bit, stereo -> mono)
echo "📞 3. Конвертация в совместимый формат..."
ffmpeg -i "$SOURCE_FILE" -ar 8000 -ac 1 -acodec pcm_s16le -y audio/example_1.wav 2>/dev/null
if [[ $? -eq 0 ]]; then
    echo "✅ audio/example_1.wav (основной файл)"
    ls -lh audio/example_1.wav
else
    echo "❌ Ошибка конвертации основного файла"
fi

echo ""
echo "📊 === ПРОВЕРКА РЕЗУЛЬТАТОВ ==="

# Проверяем все созданные файлы
for wav_file in audio/example_1*.wav; do
    if [[ -f "$wav_file" ]]; then
        filename=$(basename "$wav_file")
        size=$(stat -f%z "$wav_file" 2>/dev/null || stat -c%s "$wav_file" 2>/dev/null || echo "0")
        
        echo ""
        echo "🎵 === $filename ==="
        echo "📏 Размер: $size байт"
        
        if [[ $size -eq 0 ]]; then
            echo "❌ ФАЙЛ ПУСТОЙ!"
        elif [[ $size -lt 1000 ]]; then
            echo "⚠️ Файл очень маленький"
        else
            echo "✅ Файл нормального размера"
        fi
        
        # Показываем аудио параметры
        echo "🔍 Параметры:"
        ffprobe -v quiet -show_entries stream=sample_rate,channels,codec_name -of csv=p=0 "$wav_file" 2>/dev/null || echo "Не удалось получить параметры"
        
        # Предлагаем прослушать
        if command -v afplay > /dev/null 2>&1; then
            read -p "🔊 Прослушать $filename? (y/N): " play_it
            if [[ $play_it == [yY] ]]; then
                echo "🎵 Проигрываем..."
                afplay "$wav_file" &
                PLAY_PID=$!
                read -p "📻 Нажмите Enter для остановки..."
                kill $PLAY_PID 2>/dev/null || true
            fi
        fi
    fi
done

echo ""
echo "📋 === ИТОГИ КОНВЕРТАЦИИ ==="
echo ""

if [[ -f "audio/example_1.wav" ]]; then
    echo "✅ Основной файл создан: audio/example_1.wav"
    echo "🎯 Рекомендуемый файл для FreeSWITCH: audio/example_1_8k.wav (телефонное качество)"
else
    echo "❌ Ошибка создания WAV файла!"
    exit 1
fi

echo ""
echo "🚀 === СЛЕДУЮЩИЕ ШАГИ ==="
echo ""
echo "1. 📤 Закоммитить WAV файлы в Git:"
echo "   git add audio/"
echo "   git commit -m '🎵 Добавлены WAV файлы для FreeSWITCH'"
echo "   git push origin main"
echo ""
echo "2. 📞 На тестовом сервере обновить и протестировать:"
echo "   git pull origin main"
echo "   ./setup-wav-audio-test.sh"
echo ""
echo "3. 🔧 Или протестировать прямо сейчас:"
echo "   ./test-wav-calls.sh"

# Создаем скрипт тестирования WAV
echo ""
echo "📝 Создаю скрипт тестирования WAV файлов..." 