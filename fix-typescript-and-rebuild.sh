#!/bin/bash

# ИСПРАВЛЕНИЕ ВСЕХ TYPESCRIPT ОШИБОК И ПЕРЕСБОРКА

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🔧 ИСПРАВЛЕНИЕ TYPESCRIPT ОШИБОК И ПЕРЕСБОРКА"

log "📋 ИСПРАВЛЕННЫЕ TYPESCRIPT ОШИБКИ:"
echo "  ✅ Добавлены типы для asterisk-manager модуля"
echo "  ✅ Исправлены ошибки с optional properties (callerIdNumber, lastError)"
echo "  ✅ Добавлен tslib в devDependencies"
echo "  ✅ Исправлены ошибки с unknown error types в catch блоках"
echo "  ✅ Исправлен protected query метод (добавлен executeQuery)"
echo "  ✅ Исправлена ошибка с аргументами в log.error"
echo "  ✅ Убраны неиспользуемые импорты и переменные"
echo "  ✅ Исправлена дублированная переменная provider"

# Остановить все контейнеры
log "🛑 Остановка всех контейнеров..."
docker compose -f docker-compose-ready.yml down --remove-orphans 2>/dev/null || true

# Очистка backend образа
log "🧹 Очистка backend образа для пересборки..."
docker images | grep "dailer-backend" | awk '{print $3}' | xargs -r docker rmi -f 2>/dev/null || true

log "🚀 ПЕРЕСБОРКА BACKEND С ИСПРАВЛЕННЫМ TYPESCRIPT..."

# Сборка backend с исправлениями
docker compose -f docker-compose-ready.yml build backend --no-cache --progress=plain

BUILD_RESULT=$?

if [ $BUILD_RESULT -ne 0 ]; then
    log "❌ СБОРКА BACKEND ВСЕ ЕЩЕ НЕ УДАЛАСЬ"
    echo ""
    echo "📝 Возможные причины:"
    echo "  - Остались другие TypeScript ошибки"
    echo "  - Проблемы с зависимостями"
    echo "  - Синтаксические ошибки в коде"
    echo ""
    log "💡 ДИАГНОСТИКА:"
    echo "  1. Проверьте логи сборки выше на предмет новых ошибок"
    echo "  2. Локальная проверка TypeScript:"
    echo "     cd backend && npm run typecheck"
    echo "  3. Локальная сборка:"
    echo "     cd backend && npm run build"
    
    exit 1
fi

log "✅ BACKEND СОБРАН УСПЕШНО С ИСПРАВЛЕННЫМ TYPESCRIPT!"

# Запуск всей системы
log "🔄 Запуск всех сервисов..."
docker compose -f docker-compose-ready.yml up -d

# Мониторинг запуска (2 минуты)
log "⏰ Мониторинг запуска системы (2 минуты)..."

for i in $(seq 1 24); do
    sleep 5
    
    # Детальная проверка каждого сервиса
    POSTGRES_RUNNING=$(docker ps --filter "name=dialer_postgres_ready" --format "{{.Names}}" 2>/dev/null)
    REDIS_RUNNING=$(docker ps --filter "name=dialer_redis_ready" --format "{{.Names}}" 2>/dev/null)
    ASTERISK_RUNNING=$(docker ps --filter "name=dialer_asterisk_ready" --format "{{.Names}}" 2>/dev/null)
    BACKEND_RUNNING=$(docker ps --filter "name=dialer_backend_ready" --format "{{.Names}}" 2>/dev/null)
    FRONTEND_RUNNING=$(docker ps --filter "name=dialer_frontend_ready" --format "{{.Names}}" 2>/dev/null)
    
    # Подсчет запущенных сервисов
    RUNNING_COUNT=0
    SERVICES_STATUS=""
    
    if [ -n "$POSTGRES_RUNNING" ]; then
        ((RUNNING_COUNT++))
        SERVICES_STATUS="$SERVICES_STATUS PG✅"
    else
        SERVICES_STATUS="$SERVICES_STATUS PG❌"
    fi
    
    if [ -n "$REDIS_RUNNING" ]; then
        ((RUNNING_COUNT++))
        SERVICES_STATUS="$SERVICES_STATUS Redis✅"
    else
        SERVICES_STATUS="$SERVICES_STATUS Redis❌"
    fi
    
    if [ -n "$ASTERISK_RUNNING" ]; then
        ((RUNNING_COUNT++))
        SERVICES_STATUS="$SERVICES_STATUS Asterisk✅"
    else
        SERVICES_STATUS="$SERVICES_STATUS Asterisk❌"
    fi
    
    if [ -n "$BACKEND_RUNNING" ]; then
        ((RUNNING_COUNT++))
        SERVICES_STATUS="$SERVICES_STATUS Backend✅"
    else
        SERVICES_STATUS="$SERVICES_STATUS Backend❌"
    fi
    
    if [ -n "$FRONTEND_RUNNING" ]; then
        ((RUNNING_COUNT++))
        SERVICES_STATUS="$SERVICES_STATUS Frontend✅"
    else
        SERVICES_STATUS="$SERVICES_STATUS Frontend❌"
    fi
    
    log "📊 Запущено: $RUNNING_COUNT/5 |$SERVICES_STATUS ($((i*5)) сек)"
    
    # Проверяем если все сервисы запущены
    if [ $RUNNING_COUNT -eq 5 ]; then
        log "🎉 ВСЕ 5 СЕРВИСОВ ЗАПУЩЕНЫ!"
        
        # Дополнительная проверка стабильности
        sleep 15
        
        BACKEND_STATUS=$(docker compose -f docker-compose-ready.yml ps backend --format "{{.Status}}" 2>/dev/null)
        
        if echo "$BACKEND_STATUS" | grep -q "Up"; then
            log "✅ Backend стабилен и работает"
            
            # Тестируем API
            sleep 10
            if curl -sf http://localhost:3001/health >/dev/null 2>&1; then
                log "✅ Backend API отвечает!"
                
                log "📋 ФИНАЛЬНЫЙ СТАТУС СИСТЕМЫ:"
                docker compose -f docker-compose-ready.yml ps
                
                echo ""
                echo "🎉 ВСЕ TYPESCRIPT ОШИБКИ ИСПРАВЛЕНЫ!"
                echo "   ✅ Backend собирается без ошибок TypeScript"
                echo "   ✅ Backend запускается в production режиме"
                echo "   ✅ Все 5 сервисов работают стабильно"
                echo "   ✅ API доступен и отвечает"
                echo ""
                echo "🌐 Frontend:     http://localhost:3000"
                echo "🔧 Backend API:  http://localhost:3001/health"
                echo "📞 Asterisk CLI: docker exec -it dialer_asterisk_ready asterisk -r"
                echo "📞 SIP проверка: docker exec dialer_asterisk_ready asterisk -r -x 'pjsip show endpoints'"
                echo "💾 PostgreSQL:   psql -h localhost -U dialer -d dialer"
                echo "🔴 Redis:        redis-cli -h localhost"
                echo ""
                log "🏁 МИГРАЦИЯ FreeSWITCH ➜ ASTERISK ПОЛНОСТЬЮ ЗАВЕРШЕНА!"
                
                exit 0
            else
                log "⚠️ Backend запущен, но API не отвечает"
            fi
        else
            log "❌ Backend снова упал: $BACKEND_STATUS"
        fi
    fi
done

# Если не все сервисы запустились за 2 минуты
log "❌ НЕ ВСЕ СЕРВИСЫ ЗАПУСТИЛИСЬ ЗА 2 МИНУТЫ"

echo ""
echo "📝 Логи backend (последние 30 строк):"
docker logs dialer_backend_ready --tail 30 2>/dev/null || echo "Backend логи недоступны"

echo ""
log "📊 Статус всех контейнеров:"
docker compose -f docker-compose-ready.yml ps

echo ""
log "💡 ДОПОЛНИТЕЛЬНАЯ ДИАГНОСТИКА:"
echo "  1. Проверьте логи выше на новые ошибки"
echo "  2. Проверьте что TypeScript компилируется локально:"
echo "     cd backend && npm install && npm run build"
echo "  3. Если проблемы остаются:"
echo "     docker compose -f docker-compose-ready.yml logs backend"

exit 1 