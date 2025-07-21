#!/bin/bash
# Скрипт для синхронизации обновлений на сервере

echo "🔄 СИНХРОНИЗАЦИЯ ОБНОВЛЕНИЙ СЕРВЕРА"
echo "=================================="

# Функция логирования
log() {
    echo "[$(date '+%H:%M:%S')] $1: $2"
}

log "INFO" "📋 Сохранение локальных изменений..."

# Показываем текущие изменения
log "INFO" "🔍 Текущие локальные изменения:"
git status --porcelain

# Сохраняем локальные изменения в stash
log "INFO" "💾 Сохранение изменений в stash..."
git stash push -m "Локальные настройки FreeSWITCH перед обновлением $(date)"

# Обновляем код
log "INFO" "⬇️ Получение обновлений из репозитория..."
if git pull origin main; then
    log "SUCCESS" "✅ Код успешно обновлен"
else
    log "ERROR" "❌ Ошибка при обновлении кода"
    exit 1
fi

# Показываем что появилось нового
log "INFO" "📁 Новые файлы:"
ls -la *.sh 2>/dev/null | grep -E "(check-server-ip|setup-caller-id)" || echo "Скрипты диагностики уже присутствуют"

# Проверяем доступность нового скрипта
if [ -f "check-server-ip.sh" ]; then
    log "SUCCESS" "✅ Скрипт check-server-ip.sh добавлен"
    chmod +x check-server-ip.sh
    log "INFO" "🔧 Права на выполнение установлены"
else
    log "ERROR" "❌ check-server-ip.sh не найден"
fi

# Показываем содержимое stash
log "INFO" "📦 Сохраненные локальные изменения:"
git stash list

echo ""
echo "🎯 СЛЕДУЮЩИЕ ШАГИ:"
echo "================="
echo "1. Запустите диагностику: ./check-server-ip.sh"
echo "2. При необходимости восстановите локальные настройки: git stash pop"
echo "3. Сообщите провайдеру IP адрес для добавления в whitelist"
echo ""
echo "ℹ️  ПРИМЕЧАНИЕ: Локальные настройки FreeSWITCH сохранены в stash"
echo "   Если нужно их восстановить: git stash pop" 