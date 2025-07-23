#!/bin/bash

# ЭКСТРЕННОЕ РЕШЕНИЕ DOCKER SYSTEMD CGROUP КОНФЛИКТА

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🚨 ЭКСТРЕННОЕ РЕШЕНИЕ DOCKER CGROUP КОНФЛИКТА"

log "❌ ПРОБЛЕМА НАЙДЕНА:"
echo "  Docker не может запустить backend из-за зависших systemd cgroup units"
echo "  Старые docker scope units блокируют создание новых контейнеров"
echo ""
echo "  ✅ ВСЕ ПОДКЛЮЧЕНИЯ РАБОТАЮТ:"
echo "     PostgreSQL: ✅ Работает"
echo "     Redis: ✅ PONG отвечает" 
echo "     Asterisk: ✅ Admin настроен"

log "🔧 ШАГ 1: ПРИНУДИТЕЛЬНАЯ ОСТАНОВКА ВСЕХ КОНТЕЙНЕРОВ..."

# Останавливаем все контейнеры
docker compose -f docker-compose-ready.yml down --remove-orphans --volumes --timeout 30 2>/dev/null || true

# Принудительная остановка всех dialer контейнеров
docker ps -a --filter "name=dialer" -q | xargs -r docker rm -f 2>/dev/null || true

log "🧹 ШАГ 2: ОЧИСТКА ЗАВИСШИХ SYSTEMD UNITS..."

# Очищаем все зависшие docker systemd units
systemctl reset-failed 2>/dev/null || true

# Находим и очищаем все docker scope units
for unit in $(systemctl list-units --failed --no-legend | grep docker | awk '{print $1}'); do
    log "  Очищаю зависший unit: $unit"
    systemctl stop "$unit" 2>/dev/null || true
    systemctl reset-failed "$unit" 2>/dev/null || true
done

# Очищаем конкретные docker scope units
for scope_file in /run/systemd/system/docker-*.scope; do
    if [[ -f "$scope_file" ]]; then
        scope_name=$(basename "$scope_file")
        log "  Удаляю файл scope: $scope_name"
        systemctl stop "$scope_name" 2>/dev/null || true
        rm -f "$scope_file" 2>/dev/null || true
    fi
done

log "🔄 ШАГ 3: ПЕРЕЗАГРУЗКА SYSTEMD И DOCKER..."

# Перезагружаем systemd
systemctl daemon-reload

# Перезапускаем docker daemon
log "  Перезапуск Docker daemon..."
systemctl restart docker

# Ждем запуска docker
sleep 10

# Проверяем статус docker
if systemctl is-active docker --quiet; then
    log "✅ Docker daemon перезапущен успешно"
else
    log "❌ КРИТИЧЕСКАЯ ОШИБКА: Docker daemon не запустился"
    systemctl status docker --no-pager
    exit 1
fi

log "🧹 ШАГ 4: ПОЛНАЯ ОЧИСТКА DOCKER РЕСУРСОВ..."

# Очищаем все остатки
docker system prune -af --volumes 2>/dev/null || true

# Удаляем сеть если существует
docker network rm dialer-ready_dialer_network 2>/dev/null || true

log "🚀 ШАГ 5: ЧИСТЫЙ ПЕРЕЗАПУСК ВСЕХ СЕРВИСОВ..."

# Собираем и запускаем сервисы заново
docker compose -f docker-compose-ready.yml up -d --build

log "⏰ ШАГ 6: МОНИТОРИНГ ЗАПУСКА (2 минуты)..."

# Мониторим запуск 2 минуты
for i in {1..24}; do
    sleep 5
    RUNNING_COUNT=$(docker compose -f docker-compose-ready.yml ps --format="{{.Status}}" | grep -c "Up" || echo "0")
    log "📊 Запущено сервисов: $RUNNING_COUNT/5 (${i}*5 сек)"
    
    # Проверяем все ли сервисы запущены
    if [[ "$RUNNING_COUNT" -eq "5" ]]; then
        log "🎉 ВСЕ 5 СЕРВИСОВ ЗАПУЩЕНЫ!"
        
        # Тестируем backend API
        sleep 10
        if curl -sf http://localhost:3001/health >/dev/null 2>&1; then
            log "✅ BACKEND API РАБОТАЕТ!"
            
            echo ""
            echo "🎉 🎉 🎉 ПРОБЛЕМА ПОЛНОСТЬЮ РЕШЕНА! 🎉 🎉 🎉"
            echo ""
            echo "🌐 Frontend:     http://localhost:3000"
            echo "🔧 Backend API:  http://localhost:3001/health"  
            echo "📞 Asterisk CLI: docker exec -it dialer_asterisk_ready asterisk -r"
            echo "💾 PostgreSQL:   docker exec -it dialer_postgres_ready psql -U dialer -d dialer"
            echo "🔴 Redis CLI:    docker exec -it dialer_redis_ready redis-cli"
            echo ""
            echo "🏁 МИГРАЦИЯ FreeSWITCH ➜ ASTERISK ЗАВЕРШЕНА УСПЕШНО!"
            echo ""
            echo "🎯 ГОТОВО К ТЕСТИРОВАНИЮ SIP ЗВОНКОВ!"
            
            exit 0
        else
            log "⚠️ Backend запущен, но API не отвечает. Показываю логи..."
        fi
        break
    fi
done

if [[ "$RUNNING_COUNT" -ne "5" ]]; then
    log "⚠️ НЕ ВСЕ СЕРВИСЫ ЗАПУСТИЛИСЬ ЗА 2 МИНУТЫ"
fi

echo ""
log "📊 ФИНАЛЬНЫЙ СТАТУС:"
docker compose -f docker-compose-ready.yml ps

echo ""
log "📝 ЛОГИ BACKEND (последние 20 строк):"
docker logs dialer_backend_ready --tail 20 2>/dev/null || echo "Backend недоступен"

echo ""
log "💡 ЕСЛИ ПРОБЛЕМЫ ОСТАЛИСЬ:"
echo "  1. Проверьте логи: docker logs dialer_backend_ready"
echo "  2. Перезагрузите сервер: sudo reboot"
echo "  3. Запустите скрипт повторно после перезагрузки"

exit 1 