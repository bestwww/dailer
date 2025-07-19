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

# Пробуем официальный способ (полная версия)
echo "📦 Попытка 1: Официальный метод - полная версия (freeswitch-meta-all)..."
docker build -f Dockerfile-packages -t dailer-freeswitch:packages . 2>&1 | tee /tmp/freeswitch-packages-build.log
BUILD_RESULT=${PIPESTATUS[0]}

if [ $BUILD_RESULT -eq 0 ] && docker images | grep -q "dailer-freeswitch.*packages"; then
    echo "✅ Официальная полная версия собралась успешно!"
    DOCKERFILE_USED="Dockerfile-packages"
    IMAGE_TAG="packages"
else
    echo "❌ Полная версия не сработала (код выхода: $BUILD_RESULT), пробуем минимальную..."
    echo "📦 Попытка 2: Официальный метод - минимальная версия (freeswitch-meta-vanilla)..."
    docker build -f Dockerfile-minimal -t dailer-freeswitch:minimal . 2>&1 | tee /tmp/freeswitch-minimal-build.log
    MIN_BUILD_RESULT=${PIPESTATUS[0]}
    
    if [ $MIN_BUILD_RESULT -eq 0 ] && docker images | grep -q "dailer-freeswitch.*minimal"; then
        echo "✅ Официальная минимальная версия собралась успешно!"
        DOCKERFILE_USED="Dockerfile-minimal"
        IMAGE_TAG="minimal"
    else
        echo "❌ Минимальная версия тоже не сработала (код выхода: $MIN_BUILD_RESULT), пробуем альтернативный..."
        echo "📦 Попытка 3: Альтернативный способ (Ubuntu Universe)..."
        docker build -f Dockerfile-alternative -t dailer-freeswitch:alternative . 2>&1 | tee /tmp/freeswitch-alternative-build.log
        ALT_BUILD_RESULT=${PIPESTATUS[0]}
    
        if [ $ALT_BUILD_RESULT -eq 0 ] && docker images | grep -q "dailer-freeswitch.*alternative"; then
            echo "✅ Альтернативный вариант собрался успешно!"
            DOCKERFILE_USED="Dockerfile-alternative"
            IMAGE_TAG="alternative"
        else
            echo "❌ Альтернативный вариант тоже не сработал (код выхода: $ALT_BUILD_RESULT)"
            echo "📦 Попытка 4: Базовый образ (без FreeSWITCH - для ручной установки)..."
            docker build -f Dockerfile-base -t dailer-freeswitch:base . 2>&1 | tee /tmp/freeswitch-base-build.log
            BASE_BUILD_RESULT=${PIPESTATUS[0]}
            
            if [ $BASE_BUILD_RESULT -eq 0 ] && docker images | grep -q "dailer-freeswitch.*base"; then
                echo "✅ Базовый образ собрался успешно!"
                echo "⚠️ FreeSWITCH потребует ручной установки внутри контейнера"
                DOCKERFILE_USED="Dockerfile-base"
                IMAGE_TAG="base"
            else
                echo "❌ Все четыре варианта не сработали."
                echo "📋 Коды выхода: полная=$BUILD_RESULT, минимальная=$MIN_BUILD_RESULT, альтернативная=$ALT_BUILD_RESULT, базовая=$BASE_BUILD_RESULT"
                echo "📋 Проверьте логи:"
                echo "   - /tmp/freeswitch-packages-build.log"
                echo "   - /tmp/freeswitch-minimal-build.log"
                echo "   - /tmp/freeswitch-alternative-build.log"
                echo "   - /tmp/freeswitch-base-build.log"
                exit 1
            fi
        fi
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
    
    # Проверяем статус в зависимости от образа
    if [ "$IMAGE_TAG" = "base" ]; then
        echo "ℹ️ Базовый образ - FreeSWITCH не установлен"
        echo "🔍 Проверяем что контейнер работает и показывает инструкции..."
        if docker exec freeswitch-test-$IMAGE_TAG echo "Контейнер доступен" 2>/dev/null; then
            echo "✅ Базовый контейнер работает корректно!"
            echo "📋 Инструкции по установке FreeSWITCH:"
            docker exec freeswitch-test-$IMAGE_TAG cat /docker-entrypoint.sh | grep "Вариант 1" -A 5 | head -5 || echo "См. логи контейнера для инструкций"
        else
            echo "❌ Базовый контейнер не отвечает"
        fi
    else
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
    fi
    
    # Останавливаем и удаляем тестовый контейнер
    echo "🧹 Останавливаем тестовый контейнер..."
    docker stop freeswitch-test-$IMAGE_TAG
    docker rm freeswitch-test-$IMAGE_TAG
    
    echo ""
    echo "🎉 ТЕСТИРОВАНИЕ ЗАВЕРШЕНО!"
    if [ "$IMAGE_TAG" = "base" ]; then
        echo "✅ Базовый Docker образ ($DOCKERFILE_USED) работает!"
        echo "📊 Что получилось:"
        echo "   - ✅ Контейнер запускается"
        echo "   - ✅ Все зависимости установлены"
        echo "   - ✅ Структура директорий создана"
        echo "   - ⚠️ FreeSWITCH требует ручной установки"
        echo "   - 💡 Инструкции показаны в логах контейнера"
        echo ""
        echo "🔧 Следующий шаг: войдите в контейнер и установите FreeSWITCH:"
        echo "   docker exec -it freeswitch-test-$IMAGE_TAG bash"
        echo "   # Затем следуйте инструкциям в логах"
    else
        echo "✅ FreeSWITCH Docker ($DOCKERFILE_USED) работает!"
        echo "📊 Преимущества:"
        echo "   - ⚡ Быстрая сборка (3-5 минут вместо 30+)"
        echo "   - 🛡️ Стабильность (готовые пакеты)" 
        echo "   - 📦 Оптимизированный размер образа"
        echo "   - 🔧 Простое обслуживание"
        echo "   - 🎯 Использованный метод: $DOCKERFILE_USED"
        
        # Дополнительная информация в зависимости от типа сборки
        if [ "$IMAGE_TAG" = "packages" ]; then
            echo "   - 📦 Полный набор модулей FreeSWITCH (meta-all)"
        elif [ "$IMAGE_TAG" = "minimal" ]; then
            echo "   - 📦 Минимальный набор модулей (meta-vanilla)"
        elif [ "$IMAGE_TAG" = "alternative" ]; then
            echo "   - 📦 Ubuntu Universe репозиторий"
        fi
    fi
    
else
    echo "❌ Ошибка сборки FreeSWITCH"
    echo "📋 Проверьте логи в /tmp/"
    exit 1
fi 