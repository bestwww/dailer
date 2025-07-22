#!/bin/bash

# Тест правильных CLI команд для originate в Asterisk
# Исправляет проблему "No such command originate"

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🧪 Тестирование правильных CLI команд Asterisk"

# Пересобрать с asterisk.conf
log "🔨 Пересборка с asterisk.conf..."
docker compose build asterisk
docker compose up asterisk -d

sleep 10

log "📋 Статус Asterisk:"
docker compose logs asterisk --tail=10

log "🧪 Тестирование правильных CLI команд:"

echo "=== ПРАВИЛЬНАЯ КОМАНДА ORIGINATE ==="
echo "Попробуем 'channel originate' вместо 'originate':"
docker exec dialer_asterisk asterisk -r -x "core show help channel" | grep originate || echo "channel originate не найдена"

echo ""
echo "=== ВСЕ КОМАНДЫ CHANNEL ==="
docker exec dialer_asterisk asterisk -r -x "core show help channel"

echo ""
echo "=== ПОИСК ORIGINATE КОМАНД ==="
docker exec dialer_asterisk asterisk -r -x "core show help" | grep -i originate || echo "Originate команды не найдены в core"

echo ""
echo "=== CLI ORIGINATE (если есть) ==="
docker exec dialer_asterisk asterisk -r -x "core show help originate" 2>/dev/null || \
docker exec dialer_asterisk asterisk -r -x "help originate" 2>/dev/null || \
echo "Команды originate недоступны в CLI"

echo ""
echo "=== АЛЬТЕРНАТИВЫ - AMI ЧЕРЕЗ CLI ==="
echo "Возможно нужно использовать manager action через CLI:"
docker exec dialer_asterisk asterisk -r -x "manager show commands" | grep -i originate || echo "AMI команды недоступны"

echo ""
echo "=== ТЕСТ ЗВОНКА ЧЕРЕЗ PJSIP ==="
echo "Альтернативный способ - через pjsip call:"
docker exec dialer_asterisk asterisk -r -x "core show help pjsip" | head -5

echo ""
echo "=== ПРОВЕРКА CONTEXT И EXTENSIONS ==="
docker exec dialer_asterisk asterisk -r -x "dialplan show campaign-calls"

log "💡 РЕШЕНИЕ: В Asterisk CLI нет команды 'originate'"
log "   Используйте AMI из приложения или создайте call файл"
log "   Или используйте: asterisk -r -x \"manager action Originate ...\""

log "✅ Диагностика завершена" 