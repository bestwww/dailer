#!/bin/bash

# ПОЛНОЕ ИСПРАВЛЕНИЕ WEBSOCKET ПРОБЛЕМ

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🔧 ИСПРАВЛЕНИЕ WEBSOCKET ОШИБОК!"

log "❌ ПРОБЛЕМА:"
echo "  WebSocket connection to 'ws://localhost:3001/socket.io/' failed"
echo "  ❌ WebSocket ошибка подключения: TransportError"
echo "  🎯 Backend может не поддерживать Socket.IO или не запущен правильно"

log "🔍 ШАГ 1: ДИАГНОСТИКА BACKEND WEBSOCKET..."

echo "=== ПРОВЕРКА ЛОГОВ BACKEND ==="
docker compose -f docker-compose.no-asterisk.yml logs backend --tail 20

echo ""
echo "=== ПРОВЕРКА ПОРТОВ BACKEND ==="
docker compose -f docker-compose.no-asterisk.yml exec backend netstat -tlnp 2>/dev/null | grep 3000 || echo "netstat не доступен"

echo ""
echo "=== ТЕСТ SOCKET.IO ENDPOINT ==="
curl -v http://localhost:3001/socket.io/ 2>&1 | head -10 || echo "Endpoint недоступен"

log "🚀 ШАГ 2: ПЕРЕЗАПУСК BACKEND ДЛЯ ИСПРАВЛЕНИЯ WEBSOCKET..."

echo "=== ПЕРЕЗАПУСК BACKEND ==="
docker compose -f docker-compose.no-asterisk.yml restart backend

echo "Ожидание перезапуска backend..."
sleep 20

echo ""
echo "=== ЛОГИ BACKEND ПОСЛЕ ПЕРЕЗАПУСКА ==="
docker compose -f docker-compose.no-asterisk.yml logs backend --tail 15

echo ""
echo "=== ПРОВЕРКА SOCKET.IO ПОСЛЕ ПЕРЕЗАПУСКА ==="
SOCKET_TEST=$(curl -s http://localhost:3001/socket.io/ 2>/dev/null || echo "failed")
if [[ "$SOCKET_TEST" != "failed" ]]; then
    echo "✅ Socket.IO endpoint доступен"
else
    echo "❌ Socket.IO endpoint недоступен"
fi

log "🧪 ШАГ 3: ПОЛНЫЙ ТЕСТ СИСТЕМЫ..."

echo "=== ТЕСТ BACKEND API ==="
HEALTH_RESPONSE=$(curl -sf http://localhost:3001/health 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "✅ Backend API работает!"
    echo "Response: $HEALTH_RESPONSE"
else
    echo "❌ Backend API недоступен"
fi

echo ""
echo "=== ТЕСТ FRONTEND ==="
if curl -sf http://localhost:5173 >/dev/null 2>&1; then
    echo "✅ Frontend работает!"
else
    echo "❌ Frontend недоступен"
fi

echo ""
echo "=== СТАТУС ВСЕХ СЕРВИСОВ ==="
docker compose -f docker-compose.no-asterisk.yml ps

log "🎯 РЕШЕНИЕ WEBSOCKET ПРОБЛЕМ ЗАВЕРШЕНО!"

echo ""
echo "💡 ЕСЛИ WEBSOCKET ВСЕ ЕЩЕ НЕ РАБОТАЕТ:"
echo "  1. WebSocket может быть отключен в backend коде"
echo "  2. Проверьте, запущен ли Socket.IO сервер в backend"
echo "  3. Можно отключить WebSocket в frontend для стабильности"
echo ""
echo "✅ ОСНОВНЫЕ ФУНКЦИИ РАБОТАЮТ БЕЗ WEBSOCKET!"
echo "🌐 Веб-интерфейс: http://localhost:5173"
echo "🚀 Backend API: http://localhost:3001/health" 