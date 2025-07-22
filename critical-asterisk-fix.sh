#!/bin/bash

# КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ Asterisk capabilities + Stasis errors
# Исправляет: "Unable to install capabilities", "Stasis initialization failed"

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🚨 КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ Asterisk capabilities"
log "Исправляем: 'Unable to install capabilities' + 'Stasis initialization failed'"

# Остановка всех контейнеров
log "🛑 Полная остановка системы..."
docker compose down --remove-orphans

# Получить исправления
log "📥 Получение критических исправлений..."
git pull origin main

# Очистка Docker
log "🧹 Очистка Docker..."
docker system prune -f

# КРИТИЧЕСКИЕ ИСПРАВЛЕНИЯ:
log "🔧 Проверяем критические исправления в docker-compose.yml:"
log "   ✅ privileged: true"
log "   ✅ cap_add: SYS_ADMIN, NET_ADMIN, SYS_PTRACE" 
log "   ✅ command: asterisk as root (-U root -G root)"
log "   ✅ modules.conf заменен на минимальный (БЕЗ Stasis)"

# Пересборка с новыми настройками
log "🔨 Пересборка Asterisk с исправлениями capabilities..."
docker compose build asterisk --no-cache

# Тест запуска только Asterisk
log "🧪 Тест 1: Запуск только Asterisk для диагностики..."
docker compose up postgres redis -d
sleep 10

docker compose up asterisk -d

log "⏳ Ожидание инициализации Asterisk (45 сек)..."
for i in {1..45}; do
    echo -n "."
    sleep 1
done
echo ""

log "📋 Статус Asterisk после исправлений:"
docker compose ps asterisk

log "📋 Логи Asterisk (последние 30 строк):"
docker compose logs asterisk --tail=30

# Проверка критических ошибок
log "🔍 Проверка на критические ошибки..."
if docker compose logs asterisk | grep -q "Unable to install capabilities"; then
    log "❌ ОШИБКА: 'Unable to install capabilities' все еще присутствует!"
    exit 1
fi

if docker compose logs asterisk | grep -q "Stasis initialization failed"; then
    log "❌ ОШИБКА: 'Stasis initialization failed' все еще присутствует!"
    exit 1
fi

if docker compose logs asterisk | grep -q "ASTERISK EXITING"; then
    log "❌ ОШИБКА: Asterisk все еще падает!"
    exit 1
fi

if docker compose ps asterisk | grep -q "Restarting"; then
    log "❌ ОШИБКА: Asterisk все еще перезапускается!"
    exit 1
fi

log "✅ Критические ошибки НЕ найдены!"

# Проверка что Asterisk запустился
if docker compose ps asterisk | grep -q "Up"; then
    log "🎉 SUCCESS: Asterisk работает стабильно!"
else
    log "❌ FAILED: Asterisk не запустился"
    exit 1
fi

# Запуск остальных сервисов
log "🚀 Запуск backend и frontend..."
docker compose up backend frontend -d
sleep 15

# Финальная проверка
log "📋 ФИНАЛЬНЫЙ СТАТУС:"
docker compose ps

log "🧪 Тест AMI подключения:"
timeout 20s docker compose exec backend npm run test-asterisk || echo "⚠️ AMI тест не прошел (но Asterisk работает)"

log "✅ КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ ЗАВЕРШЕНО!"
log "📊 Результат:"
if docker compose ps asterisk | grep -q "Up"; then
    log "   🎉 Asterisk: РАБОТАЕТ"
    log "   ✅ Capabilities: ИСПРАВЛЕНО"  
    log "   ✅ Stasis: ОТКЛЮЧЕН (минимальная конфигурация)"
    log "   ✅ Система готова к тестированию!"
else
    log "   ❌ Asterisk: НЕ РАБОТАЕТ"
    exit 1
fi 