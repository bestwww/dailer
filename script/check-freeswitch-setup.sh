#!/bin/bash

# 🔍 Скрипт диагностики FreeSWITCH Docker настроек
# Проверяет существующие образы, контейнеры и конфигурацию

set -e

# 🎨 Функции для красивого вывода
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1"
}

log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] ✅ $1"
}

log_warning() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] ⚠️ $1"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] ❌ $1"
}

echo "🔍 ДИАГНОСТИКА FREESWITCH DOCKER НАСТРОЕК"
echo "=============================================="
echo ""

# 🐳 Проверяем Docker
log_info "🐳 Проверяем Docker..."
if ! command -v docker >/dev/null 2>&1; then
    log_error "Docker не установлен!"
    exit 1
fi
log_success "Docker установлен: $(docker --version)"

# 📦 Проверяем образы FreeSWITCH
log_info "📦 Проверяем существующие образы FreeSWITCH..."
echo ""
echo "🔍 Все образы с 'freeswitch' в названии:"
docker images | grep -i freeswitch || echo "❌ Образы FreeSWITCH не найдены"
echo ""

echo "🔍 Все образы с 'signalwire' в названии:"
docker images | grep -i signalwire || echo "❌ Образы SignalWire не найдены"
echo ""

echo "🔍 Все образы с 'dailer' в названии:"
docker images | grep -i dailer || echo "❌ Пользовательские образы не найдены"
echo ""

# 🏃 Проверяем контейнеры FreeSWITCH
log_info "🏃 Проверяем существующие контейнеры FreeSWITCH..."
echo ""
echo "🔍 Все контейнеры (запущенные и остановленные):"
docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
echo ""

echo "🔍 Контейнеры с 'freeswitch' в названии:"
docker ps -a | grep -i freeswitch || echo "❌ Контейнеры FreeSWITCH не найдены"
echo ""

# 📁 Проверяем конфигурационные файлы
log_info "📁 Проверяем конфигурационные файлы..."

if [ -f "docker-compose.yml" ]; then
    log_success "docker-compose.yml найден"
    echo ""
    echo "🔍 FreeSWITCH сервис в docker-compose.yml:"
    grep -A 20 -B 2 "freeswitch:" docker-compose.yml || echo "❌ FreeSWITCH сервис не найден"
    echo ""
else
    log_error "docker-compose.yml не найден!"
fi

if [ -f "docker-compose.no-build.yml" ]; then
    log_success "docker-compose.no-build.yml найден (альтернативная конфигурация)"
else
    log_info "docker-compose.no-build.yml не найден (можно создать для быстрого запуска)"
fi

# 🔗 Проверяем сети Docker
log_info "🔗 Проверяем Docker сети..."
echo ""
echo "🔍 Доступные сети:"
docker network ls
echo ""

# 💾 Проверяем тома Docker  
log_info "💾 Проверяем Docker тома..."
echo ""
echo "🔍 Тома с 'freeswitch' в названии:"
docker volume ls | grep -i freeswitch || echo "❌ Тома FreeSWITCH не найдены"
echo ""

echo "🔍 Тома с 'dialer' в названии:"
docker volume ls | grep -i dialer || echo "❌ Тома диалера не найдены"
echo ""

# 🔧 Проверяем конфигурацию FreeSWITCH
log_info "🔧 Проверяем файлы конфигурации FreeSWITCH..."

if [ -d "freeswitch/conf" ]; then
    log_success "Директория freeswitch/conf найдена"
    
    if [ -f "freeswitch/conf/dialplan/default.xml" ]; then
        log_success "Dialplan найден"
        if grep -q "79058615815" freeswitch/conf/dialplan/default.xml; then
            log_success "Caller ID 79058615815 найден в dialplan"
        else
            log_warning "Caller ID 79058615815 НЕ найден в dialplan"
        fi
    else
        log_error "Dialplan не найден"
    fi
    
    if [ -f "freeswitch/conf/autoload_configs/sofia.conf.xml" ]; then
        log_success "Sofia конфигурация найдена"
        if grep -q "79058615815" freeswitch/conf/autoload_configs/sofia.conf.xml; then
            log_success "Caller ID 79058615815 найден в Sofia конфигурации"
        else
            log_warning "Caller ID 79058615815 НЕ найден в Sofia конфигурации"
        fi
    else
        log_error "Sofia конфигурация не найдена"
    fi
else
    log_error "Директория freeswitch/conf не найдена!"
fi

# 🎯 Рекомендации
echo ""
echo "🎯 РЕКОМЕНДАЦИИ:"
echo "================"

# Определяем тип установки
HAS_IMAGES=$(docker images | grep -i freeswitch | wc -l)
HAS_CONTAINERS=$(docker ps -a | grep -i freeswitch | wc -l)
HAS_BUILD_CONFIG=$(grep -c "build:" docker-compose.yml 2>/dev/null || echo "0")

if [ "$HAS_CONTAINERS" -gt 0 ]; then
    log_success "✅ FreeSWITCH контейнеры найдены - используйте update-config-only.sh"
    echo ""
    echo "💡 Рекомендуемые команды:"
    echo "   ./update-config-only.sh                    # Быстрое обновление БЕЗ пересборки"
    echo "   docker logs -f \$(docker ps --format '{{.Names}}' | grep freeswitch)"
    echo ""
elif [ "$HAS_IMAGES" -gt 0 ]; then
    log_info "📦 Образы FreeSWITCH найдены, но контейнеры не запущены"
    echo ""
    echo "💡 Рекомендуемые команды:"
    echo "   docker compose up -d freeswitch           # Запустить FreeSWITCH"
    echo "   ./update-config-only.sh                   # Затем обновить конфигурацию"
    echo ""
elif [ "$HAS_BUILD_CONFIG" -gt 0 ]; then
    log_warning "⚠️ Найдена конфигурация сборки из исходников (долго!)"
    echo ""
    echo "💡 Альтернативы:"
    echo "   1. Используйте готовый образ:"
    echo "      docker pull signalwire/freeswitch:latest"
    echo "      docker compose -f docker-compose.no-build.yml up -d freeswitch"
    echo ""
    echo "   2. Или выполните полную сборку (ДОЛГО!):"
    echo "      ./deploy-to-test-server.sh"
    echo ""
else
    log_info "🆕 Похоже на новую установку"
    echo ""
    echo "💡 Рекомендуемые команды:"
    echo "   docker pull signalwire/freeswitch:latest  # Скачать готовый образ"
    echo "   docker compose up -d                      # Запустить все сервисы"
    echo ""
fi

echo "📖 Дополнительная документация:"
echo "   • DEPLOYMENT_INSTRUCTIONS.md - инструкции по развертыванию"
echo "   • FREESWITCH_PROTOCOL_ERROR_FIX.md - техническая документация"
echo ""

log_success "🎉 Диагностика завершена!" 