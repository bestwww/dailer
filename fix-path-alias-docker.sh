#!/bin/bash

# ИСПРАВЛЕНИЕ TYPESCRIPT PATH ALIAS ЧЕРЕЗ DOCKER

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🎯 ИСПРАВЛЕНИЕ TYPESCRIPT PATH ALIAS ЧЕРЕЗ DOCKER"

log "❌ ПРОБЛЕМА:"
echo "  Error: Cannot find module '@/config'"
echo "  npm не доступен на хосте"

log "🔧 РЕШЕНИЕ: ИСПРАВЛЯЕМ АЛИАСЫ НАПРЯМУЮ В DOCKER КОНТЕЙНЕРЕ..."

# Получаем актуальный backend образ
BACKEND_IMAGE="dailer-backend:latest"

log "🔍 ШАГ 1: ПРОВЕРЯЕМ ПРОБЛЕМУ В ТЕКУЩЕМ ОБРАЗЕ..."

echo "=== СОДЕРЖИМОЕ app.js (строки с @/) ==="
docker run --rm $BACKEND_IMAGE grep -n "@/" dist/app.js | head -10

log "🔧 ШАГ 2: СОЗДАЕМ ИСПРАВЛЕННУЮ ВЕРСИЮ НАПРЯМУЮ..."

# Создаем временный контейнер для исправления
TEMP_CONTAINER="temp_backend_fix"

# Создаем контейнер из образа
docker create --name $TEMP_CONTAINER $BACKEND_IMAGE

# Копируем dist папку из контейнера
log "  Копирование dist/ из контейнера..."
docker cp $TEMP_CONTAINER:/app/dist ./temp_dist

# Удаляем временный контейнер
docker rm $TEMP_CONTAINER

# Исправляем все алиасы в локальной копии
log "  Замена всех @/ алиасов на относительные пути..."

find temp_dist -name "*.js" -type f -exec sed -i 's|require("@/config|require("./config|g' {} \;
find temp_dist -name "*.js" -type f -exec sed -i 's|require("@/controllers|require("./controllers|g' {} \;
find temp_dist -name "*.js" -type f -exec sed -i 's|require("@/services|require("./services|g' {} \;
find temp_dist -name "*.js" -type f -exec sed -i 's|require("@/models|require("./models|g' {} \;
find temp_dist -name "*.js" -type f -exec sed -i 's|require("@/middleware|require("./middleware|g' {} \;
find temp_dist -name "*.js" -type f -exec sed -i 's|require("@/utils|require("./utils|g' {} \;
find temp_dist -name "*.js" -type f -exec sed -i 's|require("@/types|require("./types|g' {} \;

# Также исправляем import statements если есть
find temp_dist -name "*.js" -type f -exec sed -i 's|from "@/config|from "./config|g' {} \;
find temp_dist -name "*.js" -type f -exec sed -i 's|from "@/controllers|from "./controllers|g' {} \;
find temp_dist -name "*.js" -type f -exec sed -i 's|from "@/services|from "./services|g' {} \;
find temp_dist -name "*.js" -type f -exec sed -i 's|from "@/models|from "./models|g' {} \;
find temp_dist -name "*.js" -type f -exec sed -i 's|from "@/middleware|from "./middleware|g' {} \;
find temp_dist -name "*.js" -type f -exec sed -i 's|from "@/utils|from "./utils|g' {} \;
find temp_dist -name "*.js" -type f -exec sed -i 's|from "@/types|from "./types|g' {} \;

log "✅ Алиасы заменены! Проверяем результат..."

echo "=== ИСПРАВЛЕННЫЙ app.js (строки с @/) ==="
grep -n "@/" temp_dist/app.js | head -5 || echo "✅ Алиасы больше не найдены!"

echo ""
echo "=== ИСПРАВЛЕННЫЙ app.js (первые 10 require) ==="
grep -n "require(" temp_dist/app.js | head -10

log "🚀 ШАГ 3: СОЗДАЕМ НОВЫЙ BACKEND ОБРАЗ С ИСПРАВЛЕННЫМ КОДОМ..."

# Создаем Dockerfile для патченого образа
cat > Dockerfile.patched << 'EOF'
FROM dailer-backend:latest

# Копируем исправленную dist папку
COPY temp_dist /app/dist

# Убеждаемся что права корректны
USER root
RUN chown -R nodeuser:nodejs /app/dist
USER nodeuser

# Используем тот же entrypoint
CMD ["node", "dist/app.js"]
EOF

# Собираем патченый образ
log "  Сборка исправленного образа..."
docker build -f Dockerfile.patched -t dailer-backend-fixed:latest .

# Очищаем временные файлы
rm -rf temp_dist Dockerfile.patched

log "🔄 ШАГ 4: ОБНОВЛЯЕМ DOCKER-COMPOSE ФАЙЛ..."

# Обновляем docker-compose чтобы использовать исправленный образ
sed -i 's|image: dailer-backend:latest|image: dailer-backend-fixed:latest|g' docker-compose-ready.yml || \
sed -i 's|dailer-backend:latest|dailer-backend-fixed:latest|g' docker-compose-ready.yml

log "🚀 ШАГ 5: ПЕРЕЗАПУСК BACKEND С ИСПРАВЛЕННЫМ ОБРАЗОМ..."

# Останавливаем и удаляем старый backend
docker compose -f docker-compose-ready.yml stop backend
docker compose -f docker-compose-ready.yml rm -f backend

# Запускаем с новым образом
docker compose -f docker-compose-ready.yml up -d backend

log "⏰ ШАГ 6: ПРОВЕРКА ЗАПУСКА (60 секунд)..."

sleep 15

for i in {1..9}; do
    BACKEND_STATUS=$(docker ps --filter "name=dialer_backend_ready" --format "{{.Status}}" 2>/dev/null)
    
    if echo "$BACKEND_STATUS" | grep -q "Up"; then
        log "✅ Backend контейнер запущен: $BACKEND_STATUS"
        
        # Тестируем API
        sleep 5
        if curl -sf http://localhost:3001/health >/dev/null 2>&1; then
            log "🎉 BACKEND API РАБОТАЕТ!"
            
            echo ""
            echo "🎉 🎉 🎉 ПРОБЛЕМА ПОЛНОСТЬЮ РЕШЕНА! 🎉 🎉 🎉"
            echo ""
            echo "✅ TypeScript path alias проблема исправлена через Docker"
            echo "✅ Backend успешно запущен и работает"
            echo ""
            echo "🌐 Frontend:     http://localhost:3000"
            echo "🔧 Backend API:  http://localhost:3001/health"
            echo "📞 Asterisk CLI: docker exec -it dialer_asterisk_ready asterisk -r"
            echo "💾 PostgreSQL:   docker exec -it dialer_postgres_ready psql -U dialer -d dialer"
            echo "🔴 Redis CLI:    docker exec -it dialer_redis_ready redis-cli"
            echo ""
            echo "🏁 МИГРАЦИЯ FreeSWITCH ➜ ASTERISK ЗАВЕРШЕНА УСПЕШНО!"
            echo ""
            echo "🎯 СИСТЕМА ГОТОВА К ТЕСТИРОВАНИЮ SIP ЗВОНКОВ!"
            
            # Показываем финальный статус всех сервисов
            echo ""
            echo "📊 ФИНАЛЬНЫЙ СТАТУС ВСЕХ СЕРВИСОВ:"
            docker compose -f docker-compose-ready.yml ps
            
            exit 0
        else
            log "⚠️ Backend запущен, но API еще не отвечает (${i}*5 сек)"
        fi
    else
        log "📊 Backend статус: $BACKEND_STATUS (${i}*5 сек)"
    fi
    
    sleep 5
done

log "⚠️ Проблемы с запуском. Показываю диагностику..."

echo ""
echo "📝 Логи backend:"
docker logs dialer_backend_ready --tail 30

echo ""
echo "📊 Статус всех контейнеров:"
docker compose -f docker-compose-ready.yml ps

echo ""
log "💡 ЕСЛИ ПРОБЛЕМЫ ОСТАЛИСЬ:"
echo "  1. Проверьте логи: docker logs dialer_backend_ready"
echo "  2. Ручной тест: docker run --rm -it dailer-backend-fixed:latest node dist/app.js"
echo "  3. Перезапуск: docker compose -f docker-compose-ready.yml restart backend"

exit 1 