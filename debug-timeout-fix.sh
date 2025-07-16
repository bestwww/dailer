#!/bin/bash

# Скрипт для диагностики и исправления таймаута загрузки аудиофайлов
# Проблема: файл загружается до 27%, затем таймаут 30 секунд
# Автор: AI Assistant

echo "==============================================="
echo "⏰ ДИАГНОСТИКА ТАЙМАУТА ЗАГРУЗКИ АУДИОФАЙЛОВ"
echo "==============================================="

SERVER_URL=${1:-"http://localhost:3000"}
echo "🌐 Сервер: $SERVER_URL"

echo ""
echo "🔍 1. ПРОВЕРКА СОСТОЯНИЯ BACKEND:"
echo "-----------------------------------------------"
if docker ps -q -f name="dialer_backend" | grep -q .; then
    echo "✅ Backend контейнер запущен"
    
    # Проверка использования ресурсов
    echo "📊 Использование ресурсов backend:"
    docker stats dialer_backend --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
    
    # Проверка места на диске
    echo ""
    echo "💾 Свободное место в контейнере:"
    docker exec dialer_backend df -h /app 2>/dev/null
    
    # Проверка папки audio
    echo ""
    echo "📂 Папка для аудио файлов:"
    docker exec dialer_backend ls -la /app/audio 2>/dev/null || {
        echo "❌ Папка /app/audio не найдена, создаем..."
        docker exec dialer_backend mkdir -p /app/audio
        docker exec dialer_backend chmod 755 /app/audio
        echo "✅ Папка создана"
    }
    
    # Проверка процессов в контейнере
    echo ""
    echo "⚙️ Процессы в контейнере:"
    docker exec dialer_backend ps aux | head -10
    
else
    echo "❌ Backend контейнер не запущен!"
    echo "Запуск контейнера..."
    docker-compose up -d backend
    sleep 10
fi

echo ""
echo "🏥 2. ПРОВЕРКА HEALTH CHECK:"
echo "-----------------------------------------------"
echo "🔍 Проверка основного health check:"
HEALTH_RESPONSE=$(curl -s -w "HTTP_CODE:%{http_code}\nTIME:%{time_total}s" "$SERVER_URL/health")
echo "$HEALTH_RESPONSE"

echo ""
echo "🔍 Проверка API health check:"
API_HEALTH=$(curl -s -w "HTTP_CODE:%{http_code}\nTIME:%{time_total}s" "$SERVER_URL/api/health")
echo "$API_HEALTH"

echo ""
echo "📋 3. ТЕСТ БЫСТРОГО ENDPOINT'А:"
echo "-----------------------------------------------"
echo "🔍 Проверка списка кампаний (должен быть быстрым):"
CAMPAIGNS_RESPONSE=$(curl -s -w "HTTP_CODE:%{http_code}\nTIME:%{time_total}s" "$SERVER_URL/api/campaigns")
echo "Время ответа кампаний: $(echo "$CAMPAIGNS_RESPONSE" | grep 'TIME:' | cut -d':' -f2)"

# Извлекаем ID кампании для тестирования
CAMPAIGN_ID=$(echo "$CAMPAIGNS_RESPONSE" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
echo "🆔 Найдена кампания с ID: $CAMPAIGN_ID"

echo ""
echo "🧪 4. ТЕСТ ЗАГРУЗКИ С МИНИМАЛЬНЫМ ФАЙЛОМ:"
echo "-----------------------------------------------"

# Создаем ОЧЕНЬ маленький тестовый файл
TEST_FILE="/tmp/micro_test.mp3"
echo -e "\xFF\xFB\x90\x00" > "$TEST_FILE"  # Минимальный MP3 заголовок
echo "📁 Создан микро-файл: $(ls -la $TEST_FILE)"

if [ ! -z "$CAMPAIGN_ID" ]; then
    echo ""
    echo "🚀 Тест загрузки микро-файла для кампании $CAMPAIGN_ID:"
    
    # Запускаем в background мониторинг логов
    echo "📊 Запуск мониторинга логов в фоне..."
    docker logs -f dialer_backend > /tmp/backend_logs_during_upload.log 2>&1 &
    LOGS_PID=$!
    
    # Выполняем запрос с коротким таймаутом
    MICRO_UPLOAD=$(timeout 10s curl -s -X POST \
        -F "audio=@$TEST_FILE" \
        -w "\nHTTP_CODE:%{http_code}\nTIME:%{time_total}s\nSIZE_UPLOAD:%{size_upload}\nSPEED_UPLOAD:%{speed_upload}" \
        "$SERVER_URL/api/campaigns/$CAMPAIGN_ID/audio" 2>&1)
    
    # Останавливаем мониторинг логов
    sleep 2
    kill $LOGS_PID 2>/dev/null
    
    echo "Результат загрузки микро-файла:"
    echo "$MICRO_UPLOAD"
    
    echo ""
    echo "📋 Логи backend во время загрузки:"
    tail -20 /tmp/backend_logs_during_upload.log 2>/dev/null || echo "❓ Логи не найдены"
    
    # Очистка
    rm -f "$TEST_FILE" /tmp/backend_logs_during_upload.log
else
    echo "❌ Не найдено кампаний для тестирования"
fi

echo ""
echo "🔍 5. АНАЛИЗ КОНФИГУРАЦИИ MULTER:"
echo "-----------------------------------------------"
echo "🔍 Переменные окружения для загрузки файлов:"
docker exec dialer_backend printenv | grep -E "(AUDIO|UPLOAD|MULTER|TIMEOUT)" || echo "❓ Переменные не найдены"

echo ""
echo "📊 6. АНАЛИЗ ЛОГОВ НА ПРЕДМЕТ ЗАВИСАНИЯ:"
echo "-----------------------------------------------"
echo "🔍 Ошибки в последних логах:"
docker logs --tail 50 dialer_backend 2>&1 | grep -i -E "(error|timeout|hang|stuck|abort)" | tail -10 || echo "✅ Ошибок зависания не найдено"

echo ""
echo "🔍 Логи multer/upload за последние 100 строк:"
docker logs --tail 100 dialer_backend 2>&1 | grep -i -E "(multer|upload|audio)" | tail -10 || echo "❓ Логов загрузки не найдено"

echo ""
echo "💾 7. ПРОВЕРКА БАЗЫ ДАННЫХ:"
echo "-----------------------------------------------"
echo "🔍 Подключение к базе данных:"
if docker exec dialer_postgres pg_isready -U dialer_user >/dev/null 2>&1; then
    echo "✅ PostgreSQL доступен"
    
    # Проверка таблицы кампаний
    echo "📋 Проверка таблицы campaigns:"
    docker exec dialer_postgres psql -U dialer_user -d dialer_db -c "SELECT COUNT(*) as campaigns_count FROM campaigns;" 2>/dev/null || echo "❌ Ошибка доступа к таблице campaigns"
    
else
    echo "❌ PostgreSQL недоступен!"
fi

echo ""
echo "🌐 8. ПРОВЕРКА СЕТЕВОГО ПОДКЛЮЧЕНИЯ:"
echo "-----------------------------------------------"
echo "🔍 Ping между контейнерами:"
docker exec dialer_frontend ping -c 2 backend 2>/dev/null && echo "✅ Frontend → Backend OK" || echo "❌ Frontend → Backend FAIL"
docker exec dialer_backend ping -c 2 postgres 2>/dev/null && echo "✅ Backend → Postgres OK" || echo "❌ Backend → Postgres FAIL"

echo ""
echo "==============================================="
echo "🔧 РЕКОМЕНДАЦИИ ПО ИСПРАВЛЕНИЮ"
echo "==============================================="

echo ""
echo "📝 Выявленная проблема:"
echo "- Файл начинает загружаться (прогресс до 27%)"
echo "- Происходит таймаут через 30 секунд"
echo "- Backend не отвечает на запрос"

echo ""
echo "🚀 Шаги для исправления:"

echo ""
echo "1️⃣ УВЕЛИЧЕНИЕ ТАЙМАУТОВ:"
echo "   # В docker-compose.yml добавить переменные:"
echo "   - REQUEST_TIMEOUT=120000"
echo "   - BODY_PARSER_LIMIT=50mb"

echo ""
echo "2️⃣ ПЕРЕЗАПУСК С ОЧИСТКОЙ:"
echo "   docker-compose down"
echo "   docker system prune -f"
echo "   docker-compose up -d --build"

echo ""
echo "3️⃣ ПРОВЕРКА РЕСУРСОВ СЕРВЕРА:"
echo "   free -h    # Проверка RAM"
echo "   df -h      # Проверка места на диске"
echo "   top        # Проверка загрузки CPU"

echo ""
echo "4️⃣ МОНИТОРИНГ В РЕАЛЬНОМ ВРЕМЕНИ:"
echo "   # В одном терминале:"
echo "   docker logs -f dialer_backend | grep -i audio"
echo "   # В другом терминале попробуйте загрузить файл"

echo ""
echo "5️⃣ АЛЬТЕРНАТИВНОЕ РЕШЕНИЕ:"
echo "   # Попробуйте загрузить файл через прямой endpoint:"
echo "   curl -X POST -F \"audio=@your_file.mp3\" $SERVER_URL/api/audio/upload"

echo ""
echo "==============================================="
echo "✅ ДИАГНОСТИКА ТАЙМАУТА ЗАВЕРШЕНА"
echo "===============================================" 