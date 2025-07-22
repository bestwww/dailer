#!/bin/bash

# ЭКСТРЕННОЕ ИСПРАВЛЕНИЕ Asterisk - убираем profiles и исправляем VOIP_PROVIDER
# Решает проблемы: profiles, command, VOIP_PROVIDER

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🚨 ЭКСТРЕННОЕ ИСПРАВЛЕНИЕ Asterisk"
log "Проблемы: profiles блокирует запуск, VOIP_PROVIDER=freeswitch вместо asterisk"

# Остановка всех контейнеров
log "🛑 Остановка системы..."
docker compose down --remove-orphans

# Получить последние исправления из Git
log "📥 Получение исправлений из Git..."
git pull origin main

# Форсированное создание .env с правильными настройками
log "⚙️ Создание .env с принудительными настройками для Asterisk..."
cat > .env << EOF
# ===================
# ПРИНУДИТЕЛЬНО ASTERISK 
# ===================
VOIP_PROVIDER=asterisk

# Asterisk AMI настройки
ASTERISK_HOST=asterisk
ASTERISK_PORT=5038
ASTERISK_USERNAME=admin
ASTERISK_PASSWORD=admin

# SIP Trunk настройки
SIP_PROVIDER_HOST=62.141.121.197
SIP_PROVIDER_PORT=5070
SIP_CALLER_ID_NUMBER=9058615815

# Остальные настройки
NODE_ENV=development
PORT=3000
DATABASE_URL=postgresql://dialer_user:secure_password_123@postgres:5432/dialer_db
REDIS_URL=redis://:redis_password_123@redis:6379
JWT_SECRET=e556e588ee21e16ed4485a2c94149363ec8c85c881801895ecce9d786d41084e445fca510a8cf7d6fe771e65d956e23d1e0b40b6b82029b1920bb034c17a5149
TZ=Europe/Moscow
EXTERNAL_IP=auto
EOF

log "✅ .env файл создан с принудительными настройками"

# Очистка Docker
log "🧹 Очистка Docker..."
docker system prune -f

# Пересборка образов
log "🔨 Пересборка образов с исправлениями..."
docker compose build asterisk backend --no-cache

# Поэтапный запуск с диагностикой
log "🚀 Запуск с диагностикой..."

log "1️⃣ Базовые сервисы..."
docker compose up postgres redis -d
sleep 10

log "2️⃣ Asterisk (с исправлениями)..."
docker compose up asterisk -d

log "⏳ Ожидание стабилизации Asterisk (30 сек)..."
sleep 30

log "📋 Статус Asterisk:"
docker compose ps asterisk

log "📋 Логи Asterisk (последние 20 строк):"
docker compose logs asterisk --tail=20

# Проверяем что Asterisk не перезапускается
log "🔍 Проверка стабильности Asterisk..."
sleep 10
if docker compose ps asterisk | grep -q "Restarting"; then
    log "❌ Asterisk все еще перезапускается!"
    log "📋 Детальные логи Asterisk:"
    docker compose logs asterisk --tail=50
    exit 1
else
    log "✅ Asterisk стабилен!"
fi

log "3️⃣ Backend (должен подключиться к Asterisk)..."
docker compose up backend -d
sleep 15

log "📋 Логи Backend (ищем подключение к Asterisk):"
docker compose logs backend --tail=20 | grep -i asterisk || echo "Логи Asterisk не найдены"

log "4️⃣ Frontend..."
docker compose up frontend -d
sleep 5

# Финальная проверка
log "📋 ФИНАЛЬНЫЙ СТАТУС:"
docker compose ps

log "🧪 Тест подключения backend → asterisk:"
docker compose exec backend ping asterisk -c 2 || echo "❌ Ping не прошел"

log "🧪 Тест AMI (краткий):"
timeout 15s docker compose exec backend npm run test-asterisk || echo "❌ AMI тест не прошел"

log "✅ Экстренное исправление завершено!"

if docker compose ps asterisk | grep -q "Up"; then
    log "🎉 SUCCESS: Asterisk работает!"
else
    log "❌ FAILED: Asterisk все еще проблемный"
    exit 1
fi 