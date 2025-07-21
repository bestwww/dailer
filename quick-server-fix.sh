#!/bin/bash

# 🚀 Быстрое решение git проблемы на сервере

echo "🔧 === БЫСТРОЕ ИСПРАВЛЕНИЕ GIT КОНФЛИКТА ==="
echo

# Удаляем конфликтующий файл
echo "🗑️ Удаляем локальный fix-git-conflicts-server.sh..."
rm -f fix-git-conflicts-server.sh

# Создаем резервную копию диалплана
echo "💾 Создаем резервную копию диалплана..."
cp freeswitch/conf/dialplan/default.xml freeswitch/conf/dialplan/default.xml.backup.$(date +%s) 2>/dev/null || true

# Выполняем git pull
echo "⬇️ Выполняем git pull..."
git pull origin main

if [ $? -eq 0 ]; then
    echo "✅ Git pull выполнен успешно!"
    
    # Устанавливаем права
    echo "🔧 Устанавливаем права на выполнение..."
    chmod +x test-calls.sh 2>/dev/null || true
    chmod +x fix-git-conflicts-server.sh 2>/dev/null || true
    
    # Проверяем новые файлы
    echo ""
    echo "📋 Проверяем новые файлы:"
    
    if [ -f "test-calls.sh" ]; then
        echo "✅ test-calls.sh найден"
    else
        echo "❌ test-calls.sh не найден"
    fi
    
    if [ -f "TESTING_GUIDE.md" ]; then
        echo "✅ TESTING_GUIDE.md найден"
    else
        echo "❌ TESTING_GUIDE.md не найден"
    fi
    
    if [ -f "audio/example_1.mp3" ]; then
        echo "✅ audio/example_1.mp3 найден ($(ls -lh audio/example_1.mp3 | awk '{print $5}'))"
    else
        echo "❌ audio/example_1.mp3 не найден"
    fi
    
    # Проверяем диалплан
    echo ""
    echo "🔍 Проверяем обновления диалплана..."
    if grep -q "test_internal_1204" freeswitch/conf/dialplan/default.xml 2>/dev/null; then
        echo "✅ Тестовые номера (1204-1206) настроены"
    else
        echo "⚠️ Тестовые номера не найдены"
    fi
    
    if grep -q "79206054020" freeswitch/conf/dialplan/default.xml 2>/dev/null; then
        echo "✅ Маршрут для реального номера настроен"
    else
        echo "⚠️ Маршрут для реального номера не найден"
    fi
    
    echo ""
    echo "🚀 СЛЕДУЮЩИЕ ШАГИ:"
    echo "   1. docker compose restart freeswitch"
    echo "   2. sleep 30"
    echo "   3. ./test-calls.sh"
    echo ""
    echo "✅ Обновление завершено успешно!"
    
else
    echo "❌ Ошибка при git pull"
    echo "Попробуйте выполнить команды вручную:"
    echo "   git reset --hard HEAD"
    echo "   git clean -fd"
    echo "   git pull origin main"
fi 