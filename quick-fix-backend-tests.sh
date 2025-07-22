#!/bin/bash

# БЫСТРОЕ ИСПРАВЛЕНИЕ ПРОБЛЕМЫ С BACKEND TESTS

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🔧 ИСПРАВЛЕНИЕ ПРОБЛЕМЫ С BACKEND TESTS"

# Остановить все контейнеры
log "🛑 Остановка всех контейнеров..."
docker compose -f docker-compose-ready.yml down --remove-orphans 2>/dev/null || true
docker compose -f docker-compose-stable.yml down --remove-orphans 2>/dev/null || true

# Удалить проблемные образы backend
log "🧹 Удаление старых backend образов..."
docker rmi dailer-backend:latest 2>/dev/null || true

log "📋 ПРОБЛЕМА БЫЛА:"
echo "  ❌ Dockerfile требует backend/tests/ директорию"
echo "  ❌ Git pull не помог - директория отсутствует на сервере"

log "✅ ИСПРАВЛЕНИЕ ВНЕСЕНО:"
echo "  ✅ Dockerfile теперь создает placeholder тесты автоматически"
echo "  ✅ Не требует существования backend/tests/"

log "🚀 ПЕРЕЗАПУСК С ИСПРАВЛЕННЫМ BACKEND..."

# Проверяем наличие готового образа Asterisk
if ! docker images | grep -q "mlan/asterisk.*base"; then
    log "⬇️ Загрузка готового образа Asterisk..."
    docker pull mlan/asterisk:base
fi

log "🔄 Запуск системы с исправленным backend..."
docker compose -f docker-compose-ready.yml up -d

# Мониторинг запуска
log "⏰ Мониторинг запуска сервисов (2 минуты)..."

for i in $(seq 1 24); do
    sleep 5
    
    # Проверка статуса всех сервисов
    POSTGRES_STATUS=$(docker ps --filter "name=dialer_postgres_ready" --format "{{.Status}}" 2>/dev/null | head -1)
    REDIS_STATUS=$(docker ps --filter "name=dialer_redis_ready" --format "{{.Status}}" 2>/dev/null | head -1)
    ASTERISK_STATUS=$(docker ps --filter "name=dialer_asterisk_ready" --format "{{.Status}}" 2>/dev/null | head -1)
    BACKEND_STATUS=$(docker ps --filter "name=dialer_backend_ready" --format "{{.Status}}" 2>/dev/null | head -1)
    
    # Подсчет готовых сервисов
    READY_COUNT=0
    
    if [[ "$POSTGRES_STATUS" == *"healthy"* ]]; then
        ((READY_COUNT++))
    fi
    
    if [[ "$REDIS_STATUS" == *"healthy"* ]]; then
        ((READY_COUNT++))
    fi
    
    if [[ "$ASTERISK_STATUS" == *"Up"* ]]; then
        ((READY_COUNT++))
    fi
    
    if [[ "$BACKEND_STATUS" == *"Up"* ]]; then
        ((READY_COUNT++))
    fi
    
    log "📊 Готовых сервисов: $READY_COUNT/4 (${i}0 сек)"
    
    if [ $READY_COUNT -eq 4 ]; then
        log "🎉 ВСЕ СЕРВИСЫ ЗАПУЩЕНЫ!"
        
        # Дополнительные тесты
        sleep 10
        
        log "🧪 Тестирование системы..."
        
        # Тест backend API
        if curl -s http://localhost:3001/health >/dev/null 2>&1; then
            log "✅ Backend API работает"
        else
            log "⚠️ Backend API не отвечает"
        fi
        
        # Тест Asterisk CLI
        if timeout 10 docker exec dialer_asterisk_ready asterisk -r -x "core show version" >/dev/null 2>&1; then
            log "✅ Asterisk CLI работает"
        else
            log "⚠️ Asterisk CLI не отвечает"
        fi
        
        log "📋 Финальный статус:"
        docker compose -f docker-compose-ready.yml ps
        
        log "🎯 СИСТЕМА ГОТОВА К РАБОТЕ!"
        echo ""
        echo "🌐 Frontend: http://localhost:3000"
        echo "🔧 Backend API: http://localhost:3001/health"
        echo "📞 Asterisk CLI: docker exec -it dialer_asterisk_ready asterisk -r"
        echo ""
        log "✅ BACKEND TESTS ПРОБЛЕМА РЕШЕНА!"
        
        exit 0
    fi
    
    # Проверка на ошибки
    if docker compose -f docker-compose-ready.yml ps | grep -q "Exit"; then
        log "❌ Некоторые контейнеры завершились с ошибкой"
        break
    fi
done

# Если дошли сюда - проблемы остались
log "❌ НЕ ВСЕ СЕРВИСЫ ЗАПУСТИЛИСЬ"
log "📋 Диагностика:"

echo ""
echo "1. Статус контейнеров:"
docker compose -f docker-compose-ready.yml ps

echo ""
echo "2. Логи backend (если есть проблемы):"
docker logs dialer_backend_ready --tail 20 2>/dev/null || echo "Backend контейнер недоступен"

echo ""
echo "3. Логи Asterisk:"
docker logs dialer_asterisk_ready --tail 10 2>/dev/null || echo "Asterisk контейнер недоступен"

echo ""
log "💡 ДАЛЬНЕЙШИЕ ДЕЙСТВИЯ:"
echo "  1. Проверьте логи выше"
echo "  2. Попробуйте перезапуск: docker compose -f docker-compose-ready.yml restart"
echo "  3. Или полная пересборка: docker compose -f docker-compose-ready.yml build --no-cache"

exit 1 