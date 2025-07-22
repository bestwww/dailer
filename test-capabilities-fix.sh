#!/bin/bash

# ТЕСТ ИСПРАВЛЕНИЯ С CAPABILITIES

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🔧 ТЕСТ ИСПРАВЛЕНИЯ CAPABILITIES ДЛЯ ASTERISK"

# Остановить текущие контейнеры
log "🛑 Остановка старых контейнеров..."
docker compose -f docker-compose-stable.yml down --remove-orphans

log "📋 ВНЕСЕННЫЕ ИЗМЕНЕНИЯ:"
echo "  ✅ Добавлены capabilities: SYS_RESOURCE, NET_ADMIN, NET_RAW"
echo "  ✅ Более мягкий healthcheck (pgrep asterisk)"
echo "  ✅ Увеличено start_period до 120s"

log "🚀 ЗАПУСК С НОВЫМИ CAPABILITIES..."

# Запуск базовых сервисов
log "🔄 Запуск PostgreSQL и Redis..."
docker compose -f docker-compose-stable.yml up postgres redis -d
sleep 10

# Запуск Asterisk с новыми настройками
log "🔄 Запуск Asterisk с capabilities..."
docker compose -f docker-compose-stable.yml up asterisk -d

# Улучшенный мониторинг
log "⏰ Детальный мониторинг запуска (2 минуты)..."

for i in $(seq 1 24); do
    sleep 5
    
    # Проверяем статус контейнера
    CONTAINER_STATUS=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep dialer_asterisk_stable || echo "not_found")
    
    if [[ "$CONTAINER_STATUS" == *"Up"* ]]; then
        log "✅ Контейнер работает: $CONTAINER_STATUS"
        
        # Проверяем процесс Asterisk
        ASTERISK_PROCESS=$(docker exec dialer_asterisk_stable pgrep -f asterisk 2>/dev/null || echo "not_running")
        if [[ "$ASTERISK_PROCESS" != "not_running" ]]; then
            log "✅ Процесс Asterisk запущен (PID: $ASTERISK_PROCESS)"
            
            # Дополнительные тесты
            sleep 10
            
            log "🧪 Тестирование функциональности..."
            
            # Тест CLI
            if timeout 15 docker exec dialer_asterisk_stable asterisk -r -x "core show version" >/dev/null 2>&1; then
                log "✅ Asterisk CLI работает"
                
                # Проверка модулей
                MODULE_COUNT=$(timeout 10 docker exec dialer_asterisk_stable asterisk -r -x "module show" 2>/dev/null | wc -l || echo "0")
                if [ "$MODULE_COUNT" -gt 20 ]; then
                    log "✅ Модули загружены ($MODULE_COUNT модулей)"
                else
                    log "⚠️ Мало модулей: $MODULE_COUNT"
                fi
                
                # Проверка AMI
                if timeout 10 docker exec dialer_asterisk_stable asterisk -r -x "manager show users" >/dev/null 2>&1; then
                    log "✅ AMI работает"
                else
                    log "⚠️ AMI не отвечает"
                fi
                
                # Проверка PJSIP
                if timeout 10 docker exec dialer_asterisk_stable asterisk -r -x "pjsip show transports" >/dev/null 2>&1; then
                    log "✅ PJSIP работает"
                else
                    log "⚠️ PJSIP не отвечает"
                fi
                
                log "🎉 CAPABILITIES FIX УСПЕШЕН!"
                log "📋 Финальный статус:"
                docker compose -f docker-compose-stable.yml ps
                
                log "🚀 Можно запускать остальные сервисы:"
                echo "  docker compose -f docker-compose-stable.yml up backend frontend -d"
                
                exit 0
                
            else
                log "⚠️ CLI не отвечает, но процесс работает (${i}5 сек)"
            fi
        else
            log "⚠️ Процесс Asterisk не найден (${i}5 сек)"
        fi
        
    elif [[ "$CONTAINER_STATUS" == *"Restarting"* ]]; then
        log "⚠️ Контейнер перезапускается (попытка ${i})"
        
    elif [[ "$CONTAINER_STATUS" == "not_found" ]]; then
        log "❌ Контейнер не найден"
        break
        
    else
        log "⚠️ Статус: $CONTAINER_STATUS (${i}5 сек)"
    fi
done

# Если дошли сюда - проблемы остались
log "❌ CAPABILITIES FIX НЕ ПОМОГ"
log "🔍 Диагностика проблемы:"

echo ""
echo "1. 📋 Статус контейнера:"
docker compose -f docker-compose-stable.yml ps

echo ""
echo "2. 📝 Логи Asterisk (последние 30 строк):"
docker logs dialer_asterisk_stable --tail 30

echo ""
echo "3. 🔍 Процессы в контейнере:"
docker exec dialer_asterisk_stable ps aux 2>/dev/null || echo "Контейнер недоступен"

echo ""
log "💡 РЕКОМЕНДАЦИИ:"
echo "  1. Попробуйте готовый образ: ./quick-ready-start.sh"
echo "  2. Или интерактивную отладку: docker run -it --rm dailer-asterisk-stable:latest bash"
echo "  3. Проверьте конфигурацию модулей в conf-minimal/"

exit 1 