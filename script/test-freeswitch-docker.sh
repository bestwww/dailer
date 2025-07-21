#!/bin/bash

# 🔧 Скрипт тестирования сборки FreeSWITCH Docker контейнера
# Запускать на тестовом сервере после git pull

set -e

echo "🚀 Тестирование сборки FreeSWITCH Docker контейнера..."

# Переходим в директорию проекта
cd /path/to/dailer  # Измените на реальный путь на сервере

# Обновляемся из git
echo "📥 Обновляем код из git..."
git pull origin main

# Переходим в директорию FreeSWITCH Docker
cd docker/freeswitch

echo "🔨 Начинаем сборку FreeSWITCH контейнера..."
echo "⏱️ Это может занять 15-30 минут..."

# Собираем контейнер с выводом логов
docker build -t dailer-freeswitch:test . 2>&1 | tee /tmp/freeswitch-build.log

# Проверяем успешность сборки
if [ $? -eq 0 ]; then
    echo "✅ Сборка FreeSWITCH контейнера завершена успешно!"
    
    # Тестируем запуск контейнера
    echo "🧪 Тестируем запуск контейнера..."
    docker run --rm -d --name freeswitch-test \
        -p 5060:5060/udp \
        -p 8021:8021 \
        dailer-freeswitch:test
    
    # Ждем запуска
    sleep 10
    
    # Проверяем Event Socket
    echo "🔍 Проверяем Event Socket..."
    if nc -z localhost 8021; then
        echo "✅ Event Socket доступен!"
    else
        echo "❌ Event Socket недоступен"
    fi
    
    # Останавливаем тестовый контейнер
    docker stop freeswitch-test
    
    # Показываем информацию об образе
    echo "📊 Информация об образе:"
    docker images | grep dailer-freeswitch
    
    echo ""
    echo "🎉 Тестирование завершено успешно!"
    echo "💡 Контейнер готов к использованию: dailer-freeswitch:test"
    
else
    echo "❌ Ошибка сборки FreeSWITCH контейнера!"
    echo "📋 Логи сборки сохранены в /tmp/freeswitch-build.log"
    echo ""
    echo "🔍 Последние строки лога:"
    tail -20 /tmp/freeswitch-build.log
    exit 1
fi 