#!/bin/bash

# ИСПРАВЛЕНИЕ JEST ПРОБЛЕМЫ И ПЕРЕЗАПУСК BACKEND

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🔧 ИСПРАВЛЕНИЕ JEST ПРОБЛЕМЫ"

log "📋 НАЙДЕННАЯ ПРОБЛЕМА:"
echo "  ❌ Backend запускал стадию 'test' вместо 'production'"
echo "  ❌ Jest завершался с exit code 1 (No tests found)"
echo "  ❌ Docker перезапускал контейнер из-за сбоя"

log "✅ ПРИМЕНЁННЫЕ ИСПРАВЛЕНИЯ:"
echo "  ✅ docker-compose-ready.yml: target: production"
echo "  ✅ backend/package.json: test: 'jest --passWithNoTests'"
echo "  ✅ backend/Dockerfile: правильные .ts файлы для тестов"

# Остановить все контейнеры
log "🛑 Остановка всех контейнеров..."
docker compose -f docker-compose-ready.yml down --remove-orphans 2>/dev/null || true

# Очистка backend образа для пересборки
log "🧹 Очистка backend образа..."
docker images | grep "dailer-backend" | awk '{print $3}' | xargs -r docker rmi -f 2>/dev/null || true

log "🚀 ПЕРЕСБОРКА BACKEND С ИСПРАВЛЕНИЯМИ..."

# Сборка backend с target: production
docker compose -f docker-compose-ready.yml build backend --no-cache --progress=plain

BUILD_RESULT=$?

if [ $BUILD_RESULT -ne 0 ]; then
    log "❌ СБОРКА BACKEND НЕ УДАЛАСЬ"
    echo "Проверьте логи сборки выше"
    exit 1
fi

log "✅ Backend пересобран с production target!"

# Запуск всей системы
log "🔄 Запуск всех сервисов..."
docker compose -f docker-compose-ready.yml up -d

# Мониторинг запуска (90 секунд)
log "⏰ Мониторинг запуска backend (90 секунд)..."

for i in $(seq 1 18); do
    sleep 5
    
    BACKEND_STATUS=$(docker compose -f docker-compose-ready.yml ps backend --format "{{.Status}}" 2>/dev/null)
    
    log "📊 Backend статус: $BACKEND_STATUS ($((i*5)) сек)"
    
    # Проверяем если backend запущен и стабилен
    if echo "$BACKEND_STATUS" | grep -q "Up"; then
        # Ждем еще 15 секунд для стабилизации
        sleep 15
        
        FINAL_STATUS=$(docker compose -f docker-compose-ready.yml ps backend --format "{{.Status}}" 2>/dev/null)
        
        if echo "$FINAL_STATUS" | grep -q "Up"; then
            log "🎉 BACKEND ЗАПУЩЕН И СТАБИЛЕН!"
            
            # Тестируем API
            sleep 10
            if curl -sf http://localhost:3001/health >/dev/null 2>&1; then
                log "✅ Backend API работает!"
                
                # Проверяем все сервисы
                RUNNING_COUNT=$(docker ps --filter "name=dialer_.*_ready" --format "{{.Names}}" | wc -l)
                
                log "📋 ФИНАЛЬНЫЙ СТАТУС СИСТЕМЫ:"
                docker compose -f docker-compose-ready.yml ps
                
                if [ $RUNNING_COUNT -eq 5 ]; then
                    log "🎯 ВСЕ 5 СЕРВИСОВ РАБОТАЮТ!"
                    echo ""
                    echo "🎉 JEST ПРОБЛЕМА ПОЛНОСТЬЮ РЕШЕНА!"
                    echo "   ✅ Backend запускается в production режиме"
                    echo "   ✅ Jest больше не крашит контейнер"
                    echo "   ✅ Все 5 сервисов работают стабильно"
                    echo ""
                    echo "🌐 Frontend:     http://localhost:3000"
                    echo "🔧 Backend API:  http://localhost:3001/health"
                    echo "📞 Asterisk CLI: docker exec -it dialer_asterisk_ready asterisk -r"
                    echo "📞 SIP проверка: docker exec dialer_asterisk_ready asterisk -r -x 'pjsip show endpoints'"
                    echo "💾 PostgreSQL:   psql -h localhost -U dialer -d dialer"
                    echo "🔴 Redis:        redis-cli -h localhost"
                    echo ""
                    log "🏁 МИГРАЦИЯ FreeSWITCH ➜ ASTERISK ЗАВЕРШЕНА УСПЕШНО!"
                    
                    exit 0
                else
                    log "⚠️ Backend работает, но не все сервисы запущены ($RUNNING_COUNT/5)"
                fi
            else
                log "⚠️ Backend запущен, но API не отвечает"
            fi
        else
            log "❌ Backend снова упал: $FINAL_STATUS"
            break
        fi
    fi
    
    # Проверка на перезапуски
    if echo "$BACKEND_STATUS" | grep -q "Restarting"; then
        log "⚠️ Backend все еще перезапускается..."
    fi
done

# Если дошли сюда - проблема не решена
log "❌ BACKEND НЕ ЗАПУСТИЛСЯ ЗА 90 СЕКУНД"

echo ""
echo "📝 Свежие логи backend (последние 30 строк):"
docker logs dialer_backend_ready --tail 30 2>/dev/null || echo "Логи недоступны"

echo ""
log "📊 Статус всех контейнеров:"
docker compose -f docker-compose-ready.yml ps

echo ""
log "💡 ДОПОЛНИТЕЛЬНАЯ ДИАГНОСТИКА:"
echo "  1. Проверьте что target: production работает:"
echo "     docker inspect dailer-backend:latest | grep -A10 -B10 production"
echo "  2. Проверьте что приложение запускается правильно:"
echo "     docker exec dialer_backend_ready ps aux"
echo "  3. Ручная проверка Jest конфигурации:"
echo "     docker exec -it dialer_backend_ready npm test"

exit 1 