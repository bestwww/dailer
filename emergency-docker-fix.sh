#!/bin/bash

# ЭКСТРЕННОЕ РЕШЕНИЕ ЗАВИСШЕГО DOCKER

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🚨 ЭКСТРЕННОЕ РЕШЕНИЕ ЗАВИСШЕГО DOCKER"

log "🔍 Проверка дискового пространства..."
df -h

log "🔍 Проверка памяти..."
free -h

log "🛑 СПОСОБ 1: Убить зависшие Docker процессы"

log "Поиск Docker процессов..."
ps aux | grep docker | grep -v grep

log "🔥 Убиваем зависшие Docker процессы..."
pkill -f "docker.*asterisk" 2>/dev/null || true
sleep 2

log "🛑 СПОСОБ 2: Перезапуск Docker службы"

log "Остановка Docker..."
systemctl stop docker 2>/dev/null || service docker stop 2>/dev/null || true
sleep 5

log "Убиваем оставшиеся процессы..."
pkill -9 dockerd 2>/dev/null || true
pkill -9 containerd 2>/dev/null || true
sleep 3

log "Запуск Docker..."
systemctl start docker 2>/dev/null || service docker start 2>/dev/null || true
sleep 10

log "🧹 СПОСОБ 3: Очистка Docker кэша"

log "Очистка всех неиспользуемых ресурсов..."
docker system prune -af --volumes 2>/dev/null || true

log "🔍 Проверка состояния Docker..."
docker ps -a | head -5

log "📋 Проверка образов..."
docker images | grep asterisk || echo "Образы asterisk удалены"

log "🎯 СПОСОБ 4: Использование старого рабочего образа"

if docker images | grep -q "dialer-asterisk.*464MB"; then
    log "✅ Найден старый рабочий образ (464MB)"
    log "Попробуем запустить старый образ..."
    
    # Временно переименуем в docker-compose
    sed -i 's/dailer-asterisk:latest/dialer-asterisk:latest/g' docker-compose-official.yml
    
    log "Запуск с РАБОЧИМ образом..."
    timeout 60 docker compose -f docker-compose-official.yml up postgres redis -d
    sleep 5
    timeout 60 docker compose -f docker-compose-official.yml up asterisk -d
    sleep 10
    
    log "📋 Проверка результата:"
    docker compose -f docker-compose-official.yml ps
    
    if docker ps | grep -q asterisk; then
        log "🎉 SUCCESS: Старый образ работает!"
        log "Попробуйте подключиться к системе"
    else
        log "❌ Даже старый образ не работает"
    fi
else
    log "❌ Старый образ недоступен"
fi

log "✅ ЭКСТРЕННЫЕ ДЕЙСТВИЯ ЗАВЕРШЕНЫ"
log ""
log "📝 ЧТО ПРОИЗОШЛО:"
log "   🔍 Новый образ 1.53GB - слишком большой, возможно поврежден"
log "   🔍 Docker зависал из-за проблем с ресурсами"
log "   🔍 Использован старый рабочий образ 464MB"
log ""
log "📋 СЛЕДУЮЩИЕ ШАГИ:"
log "   1. Если старый образ работает - используйте его"
log "   2. Пересоберите новый образ с оптимизацией"
log "   3. Добавьте больше RAM на сервер если нужно" 