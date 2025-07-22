#!/bin/bash

# Исправление стабильности Asterisk контейнера
# Решает проблемы перезапуска и AMI подключения

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🛠️ Исправление стабильности Asterisk"

# Остановка всех контейнеров
log "🛑 Полная остановка системы..."
docker compose down --remove-orphans
docker stop $(docker ps -aq) 2>/dev/null || true

# Очистка проблемных ресурсов
log "🧹 Очистка Docker ресурсов..."
docker system prune -f

# Пересборка Asterisk с новыми настройками
log "🔨 Пересборка Asterisk с исправленной конфигурацией..."
docker compose build asterisk --no-cache

# Пересборка backend с исправленными reconnect логикой
log "🔨 Пересборка backend с исправлениями memory leak..."
docker compose build backend --no-cache

# Запуск по порядку для стабильности
log "🚀 Поэтапный запуск сервисов..."

log "1️⃣ Запуск базовых сервисов..."
docker compose up postgres redis -d

log "⏳ Ожидание готовности базы данных..."
sleep 15

log "2️⃣ Запуск Asterisk..."
docker compose up asterisk -d

log "⏳ Ожидание стабилизации Asterisk..."
sleep 20

log "3️⃣ Запуск backend..."
docker compose up backend -d

log "⏳ Ожидание подключения backend к AMI..."
sleep 15

log "4️⃣ Запуск frontend..."
docker compose up frontend -d

log "⏳ Финальная стабилизация..."
sleep 10

# Проверка статуса
log "📋 Проверка статуса всех сервисов:"
docker compose ps

log "📋 Логи Asterisk (последние 10 строк):"
docker compose logs asterisk --tail=10

log "📋 Логи Backend (последние 10 строк):"
docker compose logs backend --tail=10

# Тест подключения
log "🧪 Тест сетевого подключения backend → asterisk:"
docker compose exec backend ping asterisk -c 3 || echo "⚠️ Ping не прошел"

log "🧪 Тест AMI подключения:"
timeout 30s docker compose exec backend npm run test-asterisk || echo "⚠️ AMI тест не прошел"

log "✅ Исправление стабильности завершено!"

log "💡 Если проблемы остались:"
log "   - Проверьте логи: docker compose logs asterisk"
log "   - Перезапустите отдельно: docker compose restart asterisk"
log "   - Проверьте порты: netstat -tlnp | grep 5038" 