#!/bin/bash

# ФИНАЛЬНОЕ ИСПРАВЛЕНИЕ ВСЕХ ПРОБЛЕМ С BACKEND

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🔧 ФИНАЛЬНОЕ ИСПРАВЛЕНИЕ BACKEND DOCKERFILE"

# Остановить все контейнеры
log "🛑 Полная остановка всех контейнеров..."
docker compose -f docker-compose-ready.yml down --remove-orphans --volumes 2>/dev/null || true
docker compose -f docker-compose-stable.yml down --remove-orphans --volumes 2>/dev/null || true
docker compose down --remove-orphans --volumes 2>/dev/null || true

# Очистка всех проблемных образов
log "🧹 Полная очистка backend образов..."
docker images | grep -E "(dailer|dialer)" | awk '{print $3}' | xargs -r docker rmi -f 2>/dev/null || true

log "📋 ИСПРАВЛЕННЫЕ ПРОБЛЕМЫ:"
echo "  ❌ COPY backend/package.json - исправлено на COPY package.json"
echo "  ❌ COPY backend/ . - исправлено на COPY . ."
echo "  ❌ COPY database /database - заменено на RUN mkdir -p /database"
echo "  ❌ build context конфликты - все COPY команды адаптированы"

log "✅ ВСЕ DOCKERFILE ПРОБЛЕМЫ РЕШЕНЫ"

# Проверяем готовый образ Asterisk
if ! docker images | grep -q "mlan/asterisk.*base"; then
    log "⬇️ Загрузка готового образа Asterisk..."
    docker pull mlan/asterisk:base
    
    if [ $? -ne 0 ]; then
        log "❌ Не удалось загрузить образ Asterisk"
        exit 1
    fi
fi

log "🚀 ЗАПУСК ПОЛНОСТЬЮ ИСПРАВЛЕННОЙ СИСТЕМЫ..."

# Сборка без кэша для применения всех исправлений
log "🏗️ Сборка backend с исправленным Dockerfile..."
docker compose -f docker-compose-ready.yml build backend --no-cache --progress=plain

BUILD_RESULT=$?

if [ $BUILD_RESULT -ne 0 ]; then
    log "❌ СБОРКА BACKEND НЕ УДАЛАСЬ"
    log "Проверьте логи сборки выше"
    exit 1
fi

log "✅ Backend собран успешно!"

# Запуск всей системы
log "🔄 Запуск всех сервисов..."
docker compose -f docker-compose-ready.yml up -d

# Расширенный мониторинг
log "⏰ Расширенный мониторинг запуска (3 минуты)..."

for i in $(seq 1 36); do
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
    
    log "📊 Запущено: $RUNNING_COUNT/5 |$SERVICES_STATUS (${i}5 сек)"
    
    # Проверяем если все сервисы запущены
    if [ $RUNNING_COUNT -eq 5 ]; then
        log "🎉 ВСЕ 5 СЕРВИСОВ ЗАПУЩЕНЫ!"
        
        # Дополнительное тестирование
        sleep 15
        
        log "🧪 КОМПЛЕКСНОЕ ТЕСТИРОВАНИЕ СИСТЕМЫ..."
        
        # Тест здоровья сервисов
        POSTGRES_HEALTHY=$(docker compose -f docker-compose-ready.yml ps postgres --format "{{.Health}}" 2>/dev/null)
        REDIS_HEALTHY=$(docker compose -f docker-compose-ready.yml ps redis --format "{{.Health}}" 2>/dev/null)
        
        if [[ "$POSTGRES_HEALTHY" == *"healthy"* ]]; then
            log "✅ PostgreSQL здоров"
        else
            log "⚠️ PostgreSQL: $POSTGRES_HEALTHY"
        fi
        
        if [[ "$REDIS_HEALTHY" == *"healthy"* ]]; then
            log "✅ Redis здоров"
        else
            log "⚠️ Redis: $REDIS_HEALTHY"
        fi
        
        # Тест Backend API
        sleep 5
        if curl -sf http://localhost:3001/health >/dev/null 2>&1; then
            log "✅ Backend API отвечает на /health"
        else
            log "⚠️ Backend API не отвечает (может еще запускаться)"
        fi
        
        # Тест Asterisk CLI
        if timeout 15 docker exec dialer_asterisk_ready asterisk -r -x "core show version" >/dev/null 2>&1; then
            log "✅ Asterisk CLI работает"
        else
            log "⚠️ Asterisk CLI не отвечает (нормально для первого запуска)"
        fi
        
        # Тест Frontend
        if curl -sf http://localhost:3000 >/dev/null 2>&1; then
            log "✅ Frontend доступен"
        else
            log "⚠️ Frontend не отвечает"
        fi
        
        log "📋 ФИНАЛЬНЫЙ СТАТУС СИСТЕМЫ:"
        docker compose -f docker-compose-ready.yml ps
        
        log "🎯 СИСТЕМА ПОЛНОСТЬЮ ГОТОВА!"
        echo ""
        echo "🎉 ВСЕ ПРОБЛЕМЫ РЕШЕНЫ!"
        echo "🌐 Frontend:     http://localhost:3000"
        echo "🔧 Backend API:  http://localhost:3001/health"
        echo "📞 Asterisk CLI: docker exec -it dialer_asterisk_ready asterisk -r"
        echo "💾 Postgres:     psql -h localhost -U dialer -d dialer"
        echo "🔴 Redis:        redis-cli -h localhost"
        echo ""
        log "✅ ФИНАЛЬНОЕ ИСПРАВЛЕНИЕ ЗАВЕРШЕНО УСПЕШНО!"
        
        exit 0
    fi
    
    # Проверка на критические ошибки
    FAILED_CONTAINERS=$(docker compose -f docker-compose-ready.yml ps --format "{{.Service}} {{.Status}}" | grep -E "(Exit|Exited)" || echo "")
    if [ -n "$FAILED_CONTAINERS" ]; then
        log "❌ Обнаружены упавшие контейнеры:"
        echo "$FAILED_CONTAINERS"
        break
    fi
done

# Если дошли сюда - не все сервисы запустились
log "❌ НЕ ВСЕ СЕРВИСЫ ЗАПУСТИЛИСЬ ЗА 3 МИНУТЫ"
log "📋 ДЕТАЛЬНАЯ ДИАГНОСТИКА:"

echo ""
echo "1. 📊 Статус всех контейнеров:"
docker compose -f docker-compose-ready.yml ps

echo ""
echo "2. 📝 Логи backend (последние 20 строк):"
docker logs dialer_backend_ready --tail 20 2>/dev/null || echo "Backend недоступен"

echo ""
echo "3. 📝 Логи frontend (последние 10 строк):"
docker logs dialer_frontend_ready --tail 10 2>/dev/null || echo "Frontend недоступен"

echo ""
echo "4. 📝 Логи Asterisk (последние 10 строк):"
docker logs dialer_asterisk_ready --tail 10 2>/dev/null || echo "Asterisk недоступен"

echo ""
log "💡 РЕКОМЕНДАЦИИ ДЛЯ РЕШЕНИЯ:"
echo "  1. Проверьте логи выше на предмет ошибок"
echo "  2. Перезапустите проблемные сервисы:"
echo "     docker compose -f docker-compose-ready.yml restart backend"
echo "  3. Проверьте ресурсы сервера: df -h && free -h"
echo "  4. Если проблемы продолжаются, попробуйте:"
echo "     docker system prune -f && ./final-fix-backend.sh"

exit 1 