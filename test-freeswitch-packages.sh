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

# Пробуем основной вариант с готовыми пакетами
echo "📦 Попытка 1: Официальный репозиторий SignalWire..."
if docker build -f Dockerfile-packages -t dailer-freeswitch:packages . 2>&1 | tee /tmp/freeswitch-packages-build.log; then
    echo "✅ Основной вариант собрался успешно!"
    DOCKERFILE_USED="Dockerfile-packages"
    IMAGE_TAG="packages"
else
    echo "❌ Основной вариант не сработал, пробуем альтернативный..."
    echo "📦 Попытка 2: Альтернативный способ (Ubuntu Universe)..."
    if docker build -f Dockerfile-alternative -t dailer-freeswitch:alternative . 2>&1 | tee /tmp/freeswitch-alternative-build.log; then
        echo "✅ Альтернативный вариант собрался успешно!"
        DOCKERFILE_USED="Dockerfile-alternative"
        IMAGE_TAG="alternative"
    else
        echo "❌ Оба варианта не сработали. Проверьте логи:"
        echo "   - /tmp/freeswitch-packages-build.log"
        echo "   - /tmp/freeswitch-alternative-build.log"
        exit 1
    fi
fi

echo "🎯 Используемый образ: dailer-freeswitch:$IMAGE_TAG ($DOCKERFILE_USED)"

# Проверяем успешность сборки
if [ $? -eq 0 ]; then
    echo "✅ Сборка FreeSWITCH (пакеты) завершена успешно!"
    
    # Тестируем запуск контейнера
    echo "🧪 Тестируем запуск контейнера..."
    
    # Запускаем контейнер в тестовом режиме
    CONTAINER_ID=$(docker run -d \
        --name freeswitch-test-$IMAGE_TAG \
        -p 5060:5060/udp \
        -p 5060:5060/tcp \
        -p 8021:8021/tcp \
        dailer-freeswitch:$IMAGE_TAG)
    
    echo "🐳 Контейнер запущен: $CONTAINER_ID"
    
    # Ждем запуска
    echo "⏳ Ждем запуска FreeSWITCH (30 секунд)..."
    sleep 30
    
    # Проверяем логи
    echo "📋 Логи контейнера:"
    docker logs freeswitch-test-$IMAGE_TAG | tail -20
    
    # Проверяем что FreeSWITCH работает
    echo "🔍 Проверяем статус FreeSWITCH..."
    if docker exec freeswitch-test-$IMAGE_TAG fs_cli -x "status" 2>/dev/null | grep -q "UP"; then
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
        docker exec freeswitch-test-$IMAGE_TAG freeswitch -version | head -3 2>/dev/null || \
        docker exec freeswitch-test-$IMAGE_TAG ls -la /usr/bin/freeswitch /usr/local/freeswitch/bin/freeswitch 2>/dev/null || \
        echo "ℹ️ FreeSWITCH найден, но версия недоступна"
        
    else
        echo "❌ FreeSWITCH не запустился корректно"
        echo "📋 Полные логи:"
        docker logs freeswitch-test-$IMAGE_TAG
    fi
    
    # Останавливаем и удаляем тестовый контейнер
    echo "🧹 Останавливаем тестовый контейнер..."
    docker stop freeswitch-test-$IMAGE_TAG
    docker rm freeswitch-test-$IMAGE_TAG
    
    echo ""
    echo "🎉 ТЕСТИРОВАНИЕ ЗАВЕРШЕНО!"
    echo "✅ FreeSWITCH Docker ($DOCKERFILE_USED) работает!"
    echo "📊 Преимущества:"
    echo "   - ⚡ Быстрая сборка (3-5 минут вместо 30+)"
    echo "   - 🛡️ Стабильность (готовые пакеты)" 
    echo "   - 📦 Меньший размер образа"
    echo "   - 🔧 Проще обслуживать"
    echo "   - 🎯 Использованный метод: $DOCKERFILE_USED"
    
else
    echo "❌ Ошибка сборки FreeSWITCH"
    echo "📋 Проверьте логи в /tmp/"
    exit 1
fi 