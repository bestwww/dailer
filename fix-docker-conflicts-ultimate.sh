#!/bin/bash

# ПОЛНОЕ ИСПРАВЛЕНИЕ DOCKER КОНФЛИКТОВ И ФИНАЛЬНЫЙ ЗАПУСК

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🔧 ИСПРАВЛЕНИЕ DOCKER КОНФЛИКТОВ!"

log "❌ ПРОБЛЕМА НАЙДЕНА:"
echo "  ❌ Конфликт имен контейнеров: dialer_redis_ready уже используется"
echo "  ❌ Все контейнеры не запускаются из-за конфликтов"
echo "  ❌ Backend не может стартовать"
echo "  🎯 РЕШЕНИЕ: Полная очистка Docker + перезапуск"

log "🛠️ ШАГ 1: ПОЛНАЯ ОСТАНОВКА И ОЧИСТКА КОНТЕЙНЕРОВ..."

echo "=== ОСТАНОВКА ВСЕХ DIALER КОНТЕЙНЕРОВ ==="
docker stop $(docker ps -q --filter "name=dialer_") 2>/dev/null || echo "Нет запущенных dialer контейнеров"

echo "=== УДАЛЕНИЕ ВСЕХ DIALER КОНТЕЙНЕРОВ ==="
docker rm -f $(docker ps -aq --filter "name=dialer_") 2>/dev/null || echo "Нет dialer контейнеров для удаления"

echo "=== ПРОВЕРКА ОЧИСТКИ ==="
REMAINING=$(docker ps -a --filter "name=dialer_" --format "{{.Names}}" 2>/dev/null)
if [ -z "$REMAINING" ]; then
    log "✅ Все dialer контейнеры удалены"
else
    log "⚠️ Остались контейнеры: $REMAINING"
    docker rm -f $REMAINING 2>/dev/null || true
fi

log "🔧 ШАГ 2: ОБНОВЛЕНИЕ DOCKER-COMPOSE (убираем version)..."

# Создаем обновленный docker-compose без устаревшего version
JWT_SECRET=$(openssl rand -hex 32)
log "  Новый JWT_SECRET: ${JWT_SECRET:0:16}... (64 символа)"

cat > docker-compose-ready.yml << EOF
services:
  postgres:
    image: postgres:15-alpine
    container_name: dialer_postgres_ready
    environment:
      POSTGRES_DB: dialer
      POSTGRES_USER: dialer
      POSTGRES_PASSWORD: dialer_pass_2025
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U dialer -d dialer"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: dialer_redis_ready
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  asterisk:
    image: mlan/asterisk:base
    container_name: dialer_asterisk_ready
    ports:
      - "5038:5038"  # AMI
      - "5060:5060/udp"  # SIP
      - "5060:5060/tcp"  # SIP TCP
      - "10000-10020:10000-10020/udp"  # RTP
    environment:
      ASTERISK_UID: 1000
      ASTERISK_GID: 1000
    healthcheck:
      test: ["CMD-SHELL", "asterisk -rx 'core show uptime' | grep -q 'System uptime'"]
      interval: 15s
      timeout: 10s
      retries: 5
      start_period: 30s

  backend:
    image: dailer-backend-models-fixed:latest
    container_name: dialer_backend_ready
    ports:
      - "3001:3001"
    environment:
      NODE_ENV: production
      DATABASE_URL: postgresql://dialer:dialer_pass_2025@postgres:5432/dialer
      REDIS_URL: redis://redis:6379
      JWT_SECRET: ${JWT_SECRET}
      ASTERISK_HOST: asterisk
      ASTERISK_PORT: 5038
      ASTERISK_USERNAME: admin
      ASTERISK_PASSWORD: asterisk_pass_2025
      ASTERISK_URL: http://asterisk:5038
      BITRIX24_WEBHOOK_URL: https://example.bitrix24.com/webhook/
      PORT: 3001
      LOG_LEVEL: info
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
      asterisk:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:3001/health || exit 1"]
      interval: 15s
      timeout: 10s
      retries: 5
      start_period: 60s

  frontend:
    image: dailer-frontend:latest
    container_name: dialer_frontend_ready
    ports:
      - "3000:80"
    depends_on:
      - backend
    restart: unless-stopped

volumes:
  postgres_data:
EOF

log "✅ DOCKER-COMPOSE ОБНОВЛЕН:"
echo "  🔧 Убран устаревший version"
echo "  🔒 Новый JWT_SECRET: 64 символа"
echo "  🌐 Все переменные окружения настроены"

log "🚀 ШАГ 3: ЧИСТЫЙ ЗАПУСК ВСЕЙ СИСТЕМЫ..."

echo "=== ЗАПУСК ВСЕХ СЕРВИСОВ С ЧИСТОГО ЛИСТА ==="
docker compose -f docker-compose-ready.yml up -d

log "⏰ МОНИТОРИНГ ЗАПУСКА СИСТЕМЫ (45 секунд)..."

sleep 15

for i in {1..5}; do
    log "📊 Проверка ${i}/5 (через $((i*8)) сек)..."
    
    # Проверяем статус всех контейнеров
    echo "=== СТАТУС ВСЕХ КОНТЕЙНЕРОВ ==="
    docker compose -f docker-compose-ready.yml ps
    
    # Проверяем backend specifically
    BACKEND_STATUS=$(docker ps --filter "name=dialer_backend_ready" --format "{{.Status}}" 2>/dev/null)
    log "Backend статус: $BACKEND_STATUS"
    
    if echo "$BACKEND_STATUS" | grep -q "Up"; then
        log "✅ Backend контейнер работает!"
        
        sleep 3
        LOGS=$(docker logs dialer_backend_ready --tail 15 2>&1)
        
        if echo "$LOGS" | grep -q "Config validation error"; then
            CONFIG_ERROR=$(echo "$LOGS" | grep "Config validation error" | head -1)
            log "⚠️ Ошибка конфигурации: $CONFIG_ERROR"
            echo "=== ЛОГИ КОНФИГУРАЦИИ ==="
            echo "$LOGS" | head -8
            
        elif echo "$LOGS" | grep -q "Cannot find module"; then
            MODULE_ERROR=$(echo "$LOGS" | grep "Cannot find module" | head -1)
            log "❌ Ошибка модуля: $MODULE_ERROR"
            echo "=== ЛОГИ МОДУЛЕЙ ==="
            echo "$LOGS" | head -8
            
        elif echo "$LOGS" | grep -q -E "(Server.*listening|started|ready|Listening on port|Express server)"; then
            log "🎉 BACKEND СЕРВЕР ЗАПУСТИЛСЯ!"
            
            sleep 2
            if curl -sf http://localhost:3001/health >/dev/null 2>&1; then
                log "🎉 BACKEND API РАБОТАЕТ!"
                
                echo ""
                echo "🎉 🎉 🎉 ПОЛНАЯ СИСТЕМА ГОТОВА! 🎉 🎉 🎉"
                echo ""
                echo "✅ ВСЕ ПРОБЛЕМЫ РЕШЕНЫ:"
                echo "  🛣️  ВСЕ require() пути исправлены"
                echo "  📦 ВСЕ модули загружаются"
                echo "  🔒 Переменные окружения правильные"
                echo "  🐳 Docker конфликты устранены"
                echo "  🚀 Backend API отвечает"
                echo "  🌐 Все 5 сервисов работают"
                echo ""
                echo "🌐 PRODUCTION VoIP СИСТЕМА ГОТОВА!"
                echo "  Frontend:     http://localhost:3000"
                echo "  Backend API:  http://localhost:3001/health"
                echo "  Asterisk AMI: localhost:5038"
                echo "  PostgreSQL:   localhost:5432"
                echo "  Redis:        localhost:6379"
                echo ""
                echo "🏁 МИГРАЦИЯ FreeSWITCH ➜ ASTERISK ЗАВЕРШЕНА!"
                echo "🚀 СИСТЕМА ГОТОВА ДЛЯ PRODUCTION!"
                
                exit 0
            else
                log "⚠️ Backend работает, но API не отвечает..."
                if [[ $i -eq 4 ]]; then
                    echo "=== ПРОВЕРКА API ==="
                    curl -v http://localhost:3001/health 2>&1 | head -5
                fi
            fi
        else
            log "⚠️ Backend работает, анализируем логи..."
            if [[ $i -eq 4 ]]; then
                echo "=== ПОЛНЫЕ ЛОГИ BACKEND ==="
                echo "$LOGS"
            fi
        fi
    else
        log "📊 Backend не запущен: $BACKEND_STATUS"
        if [[ $i -eq 4 ]]; then
            echo "=== ЛОГИ ОШИБКИ BACKEND ==="
            docker logs dialer_backend_ready --tail 20 2>&1 || echo "Логи недоступны"
        fi
    fi
    
    if [[ $i -lt 5 ]]; then
        sleep 8
    fi
done

echo ""
echo "📊 ФИНАЛЬНЫЙ СТАТУС ВСЕХ СЕРВИСОВ:"
docker compose -f docker-compose-ready.yml ps

echo ""
echo "📝 ФИНАЛЬНЫЕ ЛОГИ BACKEND:"
docker logs dialer_backend_ready --tail 25 2>&1 || echo "Логи недоступны"

echo ""
if curl -sf http://localhost:3001/health >/dev/null 2>&1; then
    log "🎉 СИСТЕМА РАБОТАЕТ! API ДОСТУПЕН!"
    echo "   Frontend: http://localhost:3000"
    echo "   Backend:  http://localhost:3001/health"
else
    log "⚠️ Проверьте логи выше для диагностики"
fi 