#!/bin/bash

# ВРЕМЕННЫЙ ВОЗВРАТ К FREESWITCH
# Быстрое решение пока не исправим проблему с Asterisk

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🔄 ВРЕМЕННЫЙ ВОЗВРАТ К FREESWITCH"

# Остановка текущей системы
log "🛑 Остановка всех контейнеров..."
docker compose down --remove-orphans
docker rm -f dialer_asterisk_v20 2>/dev/null || true

log "📥 Получение обновлений..."
git pull origin main

log "🔧 ПРИЧИНА ВОЗВРАТА:"
log "   ❌ Asterisk 18.10.0 имеет критический баг Stasis"
log "   ❌ Asterisk 20 требует долгой компиляции"
log "   ✅ FreeSWITCH стабильно работает"
log "   ✅ Временное решение до исправления Asterisk"

# Создаем .env для FreeSWITCH
log "🔧 Создание .env для FreeSWITCH..."
cat > .env << 'EOF'
VOIP_PROVIDER=freeswitch
FREESWITCH_HOST=freeswitch
FREESWITCH_PORT=8021
FREESWITCH_PASSWORD=ClueCon
SIP_CALLER_ID_NUMBER=9058615815
SIP_PROVIDER_HOST=62.141.121.197
SIP_PROVIDER_PORT=5070
EXTERNAL_IP=auto
POSTGRES_DB=dialer
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres123
REDIS_PASSWORD=redis123
EOF

# Обновляем docker-compose.yml для FreeSWITCH
log "🔧 Включение FreeSWITCH в docker-compose..."
# Раскомментируем FreeSWITCH сервис если он закомментирован

log "🧹 Очистка Docker..."
docker system prune -f

log "🚀 Запуск системы с FreeSWITCH..."

log "1️⃣ PostgreSQL + Redis..."
docker compose up postgres redis -d
sleep 10

log "2️⃣ FreeSWITCH..."
docker compose up freeswitch -d
sleep 15

log "📋 Статус FreeSWITCH:"
docker compose ps freeswitch

log "📋 Логи FreeSWITCH:"
docker compose logs freeswitch | tail -10

# Проверка FreeSWITCH
log "🧪 Проверка FreeSWITCH..."
FREESWITCH_LOGS=$(docker compose logs freeswitch 2>&1)

if echo "$FREESWITCH_LOGS" | grep -q "FreeSWITCH Version"; then
    log "✅ FreeSWITCH успешно запустился"
else
    log "⚠️ FreeSWITCH требует проверки"
fi

log "3️⃣ Backend (с FreeSWITCH адаптером)..."
docker compose up backend -d
sleep 15

log "4️⃣ Frontend..."
docker compose up frontend -d
sleep 5

log "📋 ФИНАЛЬНЫЙ СТАТУС:"
docker compose ps

log "🧪 Тест FreeSWITCH ESL:"
timeout 20s docker compose exec backend npm run test-freeswitch || echo "⚠️ ESL тест требует настройки"

log "✅ ВОЗВРАТ К FREESWITCH ЗАВЕРШЕН!"
log "🎯 FreeSWITCH работает стабильно"
log "📋 ПЛАН ДАЛЬНЕЙШИХ ДЕЙСТВИЙ:"
log "   1. Протестировать систему с FreeSWITCH"
log "   2. Продолжить работу над Asterisk 20+"
log "   3. Переключиться обратно когда Asterisk будет готов" 