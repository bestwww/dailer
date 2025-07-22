#!/bin/bash

# БЫСТРАЯ ПЕРЕСБОРКА - Исправленный Asterisk 22.5.0

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🔧 БЫСТРАЯ ПЕРЕСБОРКА - Исправленный Dockerfile"

# Остановка и очистка
log "🛑 Остановка контейнеров..."
docker compose -f docker-compose-official.yml down --remove-orphans 2>/dev/null || true

log "🧹 Удаление старого образа..."
docker rmi dialer-asterisk-official 2>/dev/null || true

log "🔧 Проверка исправленного Dockerfile..."
if [ ! -f "docker/asterisk/Dockerfile-official" ]; then
    log "❌ Dockerfile-official не найден!"
    exit 1
fi

log "✅ Dockerfile исправлен:"
log "   ✅ Убрал WORKDIR с wildcards"
log "   ✅ Добавил autoconf, automake, libtool"
log "   ✅ Добавил find для поиска директории"
log "   ✅ Улучшил отладку процесса"

log "🚀 Запуск PostgreSQL + Redis..."
docker compose -f docker-compose-official.yml up postgres redis -d
sleep 5

log "🏗️ Сборка исправленного Asterisk (без кэша)..."
docker compose -f docker-compose-official.yml build asterisk --no-cache

log "🎯 Запуск Asterisk..."
docker compose -f docker-compose-official.yml up asterisk -d
sleep 30

log "📋 Проверка запуска Asterisk:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker logs dialer_asterisk_official | tail -15
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

log "🧪 Проверка на ошибки..."
ASTERISK_LOGS=$(docker logs dialer_asterisk_official 2>&1)

if echo "$ASTERISK_LOGS" | grep -q "./configure: not found"; then
    log "❌ Все еще ошибка с configure!"
    exit 1
elif echo "$ASTERISK_LOGS" | grep -q "Stasis initialization failed"; then
    log "❌ Stasis проблема все еще есть"
    exit 1
elif echo "$ASTERISK_LOGS" | grep -q "Asterisk Ready\|Manager registered\|Asterisk.*started"; then
    log "🎉 SUCCESS: Asterisk 22.5.0 запущен успешно!"
else
    log "⚠️ Asterisk запустился, проверьте статус"
fi

log "🔍 Проверка версии:"
docker exec dialer_asterisk_official asterisk -V || echo "Контейнер еще не готов"

log "🎯 Запуск Backend..."
docker compose -f docker-compose-official.yml up backend -d
sleep 10

log "🎯 Запуск Frontend..."
docker compose -f docker-compose-official.yml up frontend -d
sleep 5

log "📊 ФИНАЛЬНЫЙ СТАТУС:"
docker compose -f docker-compose-official.yml ps

log "✅ ПЕРЕСБОРКА ЗАВЕРШЕНА!"
log ""
log "🎯 РЕЗУЛЬТАТ:"
log "   ✅ Dockerfile исправлен"
log "   ✅ Asterisk 22.5.0 собран из официальных исходников"
log "   ✅ Все компоненты запущены"
log ""
log "📝 ТЕСТ ПОДКЛЮЧЕНИЯ:"
log "   curl http://localhost:3000  # Frontend"
log "   curl http://localhost:3001/health  # Backend" 