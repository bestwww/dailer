#!/bin/bash

# ГОТОВЫЕ DOCKER ОБРАЗЫ ASTERISK - БЕЗ компиляции
# Основано на реальных работающих решениях

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🎯 ГОТОВЫЕ ОБРАЗЫ ASTERISK - Быстрое решение БЕЗ компиляции"

# Остановка текущей системы
log "🛑 Остановка..."
docker compose down --remove-orphans

log "📥 Получение обновлений..."
git pull origin main

log "🧹 Очистка Docker..."
docker system prune -f

log "🔍 ДОСТУПНЫЕ ГОТОВЫЕ ОБРАЗЫ:"
log "   1. andrius/asterisk:20.1.0 - Готовый Asterisk 20 (РЕКОМЕНДУЕТСЯ)"
log "   2. dougbtv/asterisk:16 - Стабильная версия"
log "   3. jrhavlik/asterisk:16 - Production ready"

# Меню выбора
echo ""
echo "Выберите образ Asterisk:"
echo "1) andrius/asterisk:20.1.0 (БЕЗ Stasis проблем)"
echo "2) dougbtv/asterisk:16 (Стабильная версия)"  
echo "3) jrhavlik/asterisk:16 (Production ready)"
echo "4) Custom Asterisk 22 (как в статье)"
echo ""
read -p "Ваш выбор (1-4): " choice

case $choice in
    1)
        ASTERISK_IMAGE="andrius/asterisk:20.1.0"
        ASTERISK_NAME="Asterisk 20.1.0 БЕЗ Stasis"
        ;;
    2)
        ASTERISK_IMAGE="dougbtv/asterisk:16"
        ASTERISK_NAME="Asterisk 16 стабильная"
        ;;
    3)
        ASTERISK_IMAGE="jrhavlik/asterisk:16"
        ASTERISK_NAME="Asterisk 16 production"
        ;;
    4)
        # Создаем простой Asterisk 22 как в статье
        log "📦 Создание Asterisk 22 Docker образа..."
        cat > /tmp/Dockerfile-asterisk22 << 'EOF'
FROM ubuntu:22.04

# Установка зависимостей
RUN apt-get update && \
    apt-get install -y \
        wget \
        build-essential \
        libjansson-dev \
        libxml2-dev \
        libsqlite3-dev \
        libssl-dev \
        libedit-dev

# Создание пользователя
RUN useradd -d /home/asterisk -m --uid 2000 asterisk

USER asterisk
WORKDIR /home/asterisk

# Скачивание и сборка Asterisk 22
RUN wget -q http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-22-current.tar.gz && \
    tar -xzf asterisk-22-current.tar.gz && \
    cd asterisk-22* && \
    ./configure --with-jansson-bundled && \
    make -j$(nproc)

USER root
WORKDIR /home/asterisk/asterisk-22*
RUN make install && make config && make samples

# Создание директорий для конфигурации
RUN mkdir -p /etc/asterisk/custom

# Команда запуска
CMD ["/usr/sbin/asterisk", "-f", "-c", "-vvvvv"]
EOF
        
        log "🔨 Сборка Asterisk 22..."
        docker build -f /tmp/Dockerfile-asterisk22 -t asterisk-22-custom .
        ASTERISK_IMAGE="asterisk-22-custom"
        ASTERISK_NAME="Asterisk 22 Custom"
        ;;
    *)
        log "❌ Неверный выбор. Используется по умолчанию andrius/asterisk:20.1.0"
        ASTERISK_IMAGE="andrius/asterisk:20.1.0"
        ASTERISK_NAME="Asterisk 20.1.0 БЕЗ Stasis"
        ;;
esac

log "✅ Выбран образ: $ASTERISK_NAME"

# Создаем .env
log "🔧 Создание .env..."
cat > .env << 'EOF'
VOIP_PROVIDER=asterisk
ASTERISK_HOST=asterisk
ASTERISK_PORT=5038
ASTERISK_USERNAME=admin
ASTERISK_PASSWORD=admin
SIP_CALLER_ID_NUMBER=9058615815
SIP_PROVIDER_HOST=62.141.121.197
SIP_PROVIDER_PORT=5070
EXTERNAL_IP=auto
POSTGRES_DB=dialer
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres123
REDIS_PASSWORD=redis123
EOF

log "🚀 Запуск системы с готовым образом..."

log "1️⃣ PostgreSQL + Redis..."
docker compose up postgres redis -d
sleep 10

log "2️⃣ $ASTERISK_NAME..."

# Скачиваем образ если нужно
if [[ "$ASTERISK_IMAGE" != "asterisk-22-custom" ]]; then
    log "📥 Скачивание образа $ASTERISK_IMAGE..."
    docker pull $ASTERISK_IMAGE
fi

# Запускаем Asterisk контейнер
docker run -d --name dialer_asterisk_ready \
    --network dialer_dialer_network \
    -p 5060:5060/udp \
    -p 5060:5060/tcp \
    -p 5038:5038/tcp \
    -p 10000-20000:10000-20000/udp \
    -e ASTERISK_UID=1001 \
    -e ASTERISK_GID=1001 \
    $ASTERISK_IMAGE

log "⏳ Ожидание Asterisk (30 сек)..."
sleep 30

log "📋 Статус Asterisk:"
docker ps | grep asterisk

log "📋 Логи Asterisk:"
docker logs dialer_asterisk_ready | tail -20

# Проверка на Stasis проблемы
log "🚨 Проверка на Stasis ошибки..."
ASTERISK_LOGS=$(docker logs dialer_asterisk_ready 2>&1)

if echo "$ASTERISK_LOGS" | grep -q "Stasis initialization failed"; then
    log "❌ Stasis проблема найдена в образе $ASTERISK_IMAGE"
    log "💡 Попробуйте другой образ или Asterisk 22"
    exit 1
fi

if echo "$ASTERISK_LOGS" | grep -q "Asterisk Ready\|PBX UUID\|Manager registered"; then
    log "🎉 SUCCESS: $ASTERISK_NAME запустился успешно!"
else
    log "⚠️ Проверьте логи - возможны проблемы с конфигурацией"
fi

log "3️⃣ Backend..."
docker compose up backend -d
sleep 15

log "4️⃣ Frontend..."
docker compose up frontend -d
sleep 5

log "📋 ФИНАЛЬНЫЙ СТАТУС:"
docker compose ps
docker ps | grep asterisk

log "🧪 Информация об Asterisk:"
docker exec dialer_asterisk_ready asterisk -rx "core show version" || echo "CLI недоступен"

log "✅ РЕШЕНИЕ С ГОТОВЫМ ОБРАЗОМ ЗАВЕРШЕНО!"
log "🎯 Используется: $ASTERISK_NAME"
log "📝 Если нужны настройки - скопируйте конфигурацию в контейнер"
log "🔧 AMI должен быть доступен на порту 5038" 