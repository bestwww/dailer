#!/bin/bash

# 🧪 Скрипт тестирования контейнера freeswitch-test
# Проверяет работоспособность и обновляет конфигурацию

set -e

# 🎯 Название контейнера
CONTAINER_NAME="freeswitch-test"

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

echo "🧪 ТЕСТИРОВАНИЕ КОНТЕЙНЕРА: $CONTAINER_NAME"
echo "============================================="
echo ""

# 🔍 ЭТАП 1: ПРОВЕРКА КОНТЕЙНЕРА
echo "🔍 ЭТАП 1: ПРОВЕРКА КОНТЕЙНЕРА"
echo "=============================="

# Проверяем существование контейнера
if ! docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    log_error "Контейнер $CONTAINER_NAME не найден!"
    echo ""
    echo "💡 Возможные причины:"
    echo "   • Контейнер был удален"
    echo "   • Неточное название контейнера"
    echo ""
    echo "🔍 Все контейнеры:"
    docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
    exit 1
fi

log_success "Контейнер $CONTAINER_NAME найден"

# Проверяем статус контейнера
CONTAINER_STATUS=$(docker ps -a --format "{{.Status}}" --filter "name=^${CONTAINER_NAME}$")
CONTAINER_IMAGE=$(docker ps -a --format "{{.Image}}" --filter "name=^${CONTAINER_NAME}$")

echo ""
log_info "Информация о контейнере:"
echo "  📦 Название: $CONTAINER_NAME"
echo "  🖼️  Образ: $CONTAINER_IMAGE"
echo "  🔄 Статус: $CONTAINER_STATUS"

# Проверяем запущен ли контейнер
if [[ "$CONTAINER_STATUS" == *"Up"* ]]; then
    log_success "Контейнер запущен"
    CONTAINER_RUNNING=true
else
    log_warning "Контейнер остановлен"
    CONTAINER_RUNNING=false
    
    echo ""
    log_info "Запускаем контейнер..."
    if docker start "$CONTAINER_NAME"; then
        log_success "Контейнер $CONTAINER_NAME запущен"
        CONTAINER_RUNNING=true
        
        # Ждем запуска FreeSWITCH
        log_info "Ожидаем запуска FreeSWITCH (30 секунд)..."
        sleep 30
    else
        log_error "Не удалось запустить контейнер $CONTAINER_NAME"
        exit 1
    fi
fi

echo ""
echo "🔍 ЭТАП 2: ПРОВЕРКА FREESWITCH"
echo "============================="

if [ "$CONTAINER_RUNNING" = true ]; then
    # Проверяем наличие fs_cli
    if docker exec "$CONTAINER_NAME" which fs_cli >/dev/null 2>&1; then
        log_success "FreeSWITCH CLI найден"
        
        # Проверяем статус FreeSWITCH
        echo ""
        log_info "Проверяем статус FreeSWITCH..."
        if docker exec "$CONTAINER_NAME" fs_cli -x "status" 2>/dev/null | grep -q "UP"; then
            log_success "FreeSWITCH работает!"
            
            # Получаем версию
            FS_VERSION=$(docker exec "$CONTAINER_NAME" fs_cli -x "version" 2>/dev/null | head -1 || echo "Неизвестно")
            echo "  📋 Версия: $FS_VERSION"
            
        else
            log_warning "FreeSWITCH не отвечает"
            echo ""
            log_info "Пробуем перезапустить FreeSWITCH в контейнере..."
            docker exec "$CONTAINER_NAME" pkill -f freeswitch || true
            sleep 5
            docker restart "$CONTAINER_NAME"
            sleep 30
            
            if docker exec "$CONTAINER_NAME" fs_cli -x "status" 2>/dev/null | grep -q "UP"; then
                log_success "FreeSWITCH запущен после перезапуска"
            else
                log_error "FreeSWITCH не запускается"
            fi
        fi
        
    else
        log_error "FreeSWITCH CLI не найден в контейнере"
        echo "💡 Возможно это не контейнер FreeSWITCH"
    fi
else
    log_error "Не можем проверить FreeSWITCH - контейнер не запущен"
fi

echo ""
echo "🔍 ЭТАП 3: ПРОВЕРКА КОНФИГУРАЦИИ"
echo "================================"

# Проверяем текущий Caller ID
log_info "Проверяем текущую конфигурацию Caller ID..."

# Проверяем в контейнере
CURRENT_CALLER_ID=""
if docker exec "$CONTAINER_NAME" find /usr/local/freeswitch/conf -name "*.xml" -exec grep -l "79058615815" {} \; 2>/dev/null | head -1 >/dev/null; then
    log_success "Новый Caller ID (79058615815) уже настроен в контейнере!"
    CALLER_ID_UPDATED=true
else
    log_warning "Новый Caller ID (79058615815) не найден в контейнере"
    CALLER_ID_UPDATED=false
    
    # Ищем старые Caller ID
    OLD_CALLER_IDS=$(docker exec "$CONTAINER_NAME" grep -r "caller_id_number" /usr/local/freeswitch/conf/ 2>/dev/null | grep -v "79058615815" | head -3 || echo "")
    if [ -n "$OLD_CALLER_IDS" ]; then
        echo ""
        log_info "Найдены старые Caller ID в контейнере:"
        echo "$OLD_CALLER_IDS"
    fi
fi

# Проверяем локальные файлы конфигурации
echo ""
log_info "Проверяем локальную конфигурацию в freeswitch/conf/..."
if [ -d "freeswitch/conf" ]; then
    if grep -r "79058615815" freeswitch/conf/ 2>/dev/null | head -1 >/dev/null; then
        log_success "Новый Caller ID найден в локальных файлах"
        LOCAL_CONFIG_UPDATED=true
    else
        log_warning "Новый Caller ID не найден в локальных файлах"
        LOCAL_CONFIG_UPDATED=false
    fi
else
    log_warning "Локальная директория freeswitch/conf не найдена"
    LOCAL_CONFIG_UPDATED=false
fi

echo ""
echo "🔍 ЭТАП 4: ПРОВЕРКА СЕТИ И ПОРТОВ"
echo "================================="

# Проверяем порты
log_info "Проверяем открытые порты контейнера..."
CONTAINER_PORTS=$(docker port "$CONTAINER_NAME" 2>/dev/null || echo "")
if [ -n "$CONTAINER_PORTS" ]; then
    log_success "Открытые порты:"
    echo "$CONTAINER_PORTS" | while read port; do
        echo "  🔌 $port"
    done
else
    log_warning "Открытые порты не найдены"
fi

# Проверяем SIP порт (5060)
echo ""
log_info "Проверяем SIP порт (5060)..."
if echo "$CONTAINER_PORTS" | grep -q "5060"; then
    log_success "SIP порт 5060 открыт"
else
    log_warning "SIP порт 5060 не открыт"
fi

# Проверяем ESL порт (8021)
log_info "Проверяем ESL порт (8021)..."
if echo "$CONTAINER_PORTS" | grep -q "8021"; then
    log_success "ESL порт 8021 открыт"
else
    log_warning "ESL порт 8021 не открыт"
fi

echo ""
echo "🔍 ЭТАП 5: ТЕСТ ПОДКЛЮЧЕНИЯ"
echo "==========================="

# Тест ESL подключения
log_info "Тестируем ESL подключение..."
if docker exec "$CONTAINER_NAME" fs_cli -x "show status" 2>/dev/null >/dev/null; then
    log_success "ESL подключение работает"
    
    # Показываем краткую информацию
    echo ""
    log_info "Краткая информация FreeSWITCH:"
    docker exec "$CONTAINER_NAME" fs_cli -x "show status" 2>/dev/null | head -5 || true
    
else
    log_warning "ESL подключение не работает"
fi

echo ""
echo "🎯 РЕКОМЕНДАЦИИ И СЛЕДУЮЩИЕ ШАГИ"
echo "================================"

if [ "$CALLER_ID_UPDATED" = false ] || [ "$LOCAL_CONFIG_UPDATED" = false ]; then
    echo ""
    log_warning "⚠️ ТРЕБУЕТСЯ ОБНОВЛЕНИЕ CALLER ID"
    echo ""
    echo "💡 Выполните следующие команды:"
    echo ""
    echo "# 1. Обновить локальную конфигурацию"
    echo "./update-config-only.sh"
    echo ""
    echo "# 2. Скопировать конфигурацию в контейнер"
    echo "docker cp freeswitch/conf/. $CONTAINER_NAME:/usr/local/freeswitch/conf/"
    echo ""
    echo "# 3. Перезагрузить конфигурацию FreeSWITCH"
    echo "docker exec $CONTAINER_NAME fs_cli -x 'reloadxml'"
    echo ""
    echo "# 4. Проверить результат"
    echo "docker exec $CONTAINER_NAME fs_cli -x 'show status'"
    echo ""
else
    log_success "✅ CALLER ID УЖЕ ОБНОВЛЕН!"
fi

echo ""
echo "🧪 КОМАНДЫ ДЛЯ ТЕСТИРОВАНИЯ:"
echo "============================"
echo ""
echo "# Проверить статус FreeSWITCH:"
echo "docker exec $CONTAINER_NAME fs_cli -x 'status'"
echo ""
echo "# Посмотреть логи:"
echo "docker logs -f $CONTAINER_NAME"
echo ""
echo "# Подключиться к FreeSWITCH CLI:"
echo "docker exec -it $CONTAINER_NAME fs_cli"
echo ""
echo "# Проверить SIP профили:"
echo "docker exec $CONTAINER_NAME fs_cli -x 'sofia status'"
echo ""
echo "# Проверить SIP шлюзы:"
echo "docker exec $CONTAINER_NAME fs_cli -x 'sofia status gateway'"
echo ""
echo "# Остановить/запустить контейнер:"
echo "docker stop $CONTAINER_NAME"
echo "docker start $CONTAINER_NAME"
echo ""

# Сохраняем имя контейнера для будущего использования
echo "export FREESWITCH_CONTAINER=$CONTAINER_NAME" > .freeswitch_container
log_success "Имя контейнера сохранено в .freeswitch_container"

echo ""
log_success "🎉 Тестирование контейнера $CONTAINER_NAME завершено!"

echo ""
echo "📊 ИТОГОВЫЙ СТАТУС:"
echo "=================="
if [ "$CONTAINER_RUNNING" = true ]; then
    echo "✅ Контейнер: Запущен"
else
    echo "❌ Контейнер: Остановлен"
fi

if docker exec "$CONTAINER_NAME" fs_cli -x "status" 2>/dev/null | grep -q "UP"; then
    echo "✅ FreeSWITCH: Работает"
else
    echo "❌ FreeSWITCH: Не работает"
fi

if [ "$CALLER_ID_UPDATED" = true ]; then
    echo "✅ Caller ID: Обновлен (79058615815)"
else
    echo "⚠️ Caller ID: Требует обновления"
fi

echo ""
echo "📞 ГОТОВ К ТЕСТИРОВАНИЮ ЗВОНКОВ!" 