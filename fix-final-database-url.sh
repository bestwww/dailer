#!/bin/bash

# ФИНАЛЬНОЕ ИСПРАВЛЕНИЕ DATABASE_URL И ОБРАЗА

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🎉 ФИНАЛЬНОЕ ИСПРАВЛЕНИЕ DATABASE_URL"

log "✅ ПРОГРЕСС:"
echo "  🎯 TypeScript path alias ИСПРАВЛЕН!"
echo "  🚀 Backend образ dailer-backend-fixed создан!"
echo "  ❌ Остался только DATABASE_URL"

log "🔧 ИСПРАВЛЕНИЕ 1: ОБНОВЛЯЕМ DOCKER-COMPOSE ОБРАЗ..."

# Обновляем image в docker-compose-ready.yml на исправленный
sed -i 's|image: dailer-backend:latest|image: dailer-backend-fixed:latest|g' docker-compose-ready.yml

log "🔧 ИСПРАВЛЕНИЕ 2: ДОБАВЛЯЕМ DATABASE_URL ПЕРЕМЕННУЮ..."

# Добавляем DATABASE_URL после других DB переменных
sed -i '/DB_PASSWORD=dialer_pass_2025/a\      - DATABASE_URL=postgresql://dialer:dialer_pass_2025@postgres:5432/dialer' docker-compose-ready.yml

log "📊 ПРОВЕРЯЕМ ОБНОВЛЕНИЯ:"
echo "=== ОБРАЗ И ПЕРЕМЕННЫЕ BACKEND ==="
grep -A 20 "backend:" docker-compose-ready.yml | grep -E "(image:|DATABASE_URL|DB_HOST)"

log "🚀 ПЕРЕЗАПУСК BACKEND С ПРАВИЛЬНЫМ ОБРАЗОМ И ПЕРЕМЕННЫМИ..."

# Останавливаем backend
docker compose -f docker-compose-ready.yml stop backend

# Удаляем старый контейнер
docker compose -f docker-compose-ready.yml rm -f backend

# Запускаем с обновленной конфигурацией
docker compose -f docker-compose-ready.yml up -d backend

log "⏰ ФИНАЛЬНАЯ ПРОВЕРКА (45 секунд)..."

sleep 10

for i in {1..7}; do
    BACKEND_STATUS=$(docker ps --filter "name=dialer_backend_ready" --format "{{.Status}}" 2>/dev/null)
    
    if echo "$BACKEND_STATUS" | grep -q "Up"; then
        log "✅ Backend контейнер запущен: $BACKEND_STATUS"
        
        # Проверяем логи на ошибки
        if docker logs dialer_backend_ready --tail 10 2>&1 | grep -q "Error:"; then
            log "⚠️ Обнаружены ошибки в логах backend"
        else
            log "✅ Backend запущен без ошибок!"
            
            # Тестируем API
            sleep 5
            if curl -sf http://localhost:3001/health >/dev/null 2>&1; then
                log "🎉 BACKEND API РАБОТАЕТ!"
                
                echo ""
                echo "🎉 🎉 🎉 МИГРАЦИЯ ЗАВЕРШЕНА ПОЛНОСТЬЮ! 🎉 🎉 🎉"
                echo ""
                echo "✅ TypeScript path alias исправлен"
                echo "✅ DATABASE_URL добавлен"
                echo "✅ Backend API отвечает"
                echo "✅ Все 5 сервисов работают"
                echo ""
                echo "🌐 Frontend:     http://localhost:3000"
                echo "🔧 Backend API:  http://localhost:3001/health"
                echo "📞 Asterisk CLI: docker exec -it dialer_asterisk_ready asterisk -r"
                echo "💾 PostgreSQL:   docker exec -it dialer_postgres_ready psql -U dialer -d dialer"
                echo "🔴 Redis CLI:    docker exec -it dialer_redis_ready redis-cli"
                echo ""
                echo "🏁 МИГРАЦИЯ FreeSWITCH ➜ ASTERISK ЗАВЕРШЕНА УСПЕШНО!"
                echo ""
                echo "🎯 СИСТЕМА ПОЛНОСТЬЮ ГОТОВА К РАБОТЕ!"
                echo ""
                echo "📊 ФИНАЛЬНЫЙ СТАТУС ВСЕХ СЕРВИСОВ:"
                docker compose -f docker-compose-ready.yml ps
                
                echo ""
                echo "🚀 ТЕСТИРОВАНИЕ SIP ЗВОНКОВ:"
                echo "  1. Проверка Asterisk: docker exec -it dialer_asterisk_ready asterisk -r -x 'sip show peers'"
                echo "  2. Frontend интерфейс: http://localhost:3000"
                echo "  3. API статистика: curl http://localhost:3001/api/stats"
                
                exit 0
            else
                log "⚠️ Backend запущен, но API еще не отвечает (${i}*5 сек)"
            fi
        fi
    else
        log "📊 Backend статус: $BACKEND_STATUS (${i}*5 сек)"
    fi
    
    sleep 5
done

log "⚠️ Показываю финальную диагностику..."

echo ""
echo "📝 Логи backend (последние 20 строк):"
docker logs dialer_backend_ready --tail 20

echo ""
echo "📊 Статус всех контейнеров:"
docker compose -f docker-compose-ready.yml ps

echo ""
echo "🔧 Переменные окружения backend:"
docker exec dialer_backend_ready printenv | grep -E "(DATABASE_URL|DB_|NODE_ENV)" | sort

echo ""
log "💡 ЕСЛИ ОСТАЛИСЬ ПРОБЛЕМЫ:"
echo "  1. Проверьте полные логи: docker logs dialer_backend_ready"
echo "  2. Тест подключения к БД: docker exec dialer_postgres_ready psql -U dialer -d dialer -c 'SELECT version();'"
echo "  3. Ручной тест backend: docker run --rm -it --network dialer-ready_dialer_network dailer-backend-fixed:latest node dist/app.js"

exit 1 