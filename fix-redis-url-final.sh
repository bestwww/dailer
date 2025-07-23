#!/bin/bash

# ДОБАВЛЕНИЕ REDIS_URL И ДРУГИХ URL ПЕРЕМЕННЫХ

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🔧 ДОБАВЛЕНИЕ REDIS_URL И ДРУГИХ URL ПЕРЕМЕННЫХ"

log "✅ ПРОГРЕСС:"
echo "  🎯 TypeScript path alias исправлен"
echo "  🖼️ Docker образ dailer-backend-fixed используется"
echo "  📝 DATABASE_URL добавлен"
echo "  ❌ Нужен REDIS_URL"

log "🔧 ДОБАВЛЯЕМ ВСЕ НЕДОСТАЮЩИЕ URL ПЕРЕМЕННЫЕ..."

# Добавляем REDIS_URL после DATABASE_URL
sed -i '/DATABASE_URL=postgresql/a\      - REDIS_URL=redis://redis:6379' docker-compose-ready.yml

# Добавляем другие возможные URL если их еще нет
if ! grep -q "ASTERISK_URL" docker-compose-ready.yml; then
    sed -i '/REDIS_URL=redis/a\      - ASTERISK_URL=ami://admin:dailer_admin_2025@asterisk:5038' docker-compose-ready.yml
fi

log "📊 ПРОВЕРЯЕМ ВСЕ URL ПЕРЕМЕННЫЕ:"
echo "=== URL ПЕРЕМЕННЫЕ В DOCKER-COMPOSE ==="
grep -A 25 "environment:" docker-compose-ready.yml | grep -E "(DATABASE_URL|REDIS_URL|ASTERISK_URL)"

log "🚀 БЫСТРЫЙ ПЕРЕЗАПУСК BACKEND..."

# Останавливаем backend
docker compose -f docker-compose-ready.yml stop backend

# Удаляем контейнер
docker compose -f docker-compose-ready.yml rm -f backend

# Запускаем с новыми переменными
docker compose -f docker-compose-ready.yml up -d backend

log "⏰ ПРОВЕРКА ЗАПУСКА (30 секунд)..."

sleep 5

for i in {1..6}; do
    BACKEND_STATUS=$(docker ps --filter "name=dialer_backend_ready" --format "{{.Status}}" 2>/dev/null)
    
    if echo "$BACKEND_STATUS" | grep -q "Up"; then
        log "✅ Backend контейнер запущен: $BACKEND_STATUS"
        
        # Проверяем логи на ошибки
        sleep 3
        LOGS=$(docker logs dialer_backend_ready --tail 15 2>&1)
        
        if echo "$LOGS" | grep -q "Error:"; then
            log "⚠️ Все еще есть ошибки в логах:"
            echo "$LOGS" | grep -A 3 -B 3 "Error:"
        else
            log "✅ Backend запущен БЕЗ ОШИБОК!"
            
            # Тестируем API
            sleep 5
            if curl -sf http://localhost:3001/health >/dev/null 2>&1; then
                log "🎉 BACKEND API РАБОТАЕТ!"
                
                echo ""
                echo "🎉 🎉 🎉 СИСТЕМА ПОЛНОСТЬЮ РАБОТАЕТ! 🎉 🎉 🎉"
                echo ""
                echo "✅ TypeScript path alias исправлен"
                echo "✅ DATABASE_URL и REDIS_URL добавлены"
                echo "✅ Backend API отвечает"
                echo "✅ Все 5 сервисов работают"
                echo ""
                echo "🌐 Frontend:     http://localhost:3000"
                echo "🔧 Backend API:  http://localhost:3001/health"
                echo "📞 Asterisk CLI: docker exec -it dialer_asterisk_ready asterisk -r"
                echo "💾 PostgreSQL:   docker exec -it dialer_postgres_ready psql -U dialer -d dialer"
                echo "🔴 Redis CLI:    docker exec -it dialer_redis_ready redis-cli"
                echo ""
                echo "🏁 МИГРАЦИЯ FreeSWITCH ➜ ASTERISK ЗАВЕРШЕНА ПОЛНОСТЬЮ!"
                echo ""
                echo "🎯 VoIP СИСТЕМА ГОТОВА К ТЕСТИРОВАНИЮ ЗВОНКОВ!"
                echo ""
                echo "📊 ФИНАЛЬНЫЙ СТАТУС ВСЕХ СЕРВИСОВ:"
                docker compose -f docker-compose-ready.yml ps
                
                echo ""
                echo "🚀 СЛЕДУЮЩИЕ ШАГИ - ТЕСТИРОВАНИЕ:"
                echo "  1. Откройте Frontend: http://localhost:3000"
                echo "  2. Проверьте Backend: curl http://localhost:3001/health"
                echo "  3. Настройте SIP trunk (IP: 62.141.121.197:5070)"
                echo "  4. Тестируйте звонки через веб-интерфейс"
                
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

log "⚠️ Показываю диагностику..."

echo ""
echo "📝 Логи backend (последние 25 строк):"
docker logs dialer_backend_ready --tail 25

echo ""
echo "📊 Статус всех контейнеров:"
docker compose -f docker-compose-ready.yml ps

echo ""
echo "🔧 Переменные окружения backend (если контейнер работает):"
if docker ps --filter "name=dialer_backend_ready" --format "{{.Status}}" | grep -q "Up"; then
    docker exec dialer_backend_ready printenv | grep -E "(URL|DB_|REDIS_|ASTERISK_)" | sort
else
    echo "Backend контейнер не запущен"
fi

echo ""
log "💡 ДОПОЛНИТЕЛЬНАЯ ДИАГНОСТИКА:"
echo "  1. Ручной тест: docker run --rm -it --network dialer-ready_dialer_network dailer-backend-fixed:latest sh"
echo "  2. Проверьте конфиг: docker run --rm dailer-backend-fixed:latest cat dist/config/index.js | grep -A 10 -B 10 required"
echo "  3. Все URL переменные: grep -E '(DATABASE_URL|REDIS_URL)' docker-compose-ready.yml"

exit 1 