#!/bin/bash

# ОТЛАДКА ЗАПУСКА ASTERISK

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🔍 ДИАГНОСТИКА ПРОБЛЕМ ЗАПУСКА ASTERISK"

# Остановить зависший контейнер
log "🛑 Остановка зависшего контейнера..."
docker compose -f docker-compose-official.yml stop asterisk 2>/dev/null || true
docker rm dialer_asterisk_official 2>/dev/null || true

log "📋 Информация о собранном образе:"
docker images | grep asterisk || echo "Образ не найден"

log "🧪 ТЕСТ 1: Запуск Asterisk в интерактивном режиме"
echo "Проверим что происходит при запуске..."

# Временный запуск для диагностики
docker run --rm --name asterisk_debug \
    --network dailer_dialer_network \
    -e ASTERISK_UID=1001 \
    -e ASTERISK_GID=1001 \
    dailer-asterisk:latest \
    /bin/bash -c "
        echo '=== ПРОВЕРКА ПОЛЬЗОВАТЕЛЯ ==='
        whoami
        id
        
        echo '=== ПРОВЕРКА ДИРЕКТОРИЙ ==='
        ls -la /etc/asterisk/ | head -5
        ls -la /var/lib/asterisk/
        
        echo '=== ПРОВЕРКА ASTERISK BINARY ==='
        which asterisk
        asterisk -V
        
        echo '=== ТЕСТ ЗАПУСКА (без демона) ==='
        timeout 15 asterisk -f -c -vvv || echo 'TIMEOUT или ОШИБКА'
    " &

DOCKER_PID=$!
sleep 20
kill $DOCKER_PID 2>/dev/null || true

log "🧪 ТЕСТ 2: Проверка конфигурации"

# Проверка конфигурации
docker run --rm --name asterisk_config_check \
    --network dailer_dialer_network \
    dailer-asterisk:latest \
    /bin/bash -c "
        echo '=== ПРОВЕРКА ОСНОВНЫХ КОНФИГОВ ==='
        [ -f /etc/asterisk/asterisk.conf ] && echo '✅ asterisk.conf' || echo '❌ asterisk.conf'
        [ -f /etc/asterisk/manager.conf ] && echo '✅ manager.conf' || echo '❌ manager.conf'
        [ -f /etc/asterisk/pjsip.conf ] && echo '✅ pjsip.conf' || echo '❌ pjsip.conf'
        [ -f /etc/asterisk/extensions.conf ] && echo '✅ extensions.conf' || echo '❌ extensions.conf'
        
        echo '=== ПРАВА НА ФАЙЛЫ ==='
        ls -la /etc/asterisk/ | grep -E '\\.conf$' | head -5
    "

log "🧪 ТЕСТ 3: Минимальный запуск"

# Попробуем запустить с минимальной конфигурацией
log "Запуск с упрощенной командой..."
docker run -d --name asterisk_simple_test \
    --network dailer_dialer_network \
    -p 5038:5038 \
    dailer-asterisk:latest \
    asterisk -f -c &

sleep 10

log "📋 Проверка простого запуска:"
docker logs asterisk_simple_test --tail 20
docker ps | grep asterisk_simple_test

log "🧹 Очистка тестовых контейнеров..."
docker stop asterisk_simple_test 2>/dev/null || true
docker rm asterisk_simple_test 2>/dev/null || true

log "✅ ДИАГНОСТИКА ЗАВЕРШЕНА"
log ""
log "📝 РЕЗУЛЬТАТЫ ПОКАЖУТ:"
log "   🔍 Какая именно ошибка при запуске"
log "   🔍 Проблемы с правами или конфигурацией"  
log "   🔍 Работает ли Asterisk вообще в контейнере" 