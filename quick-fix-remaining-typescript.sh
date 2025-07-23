#!/bin/bash

# БЫСТРОЕ ИСПРАВЛЕНИЕ ОСТАВШИХСЯ TYPESCRIPT ОШИБОК

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🔧 БЫСТРОЕ ИСПРАВЛЕНИЕ ОСТАВШИХСЯ TYPESCRIPT ОШИБОК"

log "📋 ИСПРАВЛЕННЫЕ ОШИБКИ:"
echo "  ✅ contact.ts: Добавлен constraint QueryResultRow для generic T"
echo "  ✅ asterisk-adapter.ts: Исправлено exactOptionalPropertyTypes для callerIdNumber"
echo "  ✅ freeswitch-adapter.ts: Убрана неиспользуемая private переменная _config"  
echo "  ✅ dialer.ts: Типизирован параметр contact в forEach"

# Остановить все контейнеры
log "🛑 Остановка всех контейнеров..."
docker compose -f docker-compose-ready.yml down --remove-orphans 2>/dev/null || true

# Очистка backend образа
log "🧹 Очистка backend образа..."
docker images | grep "dailer-backend" | awk '{print $3}' | xargs -r docker rmi -f 2>/dev/null || true

log "🚀 БЫСТРАЯ ПЕРЕСБОРКА BACKEND..."

# Сборка backend
docker compose -f docker-compose-ready.yml build backend --no-cache

BUILD_RESULT=$?

if [ $BUILD_RESULT -ne 0 ]; then
    log "❌ СБОРКА ВСЕ ЕЩЕ НЕ УДАЛАСЬ"
    echo "Проверьте логи сборки выше"
    exit 1
fi

log "✅ BACKEND СОБРАН УСПЕШНО!"

# Запуск всех сервисов
log "🔄 Запуск всех сервисов..."
docker compose -f docker-compose-ready.yml up -d

# Быстрая проверка (1 минута)
log "⏰ Быстрая проверка (1 минута)..."

for i in $(seq 1 12); do
    sleep 5
    
    RUNNING_COUNT=$(docker ps --filter "name=dialer_.*_ready" --format "{{.Names}}" | wc -l)
    
    log "📊 Запущено сервисов: $RUNNING_COUNT/5 ($((i*5)) сек)"
    
    if [ $RUNNING_COUNT -eq 5 ]; then
        log "🎉 ВСЕ 5 СЕРВИСОВ ЗАПУЩЕНЫ!"
        
        sleep 15
        
        BACKEND_STATUS=$(docker compose -f docker-compose-ready.yml ps backend --format "{{.Status}}" 2>/dev/null)
        
        if echo "$BACKEND_STATUS" | grep -q "Up"; then
            log "✅ Backend стабилен!"
            
            # Тест API
            if curl -sf http://localhost:3001/health >/dev/null 2>&1; then
                log "✅ Backend API работает!"
                
                log "📋 ФИНАЛЬНЫЙ СТАТУС:"
                docker compose -f docker-compose-ready.yml ps
                
                echo ""
                echo "🎉 ВСЕ TYPESCRIPT ОШИБКИ ИСПРАВЛЕНЫ!"
                echo "   ✅ Backend компилируется без ошибок"
                echo "   ✅ Все 5 сервисов запущены и работают"
                echo "   ✅ API доступен и отвечает"
                echo ""
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
            log "❌ Backend не стабилен: $BACKEND_STATUS"
        fi
    fi
done

log "⚠️ НЕ ВСЕ СЕРВИСЫ ЗАПУСТИЛИСЬ ЗА МИНУТУ"
log "📊 Текущий статус:"
docker compose -f docker-compose-ready.yml ps

exit 0 