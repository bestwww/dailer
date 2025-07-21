#!/bin/bash

# 🔧 Скрипт для разрешения git конфликтов на сервере
# Сохраняет локальные изменения и применяет обновления

set -e

echo "🔧 === РАЗРЕШЕНИЕ GIT КОНФЛИКТОВ НА СЕРВЕРЕ ==="
echo

# Функция для логирования
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [GIT] $1"
}

# Проверяем что мы в правильной директории
if [[ ! -d ".git" ]]; then
    log "❌ Не найдена git директория!"
    echo "Выполните: cd dailer"
    exit 1
fi

log "📁 Текущая директория: $(pwd)"

# Показываем статус git
log "📊 Проверяем git статус..."
git status

echo
log "🔍 Показываем конфликтующие файлы:"
echo "   - debug-audio-upload.sh"
echo "   - debug-docker.sh" 
echo "   - debug-timeout-fix.sh"
echo "   - deploy-test.sh"
echo "   - fix-audio-permissions.sh"
echo "   - freeswitch/conf/dialplan/default.xml"
echo "   - host-permissions-fix.sh"
echo "   - test-freeswitch-packages.sh"

echo
read -p "Хотите сохранить локальные изменения перед обновлением? (y/N): " save_local

if [[ $save_local == [yY] ]]; then
    log "💾 Сохраняем локальные изменения в stash..."
    
    # Создаем резервную копию важных файлов
    log "📋 Создаем резервные копии..."
    cp freeswitch/conf/dialplan/default.xml freeswitch/conf/dialplan/default.xml.backup.$(date +%s) 2>/dev/null || true
    
    # Сохраняем все изменения в stash
    git stash push -m "Локальные изменения сервера перед обновлением $(date)"
    
    log "✅ Локальные изменения сохранены в git stash"
else
    log "⚠️ Сбрасываем локальные изменения..."
    
    # Создаем резервную копию важного файла
    cp freeswitch/conf/dialplan/default.xml freeswitch/conf/dialplan/default.xml.backup.$(date +%s) 2>/dev/null || true
    
    # Сбрасываем все локальные изменения
    git reset --hard HEAD
    
    log "✅ Локальные изменения сброшены"
fi

echo
log "🔄 Выполняем git pull..."
if git pull origin main; then
    log "✅ Git pull выполнен успешно!"
else
    log "❌ Ошибка при git pull"
    exit 1
fi

echo
log "📋 Проверяем новые файлы..."

# Проверяем наличие новых файлов
echo "🆕 Новые файлы для тестирования:"
if [[ -f "test-calls.sh" ]]; then
    log "✅ test-calls.sh найден"
    chmod +x test-calls.sh
    log "🔧 Установлены права на выполнение для test-calls.sh"
else
    log "❌ test-calls.sh не найден"
fi

if [[ -f "TESTING_GUIDE.md" ]]; then
    log "✅ TESTING_GUIDE.md найден"
else
    log "❌ TESTING_GUIDE.md не найден"
fi

if [[ -f "audio/example_1.mp3" ]]; then
    log "✅ audio/example_1.mp3 найден ($(ls -lh audio/example_1.mp3 | awk '{print $5}'))"
else
    log "❌ audio/example_1.mp3 не найден"
fi

echo
log "🔍 Проверяем обновления FreeSWITCH диалплана..."
if grep -q "test_internal_1204" freeswitch/conf/dialplan/default.xml 2>/dev/null; then
    log "✅ Тестовые номера (1204-1206) настроены в диалплане"
else
    log "⚠️ Тестовые номера не найдены в диалплане"
fi

if grep -q "79206054020" freeswitch/conf/dialplan/default.xml 2>/dev/null; then
    log "✅ Маршрут для реального номера 79206054020 настроен"
else
    log "⚠️ Маршрут для реального номера не найден"
fi

echo
if [[ $save_local == [yY] ]]; then
    log "💡 ВОССТАНОВЛЕНИЕ ЛОКАЛЬНЫХ ИЗМЕНЕНИЙ:"
    echo "   git stash list                    # Показать сохраненные изменения"
    echo "   git stash pop                     # Применить последние изменения"
    echo "   git stash apply stash@{0}         # Применить конкретные изменения"
    echo "   git stash drop                    # Удалить stash после применения"
fi

echo
log "📁 РЕЗЕРВНЫЕ КОПИИ:"
echo "   Важные файлы сохранены с суффиксом .backup.timestamp"
ls -la freeswitch/conf/dialplan/*.backup.* 2>/dev/null || echo "   Нет резервных копий"

echo
log "🚀 СЛЕДУЮЩИЕ ШАГИ:"
echo "   1. Проверить docker контейнеры:     docker compose ps"
echo "   2. Перезапустить FreeSWITCH:        docker compose restart freeswitch"
echo "   3. Запустить тестирование:          ./test-calls.sh"

echo
log "✅ Обновление завершено успешно!" 