#!/bin/bash

# ==============================================================================
# 🚨 КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ ПРАВ ДОСТУПА НА ХОСТ-СИСТЕМЕ
# ==============================================================================
# Этот скрипт исправляет права доступа к папке audio на хост-системе
# Нужно запускать на самом сервере, а НЕ внутри контейнера!

set -e

echo "==============================================="
echo "🚨 КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ ПРАВ ДОСТУПА"
echo "==============================================="

# Остановка контейнеров для безопасного изменения прав
echo "🔄 1. Остановка контейнеров..."
docker-compose down

# Проверка существующих прав
echo ""
echo "🔍 2. ПРОВЕРКА ТЕКУЩИХ ПРАВ НА ХОСТ-СИСТЕМЕ:"
echo "-----------------------------------------------"
echo "📂 Папка audio на хосте:"
ls -la ./audio/ 2>/dev/null || echo "❌ Папка audio не найдена"

# Получение UID/GID nodeuser из Dockerfile
echo ""
echo "👤 3. ПОЛУЧЕНИЕ UID/GID ИЗ DOCKERFILE:"
echo "-----------------------------------------------"
NODEUSER_UID=$(grep -oP 'RUN useradd.*-u \K\d+' backend/Dockerfile || echo "1001")
NODEUSER_GID=$(grep -oP 'RUN groupadd.*-g \K\d+' backend/Dockerfile || echo "1001")
echo "📋 nodeuser UID: $NODEUSER_UID"
echo "📋 nodejs GID: $NODEUSER_GID"

# Создание папки audio если не существует
echo ""
echo "📁 4. СОЗДАНИЕ/ИСПРАВЛЕНИЕ ПАПКИ AUDIO:"
echo "-----------------------------------------------"
if [ ! -d "./audio" ]; then
    echo "📁 Создание папки audio..."
    mkdir -p ./audio
    echo "✅ Папка создана"
else
    echo "📁 Папка audio уже существует"
fi

# Исправление прав доступа на хост-системе
echo ""
echo "🔧 5. ИСПРАВЛЕНИЕ ПРАВ НА ХОСТ-СИСТЕМЕ:"
echo "-----------------------------------------------"

# Изменение владельца (используем UID:GID напрямую)
echo "👤 Установка владельца $NODEUSER_UID:$NODEUSER_GID..."
sudo chown -R $NODEUSER_UID:$NODEUSER_GID ./audio/
echo "✅ Владелец изменен"

# Установка прав доступа
echo "🔒 Установка прав 755..."
sudo chmod -R 755 ./audio/
echo "✅ Права установлены"

# Проверка исправленных прав
echo ""
echo "✅ 6. ПРОВЕРКА ИСПРАВЛЕННЫХ ПРАВ:"
echo "-----------------------------------------------"
echo "📂 Права после исправления:"
ls -la ./audio/

# Создание .gitkeep с правильными правами
echo ""
echo "📝 7. СОЗДАНИЕ .GITKEEP С ПРАВИЛЬНЫМИ ПРАВАМИ:"
echo "-----------------------------------------------"
if [ ! -f "./audio/.gitkeep" ]; then
    echo "# Папка для аудиофайлов кампаний" > ./audio/.gitkeep
    sudo chown $NODEUSER_UID:$NODEUSER_GID ./audio/.gitkeep
    sudo chmod 644 ./audio/.gitkeep
    echo "✅ .gitkeep создан с правильными правами"
else
    sudo chown $NODEUSER_UID:$NODEUSER_GID ./audio/.gitkeep
    sudo chmod 644 ./audio/.gitkeep
    echo "✅ .gitkeep обновлен с правильными правами"
fi

# Запуск контейнеров
echo ""
echo "🚀 8. ЗАПУСК КОНТЕЙНЕРОВ:"
echo "-----------------------------------------------"
echo "🔄 Запуск с пересборкой backend..."
docker-compose up -d --build backend

# Ожидание запуска
echo "⏳ Ожидание запуска backend (10 сек)..."
sleep 10

# Проверка прав внутри контейнера
echo ""
echo "🔍 9. ПРОВЕРКА ПРАВ ВНУТРИ КОНТЕЙНЕРА:"
echo "-----------------------------------------------"
echo "📂 Права внутри контейнера:"
docker exec dialer_backend ls -la /app/audio/

echo "👤 Пользователь процесса:"
docker exec dialer_backend whoami

# Тест записи
echo ""
echo "🧪 10. ТЕСТ ЗАПИСИ ФАЙЛА:"
echo "-----------------------------------------------"
echo "📝 Тест создания файла внутри контейнера..."
if docker exec dialer_backend touch /app/audio/test_write.txt; then
    echo "✅ Тест записи УСПЕШЕН!"
    docker exec dialer_backend rm /app/audio/test_write.txt
else
    echo "❌ Тест записи НЕУДАЧЕН!"
fi

# Итоговый тест загрузки
echo ""
echo "🚀 11. ИТОГОВЫЙ ТЕСТ ЗАГРУЗКИ:"
echo "-----------------------------------------------"

# Создание тестового файла
echo "audio test content" > /tmp/final_test.mp3

# Тест загрузки
echo "📤 Тест финальной загрузки..."
UPLOAD_RESULT=$(curl -s -X POST \
    -F "audio=@/tmp/final_test.mp3" \
    -w "HTTP_CODE:%{http_code}" \
    http://localhost:3000/api/campaigns/1/audio)

echo "📋 Результат загрузки: $UPLOAD_RESULT"

if echo "$UPLOAD_RESULT" | grep -q "HTTP_CODE:200"; then
    echo "🎉 УСПЕХ! Файл загружен успешно!"
elif echo "$UPLOAD_RESULT" | grep -q "EACCES"; then
    echo "❌ Все еще проблемы с правами доступа"
else
    echo "⚠️ Другая ошибка при загрузке"
fi

# Очистка
rm -f /tmp/final_test.mp3

echo ""
echo "==============================================="
echo "📋 ИТОГОВЫЙ ОТЧЕТ"
echo "==============================================="

echo "✅ Что было исправлено:"
echo "  📂 Права папки /app/audio на хост-системе"
echo "  👤 Владелец установлен: $NODEUSER_UID:$NODEUSER_GID"
echo "  🔒 Права доступа: 755"
echo "  📝 .gitkeep с правильными правами"

echo ""
echo "🚀 Следующие шаги:"
echo "  1. Попробуйте загрузить аудиофайл через веб-интерфейс"
echo "  2. Файлы теперь должны сохраняться в папке ./audio/"
echo "  3. При проблемах проверьте: docker logs -f dialer_backend"

echo ""
echo "==============================================="
echo "✅ КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ ЗАВЕРШЕНО"
echo "===============================================" 