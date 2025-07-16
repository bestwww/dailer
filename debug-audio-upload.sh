#!/bin/bash

# Скрипт для диагностики проблем загрузки аудиофайлов
# Автор: AI Assistant
# Дата: $(date '+%Y-%m-%d')

echo "==============================================="
echo "🎵 ДИАГНОСТИКА ЗАГРУЗКИ АУДИОФАЙЛОВ"
echo "==============================================="

SERVER_URL=${1:-"http://localhost:3000"}
echo "🌐 Сервер: $SERVER_URL"

echo ""
echo "📊 1. ПРОВЕРКА BACKEND КОНТЕЙНЕРА:"
echo "-----------------------------------------------"
if docker ps -q -f name="dialer_backend" | grep -q .; then
    echo "✅ Backend контейнер запущен"
    docker ps --format "table {{.Names}}\t{{.Status}}" | grep dialer_backend
    
    echo ""
    echo "📂 Проверка папки для аудиофайлов:"
    docker exec dialer_backend ls -la /app/audio 2>/dev/null || echo "❌ Папка /app/audio не найдена"
    
    echo ""
    echo "🔍 Переменные окружения (аудио):"
    docker exec dialer_backend printenv | grep -E "(AUDIO|UPLOAD)" || echo "⚠️ Переменные для загрузки не найдены"
    
else
    echo "❌ Backend контейнер не запущен"
    exit 1
fi

echo ""
echo "📋 2. ПОСЛЕДНИЕ ЛОГИ BACKEND (загрузка файлов):"
echo "-----------------------------------------------"
echo "🔍 Поиск логов загрузки файлов..."
docker logs --tail 50 dialer_backend 2>&1 | grep -i -E "(upload|audio|file|multer)" | tail -10 || echo "❓ Логи загрузки не найдены"

echo ""
echo "🌐 3. ПРОВЕРКА ENDPOINT'ОВ:"
echo "-----------------------------------------------"

# Проверка health check
echo "🏥 Health check:"
curl -s -o /dev/null -w "Статус: %{http_code}, Время: %{time_total}s\n" "$SERVER_URL/health" || echo "❌ Health check недоступен"

# Проверка API health check
echo "🏥 API Health check:"
curl -s -o /dev/null -w "Статус: %{http_code}, Время: %{time_total}s\n" "$SERVER_URL/api/health" || echo "❌ API Health check недоступен"

# Проверка кампаний endpoint
echo "📋 Campaigns endpoint:"
curl -s -o /dev/null -w "Статус: %{http_code}, Время: %{time_total}s\n" "$SERVER_URL/api/campaigns" || echo "❌ Campaigns endpoint недоступен"

# Проверка папки аудио (статические файлы)
echo "🎵 Audio static files:"
curl -s -o /dev/null -w "Статус: %{http_code}, Время: %{time_total}s\n" "$SERVER_URL/audio/" || echo "❌ Audio endpoint недоступен"

echo ""
echo "🧪 4. ТЕСТ ЗАГРУЗКИ АУДИОФАЙЛА:"
echo "-----------------------------------------------"

# Создаем тестовый аудиофайл (простой WAV)
echo "📁 Создание тестового аудиофайла..."
TEST_FILE="/tmp/test_audio.wav"
# Создаем минимальный WAV файл (заголовок + тишина 1 секунда)
echo -e "\x52\x49\x46\x46\x24\x08\x00\x00\x57\x41\x56\x45\x66\x6d\x74\x20\x10\x00\x00\x00\x01\x00\x01\x00\x44\xac\x00\x00\x88\x58\x01\x00\x02\x00\x10\x00\x64\x61\x74\x61\x00\x08\x00\x00" > "$TEST_FILE"

if [ -f "$TEST_FILE" ]; then
    echo "✅ Тестовый файл создан: $(ls -la $TEST_FILE)"
    
    echo ""
    echo "🚀 Тест загрузки общего аудио endpoint:"
    UPLOAD_RESPONSE=$(curl -s -X POST \
        -F "audio=@$TEST_FILE" \
        -w "\nHTTP_CODE:%{http_code}\nTIME:%{time_total}s\n" \
        "$SERVER_URL/api/audio/upload")
    
    echo "Ответ сервера:"
    echo "$UPLOAD_RESPONSE"
    
    echo ""
    echo "🎯 Тест загрузки для кампании (требует существующую кампанию):"
    # Сначала получаем список кампаний
    CAMPAIGNS_RESPONSE=$(curl -s "$SERVER_URL/api/campaigns")
    echo "📋 Ответ campaigns: $CAMPAIGNS_RESPONSE"
    
    # Попробуем извлечь ID первой кампании
    CAMPAIGN_ID=$(echo "$CAMPAIGNS_RESPONSE" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
    
    if [ ! -z "$CAMPAIGN_ID" ]; then
        echo "🆔 Найдена кампания с ID: $CAMPAIGN_ID"
        
        CAMPAIGN_UPLOAD_RESPONSE=$(curl -s -X POST \
            -F "audio=@$TEST_FILE" \
            -w "\nHTTP_CODE:%{http_code}\nTIME:%{time_total}s\n" \
            "$SERVER_URL/api/campaigns/$CAMPAIGN_ID/audio")
        
        echo "Ответ сервера для кампании:"
        echo "$CAMPAIGN_UPLOAD_RESPONSE"
    else
        echo "❌ Кампании не найдены для тестирования"
    fi
    
    # Удаляем тестовый файл
    rm -f "$TEST_FILE"
    echo "🗑️ Тестовый файл удален"
else
    echo "❌ Не удалось создать тестовый файл"
fi

echo ""
echo "🔍 5. ПРОВЕРКА КОНФИГУРАЦИИ MULTER:"
echo "-----------------------------------------------"
echo "📂 Проверка директории загрузки в контейнере:"
docker exec dialer_backend find /app -name "audio*" -type d 2>/dev/null || echo "❓ Папки audio не найдены"

echo ""
echo "📁 Содержимое папки audio:"
docker exec dialer_backend ls -la /app/audio 2>/dev/null || docker exec dialer_backend mkdir -p /app/audio

echo ""
echo "🔧 Права доступа к папке audio:"
docker exec dialer_backend ls -ld /app/audio 2>/dev/null || echo "❌ Проблема с доступом к папке"

echo ""
echo "💾 Свободное место в контейнере:"
docker exec dialer_backend df -h /app 2>/dev/null || echo "❌ Не удалось проверить свободное место"

echo ""
echo "🔍 6. АНАЛИЗ ЛОГОВ НА ПРЕДМЕТ ОШИБОК:"
echo "-----------------------------------------------"
echo "❌ Ошибки в логах backend:"
docker logs --tail 100 dialer_backend 2>&1 | grep -i -E "(error|failed|exception)" | tail -5 || echo "✅ Критических ошибок не найдено"

echo ""
echo "⚠️ Предупреждения в логах:"
docker logs --tail 100 dialer_backend 2>&1 | grep -i -E "(warn|warning)" | tail -5 || echo "✅ Предупреждений не найдено"

echo ""
echo "🎵 Упоминания об аудио в логах:"
docker logs --tail 100 dialer_backend 2>&1 | grep -i "audio" | tail -5 || echo "❓ Упоминаний об аудио не найдено"

echo ""
echo "==============================================="
echo "🔧 ПОЛЕЗНЫЕ КОМАНДЫ ДЛЯ ИСПРАВЛЕНИЯ"
echo "==============================================="
echo ""
echo "Если папка audio недоступна:"
echo "docker exec dialer_backend mkdir -p /app/audio"
echo "docker exec dialer_backend chmod 755 /app/audio"
echo ""
echo "Пересоздание контейнера с правильными volume'ами:"
echo "docker-compose down"
echo "docker-compose up -d --build backend"
echo ""
echo "Проверка в реальном времени:"
echo "docker logs -f dialer_backend | grep -i audio"
echo ""
echo "Ручная проверка endpoint'а:"
echo "curl -X POST -F \"audio=@/path/to/your/file.mp3\" $SERVER_URL/api/audio/upload"
echo ""
echo "Вход в контейнер для отладки:"
echo "docker exec -it dialer_backend bash"
echo ""
echo "==============================================="
echo "✅ ДИАГНОСТИКА ЗАВЕРШЕНА"
echo "===============================================" 