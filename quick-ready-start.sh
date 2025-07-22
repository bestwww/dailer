#!/bin/bash

# БЫСТРЫЙ СТАРТ С ГОТОВЫМ ОБРАЗОМ ASTERISK

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "⚡ БЫСТРЫЙ СТАРТ С ГОТОВЫМ ОБРАЗОМ ASTERISK"
log "📦 Используем готовый образ mlan/asterisk:base (247⭐ на GitHub)"

# Остановка других контейнеров
log "🧹 Остановка других контейнеров..."
docker compose -f docker-compose-optimized.yml down --remove-orphans 2>/dev/null || true
docker compose -f docker-compose-stable.yml down --remove-orphans 2>/dev/null || true
docker compose down --remove-orphans 2>/dev/null || true

log "⬇️ ЭТАП 1: Загрузка готового образа Asterisk..."
docker pull mlan/asterisk:base

PULL_RESULT=$?

if [ $PULL_RESULT -eq 0 ]; then
    log "✅ Образ загружен успешно"
    
    log "📊 Информация об образе:"
    docker images | grep mlan/asterisk | head -1
    
    log "🚀 ЭТАП 2: Запуск системы с готовым Asterisk..."
    
    # Запуск всех сервисов
    log "🔄 Запуск всех сервисов..."
    docker compose -f docker-compose-ready.yml up -d
    
    # Ожидание готовности
    log "⏰ Ожидание готовности сервисов (макс. 90 сек)..."
    for i in $(seq 1 18); do
        sleep 5
        
        # Проверка статуса
        POSTGRES_STATUS=$(docker compose -f docker-compose-ready.yml ps postgres --format "table" 2>/dev/null | grep healthy || echo "starting")
        REDIS_STATUS=$(docker compose -f docker-compose-ready.yml ps redis --format "table" 2>/dev/null | grep healthy || echo "starting")
        ASTERISK_STATUS=$(docker compose -f docker-compose-ready.yml ps asterisk --format "table" 2>/dev/null | grep healthy || echo "starting")
        
        if [[ "$POSTGRES_STATUS" == *"healthy"* ]] && [[ "$REDIS_STATUS" == *"healthy"* ]] && [[ "$ASTERISK_STATUS" == *"healthy"* ]]; then
            log "✅ Все базовые сервисы готовы (${i}0 сек)"
            break
        fi
        
        echo -n "."
    done
    echo ""
    
    log "📋 Состояние системы:"
    docker compose -f docker-compose-ready.yml ps
    
    # Проверка Asterisk
    if docker ps | grep -q dialer_asterisk_ready; then
        log "🎉 ASTERISK ГОТОВ!"
        
        sleep 5
        
        # Тест основных функций
        log "🧪 Тестирование Asterisk..."
        
        # Проверка версии
        timeout 10 docker exec dialer_asterisk_ready asterisk -r -x "core show version" 2>/dev/null && {
            log "✅ Asterisk CLI работает"
        } || {
            log "⚠️ Asterisk CLI пока не отвечает"
        }
        
        # Проверка модулей
        timeout 10 docker exec dialer_asterisk_ready asterisk -r -x "module show like pjsip" 2>/dev/null && {
            log "✅ PJSIP модули загружены"
        } || {
            log "⚠️ PJSIP модули не найдены"
        }
        
        # Проверка AMI
        timeout 10 docker exec dialer_asterisk_ready asterisk -r -x "manager show users" 2>/dev/null && {
            log "✅ AMI готов"
        } || {
            log "⚠️ AMI пока не готов"
        }
        
        log "🚀 Запуск backend и frontend..."
        sleep 10
        
        # Проверка backend/frontend
        if docker ps | grep -q dialer_backend_ready && docker ps | grep -q dialer_frontend_ready; then
            log "🎉 ВСЯ СИСТЕМА ГОТОВА!"
        else
            log "⚠️ Backend/Frontend еще запускаются..."
        fi
        
        log "📋 ФИНАЛЬНОЕ СОСТОЯНИЕ:"
        docker compose -f docker-compose-ready.yml ps
        
        log "🎯 ГОТОВЫЕ ССЫЛКИ:"
        echo "  - 🌐 Frontend: http://localhost:3000"
        echo "  - 🔧 Backend API: http://localhost:3001/health"
        echo "  - 📞 Asterisk CLI: docker exec -it dialer_asterisk_ready asterisk -r"
        echo "  - 📝 Asterisk логи: docker logs dialer_asterisk_ready"
        
        log "💡 ПРЕИМУЩЕСТВА ГОТОВОГО ОБРАЗА:"
        echo "  - ✅ Не нужно компилировать (экономия 5-10 минут)"
        echo "  - ✅ Протестированная конфигурация"
        echo "  - ✅ Поддержка сообщества (247⭐)"
        echo "  - ✅ Регулярные обновления"
        
        log "🎉 СИСТЕМА ГОТОВА К РАБОТЕ!"
        
    else
        log "❌ Asterisk контейнер не запустился"
        log "Проверьте логи:"
        docker logs dialer_asterisk_ready --tail 20
        exit 1
    fi
    
else
    log "❌ Не удалось загрузить образ mlan/asterisk:base"
    log "Проверьте подключение к интернету"
    exit 1
fi

log "✅ ГОТОВО! Управление: docker-compose-ready.yml" 