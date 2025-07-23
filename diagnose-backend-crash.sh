#!/bin/bash

# ДЕТАЛЬНАЯ ДИАГНОСТИКА RUNTIME КРАША BACKEND

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🔍 ДЕТАЛЬНАЯ ДИАГНОСТИКА RUNTIME КРАША BACKEND"

log "✅ ПРОГРЕСС:"
echo "  🔧 Docker cgroup конфликт РЕШЕН"
echo "  🚀 Все образы пересобраны"
echo "  🌐 4/5 сервисов работают"
echo ""
echo "❌ НОВАЯ ПРОБЛЕМА:"
echo "  Backend стартует, но сразу падает от runtime ошибки"

echo ""
log "🔍 ШАГ 1: ТОЧНЫЙ СТАТУС BACKEND КОНТЕЙНЕРА..."

# Проверяем статус backend
BACKEND_STATUS=$(docker ps -a --filter "name=dialer_backend_ready" --format "table {{.Names}}\t{{.Status}}\t{{.ExitCode}}")
echo "$BACKEND_STATUS"

echo ""
log "📝 ШАГ 2: ПОЛНЫЕ ЛОГИ BACKEND..."

# Получаем все логи backend
echo "=== ВСЕ ЛОГИ BACKEND КОНТЕЙНЕРА ==="
docker logs dialer_backend_ready 2>&1 || echo "Логи недоступны"

echo ""
echo "=== ЛОГИ DOCKER COMPOSE ==="
docker compose -f docker-compose-ready.yml logs backend 2>&1 || echo "Compose логи недоступны"

echo ""
log "🔧 ШАГ 3: ПРОВЕРКА ПЕРЕМЕННЫХ ОКРУЖЕНИЯ..."

echo "=== ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ BACKEND ==="
docker run --rm dailer-backend:latest printenv | grep -E "(NODE_ENV|DB_|REDIS_|ASTERISK_|VOIP_)" | sort

echo ""
log "🔌 ШАГ 4: ПРОВЕРКА ДОСТУПНОСТИ СЕРВИСОВ..."

echo "=== ТЕСТ ПОДКЛЮЧЕНИЙ ==="

# Тест PostgreSQL с backend сетью
echo "PostgreSQL:"
if docker run --rm --network dialer-ready_dialer_network postgres:15-alpine psql -h postgres -U dialer -d dialer -c "SELECT 'PostgreSQL подключение работает';" 2>/dev/null; then
    echo "✅ PostgreSQL доступен из backend сети"
else
    echo "❌ PostgreSQL недоступен из backend сети"
fi

# Тест Redis с backend сетью
echo ""
echo "Redis:"
if docker run --rm --network dialer-ready_dialer_network redis:7-alpine redis-cli -h redis ping 2>/dev/null; then
    echo "✅ Redis доступен из backend сети"
else
    echo "❌ Redis недоступен из backend сети"
fi

# Тест Asterisk AMI
echo ""
echo "Asterisk AMI:"
if timeout 5 docker run --rm --network dialer-ready_dialer_network alpine/curl:latest -s telnet://asterisk:5038 >/dev/null 2>&1; then
    echo "✅ Asterisk AMI порт 5038 доступен"
else
    echo "❌ Asterisk AMI порт 5038 недоступен"
fi

echo ""
log "🚀 ШАГ 5: ПОПЫТКА РУЧНОГО ЗАПУСКА BACKEND..."

echo "=== РУЧНОЙ ЗАПУСК BACKEND В ОТЛАДОЧНОМ РЕЖИМЕ ==="

# Запускаем backend в интерактивном режиме для получения детальных ошибок
docker run --rm -it \
    --network dialer-ready_dialer_network \
    --env-file <(docker inspect dialer_backend_ready 2>/dev/null | jq -r '.[0].Config.Env[]' 2>/dev/null || echo "NODE_ENV=production") \
    -e NODE_ENV=production \
    -e DB_HOST=postgres \
    -e DB_PORT=5432 \
    -e DB_NAME=dialer \
    -e DB_USER=dialer \
    -e DB_PASSWORD=dialer_pass_2025 \
    -e REDIS_HOST=redis \
    -e REDIS_PORT=6379 \
    -e ASTERISK_HOST=asterisk \
    -e ASTERISK_PORT=5038 \
    -e ASTERISK_USERNAME=admin \
    -e ASTERISK_PASSWORD=dailer_admin_2025 \
    -e VOIP_PROVIDER=asterisk \
    dailer-backend:latest \
    sh -c "echo '🔍 ПРОВЕРКА СТРУКТУРЫ:' && ls -la && echo '' && echo '🔍 ПРОВЕРКА DIST:' && ls -la dist/ && echo '' && echo '🔍 ЗАПУСК NODE:' && node dist/app.js"

echo ""
log "💡 ШАГ 6: АЛЬТЕРНАТИВНЫЕ ВАРИАНТЫ ДИАГНОСТИКИ..."

echo ""
echo "🔧 ЕСЛИ РУЧНОЙ ЗАПУСК НЕ УДАЛСЯ, ПОПРОБУЙТЕ:"
echo ""
echo "1. 📝 ИНТЕРАКТИВНЫЙ SHELL:"
echo "   docker run --rm -it --network dialer-ready_dialer_network dailer-backend:latest sh"
echo "   # Внутри контейнера:"
echo "   # node dist/app.js"
echo ""
echo "2. 🔍 ПРОВЕРКА PACKAGE.JSON:"
echo "   docker run --rm dailer-backend:latest cat package.json"
echo ""
echo "3. 🔧 ПРОВЕРКА МИГРАЦИЙ БД:"
echo "   docker run --rm --network dialer-ready_dialer_network \\"
echo "     -e DB_HOST=postgres -e DB_USER=dialer -e DB_PASSWORD=dialer_pass_2025 \\"
echo "     dailer-backend:latest node dist/scripts/check-db.js"
echo ""
echo "4. 🚀 ПРИНУДИТЕЛЬНЫЙ RESTART:"
echo "   docker compose -f docker-compose-ready.yml up -d backend --force-recreate"

echo ""
log "🎯 ВОЗМОЖНЫЕ RUNTIME ПРИЧИНЫ:"
echo ""
echo "1. 🗃️ БАЗА ДАННЫХ:"
echo "   - Отсутствующие таблицы"
echo "   - Неудачные миграции"
echo "   - Неправильные права доступа"
echo ""
echo "2. 🔌 ПОДКЛЮЧЕНИЯ:"
echo "   - Asterisk AMI аутентификация"
echo "   - Redis подключение"
echo "   - Некорректные хосты/порты"
echo ""
echo "3. 🐛 КОД:"
echo "   - Необработанные Promise rejections"
echo "   - Ошибки инициализации сервисов"
echo "   - Отсутствующие модули"
echo ""
echo "4. 🏗️ КОНФИГУРАЦИЯ:"
echo "   - Неправильные переменные окружения"
echo "   - Отсутствующие директории"
echo "   - Проблемы с правами файлов"

exit 0 