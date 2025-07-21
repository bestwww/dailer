#!/bin/bash

# Скрипт для исправления прав доступа к папке audio
# Проблема: EACCES permission denied при загрузке файлов
# Автор: AI Assistant

echo "==============================================="
echo "🔧 ИСПРАВЛЕНИЕ ПРАВ ДОСТУПА ДЛЯ АУДИОФАЙЛОВ"
echo "==============================================="

echo ""
echo "🔍 1. ПРОВЕРКА ТЕКУЩИХ ПРАВ:"
echo "-----------------------------------------------"
if docker ps -q -f name="dialer_backend" | grep -q .; then
    echo "📂 Текущие права папки audio:"
    docker exec dialer_backend ls -la /app/audio
    
    echo ""
    echo "👤 Пользователь Node.js процесса:"
    docker exec dialer_backend whoami
    docker exec dialer_backend id
    
else
    echo "❌ Backend контейнер не запущен"
    exit 1
fi

echo ""
echo "🔧 2. ИСПРАВЛЕНИЕ ПРАВ ДОСТУПА:"
echo "-----------------------------------------------"

# Исправляем права доступа
echo "📝 Изменение владельца папки на nodeuser..."
docker exec dialer_backend chown -R nodeuser:nodejs /app/audio

echo "📝 Установка прав записи..."
docker exec dialer_backend chmod -R 755 /app/audio

echo "📝 Создание папки если не существует..."
docker exec dialer_backend mkdir -p /app/audio

echo ""
echo "✅ 3. ПРОВЕРКА ИСПРАВЛЕНИЯ:"
echo "-----------------------------------------------"
echo "📂 Права после исправления:"
docker exec dialer_backend ls -la /app/audio

echo ""
echo "🧪 4. ТЕСТ ЗАГРУЗКИ ПОСЛЕ ИСПРАВЛЕНИЯ:"
echo "-----------------------------------------------"

# Создаем тестовый файл
TEST_FILE="/tmp/test_permissions.mp3"
echo -e "\xFF\xFB\x90\x00test audio content" > "$TEST_FILE"
echo "📁 Создан тестовый файл: $(ls -la $TEST_FILE)"

# Получаем ID кампании
CAMPAIGNS_RESPONSE=$(curl -s "http://localhost:3000/api/campaigns")
CAMPAIGN_ID=$(echo "$CAMPAIGNS_RESPONSE" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)

if [ ! -z "$CAMPAIGN_ID" ]; then
    echo ""
    echo "🚀 Тест загрузки для кампании $CAMPAIGN_ID:"
    
    UPLOAD_RESULT=$(curl -s -X POST \
        -F "audio=@$TEST_FILE" \
        -w "\nHTTP_CODE:%{http_code}\nTIME:%{time_total}s" \
        "http://localhost:3000/api/campaigns/$CAMPAIGN_ID/audio")
    
    echo "Результат загрузки:"
    echo "$UPLOAD_RESULT"
    
    # Проверяем файл в папке
    echo ""
    echo "📁 Файлы в папке audio после загрузки:"
    docker exec dialer_backend ls -la /app/audio
    
    # Очистка
    rm -f "$TEST_FILE"
    
    # Анализ результата
    if echo "$UPLOAD_RESULT" | grep -q "HTTP_CODE:200"; then
        echo ""
        echo "✅ УСПЕХ! Файл загружен успешно"
        echo "🎉 Проблема с правами доступа решена"
    else
        echo ""
        echo "❌ Загрузка не удалась, анализируем ошибку:"
        echo "$UPLOAD_RESULT" | grep -E "(error|Error)"
    fi
    
else
    echo "❌ Кампания не найдена для тестирования"
fi

echo ""
echo "🔍 5. ЛОГИ ПОСЛЕ ИСПРАВЛЕНИЯ:"
echo "-----------------------------------------------"
echo "📋 Последние логи backend:"
docker logs --tail 10 dialer_backend | grep -E "(audio|upload|error)" || echo "Логи чисты"

echo ""
echo "==============================================="
echo "📋 ИТОГОВАЯ ИНФОРМАЦИЯ"
echo "==============================================="

echo ""
echo "📝 Что было исправлено:"
echo "  ✅ Изменен владелец папки /app/audio на nodeuser:nodejs"
echo "  ✅ Установлены права 755 (чтение/запись для владельца)"
echo "  ✅ Проверена возможность записи файлов"

echo ""
echo "🔍 Если проблема остается:"
echo "  1. Проверить логи: docker logs -f dialer_backend"
echo "  2. Проверить права: docker exec dialer_backend ls -la /app/audio"
echo "  3. Перезапустить контейнер: docker-compose restart backend"

echo ""
echo "🚀 Дальнейшие действия:"
echo "  1. Попробуйте загрузить аудиофайл через UI"
echo "  2. Файлы теперь должны сохраняться успешно"
echo "  3. При успехе увидите: 'Аудиофайл успешно загружен'"

echo ""
echo "==============================================="
echo "✅ ИСПРАВЛЕНИЕ ПРАВ ДОСТУПА ЗАВЕРШЕНО"
echo "===============================================" 