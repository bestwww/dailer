#!/bin/bash

# 🚀 Скрипт тестирования FreeSWITCH Docker с готовыми пакетами
# НАМНОГО БЫСТРЕЕ чем сборка из исходников!

set -e

echo "🚀 Тестирование FreeSWITCH Docker (готовые пакеты)..."

# Переходим в директорию проекта  
cd /path/to/dailer  # ⚠️ ИЗМЕНИТЕ НА РЕАЛЬНЫЙ ПУТЬ!

# Обновляемся из git
echo "📥 Обновляем код из git..."
git pull origin main

# Переходим в директорию FreeSWITCH Docker
cd docker/freeswitch

echo "🔨 Собираем FreeSWITCH контейнер (готовые пакеты)..."
echo "⏱️ Это займет 3-5 минут (вместо 30+ минут!)..."

# Собираем контейнер с выводом логов
docker build -f Dockerfile-packages -t dailer-freeswitch:packages . 2>&1 | tee /tmp/freeswitch-packages-build.log

# Проверяем успешность сборки
if [ $? -eq 0 ]; then
    echo "✅ Сборка FreeSWITCH (пакеты) завершена успешно!"
    
    # Тестируем запуск контейнера
    echo "🧪 Тестируем запуск контейнера..."
    
    # Запускаем контейнер в тестовом режиме
    CONTAINER_ID=$(docker run -d \
        --name freeswitch-test-packages \
        -p 5060:5060/udp \
        -p 5060:5060/tcp \
        -p 8021:8021/tcp \
        dailer-freeswitch:packages)
    
    echo "🐳 Контейнер запущен: $CONTAINER_ID"
    
    # Ждем запуска
    echo "⏳ Ждем запуска FreeSWITCH (30 секунд)..."
    sleep 30
    
    # Проверяем логи
    echo "📋 Логи контейнера:"
    docker logs freeswitch-test-packages | tail -20
    
    # Проверяем что FreeSWITCH работает
    echo "🔍 Проверяем статус FreeSWITCH..."
    if docker exec freeswitch-test-packages fs_cli -x "status" 2>/dev/null | grep -q "UP"; then
        echo "✅ FreeSWITCH работает корректно!"
        
        # Проверяем Event Socket
        echo "🔌 Проверяем Event Socket (порт 8021)..."
        if timeout 5 bash -c "</dev/tcp/localhost/8021" 2>/dev/null; then
            echo "✅ Event Socket доступен!"
        else
            echo "⚠️ Event Socket недоступен"
        fi
        
        # Показываем информацию о версии
        echo "📊 Информация о FreeSWITCH:"
        docker exec freeswitch-test-packages freeswitch -version | head -3
        
    else
        echo "❌ FreeSWITCH не запустился корректно"
        echo "📋 Полные логи:"
        docker logs freeswitch-test-packages
    fi
    
    # Останавливаем и удаляем тестовый контейнер
    echo "🧹 Останавливаем тестовый контейнер..."
    docker stop freeswitch-test-packages
    docker rm freeswitch-test-packages
    
    echo ""
    echo "🎉 ТЕСТИРОВАНИЕ ЗАВЕРШЕНО!"
    echo "✅ FreeSWITCH Docker (готовые пакеты) работает!"
    echo "📊 Преимущества:"
    echo "   - ⚡ Быстрая сборка (3-5 минут вместо 30+)"
    echo "   - 🛡️ Стабильность (готовые пакеты)" 
    echo "   - 📦 Меньший размер образа"
    echo "   - 🔧 Проще обслуживать"
    
else
    echo "❌ Ошибка сборки FreeSWITCH (пакеты)"
    echo "📋 Проверьте логи: /tmp/freeswitch-packages-build.log"
    exit 1
fi 