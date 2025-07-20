#!/bin/bash

# 🔍 Диагностика и исправление проблем с SIP gateway
# Полная перезагрузка конфигурации FreeSWITCH

set -e

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

echo "🔍 ДИАГНОСТИКА И ИСПРАВЛЕНИЕ SIP GATEWAY"
echo "======================================="
echo ""

# Проверяем контейнер
if ! docker ps --filter "name=$CONTAINER_NAME" --filter "status=running" | grep -q "$CONTAINER_NAME"; then
    log_error "Контейнер $CONTAINER_NAME не запущен!"
    exit 1
fi

log_success "Контейнер $CONTAINER_NAME найден"

# ЭТАП 1: Диагностика текущего состояния
echo ""
echo "📊 ЭТАП 1: ТЕКУЩЕЕ СОСТОЯНИЕ"
echo "============================="

log_info "Текущие SIP профили:"
docker exec "$CONTAINER_NAME" fs_cli -x "sofia status" 2>/dev/null || log_error "Ошибка получения статуса Sofia"

echo ""
log_info "Текущие SIP шлюзы:"
docker exec "$CONTAINER_NAME" fs_cli -x "sofia status gateway" 2>/dev/null || log_error "Ошибка получения статуса gateway"

echo ""
log_info "Проверяем конфигурацию sofia.conf.xml в контейнере:"
if docker exec "$CONTAINER_NAME" ls -la /usr/local/freeswitch/conf/autoload_configs/sofia.conf.xml 2>/dev/null; then
    log_success "sofia.conf.xml существует"
    # Проверяем содержит ли external профиль
    if docker exec "$CONTAINER_NAME" grep -q "profile name=\"external\"" /usr/local/freeswitch/conf/autoload_configs/sofia.conf.xml 2>/dev/null; then
        log_success "External профиль найден в конфигурации"
    else
        log_error "External профиль НЕ найден в конфигурации!"
    fi
    
    if docker exec "$CONTAINER_NAME" grep -q "gateway name=\"sip_trunk\"" /usr/local/freeswitch/conf/autoload_configs/sofia.conf.xml 2>/dev/null; then
        log_success "SIP trunk gateway найден в конфигурации"
    else
        log_error "SIP trunk gateway НЕ найден в конфигурации!"
    fi
else
    log_error "sofia.conf.xml НЕ существует в контейнере!"
fi

# ЭТАП 2: Проверяем локальную конфигурацию
echo ""
echo "📁 ЭТАП 2: ЛОКАЛЬНАЯ КОНФИГУРАЦИЯ"
echo "================================="

if [ -f "freeswitch/conf/autoload_configs/sofia.conf.xml" ]; then
    log_success "Локальная sofia.conf.xml найдена"
    
    if grep -q "62.141.121.197:5070" freeswitch/conf/autoload_configs/sofia.conf.xml 2>/dev/null; then
        log_success "Правильный адрес провайдера найден в локальной конфигурации"
    else
        log_warning "Адрес провайдера НЕ найден в локальной конфигурации"
    fi
else
    log_error "Локальная sofia.conf.xml НЕ найдена!"
    echo "💡 Нужно выполнить: ./fix-freeswitch-test-issues.sh"
fi

# ЭТАП 3: Принудительное исправление
echo ""
echo "🔧 ЭТАП 3: ПРИНУДИТЕЛЬНОЕ ИСПРАВЛЕНИЕ"
echo "==================================="

log_info "Выполняем git pull для получения последних обновлений..."
git pull origin main || log_warning "Ошибка git pull"

log_info "Выполняем fix-freeswitch-test-issues.sh..."
if [ -f "./fix-freeswitch-test-issues.sh" ]; then
    ./fix-freeswitch-test-issues.sh
    log_success "Скрипт выполнен"
else
    log_error "Скрипт fix-freeswitch-test-issues.sh не найден!"
    exit 1
fi

# ЭТАП 4: Принудительная перезагрузка Sofia
echo ""
echo "🔄 ЭТАП 4: ПРИНУДИТЕЛЬНАЯ ПЕРЕЗАГРУЗКА SOFIA"
echo "==========================================="

log_info "Останавливаем все SIP профили..."
docker exec "$CONTAINER_NAME" fs_cli -x "sofia profile internal stop" 2>/dev/null || true
docker exec "$CONTAINER_NAME" fs_cli -x "sofia profile external stop" 2>/dev/null || true

log_info "Выгружаем модуль Sofia..."
docker exec "$CONTAINER_NAME" fs_cli -x "unload mod_sofia" 2>/dev/null || true

log_info "Ожидаем 5 секунд..."
sleep 5

log_info "Перезагружаем XML конфигурацию..."
docker exec "$CONTAINER_NAME" fs_cli -x "reloadxml" 2>/dev/null || true

log_info "Загружаем модуль Sofia..."
docker exec "$CONTAINER_NAME" fs_cli -x "load mod_sofia" 2>/dev/null || true

log_info "Ожидаем стабилизации (20 секунд)..."
sleep 20

# ЭТАП 5: Проверка результата
echo ""
echo "✅ ЭТАП 5: ПРОВЕРКА РЕЗУЛЬТАТА"
echo "============================="

log_info "Статус SIP профилей после исправления:"
SIP_STATUS=$(docker exec "$CONTAINER_NAME" fs_cli -x "sofia status" 2>/dev/null)
echo "$SIP_STATUS"

if echo "$SIP_STATUS" | grep -q "external.*RUNNING"; then
    log_success "✅ External профиль работает!"
else
    log_error "❌ External профиль НЕ работает"
fi

echo ""
log_info "Статус SIP шлюзов после исправления:"
GATEWAY_STATUS=$(docker exec "$CONTAINER_NAME" fs_cli -x "sofia status gateway" 2>/dev/null)
echo "$GATEWAY_STATUS"

if echo "$GATEWAY_STATUS" | grep -q "sip_trunk"; then
    log_success "✅ SIP trunk gateway найден!"
    
    if echo "$GATEWAY_STATUS" | grep -q "REGED"; then
        log_success "✅ SIP trunk зарегистрирован на провайдере!"
    else
        log_warning "⚠️ SIP trunk НЕ зарегистрирован (нужен пароль)"
    fi
else
    log_error "❌ SIP trunk gateway НЕ найден"
fi

# ЭТАП 6: Тестирование
echo ""
echo "🧪 ЭТАП 6: ТЕСТИРОВАНИЕ"
echo "======================="

log_info "Тест IVR меню..."
IVR_TEST=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate loopback/ivr_menu &echo" 2>&1)
if echo "$IVR_TEST" | grep -q "SUCCESS"; then
    log_success "✅ IVR меню работает"
else
    log_warning "⚠️ Проблемы с IVR: $IVR_TEST"
fi

echo ""
log_info "Тест SIP trunk (если зарегистрирован)..."
if echo "$GATEWAY_STATUS" | grep -q "REGED"; then
    TRUNK_TEST=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate sofia/gateway/sip_trunk/79001234567 &echo" 2>&1)
    if echo "$TRUNK_TEST" | grep -q "SUCCESS\|NORMAL_CLEARING"; then
        log_success "✅ SIP trunk работает"
    else
        log_warning "⚠️ Проблемы с SIP trunk: $TRUNK_TEST"
    fi
else
    log_warning "⚠️ SIP trunk не зарегистрирован, тест пропущен"
fi

# ЭТАП 7: Проверка логов на ошибки
echo ""
echo "📝 ЭТАП 7: АНАЛИЗ ЛОГОВ"
echo "======================="

log_info "Проверяем последние ошибки в логах:"
RECENT_ERRORS=$(docker logs --tail=50 "$CONTAINER_NAME" 2>&1 | grep -i "error\|fail\|warn" | tail -5 || echo "Критических ошибок не найдено")
echo "$RECENT_ERRORS"

echo ""
echo "🎯 РЕКОМЕНДАЦИИ"
echo "==============="

if echo "$GATEWAY_STATUS" | grep -q "sip_trunk"; then
    if echo "$GATEWAY_STATUS" | grep -q "REGED"; then
        log_success "🎉 SIP trunk полностью настроен и работает!"
        echo ""
        echo "✅ Можно тестировать звонки:"
        echo "   docker exec $CONTAINER_NAME fs_cli -x 'originate sofia/gateway/sip_trunk/79206054020 &transfer:ivr_menu'"
    else
        log_warning "⚠️ SIP trunk настроен, но не зарегистрирован"
        echo ""
        echo "💡 Нужно добавить пароль для SIP trunk:"
        echo "   1. Узнайте пароль у провайдера"
        echo "   2. Добавьте в переменную: export external_sip_password='ВАШ_ПАРОЛЬ'"
        echo "   3. Перезапустите: docker exec $CONTAINER_NAME fs_cli -x 'sofia profile external restart'"
    fi
else
    log_error "❌ SIP trunk НЕ настроен"
    echo ""
    echo "💡 Возможные причины:"
    echo "   1. Ошибка в конфигурации sofia.conf.xml"
    echo "   2. Модуль Sofia не загрузился"
    echo "   3. Нужна полная перезагрузка контейнера"
fi

echo ""
log_success "🎉 Диагностика завершена!" 