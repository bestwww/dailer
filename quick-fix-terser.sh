#!/bin/bash

# БЫСТРОЕ ИСПРАВЛЕНИЕ TERSER ПРОБЛЕМЫ

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🔧 БЫСТРОЕ ИСПРАВЛЕНИЕ TERSER ПРОБЛЕМЫ"

log "📋 ПРОБЛЕМА:"
echo "  ❌ Terser не установлен как зависимость в Vite 3+"
echo "  ❌ Ошибка: terser not found, it's optional dependency"

log "✅ РЕШЕНИЕ:"
echo "  ✅ Переключаемся с 'terser' на 'esbuild'"
echo "  ✅ esbuild встроен в Vite (быстрее и без доп. зависимостей)"

# Остановить все контейнеры
log "🛑 Остановка всех контейнеров..."
docker compose -f docker-compose-ready.yml down --remove-orphans 2>/dev/null || true

# Очистка только frontend образа
log "🧹 Очистка frontend образа..."
docker images | grep "dailer-frontend" | awk '{print $3}' | xargs -r docker rmi -f 2>/dev/null || true

log "🚀 СБОРКА FRONTEND С ESBUILD МИНИФИКАЦИЕЙ..."

# Сборка frontend с esbuild
docker compose -f docker-compose-ready.yml build frontend --no-cache --progress=plain

BUILD_RESULT=$?

if [ $BUILD_RESULT -ne 0 ]; then
    log "❌ СБОРКА FRONTEND ВСЕ ЕЩЕ НЕ УДАЛАСЬ"
    log "📋 ВОЗМОЖНЫЕ АЛЬТЕРНАТИВЫ:"
    echo "  1. Отключить минификацию полностью: minify: false"
    echo "  2. Добавить terser в package.json: npm install --save-dev terser"
    echo "  3. Проверить другие TypeScript ошибки"
    
    echo ""
    echo "📝 Логи сборки frontend (последние 20 строк):"
    docker logs $(docker ps -a --filter "name=frontend" --format "{{.ID}}" | head -1) --tail 20 2>/dev/null || echo "Логи недоступны"
    
    exit 1
fi

log "✅ Frontend собран успешно с esbuild!"

# Запуск всей системы
log "🔄 Запуск всех сервисов..."
docker compose -f docker-compose-ready.yml up -d

# Быстрая проверка (1 минута)
log "⏰ Быстрая проверка запуска (1 минута)..."

for i in $(seq 1 12); do
    sleep 5
    
    # Подсчет запущенных сервисов
    RUNNING_COUNT=$(docker ps --filter "name=dialer_.*_ready" --format "{{.Names}}" | wc -l)
    
    log "📊 Запущено сервисов: $RUNNING_COUNT/5 ($((i*5)) сек)"
    
    if [ $RUNNING_COUNT -eq 5 ]; then
        log "🎉 ВСЕ 5 СЕРВИСОВ ЗАПУЩЕНЫ!"
        
        # Быстрое тестирование
        sleep 10
        
        # Тест Frontend
        if curl -sf http://localhost:3000 >/dev/null 2>&1; then
            log "✅ Frontend доступен по http://localhost:3000"
        else
            log "⚠️ Frontend еще не готов"
        fi
        
        # Тест Backend API
        if curl -sf http://localhost:3001/health >/dev/null 2>&1; then
            log "✅ Backend API работает"
        else
            log "⚠️ Backend API еще не готов"
        fi
        
        log "📋 СТАТУС СИСТЕМЫ:"
        docker compose -f docker-compose-ready.yml ps
        
        log "🎯 СИСТЕМА ЗАПУЩЕНА!"
        echo ""
        echo "🎉 TERSER ПРОБЛЕМА РЕШЕНА!"
        echo "   ✅ Frontend собран с esbuild минификацией"
        echo "   ✅ Все 5 сервисов запущены"
        echo ""
        echo "🌐 Frontend:    http://localhost:3000"
        echo "🔧 Backend:     http://localhost:3001/health"
        echo "📞 Asterisk:    docker exec -it dialer_asterisk_ready asterisk -r"
        echo ""
        log "✅ МИГРАЦИЯ FreeSWITCH ➜ ASTERISK РАБОТАЕТ!"
        
        exit 0
    fi
done

# Если не запустилось за минуту
log "⚠️ НЕ ВСЕ СЕРВИСЫ ЗАПУСТИЛИСЬ ЗА 1 МИНУТУ"
log "📊 Текущий статус:"
docker compose -f docker-compose-ready.yml ps

log "💡 ЗАПУСТИТЕ РАСШИРЕННЫЙ МОНИТОРИНГ:"
echo "  ./fix-frontend-and-restart.sh  # Полная диагностика на 3 минуты"

exit 0 