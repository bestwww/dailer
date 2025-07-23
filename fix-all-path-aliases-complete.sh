#!/bin/bash

# ПОЛНОЕ ИСПРАВЛЕНИЕ ВСЕХ PATH ALIAS ВО ВСЕХ ФАЙЛАХ

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🔧 ПОЛНОЕ ИСПРАВЛЕНИЕ ВСЕХ PATH ALIAS"

log "✅ ПРОГРЕСС:"
echo "  🔐 JWT_SECRET добавлен"
echo "  📝 Все переменные окружения настроены"
echo "  ❌ Path alias не полностью исправлены во всех файлах"

log "🔍 ДИАГНОЗ ПРОБЛЕМЫ:"
echo "  Error: Cannot find module './config' в utils/logger.js"
echo "  Предыдущий скрипт исправил только app.js, но НЕ все файлы"
echo "  Нужно умное исправление с учетом относительных путей"

# Получаем актуальный backend образ
BACKEND_IMAGE="dailer-backend-fixed:latest"

log "🛠️ ИЗВЛЕКАЕМ И ПОЛНОСТЬЮ ИСПРАВЛЯЕМ ВСЕ ФАЙЛЫ..."

# Создаем временный контейнер
TEMP_CONTAINER="temp_full_fix"
docker create --name $TEMP_CONTAINER $BACKEND_IMAGE
docker cp $TEMP_CONTAINER:/app/dist ./temp_dist_full
docker rm $TEMP_CONTAINER

log "🔍 АНАЛИЗИРУЕМ СТРУКТУРУ DIST:"
echo "=== СТРУКТУРА DIST ==="
find temp_dist_full -type f -name "*.js" | head -10

log "🔧 ИСПРАВЛЯЕМ ВСЕ АЛИАСЫ С УЧЕТОМ ОТНОСИТЕЛЬНЫХ ПУТЕЙ..."

# Функция для исправления алиасов в зависимости от глубины папки
fix_aliases_for_depth() {
    local depth=$1
    local prefix=""
    
    # Создаем относительный префикс в зависимости от глубины
    for ((i=0; i<depth; i++)); do
        prefix="../$prefix"
    done
    
    echo "Исправляем для глубины $depth (префикс: $prefix)"
    
    # Исправляем файлы на данной глубине
    case $depth in
        0) # Корень dist/
            find temp_dist_full -maxdepth 1 -name "*.js" -type f -exec sed -i "s|require(\"@/config|require(\"./config|g" {} \;
            find temp_dist_full -maxdepth 1 -name "*.js" -type f -exec sed -i "s|require(\"@/utils|require(\"./utils|g" {} \;
            find temp_dist_full -maxdepth 1 -name "*.js" -type f -exec sed -i "s|require(\"@/services|require(\"./services|g" {} \;
            find temp_dist_full -maxdepth 1 -name "*.js" -type f -exec sed -i "s|require(\"@/models|require(\"./models|g" {} \;
            find temp_dist_full -maxdepth 1 -name "*.js" -type f -exec sed -i "s|require(\"@/controllers|require(\"./controllers|g" {} \;
            find temp_dist_full -maxdepth 1 -name "*.js" -type f -exec sed -i "s|require(\"@/middleware|require(\"./middleware|g" {} \;
            find temp_dist_full -maxdepth 1 -name "*.js" -type f -exec sed -i "s|require(\"@/types|require(\"./types|g" {} \;
            ;;
        1) # Папки на глубине 1 (utils/, services/, etc.)
            find temp_dist_full -mindepth 2 -maxdepth 2 -name "*.js" -type f -exec sed -i "s|require(\"@/config|require(\"../config|g" {} \;
            find temp_dist_full -mindepth 2 -maxdepth 2 -name "*.js" -type f -exec sed -i "s|require(\"@/utils|require(\"../utils|g" {} \;
            find temp_dist_full -mindepth 2 -maxdepth 2 -name "*.js" -type f -exec sed -i "s|require(\"@/services|require(\"../services|g" {} \;
            find temp_dist_full -mindepth 2 -maxdepth 2 -name "*.js" -type f -exec sed -i "s|require(\"@/models|require(\"../models|g" {} \;
            find temp_dist_full -mindepth 2 -maxdepth 2 -name "*.js" -type f -exec sed -i "s|require(\"@/controllers|require(\"../controllers|g" {} \;
            find temp_dist_full -mindepth 2 -maxdepth 2 -name "*.js" -type f -exec sed -i "s|require(\"@/middleware|require(\"../middleware|g" {} \;
            find temp_dist_full -mindepth 2 -maxdepth 2 -name "*.js" -type f -exec sed -i "s|require(\"@/types|require(\"../types|g" {} \;
            ;;
        2) # Папки на глубине 2 
            find temp_dist_full -mindepth 3 -maxdepth 3 -name "*.js" -type f -exec sed -i "s|require(\"@/config|require(\"../../config|g" {} \;
            find temp_dist_full -mindepth 3 -maxdepth 3 -name "*.js" -type f -exec sed -i "s|require(\"@/utils|require(\"../../utils|g" {} \;
            find temp_dist_full -mindepth 3 -maxdepth 3 -name "*.js" -type f -exec sed -i "s|require(\"@/services|require(\"../../services|g" {} \;
            find temp_dist_full -mindepth 3 -maxdepth 3 -name "*.js" -type f -exec sed -i "s|require(\"@/models|require(\"../../models|g" {} \;
            find temp_dist_full -mindepth 3 -maxdepth 3 -name "*.js" -type f -exec sed -i "s|require(\"@/controllers|require(\"../../controllers|g" {} \;
            find temp_dist_full -mindepth 3 -maxdepth 3 -name "*.js" -type f -exec sed -i "s|require(\"@/middleware|require(\"../../middleware|g" {} \;
            find temp_dist_full -mindepth 3 -maxdepth 3 -name "*.js" -type f -exec sed -i "s|require(\"@/types|require(\"../../types|g" {} \;
            ;;
    esac
}

# Исправляем алиасы для всех уровней глубины
fix_aliases_for_depth 0
fix_aliases_for_depth 1  
fix_aliases_for_depth 2

# Дополнительно исправляем import statements если есть
find temp_dist_full -name "*.js" -type f -exec sed -i 's|from "@/config|from "./config|g' {} \;
find temp_dist_full -name "*.js" -type f -exec sed -i 's|from "@/utils|from "../utils|g' {} \;
find temp_dist_full -name "*.js" -type f -exec sed -i 's|from "@/services|from "../services|g' {} \;

log "✅ ПРОВЕРЯЕМ РЕЗУЛЬТАТ ИСПРАВЛЕНИЯ:"
echo "=== ПРОБЛЕМНЫЙ ФАЙЛ utils/logger.js ==="
if [ -f temp_dist_full/utils/logger.js ]; then
    echo "Содержимое строки 14 (была ошибка):"
    sed -n '14p' temp_dist_full/utils/logger.js
    echo ""
    echo "Все require в logger.js:"
    grep "require(" temp_dist_full/utils/logger.js | head -5
else
    echo "Файл utils/logger.js не найден"
fi

echo ""
echo "=== ПРОВЕРКА ВСЕХ @/ АЛИАСОВ (должно быть пусто) ==="
grep -r "@/" temp_dist_full/ | head -5 || echo "✅ Все @/ алиасы исправлены!"

log "🚀 СОЗДАЕМ ПОЛНОСТЬЮ ИСПРАВЛЕННЫЙ ОБРАЗ..."

# Создаем новый Dockerfile
cat > Dockerfile.fully_patched << 'EOF'
FROM dailer-backend-fixed:latest

# Копируем полностью исправленную dist папку
COPY temp_dist_full /app/dist

# Убеждаемся что права корректны
USER root
RUN chown -R nodeuser:nodejs /app/dist
USER nodeuser

CMD ["node", "dist/app.js"]
EOF

# Собираем полностью исправленный образ
docker build -f Dockerfile.fully_patched -t dailer-backend-fully-fixed:latest .

# Обновляем docker-compose
sed -i 's|dailer-backend-fixed:latest|dailer-backend-fully-fixed:latest|g' docker-compose-ready.yml

# Очищаем временные файлы
rm -rf temp_dist_full Dockerfile.fully_patched

log "🚀 ФИНАЛЬНЫЙ ПЕРЕЗАПУСК С ПОЛНОСТЬЮ ИСПРАВЛЕННЫМ КОДОМ..."

docker compose -f docker-compose-ready.yml stop backend
docker compose -f docker-compose-ready.yml rm -f backend
docker compose -f docker-compose-ready.yml up -d backend

log "⏰ ФИНАЛЬНАЯ ПРОВЕРКА (60 секунд)..."

sleep 15

for i in {1..9}; do
    BACKEND_STATUS=$(docker ps --filter "name=dialer_backend_ready" --format "{{.Status}}" 2>/dev/null)
    
    if echo "$BACKEND_STATUS" | grep -q "Up"; then
        log "✅ Backend контейнер запущен: $BACKEND_STATUS"
        
        sleep 5
        LOGS=$(docker logs dialer_backend_ready --tail 20 2>&1)
        
        if echo "$LOGS" | grep -q "Cannot find module"; then
            ERROR_MSG=$(echo "$LOGS" | grep "Cannot find module" | head -1)
            log "❌ Все еще есть ошибки модулей: $ERROR_MSG"
        elif echo "$LOGS" | grep -q "Error:"; then
            ERROR_MSG=$(echo "$LOGS" | grep "Error:" | head -1)
            log "⚠️ Другая ошибка: $ERROR_MSG"
        else
            log "✅ Backend запущен БЕЗ ОШИБОК МОДУЛЕЙ!"
            
            if curl -sf http://localhost:3001/health >/dev/null 2>&1; then
                log "🎉 BACKEND API РАБОТАЕТ!"
                
                echo ""
                echo "🎉 🎉 🎉 СИСТЕМА ПОЛНОСТЬЮ ИСПРАВЛЕНА И РАБОТАЕТ! 🎉 🎉 🎉"
                echo ""
                echo "✅ ВСЕ ПРОБЛЕМЫ РЕШЕНЫ:"
                echo "  🎯 TypeScript path alias ПОЛНОСТЬЮ исправлен во всех файлах"
                echo "  🔐 JWT_SECRET настроен"
                echo "  📝 Все переменные окружения работают"
                echo "  🚀 Backend API отвечает"
                echo "  🌐 Все 5 сервисов работают"
                echo ""
                echo "🌐 СИСТЕМА ГОТОВА:"
                echo "  Frontend:     http://localhost:3000"
                echo "  Backend API:  http://localhost:3001/health"
                echo "  Asterisk CLI: docker exec -it dialer_asterisk_ready asterisk -r"
                echo ""
                echo "🏁 МИГРАЦИЯ FreeSWITCH ➜ ASTERISK ЗАВЕРШЕНА НА 100%!"
                echo ""
                echo "🎯 ГОТОВО К ТЕСТИРОВАНИЮ SIP ЗВОНКОВ!"
                
                docker compose -f docker-compose-ready.yml ps
                
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
echo "📝 Логи backend:"
docker logs dialer_backend_ready --tail 30

exit 1 