#!/bin/bash

# ГЛУБОКАЯ ДИАГНОСТИКА BACKEND - НАЙТИ ВСЕ ОШИБКИ

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🔍 ГЛУБОКАЯ ДИАГНОСТИКА BACKEND"

log "✅ ПРОГРЕСС:"
echo "  ✅ Кавычки исправлены: require(\"./config\")"
echo "  ✅ Синтаксис проверен: запускается без ошибок"
echo "  ✅ Образ создан: dailer-backend-final-victory:latest"
echo "  ❌ Backend контейнер НЕ появляется в docker ps"

log "🔍 ШАГ 1: ДЕТАЛЬНЫЙ АНАЛИЗ ФАЙЛОВ..."

# Извлекаем исправленные файлы
TEMP_CONTAINER="temp_deep_debug"
docker create --name $TEMP_CONTAINER dailer-backend-final-victory:latest
docker cp $TEMP_CONTAINER:/app/dist ./temp_dist_debug
docker rm $TEMP_CONTAINER

log "  Анализируем содержимое dist папки..."
echo "=== СТРУКТУРА DIST ==="
find temp_dist_debug -type f -name "*.js" | head -10

log "  Проверяем app.js детально..."
echo "=== ПЕРВЫЕ 25 СТРОК app.js ==="
head -25 temp_dist_debug/app.js

log "  Проверяем все require() в app.js..."
echo "=== ВСЕ REQUIRE В app.js ==="
grep -n "require(" temp_dist_debug/app.js | head -10

log "  Ищем возможные проблемы в коде..."
echo "=== ПОИСК ПОДОЗРИТЕЛЬНЫХ КОНСТРУКЦИЙ ==="
grep -n -E "(undefined|null|error|Error)" temp_dist_debug/app.js | head -5 || echo "Нет подозрительных конструкций"

log "🧪 ШАГ 2: ИНТЕРАКТИВНАЯ ДИАГНОСТИКА..."

echo "=== ТЕСТ 1: ПРОВЕРКА NODE ВЕРСИИ В КОНТЕЙНЕРЕ ==="
docker run --rm dailer-backend-final-victory:latest node --version

echo ""
echo "=== ТЕСТ 2: ПРОВЕРКА ФАЙЛОВОЙ СИСТЕМЫ ==="
docker run --rm dailer-backend-final-victory:latest ls -la /app/

echo ""
echo "=== ТЕСТ 3: ПРОВЕРКА DIST ДИРЕКТОРИИ ==="
docker run --rm dailer-backend-final-victory:latest ls -la /app/dist/ | head -5

echo ""
echo "=== ТЕСТ 4: ПОПЫТКА ЗАПУСКА С МАКСИМАЛЬНЫМИ ЛОГАМИ ==="
log "  Запуск с NODE_DEBUG=* для максимальной диагностики..."

DETAILED_OUTPUT=$(docker run --rm \
    --network dialer-ready_dialer_network \
    -e NODE_ENV=production \
    -e NODE_DEBUG=* \
    -e DATABASE_URL=postgresql://dialer:dialer_pass_2025@postgres:5432/dialer \
    -e REDIS_URL=redis://redis:6379 \
    -e ASTERISK_URL=ami://admin:dailer_admin_2025@asterisk:5038 \
    -e JWT_SECRET=2ffe1d3e9df1ffe8e07a5c2940b8d2c56e8280b9bf42965027b5605e5cfe11c2 \
    dailer-backend-final-victory:latest \
    timeout 8 node --trace-warnings --trace-uncaught dist/app.js 2>&1 || echo "TIMEOUT_OR_ERROR")

echo "=== РЕЗУЛЬТАТ ДЕТАЛЬНОГО ЗАПУСКА ==="
echo "$DETAILED_OUTPUT" | head -30

if echo "$DETAILED_OUTPUT" | grep -q "Error\|error"; then
    log "❌ НАЙДЕНЫ ОШИБКИ В ДЕТАЛЬНОМ ЗАПУСКЕ:"
    echo "$DETAILED_OUTPUT" | grep -A 5 -B 5 -i "error"
fi

if echo "$DETAILED_OUTPUT" | grep -q "Cannot find module"; then
    log "❌ МОДУЛИ НЕ НАЙДЕНЫ:"
    echo "$DETAILED_OUTPUT" | grep -A 3 -B 3 "Cannot find module"
fi

if echo "$DETAILED_OUTPUT" | grep -q "SyntaxError"; then
    log "❌ ВСЁ ЕЩЁ СИНТАКСИЧЕСКИЕ ОШИБКИ:"
    echo "$DETAILED_OUTPUT" | grep -A 5 -B 5 "SyntaxError"
fi

echo ""
echo "=== ТЕСТ 5: ПОПЫТКА ЗАПУСКА БЕЗ ПЕРЕМЕННЫХ ==="
log "  Запуск без переменных окружения для проверки базовых ошибок..."

BASIC_OUTPUT=$(docker run --rm \
    dailer-backend-final-victory:latest \
    timeout 3 node dist/app.js 2>&1 || echo "TIMEOUT_OR_ERROR")

echo "=== РЕЗУЛЬТАТ БАЗОВОГО ЗАПУСКА ==="
echo "$BASIC_OUTPUT"

echo ""
echo "=== ТЕСТ 6: ПРОВЕРКА PACKAGE.JSON И ЗАВИСИМОСТЕЙ ==="
docker run --rm dailer-backend-final-victory:latest cat package.json | head -20 || echo "package.json недоступен"

echo ""
echo "=== ТЕСТ 7: ПРОВЕРКА NODE_MODULES ==="
docker run --rm dailer-backend-final-victory:latest ls /app/node_modules | head -10 || echo "node_modules недоступны"

log "🔧 ШАГ 3: АНАЛИЗ DOCKER COMPOSE..."

echo "=== КОНФИГУРАЦИЯ BACKEND В COMPOSE ==="
grep -A 15 -B 5 "backend:" docker-compose-ready.yml

echo ""
echo "=== ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ В COMPOSE ==="
grep -A 10 "environment:" docker-compose-ready.yml | grep -E "(DATABASE_URL|REDIS_URL|ASTERISK_URL|JWT_SECRET)"

log "🚀 ШАГ 4: ПОПЫТКА РУЧНОГО ЗАПУСКА ЧЕРЕЗ COMPOSE..."

log "  Запуск backend с логами в реальном времени..."
echo "=== COMPOSE LOGS В РЕАЛЬНОМ ВРЕМЕНИ ==="

# Запускаем backend и показываем логи
docker compose -f docker-compose-ready.yml up -d backend

sleep 3

# Получаем логи в реальном времени на 10 секунд
timeout 10 docker compose -f docker-compose-ready.yml logs -f backend || echo "TIMEOUT_LOGS"

echo ""
echo "=== СТАТУС ПОСЛЕ РУЧНОГО ЗАПУСКА ==="
docker compose -f docker-compose-ready.yml ps

log "🔍 ШАГ 5: ФИНАЛЬНАЯ ДИАГНОСТИКА..."

echo ""
echo "📊 Статус всех контейнеров:"
docker ps -a --filter "name=dialer_" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"

echo ""
echo "📝 Последняя попытка получить логи backend:"
docker logs dialer_backend_ready --tail 50 2>&1 || echo "Логи недоступны - контейнер мгновенно падает"

echo ""
echo "🔧 Проверка образа на наличие файлов:"
docker run --rm dailer-backend-final-victory:latest find /app -name "*.js" | head -5

# Очистка
rm -rf temp_dist_debug

echo ""
log "⚠️ ИТОГ ГЛУБОКОЙ ДИАГНОСТИКИ ЗАВЕРШЁН"
echo ""
echo "📋 СЛЕДУЮЩИЕ ШАГИ:"
echo "  1. Проанализировать найденные ошибки выше"
echo "  2. Исправить корневую причину"
echo "  3. Создать финальный рабочий образ"
echo "  4. Запустить полную систему"
echo ""
echo "🎯 ЦЕЛЬ: Найти и устранить причину мгновенного краша backend" 