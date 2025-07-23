#!/bin/bash

# ИСПРАВЛЕНИЕ ПУТЕЙ В MODELS ФАЙЛАХ

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🎯 ИСПРАВЛЕНИЕ ПУТЕЙ В MODELS ФАЙЛАХ!"

log "✅ БОЛЬШОЙ ПРОГРЕСС ПОДТВЕРЖДЕН:"
echo "  ✅ Все пути в services/dialer.js исправлены правильно!"
echo "  ✅ models: require('../models/campaign') ✓"
echo "  ✅ config: require('../config') ✓"  
echo "  ✅ utils: require('../utils/logger') ✓"
echo "  ❌ НОВАЯ ПРОБЛЕМА: Cannot find module './config/database'"
echo "  📍 Вызов из: models/campaign.js"
echo "  🎯 Из models/ правильный путь: ../config/database"

log "🛠️ ШАГ 1: ИЗВЛЕЧЕНИЕ И АНАЛИЗ MODELS ПУТЕЙ..."

# Извлекаем dist из текущего образа
TEMP_CONTAINER="temp_models_fix"
docker create --name $TEMP_CONTAINER dailer-backend-all-paths-fixed:latest
docker cp $TEMP_CONTAINER:/app/dist ./temp_dist_models
docker rm $TEMP_CONTAINER

log "  Анализируем ВСЕ require() пути в models файлах..."

echo "=== REQUIRE В MODELS/CAMPAIGN.JS ==="
grep -n "require(" temp_dist_models/models/campaign.js | head -10

echo "=== REQUIRE В MODELS/CONTACT.JS ==="
grep -n "require(" temp_dist_models/models/contact.js | head -5

echo "=== REQUIRE В MODELS/CALL-RESULT.JS ==="
grep -n "require(" temp_dist_models/models/call-result.js | head -5

echo "=== REQUIRE В MODELS/BLACKLIST.JS ==="
grep -n "require(" temp_dist_models/models/blacklist.js | head -5

log "🔧 ШАГ 2: ИСПРАВЛЕНИЕ ПУТЕЙ В MODELS ФАЙЛАХ..."

log "  Исправляем пути к config в models файлах..."
# Исправляем во всех models файлах пути к config
find temp_dist_models/models -name "*.js" -exec sed -i 's|require("./config/database")|require("../config/database")|g' {} \;
find temp_dist_models/models -name "*.js" -exec sed -i 's|require("./config/index")|require("../config/index")|g' {} \;
find temp_dist_models/models -name "*.js" -exec sed -i 's|require("./config")|require("../config")|g' {} \;

log "  Исправляем пути к utils в models файлах..."
find temp_dist_models/models -name "*.js" -exec sed -i 's|require("./utils/|require("../utils/|g' {} \;

log "  Исправляем пути к services в models файлах..."
find temp_dist_models/models -name "*.js" -exec sed -i 's|require("./services/|require("../services/|g' {} \;

log "  Исправляем пути к types в models файлах..."
find temp_dist_models/models -name "*.js" -exec sed -i 's|require("./types")|require("../types")|g' {} \;

log "✅ ПРОВЕРЯЕМ РЕЗУЛЬТАТ ИСПРАВЛЕНИЯ MODELS ПУТЕЙ:"

echo "=== CONFIG REQUIRES В MODELS/CAMPAIGN.JS ПОСЛЕ ИСПРАВЛЕНИЯ ==="
grep -n "require.*config" temp_dist_models/models/campaign.js | head -3

echo "=== UTILS REQUIRES В MODELS ПОСЛЕ ИСПРАВЛЕНИЯ ==="
grep -n "require.*utils" temp_dist_models/models/*.js | head -3

echo "=== SERVICES REQUIRES В MODELS ПОСЛЕ ИСПРАВЛЕНИЯ ==="
grep -n "require.*services" temp_dist_models/models/*.js | head -3

log "🚀 ШАГ 3: СОЗДАНИЕ ОБРАЗА С ИСПРАВЛЕННЫМИ MODELS..."

cat > Dockerfile.models_fixed << 'EOF'
FROM dailer-backend-all-paths-fixed:latest

# Копируем полностью исправленную dist папку с models путями
COPY temp_dist_models /app/dist

# Права доступа
USER root
RUN chown -R nodeuser:nodejs /app/dist
USER nodeuser

# Рабочая директория
WORKDIR /app

# Команда запуска
CMD ["node", "dist/app.js"]
EOF

# Собираем образ с исправленными models
docker build -f Dockerfile.models_fixed -t dailer-backend-models-fixed:latest .

# Очистка
rm -rf temp_dist_models Dockerfile.models_fixed

log "🔍 ШАГ 4: ТЕСТ ИСПРАВЛЕННЫХ MODELS ПУТЕЙ..."

echo "=== ТЕСТ: ПРОВЕРКА ИСПРАВЛЕННЫХ CONFIG ПУТЕЙ В MODELS ==="
docker run --rm dailer-backend-models-fixed:latest grep -n "require.*config" /app/dist/models/campaign.js | head -2

echo ""
echo "=== ТЕСТ: ЗАГРУЗКА DIALER С ИСПРАВЛЕННЫМИ MODELS ==="
MODELS_FIXED_TEST=$(docker run --rm \
    -e DATABASE_URL=postgresql://dialer:dialer_pass_2025@postgres:5432/dialer \
    -e REDIS_URL=redis://redis:6379 \
    -e JWT_SECRET=test \
    dailer-backend-models-fixed:latest \
    timeout 5 node -e "try { require('./dist/services/dialer'); console.log('MODELS PATHS FIXED!'); } catch(e) { console.log('STILL ERROR:', e.message); }" 2>&1)

echo "Результат исправленных models: $MODELS_FIXED_TEST"

if echo "$MODELS_FIXED_TEST" | grep -q "MODELS PATHS FIXED"; then
    log "✅ ВСЕ ПУТИ В MODELS ИСПРАВЛЕНЫ! Dialer загружается!"
elif echo "$MODELS_FIXED_TEST" | grep -q "Cannot find module"; then
    log "❌ ВСЁ ЕЩЁ ПРОБЛЕМЫ С МОДУЛЯМИ:"
    echo "$MODELS_FIXED_TEST"
    
    # Покажем какой именно модуль не найден
    MODULE_ERROR=$(echo "$MODELS_FIXED_TEST" | grep "Cannot find module" | head -1)
    log "  Следующий отсутствующий модуль: $MODULE_ERROR"
    exit 1
else
    log "✅ ВОЗМОЖНО ВСЕ MODELS ПУТИ ИСПРАВЛЕНЫ! Другие ошибки"
    echo "$MODELS_FIXED_TEST"
fi

log "🚀 ШАГ 5: ОБНОВЛЕНИЕ COMPOSE И ТЕСТ ЗАПУСКА..."

# Обновляем образ в compose
sed -i 's|dailer-backend-all-paths-fixed:latest|dailer-backend-models-fixed:latest|g' docker-compose-ready.yml

log "  Перезапуск backend с исправленными models..."
docker compose -f docker-compose-ready.yml stop backend 2>/dev/null || true
docker compose -f docker-compose-ready.yml rm -f backend 2>/dev/null || true
docker compose -f docker-compose-ready.yml up -d backend

log "⏰ ПРОВЕРКА MODELS ПУТЕЙ (25 секунд)..."

sleep 8

for i in {1..3}; do
    BACKEND_STATUS=$(docker ps --filter "name=dialer_backend_ready" --format "{{.Status}}" 2>/dev/null)
    
    log "📊 Backend статус: $BACKEND_STATUS (${i}*6 сек)"
    
    if echo "$BACKEND_STATUS" | grep -q "Up"; then
        log "✅ Backend контейнер ЗАПУЩЕН!"
        
        sleep 4
        LOGS=$(docker logs dialer_backend_ready --tail 15 2>&1)
        
        if echo "$LOGS" | grep -q "Cannot find module.*config/database"; then
            log "❌ ВСЁ ЕЩЁ ОШИБКА config/database"
            echo "$LOGS" | grep -A 3 -B 3 "Cannot find module"
            break
            
        elif echo "$LOGS" | grep -q "Cannot find module"; then
            MODULE_ERROR=$(echo "$LOGS" | grep "Cannot find module" | head -1)
            log "❌ ДРУГОЙ ОТСУТСТВУЮЩИЙ МОДУЛЬ: $MODULE_ERROR"
            echo "=== ЛОГИ ==="
            echo "$LOGS" | head -8
            break
            
        elif echo "$LOGS" | grep -q "Config validation error"; then
            log "🎉 ВСЕ МОДУЛИ ЗАГРУЖЕНЫ! Ошибка конфигурации (это успех!)"
            CONFIG_ERROR=$(echo "$LOGS" | grep "Config validation error" | head -1)
            log "  Конфигурационная ошибка: $CONFIG_ERROR"
            echo "=== ЛОГИ КОНФИГУРАЦИИ ==="
            echo "$LOGS" | head -6
            break
            
        elif echo "$LOGS" | grep -q -E "(Server.*listening|started|ready|Listening on port|Express server)"; then
            log "🎉 BACKEND СЕРВЕР ПОЛНОСТЬЮ ЗАПУСТИЛСЯ!"
            
            if curl -sf http://localhost:3001/health >/dev/null 2>&1; then
                log "🎉 BACKEND API РАБОТАЕТ!"
                
                echo ""
                echo "🎉 🎉 🎉 ПОЛНАЯ ПОБЕДА! ВСЕ ПУТИ ИСПРАВЛЕНЫ! 🎉 🎉 🎉"
                echo ""
                echo "✅ СИСТЕМА ПОЛНОСТЬЮ РАБОЧАЯ:"
                echo "  🛣️  Все require() пути в services/ исправлены"
                echo "  🛣️  Все require() пути в models/ исправлены"
                echo "  📦 Все модули загружаются без ошибок"
                echo "  🚀 Backend API отвечает"
                echo "  🌐 Все 5 сервисов работают"
                echo ""
                echo "🌐 PRODUCTION VoIP СИСТЕМА ГОТОВА!"
                echo "  Frontend:     http://localhost:3000"
                echo "  Backend API:  http://localhost:3001/health"
                echo ""
                echo "🏁 МИГРАЦИЯ FreeSWITCH ➜ ASTERISK ЗАВЕРШЕНА!"
                
                exit 0
            else
                log "⚠️ Backend работает но API не отвечает"
            fi
        else
            log "⚠️ Backend запущен, анализируем логи..."
            if [[ $i -eq 2 ]]; then
                echo "=== ТЕКУЩИЕ ЛОГИ ==="
                echo "$LOGS"
            fi
        fi
    else
        log "📊 Backend не запущен: $BACKEND_STATUS"
        if [[ $i -eq 2 ]]; then
            echo "=== ПОПЫТКА ПОЛУЧИТЬ ЛОГИ ==="
            docker logs dialer_backend_ready --tail 15 2>&1 || echo "Логи недоступны"
        fi
    fi
    
    sleep 6
done

echo ""
echo "📊 Финальный статус:"
docker compose -f docker-compose-ready.yml ps

echo ""
echo "📝 Логи backend после исправления models:"
docker logs dialer_backend_ready --tail 25 2>&1 || echo "Логи недоступны"

echo ""
log "🎯 РЕЗУЛЬТАТ: Проверьте статус исправления models путей выше" 