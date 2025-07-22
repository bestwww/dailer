#!/bin/bash

# ДИАГНОСТИКА И ИСПРАВЛЕНИЕ ПРОБЛЕМЫ С BACKEND

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🔧 ДИАГНОСТИКА ПРОБЛЕМЫ С BACKEND"

log "📋 СТАТУС ПРОБЛЕМЫ:"
echo "  ✅ Frontend работает: http://localhost:3000"
echo "  ✅ Asterisk здоров с SIP конфигурацией"
echo "  ✅ PostgreSQL и Redis готовы"
echo "  ❌ Backend перезапускается (крашится при запуске)"

log "🔍 ДИАГНОСТИКА ЛОГОВ BACKEND..."

# Проверяем логи backend
echo ""
echo "📝 Логи backend (последние 50 строк):"
docker logs dialer_backend_ready --tail 50 2>/dev/null || echo "Backend логи недоступны"

echo ""
echo "📊 Статус всех контейнеров:"
docker compose -f docker-compose-ready.yml ps

log "🛠️ ВОЗМОЖНЫЕ ПРИЧИНЫ И ИСПРАВЛЕНИЯ:"

echo ""
echo "1. 🔌 ПРОБЛЕМА ПОДКЛЮЧЕНИЯ К ASTERISK:"
echo "   - Backend пытается подключиться к FreeSWITCH вместо Asterisk"
echo "   - Неправильные настройки AMI"
echo "   - Порт/хост Asterisk недоступен"

echo ""
echo "2. 🏗️ ПРОБЛЕМА СБОРКИ/ЗАВИСИМОСТЕЙ:"
echo "   - TypeScript ошибки компиляции"
echo "   - Отсутствующие модули Node.js"
echo "   - Неправильные переменные окружения"

echo ""
echo "3. 🗄️ ПРОБЛЕМА БАЗЫ ДАННЫХ:"
echo "   - Миграции не выполнились"
echo "   - Неправильные настройки подключения"
echo "   - Таблицы не созданы"

log "🚀 АВТОМАТИЧЕСКОЕ ИСПРАВЛЕНИЕ..."

# Проверяем переменные окружения backend
log "📋 Проверка переменных окружения backend..."
docker exec dialer_backend_ready printenv | grep -E "(VOIP|ASTERISK|DATABASE|POSTGRES)" 2>/dev/null || echo "Backend недоступен для проверки переменных"

# Попробуем перезапустить backend отдельно
log "🔄 Перезапуск backend..."
docker compose -f docker-compose-ready.yml restart backend

# Ждем 30 секунд и проверяем
log "⏰ Ожидание запуска backend (30 секунд)..."
sleep 30

BACKEND_STATUS=$(docker compose -f docker-compose-ready.yml ps backend --format "{{.Status}}" 2>/dev/null)
log "📊 Статус backend после перезапуска: $BACKEND_STATUS"

if echo "$BACKEND_STATUS" | grep -q "Up"; then
    log "✅ Backend запустился успешно!"
    
    # Тестируем API
    sleep 10
    if curl -sf http://localhost:3001/health >/dev/null 2>&1; then
        log "✅ Backend API работает!"
        
        echo ""
        echo "🎉 ПРОБЛЕМА РЕШЕНА!"
        echo "🌐 Frontend:    http://localhost:3000"
        echo "🔧 Backend:     http://localhost:3001/health"
        echo "📞 Asterisk:    docker exec -it dialer_asterisk_ready asterisk -r"
        echo ""
        log "🎯 СИСТЕМА ПОЛНОСТЬЮ ГОТОВА!"
        
        exit 0
    else
        log "⚠️ Backend запущен, но API не отвечает"
    fi
else
    log "❌ Backend все еще не запускается"
    
    echo ""
    echo "📝 Свежие логи backend (последние 30 строк):"
    docker logs dialer_backend_ready --tail 30 2>/dev/null || echo "Логи недоступны"
fi

echo ""
log "💡 РЕШЕНИЯ ДЛЯ РАЗЛИЧНЫХ ПРОБЛЕМ:"

echo ""
echo "🔧 ЕСЛИ ПРОБЛЕМА В ASTERISK ПОДКЛЮЧЕНИИ:"
echo "  # Проверить AMI конфигурацию Asterisk"
echo "  docker exec -it dialer_asterisk_ready asterisk -r -x 'manager show settings'"
echo "  docker exec -it dialer_asterisk_ready asterisk -r -x 'manager show users'"

echo ""
echo "🔧 ЕСЛИ ПРОБЛЕМА В ПЕРЕМЕННЫХ ОКРУЖЕНИЯ:"
echo "  # Проверить docker-compose-ready.yml environment секцию"
echo "  # Убедиться что VOIP_PROVIDER=asterisk"
echo "  # Проверить ASTERISK_HOST, ASTERISK_PORT, etc."

echo ""
echo "🔧 ЕСЛИ ПРОБЛЕМА В БАЗЕ ДАННЫХ:"
echo "  # Проверить подключение к PostgreSQL"
echo "  docker exec dialer_postgres_ready psql -U dialer -d dialer -c '\dt'"
echo "  # Запустить миграции вручную"
echo "  docker exec dialer_backend_ready npm run migrate"

echo ""
echo "🔧 ЕСЛИ ПРОБЛЕМА В СБОРКЕ:"
echo "  # Пересобрать backend с подробными логами"
echo "  docker compose -f docker-compose-ready.yml build backend --no-cache --progress=plain"

echo ""
log "🚨 КРИТИЧЕСКИЙ АНАЛИЗ ЛОГОВ:"
echo "Ищите в логах backend ключевые ошибки:"
echo "  - 'Cannot connect to Asterisk'"
echo "  - 'ECONNREFUSED'"
echo "  - 'TypeScript compilation failed'"
echo "  - 'Module not found'"
echo "  - 'Database connection failed'"

exit 1 