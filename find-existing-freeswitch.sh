#!/bin/bash

# 🔍 Скрипт поиска существующего контейнера FreeSWITCH на тестовом сервере
# Помогает найти уже настроенный контейнер без пересборки

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

echo "🔍 ПОИСК СУЩЕСТВУЮЩЕГО КОНТЕЙНЕРА FREESWITCH"
echo "=============================================="
echo ""

# 🐳 Проверяем Docker
if ! command -v docker >/dev/null 2>&1; then
    log_error "Docker не установлен!"
    exit 1
fi

log_success "Docker доступен: $(docker --version | cut -d' ' -f3)"

echo ""
echo "🔍 ШАГ 1: ПОИСК КОНТЕЙНЕРОВ FREESWITCH"
echo "======================================"

# 📋 Все контейнеры с freeswitch в названии
echo ""
log_info "Ищем контейнеры с 'freeswitch' в названии..."
FREESWITCH_CONTAINERS=$(docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | grep -i freeswitch || echo "")

if [ -n "$FREESWITCH_CONTAINERS" ]; then
    log_success "Найдены контейнеры FreeSWITCH:"
    echo "НАЗВАНИЕ                  ОБРАЗ                    СТАТУС               ПОРТЫ"
    echo "=========================================================================="
    echo "$FREESWITCH_CONTAINERS"
    echo ""
else
    log_warning "Контейнеры с 'freeswitch' в названии не найдены"
fi

# 📋 Поиск по образам с freeswitch
echo ""
log_info "Ищем контейнеры по образам с 'freeswitch'..."
FREESWITCH_BY_IMAGE=$(docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | grep -i "freeswitch\|signalwire" || echo "")

if [ -n "$FREESWITCH_BY_IMAGE" ]; then
    log_success "Найдены контейнеры по образам FreeSWITCH/SignalWire:"
    echo "НАЗВАНИЕ                  ОБРАЗ                    СТАТУС               ПОРТЫ"
    echo "=========================================================================="
    echo "$FREESWITCH_BY_IMAGE"
    echo ""
else
    log_warning "Контейнеры с образами FreeSWITCH/SignalWire не найдены"
fi

# 📋 Поиск по портам SIP (5060)
echo ""
log_info "Ищем контейнеры использующие SIP порт 5060..."
SIP_CONTAINERS=$(docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | grep ":5060" || echo "")

if [ -n "$SIP_CONTAINERS" ]; then
    log_success "Найдены контейнеры с портом 5060 (SIP):"
    echo "НАЗВАНИЕ                  ОБРАЗ                    СТАТУС               ПОРТЫ"
    echo "=========================================================================="
    echo "$SIP_CONTAINERS"
    echo ""
else
    log_warning "Контейнеры с портом 5060 не найдены"
fi

# 📋 Поиск по названию проекта (dialer, dailer)
echo ""
log_info "Ищем контейнеры проекта (dialer, dailer)..."
PROJECT_CONTAINERS=$(docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | grep -i -E "dialer|dailer" || echo "")

if [ -n "$PROJECT_CONTAINERS" ]; then
    log_success "Найдены контейнеры проекта:"
    echo "НАЗВАНИЕ                  ОБРАЗ                    СТАТУС               ПОРТЫ"
    echo "=========================================================================="
    echo "$PROJECT_CONTAINERS"
    echo ""
fi

echo ""
echo "🔍 ШАГ 2: АНАЛИЗ НАЙДЕННЫХ КОНТЕЙНЕРОВ"
echo "======================================="

# 🎯 Определяем наиболее вероятные кандидаты
echo ""
log_info "Определяем наиболее подходящие контейнеры..."

# Ищем контейнеры по приоритету
CANDIDATES=()

# Приоритет 1: dialer_freeswitch
if docker ps -a --format "{{.Names}}" | grep -q "^dialer_freeswitch$"; then
    CANDIDATES+=("dialer_freeswitch")
fi

# Приоритет 2: dailer_freeswitch (возможная опечатка)
if docker ps -a --format "{{.Names}}" | grep -q "^dailer_freeswitch$"; then
    CANDIDATES+=("dailer_freeswitch")
fi

# Приоритет 3: просто freeswitch
if docker ps -a --format "{{.Names}}" | grep -q "^freeswitch$"; then
    CANDIDATES+=("freeswitch")
fi

# Приоритет 4: любой с freeswitch в названии
while IFS= read -r container; do
    if [ -n "$container" ] && [[ ! " ${CANDIDATES[@]} " =~ " $container " ]]; then
        CANDIDATES+=("$container")
    fi
done < <(docker ps -a --format "{{.Names}}" | grep -i freeswitch)

echo ""
if [ ${#CANDIDATES[@]} -gt 0 ]; then
    log_success "Найдены кандидаты (по приоритету):"
    for i in "${!CANDIDATES[@]}"; do
        CONTAINER="${CANDIDATES[$i]}"
        STATUS=$(docker ps -a --format "{{.Status}}" --filter "name=^${CONTAINER}$")
        IMAGE=$(docker ps -a --format "{{.Image}}" --filter "name=^${CONTAINER}$")
        echo "  $((i+1)). $CONTAINER ($STATUS) - $IMAGE"
    done
    echo ""
    
    # 🔍 Проверяем топовый кандидат
    TOP_CANDIDATE="${CANDIDATES[0]}"
    log_info "Проверяем топовый кандидат: $TOP_CANDIDATE"
    
    # Проверяем может ли контейнер быть FreeSWITCH
    if docker exec "$TOP_CANDIDATE" which fs_cli >/dev/null 2>&1; then
        log_success "✅ $TOP_CANDIDATE содержит FreeSWITCH (найден fs_cli)!"
        
        # Проверяем статус FreeSWITCH
        if docker exec "$TOP_CANDIDATE" fs_cli -x "status" 2>/dev/null | grep -q "UP"; then
            log_success "✅ FreeSWITCH в контейнере $TOP_CANDIDATE работает!"
        else
            log_warning "⚠️ FreeSWITCH в контейнере $TOP_CANDIDATE не отвечает"
        fi
        
        # Проверяем конфигурацию Caller ID
        if docker exec "$TOP_CANDIDATE" find /usr/local/freeswitch/conf -name "*.xml" -exec grep -l "79058615815" {} \; 2>/dev/null | head -1; then
            log_success "✅ Найден новый Caller ID (79058615815) в конфигурации!"
        else
            log_warning "⚠️ Новый Caller ID (79058615815) не найден, нужно обновление"
        fi
    else
        log_warning "⚠️ $TOP_CANDIDATE не содержит FreeSWITCH или недоступен"
    fi
else
    log_error "❌ Контейнеры FreeSWITCH не найдены!"
fi

echo ""
echo "🔍 ШАГ 3: ДОПОЛНИТЕЛЬНАЯ ИНФОРМАЦИЯ"
echo "==================================="

# 📦 Образы FreeSWITCH
echo ""
log_info "Доступные образы FreeSWITCH:"
docker images | head -1  # заголовок
docker images | grep -i -E "freeswitch|signalwire" || echo "Образы FreeSWITCH не найдены"

# 🔗 Сети
echo ""
log_info "Docker сети:"
docker network ls | grep -E "dialer|dailer|freeswitch" || log_warning "Специфичные сети не найдены"

# 💾 Тома
echo ""
log_info "Docker тома:"
docker volume ls | grep -E "dialer|dailer|freeswitch" || log_warning "Специфичные тома не найдены"

echo ""
echo "🎯 РЕКОМЕНДАЦИИ:"
echo "================"

if [ ${#CANDIDATES[@]} -gt 0 ]; then
    TOP_CANDIDATE="${CANDIDATES[0]}"
    echo ""
    log_success "✅ РЕКОМЕНДУЕМЫЙ КОНТЕЙНЕР: $TOP_CANDIDATE"
    echo ""
    echo "💡 Команды для работы с этим контейнером:"
    echo ""
    echo "# Проверить статус:"
    echo "docker ps -f name=$TOP_CANDIDATE"
    echo ""
    echo "# Проверить FreeSWITCH:"
    echo "docker exec $TOP_CANDIDATE fs_cli -x 'status'"
    echo ""
    echo "# Посмотреть логи:"
    echo "docker logs -f $TOP_CANDIDATE"
    echo ""
    echo "# Остановить/запустить:"
    echo "docker stop $TOP_CANDIDATE"
    echo "docker start $TOP_CANDIDATE"
    echo ""
    echo "# Обновить конфигурацию:"
    echo "./update-config-only.sh"
    echo ""
    
    # Создаем переменную окружения
    echo "export FREESWITCH_CONTAINER=$TOP_CANDIDATE" > .freeswitch_container
    log_success "Сохранено в файл .freeswitch_container для автоматического использования"
    
else
    echo ""
    log_warning "❌ FreeSWITCH контейнеры не найдены!"
    echo ""
    echo "💡 Возможные причины:"
    echo "   1. FreeSWITCH еще не был установлен"
    echo "   2. Контейнер был удален"
    echo "   3. Используется другое имя проекта"
    echo ""
    echo "💡 Рекомендуемые действия:"
    echo "   1. Проверить все контейнеры: docker ps -a"
    echo "   2. Установить FreeSWITCH: docker compose up -d freeswitch"
    echo "   3. Использовать готовый образ: docker pull signalwire/freeswitch:latest"
    echo ""
fi

echo ""
log_success "🎉 Поиск завершен!"
echo ""
echo "📖 Дополнительная помощь:"
echo "   • ./check-freeswitch-setup.sh - полная диагностика"
echo "   • ./update-config-only.sh - обновление конфигурации"
echo "   • QUICK_UPDATE_GUIDE.md - краткое руководство" 