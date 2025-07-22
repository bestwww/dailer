#!/bin/bash

# БЫСТРОЕ ИСПРАВЛЕНИЕ ПРОБЛЕМ СО СТАБИЛЬНЫМ ASTERISK

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🔧 ИСПРАВЛЕНИЕ ПРОБЛЕМ СО СТАБИЛЬНЫМ ASTERISK"

# Остановить проблемный контейнер
log "🛑 Остановка проблемного Asterisk контейнера..."
docker compose -f docker-compose-stable.yml stop asterisk 2>/dev/null || true
docker rm dialer_asterisk_stable 2>/dev/null || true

# Удалить поврежденный образ
log "🧹 Удаление поврежденного образа..."
docker rmi dailer-asterisk-stable:latest 2>/dev/null || true

log "📋 ПРОБЛЕМЫ И ИСПРАВЛЕНИЯ:"
echo "  ❌ libasteriskssl.so.1 отсутствовала"
echo "  ✅ Добавлено копирование shared libraries"
echo "  ❌ backend/tests директория отсутствовала"  
echo "  ✅ Создана backend/tests с базовыми файлами"

log "🏗️ ПЕРЕСБОРКА ТОЛЬКО ASTERISK ОБРАЗА..."
docker compose -f docker-compose-stable.yml build asterisk --no-cache

BUILD_RESULT=$?

if [ $BUILD_RESULT -eq 0 ]; then
    log "🎉 ПЕРЕСБОРКА УСПЕШНА!"
    
    log "📊 Новый размер образа:"
    docker images | grep "dailer-asterisk-stable" | head -1
    
    log "🧪 Тест исправленного образа..."
    timeout 15 docker run --rm dailer-asterisk-stable:latest asterisk -V && {
        log "✅ Asterisk РАБОТАЕТ! Проблема с библиотеками исправлена"
    } || {
        log "❌ Все еще есть проблемы с запуском"
        exit 1
    }
    
    log "🚀 Запуск исправленного Asterisk..."
    docker compose -f docker-compose-stable.yml up asterisk -d
    
    # Мониторинг запуска
    log "⏰ Мониторинг запуска (60 сек)..."
    for i in $(seq 1 12); do
        sleep 5
        
        # Проверка статуса контейнера
        if docker ps | grep -q "dialer_asterisk_stable.*Up"; then
            log "✅ Asterisk запущен и работает! (${i}0 сек)"
            
            # Дополнительные тесты
            sleep 10
            
            log "🧪 Тестирование функций..."
            
            # Тест CLI
            timeout 10 docker exec dialer_asterisk_stable asterisk -r -x "core show version" 2>/dev/null && {
                log "✅ Asterisk CLI работает"
            } || {
                log "⚠️ CLI пока не отвечает"
            }
            
            # Тест AMI  
            timeout 10 docker exec dialer_asterisk_stable asterisk -r -x "manager show users" 2>/dev/null && {
                log "✅ AMI готов"
            } || {
                log "⚠️ AMI пока не готов"
            }
            
            # Тест модулей
            timeout 10 docker exec dialer_asterisk_stable asterisk -r -x "module show" 2>/dev/null | wc -l | {
                read count
                if [ "$count" -gt 10 ]; then
                    log "✅ Модули загружены ($count модулей)"
                else
                    log "⚠️ Мало модулей загружено ($count)"
                fi
            }
            
            log "📋 Статус системы:"
            docker compose -f docker-compose-stable.yml ps
            
            log "🎉 ASTERISK ИСПРАВЛЕН И РАБОТАЕТ!"
            log "Теперь можно запускать backend и frontend:"
            echo "  docker compose -f docker-compose-stable.yml up backend frontend -d"
            
            exit 0
        elif docker ps -a | grep -q "dialer_asterisk_stable.*Exited"; then
            log "❌ Контейнер остановился"
            break
        elif docker ps -a | grep -q "dialer_asterisk_stable.*Restarting"; then
            log "⚠️ Контейнер перезапускается... (попытка ${i})"
        else
            log "⚠️ Ожидание запуска... (${i}0 сек)"
        fi
    done
    
    # Если дошли сюда - проблемы остались
    log "❌ Asterisk все еще не запускается корректно"
    log "Логи контейнера:"
    docker logs dialer_asterisk_stable --tail 20
    
    log "🔍 Диагностика:"
    echo "1. Проверьте логи: docker logs dialer_asterisk_stable"
    echo "2. Попробуйте интерактивный запуск: docker run -it --rm dailer-asterisk-stable:latest bash"
    echo "3. Проверьте библиотеки: docker run --rm dailer-asterisk-stable:latest ldd /usr/sbin/asterisk"
    
    exit 1
    
else
    log "❌ ПЕРЕСБОРКА НЕ УДАЛАСЬ"
    log "Проверьте логи сборки выше"
    exit 1
fi 