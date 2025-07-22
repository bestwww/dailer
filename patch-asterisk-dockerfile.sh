#!/bin/bash

# ПАТЧ: Исправление ошибки /usr/share/asterisk not found

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🔧 ПАТЧ: Исправление Dockerfile-optimized"

# Остановить сборку если она еще идет
docker compose -f docker-compose-optimized.yml down --remove-orphans 2>/dev/null || true

log "📋 Проблема: COPY --from=builder /usr/share/asterisk не работает"
log "✅ Решение: Убираем проблемную строку, создаем директории вручную"

log "🔍 Проверка исправленного Dockerfile..."
if grep -q "mkdir -p /usr/share/asterisk" docker/asterisk/Dockerfile-optimized; then
    log "✅ Dockerfile уже исправлен"
else
    log "❌ Dockerfile не исправлен, применяем патч..."
    exit 1
fi

log "🧹 Очистка поврежденных образов..."
docker images | grep dialer-asterisk | awk '{print $3}' | xargs -r docker rmi -f 2>/dev/null || true

log "🏗️ БЫСТРАЯ ПЕРЕСБОРКА (без кэша)..."
docker compose -f docker-compose-optimized.yml build asterisk --no-cache

BUILD_RESULT=$?

if [ $BUILD_RESULT -eq 0 ]; then
    log "🎉 SUCCESS: Сборка завершена успешно!"
    
    log "📊 Проверка размера образа:"
    docker images | grep dialer-asterisk | head -1
    
    log "🧪 Быстрый тест образа..."
    timeout 10 docker run --rm dialer-asterisk:latest asterisk -V && {
        log "✅ Образ работает корректно"
    } || {
        log "⚠️ Образ собрался, но есть проблемы с запуском"
    }
    
    log "🚀 Запуск исправленной системы..."
    docker compose -f docker-compose-optimized.yml up postgres redis -d
    sleep 10
    
    docker compose -f docker-compose-optimized.yml up asterisk -d
    sleep 20
    
    log "📋 Статус системы:"
    docker compose -f docker-compose-optimized.yml ps
    
    if docker ps | grep -q dialer_asterisk_optimized; then
        log "🎉 ПАТЧ УСПЕШНО ПРИМЕНЕН!"
        log "Asterisk контейнер запущен"
        
        # Попробуем получить версию
        timeout 10 docker exec dialer_asterisk_optimized asterisk -V 2>/dev/null && {
            log "✅ Asterisk отвечает на команды"
        } || {
            log "⚠️ Asterisk запущен, но не отвечает (возможно еще загружается)"
        }
    else
        log "❌ Контейнер не запустился, проверьте логи:"
        log "docker logs dialer_asterisk_optimized"
    fi
    
else
    log "❌ СБОРКА НЕ УДАЛАСЬ"
    log "Проверьте логи сборки выше"
    exit 1
fi

log "✅ ПАТЧ ЗАВЕРШЕН" 