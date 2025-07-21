#!/bin/bash

# Скрипт для диагностики Docker контейнеров системы автодозвона
# Автор: AI Assistant
# Дата: $(date '+%Y-%m-%d')

echo "==============================================="
echo "🔍 ДИАГНОСТИКА DOCKER КОНТЕЙНЕРОВ"
echo "==============================================="

echo ""
echo "📊 1. СТАТУС ВСЕХ КОНТЕЙНЕРОВ:"
echo "-----------------------------------------------"
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}"

echo ""
echo "📈 2. ИСПОЛЬЗОВАНИЕ РЕСУРСОВ:"
echo "-----------------------------------------------"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"

echo ""
echo "🏥 3. HEALTH CHECK СТАТУСЫ:"
echo "-----------------------------------------------"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(healthy|unhealthy|starting)"

echo ""
echo "🌐 4. СЕТИ И ПОРТЫ:"
echo "-----------------------------------------------"
echo "Активные порты на хосте:"
netstat -tulpn 2>/dev/null | grep -E ":(3000|5173|5432|6379|5060|8021)" || ss -tulpn | grep -E ":(3000|5173|5432|6379|5060|8021)"

echo ""
echo "Docker сети:"
docker network ls

echo ""
echo "==============================================="
echo "📋 ПОСЛЕДНИЕ ЛОГИ ПО СЕРВИСАМ"
echo "==============================================="

# Функция для показа логов сервиса
show_service_logs() {
    local service=$1
    local lines=${2:-50}
    
    echo ""
    echo "📝 ЛОГИ $service (последние $lines строк):"
    echo "-----------------------------------------------"
    
    if docker ps -q -f name="dialer_$service" | grep -q .; then
        docker logs --tail $lines dialer_$service 2>&1 | tail -20
        echo "... (показаны последние 20 строк из $lines)"
    else
        echo "❌ Контейнер dialer_$service не найден или не запущен"
    fi
}

# Показываем логи основных сервисов
show_service_logs "backend" 100
show_service_logs "frontend" 100
show_service_logs "postgres" 50
show_service_logs "redis" 50
show_service_logs "freeswitch" 50

echo ""
echo "==============================================="
echo "🔧 ПОЛЕЗНЫЕ КОМАНДЫ ДЛЯ ДИАГНОСТИКИ"
echo "==============================================="
echo ""
echo "Для подробного просмотра логов используйте:"
echo "docker logs -f dialer_backend     # Логи бэкенда в реальном времени"
echo "docker logs -f dialer_frontend    # Логи фронтенда в реальном времени"
echo "docker logs --tail 200 dialer_backend  # Последние 200 строк бэкенда"
echo ""
echo "Для перезапуска сервисов:"
echo "docker restart dialer_backend"
echo "docker restart dialer_frontend"
echo "docker-compose restart backend frontend"
echo ""
echo "Для проверки состояния compose:"
echo "docker-compose ps"
echo "docker-compose logs -f backend frontend"
echo ""
echo "Для входа в контейнер (отладка):"
echo "docker exec -it dialer_backend bash"
echo "docker exec -it dialer_frontend sh"
echo ""
echo "Для проверки подключений к базе:"
echo "docker exec -it dialer_postgres psql -U dialer_user -d dialer_db -c '\\l'"

echo ""
echo "==============================================="
echo "✅ ДИАГНОСТИКА ЗАВЕРШЕНА"
echo "===============================================" 