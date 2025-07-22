#!/bin/bash

# Тест Asterisk CLI команд
# Проверяет доступность originate и других команд

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🧪 Тестирование Asterisk CLI команд"

# Пересобрать Asterisk с обновленным modules.conf
log "🔨 Пересборка Asterisk с обновленными модулями..."
docker compose build asterisk --no-cache
docker compose up asterisk -d

# Ожидание запуска
log "⏳ Ожидание запуска Asterisk..."
sleep 10

# Проверка статуса
log "📋 Проверка статуса Asterisk..."
docker compose logs asterisk --tail=20

# Тест CLI команд
log "🧪 Тестирование CLI команд..."

echo "=== ДОСТУПНЫЕ КОМАНДЫ ==="
docker exec dialer_asterisk asterisk -r -x "core show help" | head -20

echo "=== МОДУЛИ ORIGINATE ==="
docker exec dialer_asterisk asterisk -r -x "module show like originate"

echo "=== МОДУЛИ APP ==="  
docker exec dialer_asterisk asterisk -r -x "module show like app_" | head -10

echo "=== ПОМОЩЬ ПО ORIGINATE ==="
docker exec dialer_asterisk asterisk -r -x "core show help originate" || echo "Команда originate недоступна"

echo "=== PJSIP ENDPOINTS ==="
docker exec dialer_asterisk asterisk -r -x "pjsip show endpoints"

echo "=== ТЕСТ КОМАНДЫ ECHO ==="
docker exec dialer_asterisk asterisk -r -x "core show application Echo" || echo "Echo app недоступна"

log "✅ Тестирование CLI завершено" 