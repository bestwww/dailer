#!/bin/bash

# ЭКСТРЕННЫЙ ПЕРЕЗАПУСК ASTERISK - Упрощенный подход

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🚨 ЭКСТРЕННЫЙ ПЕРЕЗАПУСК ASTERISK"

log "🛑 ПОЛНАЯ ОСТАНОВКА..."
# Принудительно остановить все
docker compose -f docker-compose-official.yml down --remove-orphans --timeout 10 2>/dev/null || true

log "🧹 ОЧИСТКА ЗАВИСШИХ КОНТЕЙНЕРОВ..."
# Убить все asterisk контейнеры
docker ps -aq --filter "name=asterisk" | xargs -r docker rm -f 2>/dev/null || true

log "📋 ПРОВЕРКА ОБРАЗОВ:"
docker images | grep asterisk || echo "Нет asterisk образов"

log "🎯 ПОПЫТКА 1: Запуск ТОЛЬКО Asterisk"

# Сначала запустим только базу
docker compose -f docker-compose-official.yml up postgres redis -d
sleep 5

log "🔍 Проверка готовности базы:"
docker compose -f docker-compose-official.yml ps

log "🚀 Запуск Asterisk с ПОДРОБНЫМИ логами..."

# Запуск asterisk в foreground с логами
docker compose -f docker-compose-official.yml up asterisk &
COMPOSE_PID=$!

log "⏰ Ждем 30 секунд на запуск Asterisk..."
sleep 30

log "📋 ПРОВЕРКА СТАТУСА:"
docker compose -f docker-compose-official.yml ps

log "🔍 ПОПЫТКА ПОЛУЧИТЬ ЛОГИ:"
# Попробуем получить логи с таймаутом
timeout 10 docker logs dialer_asterisk_official 2>&1 || log "❌ Логи недоступны"

log "🧪 ПРОВЕРКА КОНТЕЙНЕРА:"
if docker ps | grep -q dialer_asterisk_official; then
    log "✅ Контейнер запущен"
    
    log "🔍 Попытка подключения к контейнеру:"
    timeout 5 docker exec dialer_asterisk_official ps aux || log "❌ Контейнер не отвечает"
    
    log "🎯 Попытка получить версию Asterisk:"
    timeout 5 docker exec dialer_asterisk_official asterisk -V || log "❌ Asterisk не отвечает"
    
else
    log "❌ Контейнер НЕ запущен"
    
    log "🔍 Поиск упавших контейнеров:"
    docker ps -a | grep asterisk || log "Нет asterisk контейнеров"
    
    log "🧪 ПОПЫТКА 2: Простой запуск образа"
    log "Попробуем запустить образ напрямую..."
    
    timeout 20 docker run --rm --name asterisk_direct_test \
        dailer-asterisk:latest \
        asterisk -V 2>&1 || log "❌ Прямой запуск не работает"
fi

log "🛑 Остановка тестового запуска..."
kill $COMPOSE_PID 2>/dev/null || true
docker compose -f docker-compose-official.yml stop 2>/dev/null || true

log "✅ ДИАГНОСТИКА ЗАВЕРШЕНА"
log ""
log "📝 ЧТО ДАЛЬШЕ:"
log "   🔍 Если контейнер не запускается - проблема в образе"
log "   🔍 Если запускается но не отвечает - проблема в конфигурации" 
log "   🔍 Если логи недоступны - проблема в Docker или ресурсах" 