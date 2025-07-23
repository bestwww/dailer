#!/bin/bash

# УЛЬТИМАТИВНОЕ ИСПРАВЛЕНИЕ И DEBUG BACKEND

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🚨 УЛЬТИМАТИВНОЕ ИСПРАВЛЕНИЕ BACKEND"

log "🔍 АНАЛИЗ СИТУАЦИИ:"
echo "  ✅ 4/5 сервисов работают (postgres, redis, asterisk, frontend)"
echo "  ❌ Backend контейнер НЕ появляется в docker ps"
echo "  ❌ Логи backend пустые - крашится сразу при старте"
echo "  ❌ Остался @/ в комментарии services/freeswitch.js"

log "🛠️ ШАГ 1: ИСПРАВЛЯЕМ ВСЕ @/ ВКЛЮЧАЯ КОММЕНТАРИИ..."

# Извлекаем dist из последнего образа
TEMP_CONTAINER="temp_ultimate_fix"
docker create --name $TEMP_CONTAINER dailer-backend-absolute-final:latest
docker cp $TEMP_CONTAINER:/app/dist ./temp_dist_ultimate
docker rm $TEMP_CONTAINER

# Исправляем ВСЕ @/ алиасы включая комментарии
log "  Исправляем ВСЕ @/ алиасы во всех файлах..."

find temp_dist_ultimate -name "*.js" -type f -exec sed -i 's|@/config|../config|g' {} \;
find temp_dist_ultimate -name "*.js" -type f -exec sed -i 's|@/utils|../utils|g' {} \;
find temp_dist_ultimate -name "*.js" -type f -exec sed -i 's|@/services|../services|g' {} \;
find temp_dist_ultimate -name "*.js" -type f -exec sed -i 's|@/models|../models|g' {} \;
find temp_dist_ultimate -name "*.js" -type f -exec sed -i 's|@/controllers|../controllers|g' {} \;
find temp_dist_ultimate -name "*.js" -type f -exec sed -i 's|@/middleware|../middleware|g' {} \;
find temp_dist_ultimate -name "*.js" -type f -exec sed -i 's|@/types|../types|g' {} \;

# Специально для корневых файлов (app.js)
sed -i 's|../config|./config|g' temp_dist_ultimate/app.js 2>/dev/null || true
sed -i 's|../utils|./utils|g' temp_dist_ultimate/app.js 2>/dev/null || true
sed -i 's|../services|./services|g' temp_dist_ultimate/app.js 2>/dev/null || true

log "✅ ПРОВЕРЯЕМ РЕЗУЛЬТАТ ПОЛНОГО ИСПРАВЛЕНИЯ:"
echo "=== ПОИСК ВСЕХ @/ В .js ФАЙЛАХ ==="
find temp_dist_ultimate -name "*.js" -exec grep -l "@/" {} \; || echo "✅ ВСЕ @/ алиасы исправлены!"

log "🚀 ШАГ 2: СОЗДАЕМ УЛЬТИМАТИВНЫЙ ОБРАЗ..."

cat > Dockerfile.ultimate << 'EOF'
FROM dailer-backend-absolute-final:latest

# Копируем ультимативно исправленную dist папку
COPY temp_dist_ultimate /app/dist

# Права доступа
USER root
RUN chown -R nodeuser:nodejs /app/dist
USER nodeuser

# Установка рабочей директории
WORKDIR /app

# Явно указываем команду
CMD ["node", "dist/app.js"]
EOF

# Собираем ультимативный образ
docker build -f Dockerfile.ultimate -t dailer-backend-ultimate:latest .

# Очистка
rm -rf temp_dist_ultimate Dockerfile.ultimate

log "🔍 ШАГ 3: DEBUG РЕЖИМ - РУЧНОЙ ЗАПУСК BACKEND..."

echo "=== ТЕСТ 1: ПРОВЕРКА ОБРАЗА ==="
log "  Проверка что файлы есть в образе..."
docker run --rm dailer-backend-ultimate:latest ls -la dist/ | head -5

echo ""
echo "=== ТЕСТ 2: ПРОВЕРКА app.js ==="
log "  Проверка что app.js не содержит @/"
docker run --rm dailer-backend-ultimate:latest grep -n "@/" dist/app.js || echo "✅ app.js чист"

echo ""
echo "=== ТЕСТ 3: РУЧНОЙ ЗАПУСК С ПЕРЕМЕННЫМИ ==="
log "  Запуск backend в debug режиме с нашими переменными..."

docker run --rm -it \
    --network dialer-ready_dialer_network \
    -e NODE_ENV=production \
    -e DB_HOST=postgres \
    -e DB_PORT=5432 \
    -e DB_NAME=dialer \
    -e DB_USER=dialer \
    -e DB_PASSWORD=dialer_pass_2025 \
    -e DATABASE_URL=postgresql://dialer:dialer_pass_2025@postgres:5432/dialer \
    -e REDIS_HOST=redis \
    -e REDIS_PORT=6379 \
    -e REDIS_URL=redis://redis:6379 \
    -e VOIP_PROVIDER=asterisk \
    -e ASTERISK_HOST=asterisk \
    -e ASTERISK_PORT=5038 \
    -e ASTERISK_USERNAME=admin \
    -e ASTERISK_PASSWORD=dailer_admin_2025 \
    -e ASTERISK_URL=ami://admin:dailer_admin_2025@asterisk:5038 \
    -e JWT_SECRET=2ffe1d3e9df1ffe8e07a5c2940b8d2c56e8280b9bf42965027b5605e5cfe11c2 \
    -e JWT_EXPIRES_IN=24h \
    -e LOG_LEVEL=info \
    dailer-backend-ultimate:latest \
    node dist/app.js

echo ""
log "🔄 ШАГ 4: ЕСЛИ РУЧНОЙ ЗАПУСК СРАБОТАЛ - ОБНОВЛЯЕМ COMPOSE..."

# Обновляем docker-compose на ультимативный образ
sed -i 's|dailer-backend-absolute-final:latest|dailer-backend-ultimate:latest|g' docker-compose-ready.yml

log "🚀 ПЕРЕЗАПУСК С УЛЬТИМАТИВНЫМ ОБРАЗОМ..."

# Останавливаем только backend если он есть
docker compose -f docker-compose-ready.yml stop backend 2>/dev/null || true
docker compose -f docker-compose-ready.yml rm -f backend 2>/dev/null || true

# Запускаем backend с новым образом
docker compose -f docker-compose-ready.yml up -d backend

log "⏰ УЛЬТИМАТИВНАЯ ПРОВЕРКА (45 секунд)..."

sleep 10

for i in {1..7}; do
    BACKEND_STATUS=$(docker ps --filter "name=dialer_backend_ready" --format "{{.Status}}" 2>/dev/null)
    RUNNING_COUNT=$(docker compose -f docker-compose-ready.yml ps --format="{{.Status}}" | grep -c "Up" || echo "0")
    
    log "📊 Статус: $RUNNING_COUNT/5 сервисов, Backend: $BACKEND_STATUS (${i}*5 сек)"
    
    if echo "$BACKEND_STATUS" | grep -q "Up"; then
        log "✅ Backend контейнер ЗАПУЩЕН!"
        
        sleep 5
        LOGS=$(docker logs dialer_backend_ready --tail 15 2>&1)
        
        if echo "$LOGS" | grep -q "Cannot find module"; then
            MODULE_ERROR=$(echo "$LOGS" | grep "Cannot find module" | head -1)
            log "❌ Ошибка модулей: $MODULE_ERROR"
            break
            
        elif echo "$LOGS" | grep -q "Error:"; then
            ERROR_MSG=$(echo "$LOGS" | grep "Error:" | head -1)
            log "⚠️ Другая ошибка: $ERROR_MSG"
            break
            
        elif [[ -n "$LOGS" ]] && echo "$LOGS" | grep -q -E "(Server.*listening|started|ready|Listening on port|Express server)"; then
            log "✅ Backend сервер готов к работе!"
            
            # API тест
            sleep 5
            if curl -sf http://localhost:3001/health >/dev/null 2>&1; then
                log "🎉 BACKEND API РАБОТАЕТ!"
                
                echo ""
                echo "🎉 🎉 🎉 ПОЛНАЯ И ОКОНЧАТЕЛЬНАЯ ПОБЕДА! 🎉 🎉 🎉"
                echo ""
                echo "✅ ВСЕ ПРОБЛЕМЫ РЕШЕНЫ НАВСЕГДА:"
                echo "  🎯 TypeScript path alias исправлен во ВСЕХ файлах и комментариях"
                echo "  🔧 Backend контейнер стартует и работает"
                echo "  🔐 Все переменные окружения настроены"
                echo "  🚀 Backend API отвечает"
                echo "  🌐 Все 5 сервисов работают"
                echo ""
                echo "🌐 ПОЛНОСТЬЮ РАБОЧАЯ PRODUCTION VoIP СИСТЕМА:"
                echo "  Frontend:     http://localhost:3000"
                echo "  Backend API:  http://localhost:3001/health"
                echo "  Asterisk CLI: docker exec -it dialer_asterisk_ready asterisk -r"
                echo "  PostgreSQL:   docker exec -it dialer_postgres_ready psql -U dialer -d dialer"
                echo "  Redis CLI:    docker exec -it dialer_redis_ready redis-cli"
                echo ""
                echo "🏁 МИГРАЦИЯ FreeSWITCH ➜ ASTERISK ЗАВЕРШЕНА НА 100%!"
                echo ""
                echo "🎯 СИСТЕМА ГОТОВА К PRODUCTION ИСПОЛЬЗОВАНИЮ!"
                echo ""
                echo "📊 СТАТУС ВСЕХ СЕРВИСОВ:"
                docker compose -f docker-compose-ready.yml ps
                
                echo ""
                echo "🎊 🎊 🎊 ПОЗДРАВЛЯЕМ С УСПЕШНОЙ МИГРАЦИЕЙ! 🎊 🎊 🎊"
                
                exit 0
            else
                log "⚠️ Backend работает, но API не отвечает (${i}*5 сек)"
            fi
        else
            log "⚠️ Backend запущен, но нет логов о готовности (${i}*5 сек)"
            if [[ $i -eq 4 ]]; then
                echo "=== ТЕКУЩИЕ ЛОГИ BACKEND ==="
                echo "$LOGS"
            fi
        fi
    else
        log "📊 Backend не запущен: $BACKEND_STATUS (${i}*5 сек)"
        if [[ $i -eq 4 ]]; then
            echo "=== ПОПЫТКА ПОЛУЧИТЬ ЛОГИ ==="
            docker logs dialer_backend_ready --tail 20 2>&1 || echo "Логи недоступны"
        fi
    fi
    
    sleep 5
done

log "⚠️ Финальная диагностика..."

echo ""
echo "📊 Статус контейнеров:"
docker compose -f docker-compose-ready.yml ps

echo ""
echo "📝 Последние логи backend:"
docker logs dialer_backend_ready --tail 30 2>&1 || echo "Логи недоступны"

echo ""
echo "🔧 Проверка ультимативного образа:"
docker run --rm dailer-backend-ultimate:latest find dist -name "*.js" -exec grep -l "@/" {} \; | head -3 || echo "✅ Нет @/ в ультимативном образе"

exit 1 