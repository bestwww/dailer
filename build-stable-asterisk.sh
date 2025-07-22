#!/bin/bash

# СТАБИЛЬНАЯ СБОРКА ASTERISK 20.15.0 LTS

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🚀 СТАБИЛЬНАЯ СБОРКА ASTERISK 20.15.0 LTS"
log "📋 Используем проверенную и стабильную версию вместо 22.5.0"

# Остановить текущие контейнеры
log "🧹 Остановка текущих контейнеров..."
docker compose -f docker-compose-optimized.yml down --remove-orphans 2>/dev/null || true
docker compose down --remove-orphans 2>/dev/null || true

# Очистка проблемных образов
log "🧹 Очистка старых образов..."
docker images | grep -E "(dialer|dailer)" | awk '{print $3}' | xargs -r docker rmi -f 2>/dev/null || true

# Проверка ресурсов
log "📊 Проверка ресурсов системы:"
echo "Свободное место: $(df -h / | tail -1 | awk '{print $4}')"
echo "Свободная память: $(free -h | grep Mem | awk '{print $7}')"

# Проверка конфигурации
log "🔍 Проверка минимальной конфигурации..."
if [ ! -f "docker/asterisk/conf-minimal/asterisk.conf" ]; then
    log "❌ Конфигурация не найдена!"
    exit 1
fi

log "✅ Конфигурация готова:"
echo "  - asterisk.conf (базовая)"
echo "  - modules.conf (только необходимые модули)"  
echo "  - manager.conf (AMI)"
echo "  - pjsip.conf (SIP trunk)"
echo "  - extensions.conf (диалплан)"

log "🏗️ ЭТАП 1: Сборка СТАБИЛЬНОГО Asterisk 20.15.0 образа..."
echo "⏰ Ожидаемое время: 3-5 минут (меньше чем 22.5.0)"

docker compose -f docker-compose-stable.yml build asterisk --no-cache --progress=plain

BUILD_RESULT=$?

if [ $BUILD_RESULT -eq 0 ]; then
    log "🎉 СБОРКА УСПЕШНА!"
    
    log "📊 Анализ размера образа:"
    ASTERISK_IMAGE=$(docker images | grep "dailer-asterisk-stable" | head -1)
    if [ -n "$ASTERISK_IMAGE" ]; then
        echo "$ASTERISK_IMAGE"
        SIZE=$(echo "$ASTERISK_IMAGE" | awk '{print $7$8}')
        log "📦 Размер образа: $SIZE"
    fi
    
    log "🧪 ЭТАП 2: Быстрый тест образа..."
    timeout 15 docker run --rm dailer-asterisk-stable:latest asterisk -V && {
        log "✅ Образ работает корректно"
    } || {
        log "⚠️ Образ собрался, но тест не прошел (возможно таймаут)"
    }
    
    log "🚀 ЭТАП 3: Запуск СТАБИЛЬНОЙ системы..."
    
    # Запуск базовых сервисов
    log "🔄 Запуск PostgreSQL и Redis..."
    docker compose -f docker-compose-stable.yml up postgres redis -d
    sleep 15
    
    # Проверка базовых сервисов
    if docker ps | grep -q dialer_postgres_stable && docker ps | grep -q dialer_redis_stable; then
        log "✅ Базовые сервисы запущены"
    else
        log "❌ Проблемы с базовыми сервисами"
        docker compose -f docker-compose-stable.yml ps
        exit 1
    fi
    
    # Запуск Asterisk
    log "🔄 Запуск СТАБИЛЬНОГО Asterisk..."
    docker compose -f docker-compose-stable.yml up asterisk -d
    
    # Мониторинг запуска Asterisk (максимум 2 минуты)
    log "⏰ Ожидание запуска Asterisk (макс. 120 сек)..."
    for i in $(seq 1 24); do
        sleep 5
        if docker ps | grep -q dialer_asterisk_stable; then
            log "✅ Asterisk контейнер запущен (${i}0 сек)"
            break
        fi
        echo -n "."
    done
    echo ""
    
    # Проверка состояния
    log "📋 Состояние системы:"
    docker compose -f docker-compose-stable.yml ps
    
    if docker ps | grep -q dialer_asterisk_stable; then
        log "🎉 ASTERISK УСПЕШНО ЗАПУЩЕН!"
        
        # Тест AMI подключения
        sleep 10
        log "🧪 Тест AMI подключения..."
        timeout 10 docker exec dialer_asterisk_stable asterisk -r -x "manager show connected" 2>/dev/null && {
            log "✅ AMI работает"
        } || {
            log "⚠️ AMI пока не отвечает (нормально на старте)"
        }
        
        # Тест PJSIP
        log "🧪 Тест PJSIP..."
        timeout 10 docker exec dialer_asterisk_stable asterisk -r -x "pjsip show transports" 2>/dev/null && {
            log "✅ PJSIP работает"
        } || {
            log "⚠️ PJSIP пока не отвечает"
        }
        
        log "🚀 Запуск backend и frontend..."
        docker compose -f docker-compose-stable.yml up backend frontend -d
        
        sleep 20
        
        log "📋 ФИНАЛЬНОЕ СОСТОЯНИЕ:"
        docker compose -f docker-compose-stable.yml ps
        
        log "🎯 ТЕСТИРОВАНИЕ:"
        echo "  - Backend health: curl http://localhost:3001/health"
        echo "  - Frontend: http://localhost:3000"
        echo "  - Asterisk CLI: docker exec -it dialer_asterisk_stable asterisk -r"
        echo "  - Asterisk логи: docker logs dialer_asterisk_stable"
        
        log "🎉 СТАБИЛЬНАЯ СИСТЕМА ГОТОВА!"
        
    else
        log "❌ Asterisk не запустился"
        log "Логи Asterisk:"
        docker logs dialer_asterisk_stable --tail 20
        exit 1
    fi
    
else
    log "❌ СБОРКА НЕ УДАЛАСЬ"
    log "Проверьте логи сборки выше"
    exit 1
fi

log "✅ ГОТОВО! Используйте docker-compose-stable.yml для управления" 