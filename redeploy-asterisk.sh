#!/bin/bash

# Быстрый пересборка и деплой Asterisk
# Исправляет проблемы с modules.conf и AsteriskManager

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🔄 Быстрый редеплой Asterisk с исправлениями"

# Остановка всех контейнеров
log "🛑 Остановка существующих контейнеров..."
docker compose down --remove-orphans 2>/dev/null || true

# Удаление старых образов
log "🗑️ Удаление старых образов..."
docker rmi dialer-asterisk dialer-backend 2>/dev/null || true

# Пересборка только необходимых образов
log "🔨 Пересборка Asterisk (с modules.conf)..."
docker compose build asterisk

log "🔨 Пересборка Backend (с исправленным AsteriskManager)..."
docker compose build backend

# Запуск системы
log "🚀 Запуск системы..."
docker compose up -d

# Проверка статуса
log "⏳ Ожидание запуска..."
sleep 15

log "📋 Статус контейнеров:"
docker compose ps

log "📋 Логи Asterisk:"
docker compose logs asterisk --tail=20

log "📋 Логи Backend:"
docker compose logs backend --tail=20

log "✅ Редеплой завершен! Проверьте логи выше." 