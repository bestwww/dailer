#!/bin/bash

# 🔧 Скрипт исправления проблем FreeSWITCH
# Автор: AI Assistant
# Назначение: Диагностика и исправление проблем с Sofia SIP и SIP транком
# Использование: ./fix-freeswitch-issues.sh

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Конфигурация
FREESWITCH_CONTAINER="dialer_freeswitch"
SIP_TRUNK_IP="62.141.121.197"
SIP_TRUNK_PORT="5070"

# Функция логирования
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        INFO)  echo -e "${GREEN}[$timestamp] INFO:${NC} $message" ;;
        WARN)  echo -e "${YELLOW}[$timestamp] WARN:${NC} $message" ;;
        ERROR) echo -e "${RED}[$timestamp] ERROR:${NC} $message" ;;
        DEBUG) echo -e "${BLUE}[$timestamp] DEBUG:${NC} $message" ;;
        TITLE) echo -e "${BOLD}${BLUE}[$timestamp]${NC} ${BOLD}$message${NC}" ;;
        SUCCESS) echo -e "${BOLD}${GREEN}[$timestamp] SUCCESS:${NC} ${BOLD}$message${NC}" ;;
        *)     echo "[$timestamp] $level: $message" ;;
    esac
}

# Проверка логов FreeSWITCH на ошибки
check_freeswitch_logs() {
    log TITLE "🔍 Проверка логов FreeSWITCH на ошибки..."
    
    # Получаем последние логи
    local logs=$(docker logs "$FREESWITCH_CONTAINER" --tail=100 2>&1)
    
    # Ищем критические ошибки
    local errors=$(echo "$logs" | grep -i -E "(error|failed|fatal|critical)" | tail -10)
    
    if [ -n "$errors" ]; then
        log WARN "⚠️ Обнаружены ошибки в логах FreeSWITCH:"
        echo "$errors" | while read -r line; do
            log WARN "  $line"
        done
    else
        log INFO "✅ Критических ошибок в логах не найдено"
    fi
    
    # Ищем упоминания Sofia
    local sofia_logs=$(echo "$logs" | grep -i sofia | tail -5)
    
    if [ -n "$sofia_logs" ]; then
        log INFO "📋 Последние логи Sofia SIP:"
        echo "$sofia_logs" | while read -r line; do
            log DEBUG "  $line"
        done
    fi
}

# Проверка конфигурационных файлов
check_config_files() {
    log TITLE "📁 Проверка конфигурационных файлов..."
    
    # Проверка sofia.conf.xml
    if [ -f "freeswitch/conf/autoload_configs/sofia.conf.xml" ]; then
        log INFO "✅ sofia.conf.xml найден"
        
        if grep -q "sip_trunk" freeswitch/conf/autoload_configs/sofia.conf.xml; then
            log INFO "✅ Gateway sip_trunk найден в конфигурации"
        else
            log ERROR "❌ Gateway sip_trunk НЕ найден в конфигурации"
            return 1
        fi
        
        if grep -q "$SIP_TRUNK_IP:$SIP_TRUNK_PORT" freeswitch/conf/autoload_configs/sofia.conf.xml; then
            log INFO "✅ IP и порт SIP транка найдены в конфигурации"
        else
            log ERROR "❌ IP и порт SIP транка НЕ найдены в конфигурации"
            return 1
        fi
    else
        log ERROR "❌ sofia.conf.xml не найден"
        return 1
    fi
    
    # Проверка vars.xml
    if [ -f "freeswitch/conf/vars.xml" ]; then
        log INFO "✅ vars.xml найден"
    else
        log ERROR "❌ vars.xml не найден"
        return 1
    fi
    
    # Проверка dialplan
    if [ -f "freeswitch/conf/dialplan/default.xml" ]; then
        log INFO "✅ dialplan/default.xml найден"
        
        if grep -q "sofia/gateway/sip_trunk" freeswitch/conf/dialplan/default.xml; then
            log INFO "✅ Маршрутизация через sip_trunk найдена в dialplan"
        else
            log ERROR "❌ Маршрутизация через sip_trunk НЕ найдена в dialplan"
            return 1
        fi
    else
        log ERROR "❌ dialplan/default.xml не найден"
        return 1
    fi
    
    return 0
}

# Проверка статуса Sofia профилей
check_sofia_status() {
    log TITLE "⚙️ Проверка статуса Sofia SIP..."
    
    # Проверка общего статуса Sofia
    local sofia_status=$(docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia status" 2>/dev/null || echo "FAILED")
    
    if [ "$sofia_status" = "FAILED" ]; then
        log ERROR "❌ Не удается получить статус Sofia"
        return 1
    fi
    
    log DEBUG "Sofia Status:"
    echo "$sofia_status" | while read -r line; do
        log DEBUG "  $line"
    done
    
    # Проверка профиля external
    if echo "$sofia_status" | grep -q "external"; then
        log INFO "✅ Профиль external найден"
        
        # Проверка статуса профиля
        if echo "$sofia_status" | grep "external" | grep -q "RUNNING"; then
            log INFO "✅ Профиль external запущен"
        else
            log WARN "⚠️ Профиль external не в состоянии RUNNING"
        fi
    else
        log ERROR "❌ Профиль external НЕ найден"
        return 1
    fi
    
    # Проверка gateway
    local gateway_status=$(docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia status gateway sip_trunk" 2>/dev/null || echo "FAILED")
    
    if [ "$gateway_status" = "FAILED" ] || echo "$gateway_status" | grep -q "Invalid"; then
        log ERROR "❌ Gateway sip_trunk не найден или недоступен"
        return 1
    else
        log INFO "✅ Gateway sip_trunk найден"
        log DEBUG "Gateway Status:"
        echo "$gateway_status" | while read -r line; do
            log DEBUG "  $line"
        done
    fi
    
    return 0
}

# Перезагрузка конфигурации FreeSWITCH
reload_freeswitch_config() {
    log TITLE "🔄 Перезагрузка конфигурации FreeSWITCH..."
    
    # Перезагрузка XML конфигурации
    log INFO "Перезагрузка XML конфигурации..."
    if docker exec "$FREESWITCH_CONTAINER" fs_cli -x "reloadxml" >/dev/null 2>&1; then
        log INFO "✅ XML конфигурация перезагружена"
    else
        log ERROR "❌ Ошибка при перезагрузке XML конфигурации"
        return 1
    fi
    
    sleep 2
    
    # Перезапуск Sofia профиля external
    log INFO "Перезапуск Sofia профиля external..."
    if docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia profile external restart" >/dev/null 2>&1; then
        log INFO "✅ Профиль external перезапущен"
    else
        log ERROR "❌ Ошибка при перезапуске профиля external"
        return 1
    fi
    
    # Ожидание загрузки
    log INFO "Ожидание загрузки конфигурации..."
    sleep 5
    
    return 0
}

# Полный перезапуск FreeSWITCH контейнера
restart_freeswitch_container() {
    log TITLE "🔄 Полный перезапуск FreeSWITCH контейнера..."
    
    # Остановка контейнера
    log INFO "Остановка FreeSWITCH контейнера..."
    if docker-compose stop freeswitch; then
        log INFO "✅ FreeSWITCH остановлен"
    else
        log ERROR "❌ Ошибка при остановке FreeSWITCH"
        return 1
    fi
    
    sleep 3
    
    # Запуск контейнера
    log INFO "Запуск FreeSWITCH контейнера..."
    if docker-compose up -d freeswitch; then
        log INFO "✅ FreeSWITCH запущен"
    else
        log ERROR "❌ Ошибка при запуске FreeSWITCH"
        return 1
    fi
    
    # Ожидание полной загрузки
    log INFO "Ожидание полной загрузки FreeSWITCH..."
    sleep 15
    
    # Проверка что контейнер запустился
    if docker ps --filter "name=$FREESWITCH_CONTAINER" --filter "status=running" | grep -q "$FREESWITCH_CONTAINER"; then
        log INFO "✅ FreeSWITCH контейнер запущен и работает"
    else
        log ERROR "❌ FreeSWITCH контейнер не запустился"
        return 1
    fi
    
    # Проверка что FreeSWITCH отвечает на команды
    local retries=0
    while [ $retries -lt 10 ]; do
        if docker exec "$FREESWITCH_CONTAINER" fs_cli -x "status" >/dev/null 2>&1; then
            log INFO "✅ FreeSWITCH отвечает на команды"
            break
        fi
        sleep 2
        ((retries++))
    done
    
    if [ $retries -eq 10 ]; then
        log ERROR "❌ FreeSWITCH не отвечает на команды после перезапуска"
        return 1
    fi
    
    return 0
}

# Исправление сетевых проблем Docker
fix_docker_network() {
    log TITLE "🌐 Исправление сетевых проблем Docker..."
    
    # Проверка Docker сети
    if docker network inspect dialer_dialer_network >/dev/null 2>&1; then
        log INFO "✅ Docker сеть dialer_dialer_network существует"
    else
        log WARN "⚠️ Docker сеть dialer_dialer_network не найдена"
        
        # Попытка пересоздать сеть
        log INFO "Пересоздание Docker сети..."
        docker-compose down 2>/dev/null || true
        docker-compose up -d 2>/dev/null || true
    fi
    
    # Проверка доступности внешнего IP из контейнера
    log INFO "Проверка сетевой доступности из контейнера..."
    if docker exec "$FREESWITCH_CONTAINER" ping -c 2 "$SIP_TRUNK_IP" >/dev/null 2>&1; then
        log INFO "✅ $SIP_TRUNK_IP доступен из контейнера FreeSWITCH"
    else
        log WARN "⚠️ $SIP_TRUNK_IP недоступен из контейнера FreeSWITCH"
        log INFO "Это может быть связано с настройками сети провайдера"
        
        # Проверка DNS
        if docker exec "$FREESWITCH_CONTAINER" nslookup google.com >/dev/null 2>&1; then
            log INFO "✅ DNS работает в контейнере"
        else
            log WARN "⚠️ Проблемы с DNS в контейнере"
        fi
    fi
}

# Тестирование после исправлений
test_after_fixes() {
    log TITLE "🧪 Тестирование после исправлений..."
    
    # Проверка Sofia статуса
    if check_sofia_status; then
        log SUCCESS "✅ Sofia SIP работает корректно"
    else
        log ERROR "❌ Проблемы с Sofia SIP все еще существуют"
        return 1
    fi
    
    # Тестовый звонок
    log INFO "Попытка тестового звонка..."
    local test_result=$(docker exec "$FREESWITCH_CONTAINER" fs_cli -x "originate {call_timeout=5,hangup_after_bridge=true}sofia/gateway/sip_trunk/79001234567 &echo" 2>&1)
    
    if echo "$test_result" | grep -qi "INVALID_GATEWAY"; then
        log ERROR "❌ Gateway все еще недоступен"
        return 1
    elif echo "$test_result" | grep -qi "success\|progress\|ringing"; then
        log SUCCESS "✅ Тестовый звонок инициирован успешно"
    else
        log WARN "⚠️ Неопределенный результат тестового звонка"
        log DEBUG "Результат: $test_result"
    fi
    
    return 0
}

# Основная функция исправления
main_fix() {
    log TITLE "🔧 ИСПРАВЛЕНИЕ ПРОБЛЕМ FREESWITCH"
    
    local step=1
    
    # Шаг 1: Проверка конфигурации
    log TITLE "Шаг $((step++)): Проверка конфигурационных файлов"
    if ! check_config_files; then
        log ERROR "Критические проблемы с конфигурацией. Остановка."
        return 1
    fi
    
    # Шаг 2: Проверка логов
    log TITLE "Шаг $((step++)): Анализ логов FreeSWITCH"
    check_freeswitch_logs
    
    # Шаг 3: Проверка статуса Sofia
    log TITLE "Шаг $((step++)): Проверка статуса Sofia SIP"
    if check_sofia_status; then
        log SUCCESS "Sofia SIP работает корректно, проблем не найдено"
        return 0
    fi
    
    # Шаг 4: Попытка перезагрузки конфигурации
    log TITLE "Шаг $((step++)): Перезагрузка конфигурации"
    if reload_freeswitch_config && check_sofia_status; then
        log SUCCESS "Проблема решена перезагрузкой конфигурации"
        test_after_fixes
        return 0
    fi
    
    # Шаг 5: Полный перезапуск контейнера
    log TITLE "Шаг $((step++)): Полный перезапуск контейнера FreeSWITCH"
    if restart_freeswitch_container && check_sofia_status; then
        log SUCCESS "Проблема решена перезапуском контейнера"
        test_after_fixes
        return 0
    fi
    
    # Шаг 6: Исправление сетевых проблем
    log TITLE "Шаг $((step++)): Исправление сетевых проблем"
    fix_docker_network
    
    # Финальная проверка
    log TITLE "Финальная проверка"
    if test_after_fixes; then
        log SUCCESS "🎉 ВСЕ ПРОБЛЕМЫ ИСПРАВЛЕНЫ!"
        return 0
    else
        log ERROR "❌ Не удалось полностью исправить все проблемы"
        return 1
    fi
}

# Запуск
log TITLE "🔧 Диагностика и исправление FreeSWITCH"
main_fix 