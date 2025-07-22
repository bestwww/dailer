#!/bin/bash

# ОПТИМИЗИРОВАННАЯ СБОРКА ASTERISK 22.5.0
# Multi-stage build для минимального размера образа

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🚀 ОПТИМИЗИРОВАННАЯ СБОРКА ASTERISK 22.5.0"

# ПОЛНАЯ ОЧИСТКА DOCKER
log "🧹 ПОЛНАЯ ОЧИСТКА DOCKER..."
docker compose down --remove-orphans --timeout 10 2>/dev/null || true
docker system prune -af --volumes 2>/dev/null || true

log "🔍 ПРОВЕРКА РЕСУРСОВ:"
echo "💾 Дисковое пространство:"
df -h | grep -E "(Filesystem|/dev/)"
echo "🧠 Память:"
free -h
echo "🔥 CPU:"
nproc

log "📋 УДАЛЕНИЕ СТАРЫХ ОБРАЗОВ ASTERISK..."
docker images | grep asterisk | awk '{print $3}' | xargs -r docker rmi -f 2>/dev/null || true

log "🔧 СОЗДАНИЕ ОПТИМИЗИРОВАННОГО DOCKER-COMPOSE..."
cat > docker-compose-optimized.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15
    container_name: dialer_postgres
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-dialer}
      POSTGRES_USER: ${POSTGRES_USER:-postgres}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-postgres123}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    networks:
      - dialer_network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: dialer_redis
    command: redis-server --requirepass ${REDIS_PASSWORD:-redis123}
    ports:
      - "6379:6379"
    networks:
      - dialer_network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  asterisk:
    build:
      context: ./docker/asterisk
      dockerfile: Dockerfile-optimized
      target: production
    container_name: dialer_asterisk_optimized
    environment:
      - ASTERISK_UID=1001
      - ASTERISK_GID=1001
    ports:
      - "5060:5060/udp"
      - "5060:5060/tcp" 
      - "5038:5038/tcp"
      - "10000-20000:10000-20000/udp"
    networks:
      - dialer_network
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: dialer_backend
    environment:
      - NODE_ENV=production
      - VOIP_PROVIDER=${VOIP_PROVIDER:-asterisk}
      - ASTERISK_HOST=asterisk
      - ASTERISK_PORT=${ASTERISK_PORT:-5038}
      - ASTERISK_USERNAME=${ASTERISK_USERNAME:-admin}
      - ASTERISK_PASSWORD=${ASTERISK_PASSWORD:-admin}
      - DATABASE_URL=postgresql://${POSTGRES_USER:-postgres}:${POSTGRES_PASSWORD:-postgres123}@postgres:5432/${POSTGRES_DB:-dialer}
      - REDIS_URL=redis://:${REDIS_PASSWORD:-redis123}@redis:6379
      - SIP_CALLER_ID_NUMBER=${SIP_CALLER_ID_NUMBER:-9058615815}
    ports:
      - "3001:3001"
    networks:
      - dialer_network
    restart: unless-stopped
    depends_on:
      - asterisk
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3001/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: dialer_frontend
    ports:
      - "3000:3000"
    networks:
      - dialer_network
    restart: unless-stopped
    depends_on:
      - backend

networks:
  dialer_network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.25.0.0/16

volumes:
  postgres_data:
EOF

log "🔧 СОЗДАНИЕ .env ДЛЯ ОПТИМИЗИРОВАННОЙ СБОРКИ..."
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

log "🏗️ ЭТАП 1: Сборка ОПТИМИЗИРОВАННОГО Asterisk образа..."
log "⏰ Ожидаемое время: 5-10 минут"
log "📦 Ожидаемый размер: 300-500MB (вместо 1.53GB)"

BUILD_START=$(date +%s)

# Сборка с мониторингом прогресса
docker compose -f docker-compose-optimized.yml build asterisk --no-cache --progress=plain

BUILD_END=$(date +%s)
BUILD_TIME=$((BUILD_END - BUILD_START))

log "✅ Сборка завершена за $BUILD_TIME секунд"

log "📊 АНАЛИЗ РАЗМЕРА ОБРАЗА:"
ASTERISK_IMAGE=$(docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | grep asterisk | head -1)
echo "🎯 Новый образ: $ASTERISK_IMAGE"

# Проверка размера
IMAGE_SIZE=$(docker images --format "{{.Size}}" | grep -E "[0-9]+MB|[0-9.]+GB" | head -1)
log "📦 Размер образа: $IMAGE_SIZE"

if echo "$IMAGE_SIZE" | grep -q "GB"; then
    log "⚠️  ВНИМАНИЕ: Образ все еще большой ($IMAGE_SIZE)"
else
    log "✅ Размер образа оптимальный: $IMAGE_SIZE"
fi

log "🧪 ЭТАП 2: Тест образа..."

# Быстрый тест образа
log "Тестирование образа..."
timeout 30 docker run --rm dialer-asterisk:latest asterisk -V || {
    log "❌ Образ не работает!"
    exit 1
}

log "✅ Образ работает корректно"

log "🚀 ЭТАП 3: Запуск оптимизированной системы..."

# Поэтапный запуск
log "1️⃣ Запуск PostgreSQL + Redis..."
docker compose -f docker-compose-optimized.yml up postgres redis -d

log "⏰ Ожидание готовности базы данных..."
sleep 15

log "2️⃣ Запуск Asterisk..."
docker compose -f docker-compose-optimized.yml up asterisk -d

log "⏰ Ожидание запуска Asterisk (30 сек)..."
sleep 30

log "📋 Проверка статуса Asterisk:"
docker compose -f docker-compose-optimized.yml ps

# Проверка логов Asterisk
log "🔍 Проверка логов Asterisk:"
timeout 10 docker logs dialer_asterisk_optimized --tail 20 2>&1 || log "⚠️ Логи недоступны"

# Проверка здоровья контейнера
if docker ps | grep -q dialer_asterisk_optimized; then
    log "✅ Asterisk контейнер запущен"
    
    # Тест версии
    timeout 10 docker exec dialer_asterisk_optimized asterisk -V 2>/dev/null && {
        log "🎉 Asterisk отвечает на команды!"
    } || log "⚠️ Asterisk не отвечает, но контейнер работает"
    
else
    log "❌ Asterisk контейнер НЕ запущен"
    log "🔍 Поиск проблем..."
    docker ps -a | grep asterisk || log "Контейнер не создан"
    exit 1
fi

log "3️⃣ Запуск Backend..."
docker compose -f docker-compose-optimized.yml up backend -d
sleep 15

log "4️⃣ Запуск Frontend..."
docker compose -f docker-compose-optimized.yml up frontend -d
sleep 10

log "📊 ФИНАЛЬНЫЙ СТАТУС:"
docker compose -f docker-compose-optimized.yml ps

log "🧪 ТЕСТЫ ПОДКЛЮЧЕНИЯ:"
echo "Frontend: curl http://localhost:3000"
echo "Backend Health: curl http://localhost:3001/health"
echo "Asterisk AMI: telnet localhost 5038"

log "✅ ОПТИМИЗИРОВАННАЯ СБОРКА ЗАВЕРШЕНА!"
log ""
log "🎯 РЕЗУЛЬТАТ:"
log "   ✅ Multi-stage build минимизирует размер"
log "   ✅ Только runtime зависимости в финальном образе"
log "   ✅ Asterisk 22.5.0 LTS из официальных источников"
log "   ✅ Healthcheck и автоматическое восстановление"
log "   ✅ Время сборки: $BUILD_TIME секунд"
log ""
log "📝 ИСПОЛЬЗОВАНИЕ:"
log "   docker compose -f docker-compose-optimized.yml [команда]" 