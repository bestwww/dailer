#!/bin/bash

# ДИАГНОСТИКА RUNTIME ОШИБКИ BACKEND

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🔍 ДИАГНОСТИКА RUNTIME ОШИБКИ BACKEND"

log "📊 ТЕКУЩАЯ СИТУАЦИЯ:"
echo "  ✅ TypeScript компилируется без ошибок"
echo "  ✅ 4/5 сервисов работают (postgres, redis, asterisk, frontend)"
echo "  ❌ Backend контейнер запустился, но упал"

log "🔍 ПРОВЕРКА ЛОГОВ BACKEND..."

# Проверяем логи backend
echo ""
echo "📝 Логи backend контейнера (последние 50 строк):"
docker logs dialer_backend_ready --tail 50 2>/dev/null || echo "❌ Backend контейнер недоступен"

echo ""
echo "📊 Статус всех контейнеров:"
docker compose -f docker-compose-ready.yml ps

echo ""
echo "📋 Детальная информация о backend контейнере:"
docker inspect dialer_backend_ready 2>/dev/null || echo "❌ Backend контейнер не найден"

log "🔧 ПОПЫТКА ПЕРЕЗАПУСКА BACKEND..."

# Попробуем перезапустить только backend
docker compose -f docker-compose-ready.yml restart backend

sleep 10

BACKEND_STATUS=$(docker compose -f docker-compose-ready.yml ps backend --format "{{.Status}}" 2>/dev/null)
log "📊 Статус backend после перезапуска: $BACKEND_STATUS"

if echo "$BACKEND_STATUS" | grep -q "Up"; then
    log "✅ Backend перезапустился!"
    
    # Тестируем API
    sleep 15
    if curl -sf http://localhost:3001/health >/dev/null 2>&1; then
        log "✅ Backend API работает!"
        
        echo ""
        echo "🎉 ПРОБЛЕМА РЕШЕНА!"
        echo "🌐 Frontend:     http://localhost:3000"
        echo "🔧 Backend:      http://localhost:3001/health"
        echo "📞 Asterisk:     docker exec -it dialer_asterisk_ready asterisk -r"
        echo ""
        log "🏁 МИГРАЦИЯ FreeSWITCH ➜ ASTERISK ЗАВЕРШЕНА!"
        
        exit 0
    else
        log "⚠️ Backend запущен, но API не отвечает"
    fi
else
    log "❌ Backend не запустился: $BACKEND_STATUS"
fi

echo ""
echo "📝 Новые логи backend (последние 30 строк):"
docker logs dialer_backend_ready --tail 30 2>/dev/null || echo "Backend недоступен"

echo ""
log "🔍 ВОЗМОЖНЫЕ ПРИЧИНЫ RUNTIME ОШИБОК:"
echo ""
echo "1. 🔌 ПРОБЛЕМЫ ПОДКЛЮЧЕНИЯ:"
echo "   - Asterisk AMI недоступен"
echo "   - PostgreSQL подключение не работает"
echo "   - Redis недоступен"
echo ""
echo "2. 🏗️ ПРОБЛЕМЫ КОНФИГУРАЦИИ:"
echo "   - Неправильные переменные окружения"
echo "   - Отсутствующие модули или зависимости"
echo "   - Проблемы с миграциями базы данных"
echo ""
echo "3. 🐛 RUNTIME ОШИБКИ:"
echo "   - Необработанные исключения в коде"
echo "   - Ошибки инициализации сервисов"
echo "   - Проблемы с асинхронным кодом"

echo ""
log "💡 РЕКОМЕНДАЦИИ ДЛЯ РЕШЕНИЯ:"
echo ""
echo "🔧 ПРОВЕРКА ПОДКЛЮЧЕНИЙ:"
echo "  # Тест PostgreSQL"
echo "  docker exec dialer_postgres_ready psql -U dialer -d dialer -c 'SELECT version();'"
echo ""
echo "  # Тест Redis"
echo "  docker exec dialer_redis_ready redis-cli ping"
echo ""
echo "  # Тест Asterisk AMI"
echo "  docker exec dialer_asterisk_ready asterisk -r -x 'manager show users'"
echo ""
echo "🔧 ПРОВЕРКА ПЕРЕМЕННЫХ ОКРУЖЕНИЯ:"
echo "  docker run --rm dailer-backend:latest printenv | grep -E '(VOIP|ASTERISK|DATABASE|POSTGRES)'"
echo ""
echo "🔧 РУЧНОЙ ЗАПУСК ДЛЯ ОТЛАДКИ:"
echo "  docker run --rm -it --network dialer-ready_dialer_network dailer-backend:latest /bin/sh"
echo "  # Внутри контейнера:"
echo "  # node dist/app.js"

exit 1 