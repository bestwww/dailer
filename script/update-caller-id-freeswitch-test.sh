#!/bin/bash

# 🔄 Скрипт обновления Caller ID для контейнера freeswitch-test
# Обновляет конфигурацию и применяет изменения без пересборки

set -e

# 🎯 Настройки
CONTAINER_NAME="freeswitch-test"
NEW_CALLER_ID="79058615815"

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

echo "🔄 ОБНОВЛЕНИЕ CALLER ID ДЛЯ КОНТЕЙНЕРА: $CONTAINER_NAME"
echo "Новый Caller ID: $NEW_CALLER_ID"
echo "======================================================="
echo ""

# 🔍 ЭТАП 1: ПРОВЕРКА КОНТЕЙНЕРА
echo "🔍 ЭТАП 1: ПРОВЕРКА КОНТЕЙНЕРА"
echo "=============================="

# Проверяем существование контейнера
if ! docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    log_error "Контейнер $CONTAINER_NAME не найден!"
    exit 1
fi

log_success "Контейнер $CONTAINER_NAME найден"

# Проверяем статус контейнера
CONTAINER_STATUS=$(docker ps -a --format "{{.Status}}" --filter "name=^${CONTAINER_NAME}$")

if [[ "$CONTAINER_STATUS" == *"Up"* ]]; then
    log_success "Контейнер запущен"
    CONTAINER_RUNNING=true
else
    log_warning "Контейнер остановлен, запускаем..."
    if docker start "$CONTAINER_NAME"; then
        log_success "Контейнер запущен"
        CONTAINER_RUNNING=true
        sleep 15  # Ждем запуска FreeSWITCH
    else
        log_error "Не удалось запустить контейнер"
        exit 1
    fi
fi

echo ""
echo "🔧 ЭТАП 2: ОБНОВЛЕНИЕ ЛОКАЛЬНОЙ КОНФИГУРАЦИИ"
echo "============================================"

# Проверяем наличие директории конфигурации
if [ ! -d "freeswitch/conf" ]; then
    log_error "Директория freeswitch/conf не найдена!"
    echo "💡 Убедитесь что вы находитесь в корне проекта"
    exit 1
fi

log_info "Обновляем локальные файлы конфигурации..."

# 1. Обновляем vars.xml
if [ -f "freeswitch/conf/vars.xml" ]; then
    log_info "Обновляем freeswitch/conf/vars.xml..."
    
    # Создаем резервную копию
    cp freeswitch/conf/vars.xml freeswitch/conf/vars.xml.backup.$(date +%s)
    
    # Обновляем все Caller ID переменные
    sed -i '' "s/<X-PRE-PROCESS cmd=\"set\" data=\"default_caller_id_number=[^\"]*\"/<X-PRE-PROCESS cmd=\"set\" data=\"default_caller_id_number=$NEW_CALLER_ID\"/g" freeswitch/conf/vars.xml
    sed -i '' "s/<X-PRE-PROCESS cmd=\"set\" data=\"outbound_caller_id_number=[^\"]*\"/<X-PRE-PROCESS cmd=\"set\" data=\"outbound_caller_id_number=$NEW_CALLER_ID\"/g" freeswitch/conf/vars.xml
    sed -i '' "s/<X-PRE-PROCESS cmd=\"set\" data=\"emergency_caller_id_number=[^\"]*\"/<X-PRE-PROCESS cmd=\"set\" data=\"emergency_caller_id_number=$NEW_CALLER_ID\"/g" freeswitch/conf/vars.xml
    
    log_success "vars.xml обновлен"
else
    log_warning "freeswitch/conf/vars.xml не найден"
fi

# 2. Обновляем dialplan/default.xml
if [ -f "freeswitch/conf/dialplan/default.xml" ]; then
    log_info "Обновляем freeswitch/conf/dialplan/default.xml..."
    
    # Создаем резервную копию
    cp freeswitch/conf/dialplan/default.xml freeswitch/conf/dialplan/default.xml.backup.$(date +%s)
    
    # Обновляем Caller ID в dialplan
    sed -i '' "s/caller_id_number=\"[^\"]*\"/caller_id_number=\"$NEW_CALLER_ID\"/g" freeswitch/conf/dialplan/default.xml
    sed -i '' "s/effective_caller_id_number=[^,}]*/effective_caller_id_number=$NEW_CALLER_ID/g" freeswitch/conf/dialplan/default.xml
    
    log_success "dialplan/default.xml обновлен"
else
    log_warning "freeswitch/conf/dialplan/default.xml не найден"
fi

# 3. Обновляем sofia.conf.xml
if [ -f "freeswitch/conf/autoload_configs/sofia.conf.xml" ]; then
    log_info "Обновляем freeswitch/conf/autoload_configs/sofia.conf.xml..."
    
    # Создаем резервную копию
    cp freeswitch/conf/autoload_configs/sofia.conf.xml freeswitch/conf/autoload_configs/sofia.conf.xml.backup.$(date +%s)
    
    # Обновляем Caller ID в SIP gateway
    sed -i '' "s/<param name=\"caller-id-in-from\" value=\"[^\"]*\"/<param name=\"caller-id-in-from\" value=\"$NEW_CALLER_ID\"/g" freeswitch/conf/autoload_configs/sofia.conf.xml
    sed -i '' "s/caller_id_number=[^,}]*/caller_id_number=$NEW_CALLER_ID/g" freeswitch/conf/autoload_configs/sofia.conf.xml
    
    log_success "sofia.conf.xml обновлен"
else
    log_warning "freeswitch/conf/autoload_configs/sofia.conf.xml не найден"
fi

echo ""
echo "📋 ЭТАП 3: КОПИРОВАНИЕ В КОНТЕЙНЕР"
echo "=================================="

log_info "Копируем обновленную конфигурацию в контейнер $CONTAINER_NAME..."

# Копируем всю конфигурацию в контейнер
if docker cp freeswitch/conf/. "$CONTAINER_NAME:/usr/local/freeswitch/conf/"; then
    log_success "Конфигурация скопирована в контейнер"
else
    log_error "Ошибка копирования конфигурации"
    exit 1
fi

echo ""
echo "🔄 ЭТАП 4: ПРИМЕНЕНИЕ ИЗМЕНЕНИЙ"
echo "==============================="

# Проверяем что FreeSWITCH запущен
if docker exec "$CONTAINER_NAME" fs_cli -x "status" 2>/dev/null | grep -q "UP"; then
    log_success "FreeSWITCH запущен, применяем конфигурацию..."
    
    # Перезагружаем XML конфигурацию
    log_info "Перезагружаем XML конфигурацию..."
    if docker exec "$CONTAINER_NAME" fs_cli -x "reloadxml" 2>/dev/null; then
        log_success "XML конфигурация перезагружена"
    else
        log_warning "Ошибка перезагрузки XML, попробуем перезапустить профили"
    fi
    
    # Перезапускаем SIP профили
    log_info "Перезапускаем SIP профили..."
    docker exec "$CONTAINER_NAME" fs_cli -x "sofia profile internal restart" 2>/dev/null || true
    docker exec "$CONTAINER_NAME" fs_cli -x "sofia profile external restart" 2>/dev/null || true
    
    # Ждем применения изменений
    log_info "Ожидаем применения изменений (10 секунд)..."
    sleep 10
    
else
    log_warning "FreeSWITCH не отвечает, перезапускаем контейнер..."
    
    # Перезапускаем контейнер
    docker restart "$CONTAINER_NAME"
    
    log_info "Ожидаем запуска FreeSWITCH (30 секунд)..."
    sleep 30
fi

echo ""
echo "✅ ЭТАП 5: ПРОВЕРКА РЕЗУЛЬТАТА"
echo "============================="

# Проверяем что FreeSWITCH работает
if docker exec "$CONTAINER_NAME" fs_cli -x "status" 2>/dev/null | grep -q "UP"; then
    log_success "FreeSWITCH работает после обновления"
    
    # Проверяем что новый Caller ID применился
    echo ""
    log_info "Проверяем применение нового Caller ID..."
    
    # Ищем новый Caller ID в конфигурации контейнера
    if docker exec "$CONTAINER_NAME" find /usr/local/freeswitch/conf -name "*.xml" -exec grep -l "$NEW_CALLER_ID" {} \; 2>/dev/null | head -1 >/dev/null; then
        log_success "✅ Новый Caller ID ($NEW_CALLER_ID) найден в конфигурации!"
        
        # Показываем файлы с новым Caller ID
        echo ""
        log_info "Файлы содержащие новый Caller ID:"
        docker exec "$CONTAINER_NAME" find /usr/local/freeswitch/conf -name "*.xml" -exec grep -l "$NEW_CALLER_ID" {} \; 2>/dev/null | head -5
        
    else
        log_warning "⚠️ Новый Caller ID не найден в конфигурации контейнера"
    fi
    
    # Проверяем SIP профили
    echo ""
    log_info "Статус SIP профилей:"
    docker exec "$CONTAINER_NAME" fs_cli -x "sofia status" 2>/dev/null | head -10 || log_warning "Не удалось получить статус SIP профилей"
    
else
    log_error "❌ FreeSWITCH не запускается после обновления"
    echo ""
    echo "💡 Рекомендуемые действия:"
    echo "   1. Проверить логи: docker logs -f $CONTAINER_NAME"
    echo "   2. Проверить конфигурацию: docker exec $CONTAINER_NAME fs_cli"
    echo "   3. Откатить изменения из резервных копий"
fi

echo ""
echo "🎯 КОМАНДЫ ДЛЯ ТЕСТИРОВАНИЯ"
echo "==========================="
echo ""
echo "# Проверить статус FreeSWITCH:"
echo "docker exec $CONTAINER_NAME fs_cli -x 'status'"
echo ""
echo "# Проверить SIP шлюзы:"
echo "docker exec $CONTAINER_NAME fs_cli -x 'sofia status gateway'"
echo ""
echo "# Посмотреть логи:"
echo "docker logs -f $CONTAINER_NAME"
echo ""
echo "# Подключиться к CLI:"
echo "docker exec -it $CONTAINER_NAME fs_cli"
echo ""

echo ""
log_success "🎉 Обновление Caller ID для контейнера $CONTAINER_NAME завершено!"
echo ""
echo "📞 Новый Caller ID: $NEW_CALLER_ID"
echo "🚀 Контейнер готов к тестированию звонков!" 