#!/bin/bash

# УЛЬТРА-ГЛУБОКАЯ ДИАГНОСТИКА RUNTIME КРАША BACKEND

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🔍 УЛЬТРА-ГЛУБОКАЯ ДИАГНОСТИКА RUNTIME КРАША"

log "✅ ПОДТВЕРЖДЕННЫЙ ПРОГРЕСС:"
echo "  ✅ voip-provider-factory.js существует и исправлен"
echo "  ✅ Тест без переменных: DATABASE_URL required (модули работают)"
echo "  ✅ Docker cgroup конфликты устранены"
echo "  ✅ 4/5 сервисов работают (postgres, redis, asterisk, frontend)"
echo "  ❌ Backend контейнер НЕ появляется в docker ps при запуске с переменными"

log "🔍 ШАГ 1: ДЕТАЛЬНЫЙ АНАЛИЗ RUNTIME ОШИБОК..."

# Извлекаем финальную версию dist
TEMP_CONTAINER="temp_runtime_debug"
docker create --name $TEMP_CONTAINER dailer-backend-modules-fixed:latest
docker cp $TEMP_CONTAINER:/app/dist ./temp_dist_runtime
docker rm $TEMP_CONTAINER

log "  Анализируем воспроизводимость ошибки..."

echo "=== ТЕСТ 1: ВОСПРОИЗВЕДЕНИЕ ОШИБКИ БЕЗ ПЕРЕМЕННЫХ ==="
BASIC_OUTPUT=$(docker run --rm dailer-backend-modules-fixed:latest timeout 5 node dist/app.js 2>&1 || echo "TIMEOUT_OR_ERROR")
echo "$BASIC_OUTPUT" | head -5

if echo "$BASIC_OUTPUT" | grep -q "DATABASE_URL.*required"; then
    log "✅ БЕЗ ПЕРЕМЕННЫХ: Модули загружаются, нужны только переменные"
else
    log "❌ БЕЗ ПЕРЕМЕННЫХ: Есть другие проблемы"
    echo "$BASIC_OUTPUT"
fi

echo ""
echo "=== ТЕСТ 2: ЗАПУСК С ПОЛНЫМИ ПЕРЕМЕННЫМИ ==="
log "  Точно воспроизводим ошибку docker-compose..."

FULL_ENV_OUTPUT=$(docker run --rm \
    --network dialer-ready_dialer_network \
    -e NODE_ENV=production \
    -e DATABASE_URL=postgresql://dialer:dialer_pass_2025@postgres:5432/dialer \
    -e REDIS_URL=redis://redis:6379 \
    -e ASTERISK_URL=ami://admin:dailer_admin_2025@asterisk:5038 \
    -e JWT_SECRET=2ffe1d3e9df1ffe8e07a5c2940b8d2c56e8280b9bf42965027b5605e5cfe11c2 \
    -e JWT_EXPIRES_IN=24h \
    -e LOG_LEVEL=info \
    -e VOIP_PROVIDER=asterisk \
    dailer-backend-modules-fixed:latest \
    timeout 10 node --trace-warnings --trace-uncaught --enable-source-maps dist/app.js 2>&1 || echo "TIMEOUT_OR_ERROR")

echo "=== РЕЗУЛЬТАТ С ПОЛНЫМИ ПЕРЕМЕННЫМИ ==="
echo "$FULL_ENV_OUTPUT" | head -20

if echo "$FULL_ENV_OUTPUT" | grep -q "Error\|error\|Error:"; then
    log "❌ НАЙДЕНЫ ОШИБКИ С ПОЛНЫМИ ПЕРЕМЕННЫМИ:"
    echo "$FULL_ENV_OUTPUT" | grep -A 5 -B 5 -i "error"
fi

if echo "$FULL_ENV_OUTPUT" | grep -q "Cannot find module"; then
    log "❌ ВСЁ ЕЩЁ ОШИБКИ МОДУЛЕЙ:"
    echo "$FULL_ENV_OUTPUT" | grep -A 3 -B 3 "Cannot find module"
fi

log "🔧 ШАГ 3: АНАЛИЗ КОНКРЕТНЫХ ФАЙЛОВ..."

echo "=== ПРОВЕРКА voip-provider-factory.js ==="
log "  Содержимое voip-provider-factory.js:"
head -15 temp_dist_runtime/services/voip-provider-factory.js

echo ""
echo "=== ПРОВЕРКА dialer.js ИМПОРТОВ ==="
log "  Все импорты в dialer.js:"
grep -n "require\|import" temp_dist_runtime/services/dialer.js | head -15

echo ""
echo "=== ПРОВЕРКА models/ ДИРЕКТОРИИ ==="
log "  Файлы в models/:"
ls -la temp_dist_runtime/models/ | head -10

echo ""
echo "=== ПОИСК ВСЕХ ОТСУТСТВУЮЩИХ МОДУЛЕЙ ==="
log "  Анализируем ВСЕ require() в dialer.js..."

# Извлекаем все relative requires из dialer.js и проверяем их существование
DIALER_REQUIRES=$(grep -o "require(\"\.\/[^\"]*\")" temp_dist_runtime/services/dialer.js | sed 's/require("\.\/\(.*\)")/\1/')

for req in $DIALER_REQUIRES; do
    if [[ $req == models/* ]]; then
        # Проверяем models
        MODEL_PATH="temp_dist_runtime/$req.js"
        if [[ ! -f "$MODEL_PATH" ]]; then
            log "❌ ОТСУТСТВУЕТ: $req.js"
        else
            log "✅ НАЙДЕН: $req.js"
        fi
    elif [[ $req == services/* ]]; then
        # Проверяем services  
        SERVICE_PATH="temp_dist_runtime/$req.js"
        if [[ ! -f "$SERVICE_PATH" ]]; then
            log "❌ ОТСУТСТВУЕТ: $req.js"
        else
            log "✅ НАЙДЕН: $req.js"
        fi
    fi
done

log "🧪 ШАГ 4: ПОШАГОВАЯ ДИАГНОСТИКА ЗАПУСКА..."

echo "=== ТЕСТ: ЗАГРУЗКА ТОЛЬКО CONFIG ==="
CONFIG_TEST=$(docker run --rm \
    -e DATABASE_URL=postgresql://dialer:dialer_pass_2025@postgres:5432/dialer \
    -e REDIS_URL=redis://redis:6379 \
    dailer-backend-modules-fixed:latest \
    timeout 3 node -e "try { require('./dist/config'); console.log('CONFIG OK'); } catch(e) { console.log('CONFIG ERROR:', e.message); }" 2>&1)
echo "Результат загрузки config: $CONFIG_TEST"

echo ""
echo "=== ТЕСТ: ЗАГРУЗКА SERVICES/DIALER ==="
DIALER_TEST=$(docker run --rm \
    -e DATABASE_URL=postgresql://dialer:dialer_pass_2025@postgres:5432/dialer \
    -e REDIS_URL=redis://redis:6379 \
    dailer-backend-modules-fixed:latest \
    timeout 3 node -e "try { require('./dist/services/dialer'); console.log('DIALER OK'); } catch(e) { console.log('DIALER ERROR:', e.message); }" 2>&1)
echo "Результат загрузки dialer: $DIALER_TEST"

echo ""
echo "=== ТЕСТ: ЗАГРУЗКА ТОЛЬКО APP.JS ==="
APP_TEST=$(docker run --rm \
    -e DATABASE_URL=postgresql://dialer:dialer_pass_2025@postgres:5432/dialer \
    -e REDIS_URL=redis://redis:6379 \
    -e ASTERISK_URL=ami://admin:dailer_admin_2025@asterisk:5038 \
    -e JWT_SECRET=2ffe1d3e9df1ffe8e07a5c2940b8d2c56e8280b9bf42965027b5605e5cfe11c2 \
    dailer-backend-modules-fixed:latest \
    timeout 3 node -e "try { require('./dist/app'); console.log('APP REQUIRE OK'); } catch(e) { console.log('APP REQUIRE ERROR:', e.message); }" 2>&1)
echo "Результат загрузки app: $APP_TEST"

log "🚀 ШАГ 5: РУЧНОЙ ЗАПУСК С COMPOSE ЛОГАМИ..."

echo "=== COMPOSE ЗАПУСК С ДЕТАЛЬНЫМИ ЛОГАМИ ==="
log "  Запускаем backend через compose с логами в реальном времени..."

# Останавливаем backend если есть
docker compose -f docker-compose-ready.yml stop backend 2>/dev/null || true
docker compose -f docker-compose-ready.yml rm -f backend 2>/dev/null || true

# Запускаем backend и сразу смотрим логи
docker compose -f docker-compose-ready.yml up -d backend

sleep 3

echo "=== ЛОГИ СРАЗУ ПОСЛЕ ЗАПУСКА ==="
docker logs dialer_backend_ready --tail 50 2>&1 || echo "Контейнер не существует или уже упал"

echo ""
echo "=== СТАТУС BACKEND КОНТЕЙНЕРА ==="
docker ps -a --filter "name=dialer_backend_ready" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Command}}"

echo ""
echo "=== СОБЫТИЯ DOCKER ДЛЯ BACKEND ==="
docker events --filter container=dialer_backend_ready --since 2m --until now || echo "Нет событий"

log "🔍 ШАГ 6: АНАЛИЗ КОНФИГУРАЦИИ COMPOSE..."

echo "=== BACKEND СЕКЦИЯ В COMPOSE ==="
grep -A 20 -B 5 "backend:" docker-compose-ready.yml

echo ""
echo "=== ПРОВЕРКА ОБРАЗА ==="
docker images | grep "dailer-backend-modules-fixed"

echo ""
echo "=== ПРОВЕРКА NETWORK ==="
docker network ls | grep dialer

log "📊 ШАГ 7: ФИНАЛЬНАЯ ДИАГНОСТИКА..."

echo ""
echo "=== СТАТУС ВСЕХ КОНТЕЙНЕРОВ ==="
docker compose -f docker-compose-ready.yml ps

echo ""
echo "=== ПОСЛЕДНЯЯ ПОПЫТКА ПОЛУЧИТЬ ЛЮБЫЕ ЛОГИ ==="
docker logs dialer_backend_ready 2>&1 || echo "Логи недоступны"

echo ""
echo "=== ИНСПЕКЦИЯ BACKEND КОНТЕЙНЕРА ==="
docker inspect dialer_backend_ready --format="{{.State.Status}}: {{.State.Error}}" 2>/dev/null || echo "Контейнер не найден"

# Очистка
rm -rf temp_dist_runtime

echo ""
log "⚠️ ИТОГ УЛЬТРА-ГЛУБОКОЙ ДИАГНОСТИКИ ЗАВЕРШЁН"
echo ""
echo "📋 ВЫВОДЫ:"
echo "  1. Модули voip-provider-factory работают без переменных"
echo "  2. С переменными backend все еще крашится"
echo "  3. Нужно найти точную runtime ошибку"
echo ""
echo "🎯 ЦЕЛЬ: Найти точную причину runtime краша с переменными окружения" 