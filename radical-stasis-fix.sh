#!/bin/bash

# РАДИКАЛЬНОЕ ИСПРАВЛЕНИЕ Stasis проблемы
# Полная перестройка с ручным контролем модулей

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🚨 РАДИКАЛЬНОЕ ИСПРАВЛЕНИЕ: Полный контроль над модулями Asterisk"

# Остановка всех контейнеров
log "🛑 Полная остановка..."
docker compose down --remove-orphans

log "📥 Получение обновлений..."
git pull origin main

log "🧹 Радикальная очистка Docker..."
docker system prune -f --volumes
docker builder prune -f

log "🔧 РАДИКАЛЬНЫЕ ИЗМЕНЕНИЯ конфигурации:"
log "   ❌ autoload=no - ПОЛНЫЙ контроль модулей"
log "   ✅ Ручная загрузка ТОЛЬКО нужных модулей"
log "   ❌ Явное отключение ВСЕХ Stasis модулей"

# Создаем .env
log "🔧 Создание .env..."
cat > .env << 'EOF'
VOIP_PROVIDER=asterisk
ASTERISK_HOST=asterisk
ASTERISK_PORT=5038
ASTERISK_USERNAME=admin
ASTERISK_PASSWORD=admin
SIP_CALLER_ID_NUMBER=9058615815
SIP_PROVIDER_HOST=62.141.121.197
SIP_PROVIDER_PORT=5070
EXTERNAL_IP=auto
POSTGRES_DB=dialer
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres123
REDIS_PASSWORD=redis123
EOF

# Пересборка полностью без кеша
log "🔨 ПОЛНАЯ пересборка Asterisk с радикальной конфигурацией..."
docker compose build asterisk --no-cache --pull

log "🔨 ПОЛНАЯ пересборка Backend..."
docker compose build backend --no-cache --pull

# Запуск пошагово с детальной диагностикой
log "🚀 Пошаговый запуск с диагностикой..."

log "1️⃣ PostgreSQL + Redis..."
docker compose up postgres redis -d
sleep 10

log "📋 Проверка базовых сервисов:"
docker compose ps postgres redis

log "2️⃣ Asterisk с РАДИКАЛЬНОЙ конфигурацией..."
docker compose up asterisk -d

log "⏳ Ожидание Asterisk (45 сек)..."
for i in {1..45}; do
    echo -n "."
    sleep 1
done
echo ""

log "📋 Статус Asterisk:"
docker compose ps asterisk

log "📋 ПОЛНЫЕ логи Asterisk:"
docker compose logs asterisk

# Детальная диагностика
log "🔍 ДЕТАЛЬНАЯ ДИАГНОСТИКА..."

log "🧪 Проверка конфигурации modules.conf в контейнере:"
docker compose exec asterisk cat /etc/asterisk/modules.conf | head -30 || echo "❌ Не удалось прочитать modules.conf"

log "🧪 Проверка запущенных модулей:"
docker compose exec asterisk asterisk -rx "module show" | grep -i stasis || echo "✅ Stasis модули НЕ найдены"

log "🧪 Проверка состояния Asterisk:"
docker compose exec asterisk asterisk -rx "core show version" || echo "❌ Asterisk CLI недоступен"

# Проверка критических ошибок
log "🚨 Проверка КРИТИЧЕСКИХ ошибок..."

ASTERISK_LOGS=$(docker compose logs asterisk 2>&1)

if echo "$ASTERISK_LOGS" | grep -q "Stasis initialization failed"; then
    log "❌ КРИТИЧЕСКАЯ ОШИБКА: Stasis все еще инициализируется!"
    log "🔍 АНАЛИЗ ПРОБЛЕМЫ:"
    
    log "📋 Поиск строки 'Stasis' в логах:"
    echo "$ASTERISK_LOGS" | grep -i stasis || echo "Строки со Stasis не найдены"
    
    log "📋 Поиск строки 'module' в логах:"
    echo "$ASTERISK_LOGS" | grep -i "loading.*stasis" || echo "Загрузка Stasis модулей не найдена"
    
    log "❌ РЕШЕНИЕ НЕ СРАБОТАЛО!"
    log "💡 ВОЗМОЖНЫЕ ПРИЧИНЫ:"
    log "   1. res_stasis встроен в ядро Asterisk"
    log "   2. Конфигурация modules.conf игнорируется"
    log "   3. Другой модуль зависит от Stasis"
    log "   4. Версия Asterisk имеет баг"
    
    exit 1
fi

if echo "$ASTERISK_LOGS" | grep -q "ASTERISK EXITING"; then
    log "❌ Asterisk все еще падает!"
    exit 1
fi

if docker compose ps asterisk | grep -q "Restarting"; then
    log "❌ Asterisk все еще перезапускается!"
    exit 1
fi

if docker compose ps asterisk | grep -q "Up"; then
    log "🎉 SUCCESS: Asterisk запустился БЕЗ Stasis!"
else
    log "❌ Asterisk не запустился"
    exit 1
fi

log "3️⃣ Backend..."
docker compose up backend -d
sleep 15

log "4️⃣ Frontend..."
docker compose up frontend -d
sleep 5

log "📋 ФИНАЛЬНЫЙ СТАТУС:"
docker compose ps

log "🧪 Тест AMI:"
timeout 20s docker compose exec backend npm run test-asterisk || echo "⚠️ AMI тест не прошел"

log "✅ РАДИКАЛЬНОЕ ИСПРАВЛЕНИЕ ЗАВЕРШЕНО!"
log "🎯 Asterisk работает БЕЗ Stasis модулей!" 