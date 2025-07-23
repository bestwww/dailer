#!/bin/bash

# ИСПРАВЛЕНИЕ TYPESCRIPT PATH ALIAS ПРОБЛЕМЫ

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🎯 ИСПРАВЛЕНИЕ TYPESCRIPT PATH ALIAS ПРОБЛЕМЫ"

log "❌ ПРОБЛЕМА НАЙДЕНА:"
echo "  Error: Cannot find module '@/config'"
echo "  TypeScript не компилирует path aliases правильно"
echo "  Node.js не понимает '@/config' в runtime"

log "🔧 РЕШЕНИЕ 1: ДОБАВЛЯЕМ TSC-ALIAS ДЛЯ АВТОМАТИЧЕСКОГО ПРЕОБРАЗОВАНИЯ..."

cd backend

# Добавляем tsc-alias
log "  Установка tsc-alias..."
npm install --save-dev tsc-alias

# Обновляем build script
log "  Обновление build script в package.json..."
sed -i 's/"build": "tsc"/"build": "tsc \&\& tsc-alias"/' package.json

# Пересобираем backend
log "🏗️ ПЕРЕСБОРКА BACKEND С ПРАВИЛЬНЫМИ ПУТЯМИ..."
npm run clean || true
npm run build

if [ $? -eq 0 ]; then
    log "✅ Backend собран успешно с tsc-alias!"
    
    # Проверяем что алиасы преобразованы
    if grep -q "@/config" dist/app.js; then
        log "⚠️ Алиасы все еще присутствуют в dist/app.js"
        log "🔧 ПРИМЕНЯЕМ РЕШЕНИЕ 2: РУЧНАЯ ЗАМЕНА АЛИАСОВ..."
        
        # Заменяем все алиасы на относительные пути в dist
        find dist -name "*.js" -type f -exec sed -i 's|@/config|./config|g' {} \;
        find dist -name "*.js" -type f -exec sed -i 's|@/controllers|./controllers|g' {} \;
        find dist -name "*.js" -type f -exec sed -i 's|@/services|./services|g' {} \;
        find dist -name "*.js" -type f -exec sed -i 's|@/models|./models|g' {} \;
        find dist -name "*.js" -type f -exec sed -i 's|@/middleware|./middleware|g' {} \;
        find dist -name "*.js" -type f -exec sed -i 's|@/utils|./utils|g' {} \;
        find dist -name "*.js" -type f -exec sed -i 's|@/types|./types|g' {} \;
        
        log "✅ Алиасы заменены на относительные пути в dist/"
    else
        log "✅ Алиасы успешно преобразованы tsc-alias!"
    fi
    
    cd ..
    
    log "🚀 ПЕРЕСБОРКА И ПЕРЕЗАПУСК BACKEND КОНТЕЙНЕРА..."
    
    # Останавливаем backend
    docker compose -f docker-compose-ready.yml stop backend
    
    # Пересобираем backend образ
    docker compose -f docker-compose-ready.yml build backend --no-cache
    
    # Запускаем backend
    docker compose -f docker-compose-ready.yml up -d backend
    
    log "⏰ ПРОВЕРКА ЗАПУСКА BACKEND (30 сек)..."
    
    sleep 10
    
    for i in {1..6}; do
        BACKEND_STATUS=$(docker ps --filter "name=dialer_backend_ready" --format "{{.Status}}" 2>/dev/null)
        
        if echo "$BACKEND_STATUS" | grep -q "Up"; then
            log "✅ Backend контейнер запущен: $BACKEND_STATUS"
            
            # Тестируем API
            sleep 5
            if curl -sf http://localhost:3001/health >/dev/null 2>&1; then
                log "🎉 BACKEND API РАБОТАЕТ!"
                
                echo ""
                echo "🎉 🎉 🎉 ПРОБЛЕМА ПОЛНОСТЬЮ РЕШЕНА! 🎉 🎉 🎉"
                echo ""
                echo "✅ TypeScript path alias проблема исправлена"
                echo "✅ Backend успешно запущен и работает"
                echo ""
                echo "🌐 Frontend:     http://localhost:3000"
                echo "🔧 Backend API:  http://localhost:3001/health"
                echo "📞 Asterisk CLI: docker exec -it dialer_asterisk_ready asterisk -r"
                echo ""
                echo "🏁 МИГРАЦИЯ FreeSWITCH ➜ ASTERISK ЗАВЕРШЕНА УСПЕШНО!"
                echo ""
                echo "🎯 СИСТЕМА ГОТОВА К ТЕСТИРОВАНИЮ SIP ЗВОНКОВ!"
                
                exit 0
            else
                log "⚠️ Backend запущен, но API еще не отвечает (${i}*5 сек)"
            fi
        else
            log "📊 Backend контейнер: $BACKEND_STATUS (${i}*5 сек)"
        fi
        
        sleep 5
    done
    
    log "⚠️ Backend не запустился за 30 секунд. Показываю логи..."
    
    echo ""
    echo "📝 Логи backend:"
    docker logs dialer_backend_ready --tail 20
    
    echo ""
    echo "📊 Статус всех контейнеров:"
    docker compose -f docker-compose-ready.yml ps
    
else
    log "❌ Ошибка при сборке backend"
    cd ..
    exit 1
fi

exit 1 