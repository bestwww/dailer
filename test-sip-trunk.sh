#!/bin/bash

# 🔗 Скрипт тестирования подключения к SIP транку
# Автор: AI Assistant
# Назначение: Проверка подключения FreeSWITCH к SIP транку 62.141.121.197:5070
# Использование: ./test-sip-trunk.sh [действие]

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Конфигурация
SIP_TRUNK_IP="62.141.121.197"
SIP_TRUNK_PORT="5070"
# Автоматическое определение контейнера FreeSWITCH (приоритет host networking)
FREESWITCH_CONTAINER=""
TEST_NUMBERS=("79001234567" "+79001234567" "79009876543")

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
        *)     echo "[$timestamp] $level: $message" ;;
    esac
}

# Автоматическое определение контейнера FreeSWITCH
detect_freeswitch_container() {
    # Приоритет: host networking контейнер
    if docker ps --filter "name=dialer_freeswitch_host" --filter "status=running" | grep -q "dialer_freeswitch_host"; then
        FREESWITCH_CONTAINER="dialer_freeswitch_host"
        return 0
    fi
    
    # Резерв: обычный контейнер
    if docker ps --filter "name=dialer_freeswitch" --filter "status=running" | grep -q "dialer_freeswitch"; then
        FREESWITCH_CONTAINER="dialer_freeswitch"
        return 0
    fi
    
    # Поиск любого freeswitch контейнера
    local found_container=$(docker ps --filter "name=freeswitch" --filter "status=running" --format "{{.Names}}" | head -1)
    if [ -n "$found_container" ]; then
        FREESWITCH_CONTAINER="$found_container"
        return 0
    fi
    
    return 1
}

# Проверка доступности FreeSWITCH
check_freeswitch() {
    log TITLE "🔍 Проверка FreeSWITCH..."
    
    # Автоматически определяем контейнер
    if ! detect_freeswitch_container; then
        log ERROR "FreeSWITCH контейнер не найден!"
        log INFO "Доступные контейнеры:"
        docker ps --filter "name=freeswitch" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" || true
        log INFO "Для host networking: ./manage-freeswitch-host.sh start"
        log INFO "Для обычной сети: docker-compose up -d freeswitch"
        return 1
    fi
    
    log INFO "✅ FreeSWITCH контейнер запущен: $FREESWITCH_CONTAINER"
    
    # Проверка статуса FreeSWITCH
    if docker exec "$FREESWITCH_CONTAINER" fs_cli -x "status" >/dev/null 2>&1; then
        log INFO "✅ FreeSWITCH отвечает на команды"
    else
        log ERROR "❌ FreeSWITCH не отвечает на fs_cli команды"
        return 1
    fi
    
    return 0
}

# Проверка сетевой доступности SIP транка
check_network_connectivity() {
    log TITLE "🌐 Проверка сетевой доступности SIP транка..."
    
    # Проверка доступности IP
    if ping -c 3 "$SIP_TRUNK_IP" >/dev/null 2>&1; then
        log INFO "✅ IP $SIP_TRUNK_IP доступен"
    else
        log WARN "⚠️ IP $SIP_TRUNK_IP недоступен по ping"
    fi
    
    # Проверка доступности порта
    if nc -z -v -w5 "$SIP_TRUNK_IP" "$SIP_TRUNK_PORT" 2>/dev/null; then
        log INFO "✅ Порт $SIP_TRUNK_PORT на $SIP_TRUNK_IP доступен"
    else
        log WARN "⚠️ Порт $SIP_TRUNK_PORT на $SIP_TRUNK_IP недоступен"
        log INFO "Это может быть нормально если SIP сервер отвечает только на SIP пакеты"
    fi
    
    # Проверка из контейнера FreeSWITCH
    log INFO "Проверка доступности из контейнера FreeSWITCH..."
    if docker exec "$FREESWITCH_CONTAINER" ping -c 2 "$SIP_TRUNK_IP" >/dev/null 2>&1; then
        log INFO "✅ $SIP_TRUNK_IP доступен из контейнера FreeSWITCH"
    else
        log WARN "⚠️ $SIP_TRUNK_IP недоступен из контейнера FreeSWITCH"
    fi
}

# Проверка конфигурации Sofia SIP
check_sofia_configuration() {
    log TITLE "⚙️ Проверка конфигурации Sofia SIP..."
    
    # Проверка загрузки профилей
    local profiles=$(docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia status" 2>/dev/null)
    
    if echo "$profiles" | grep -q "external"; then
        log INFO "✅ Профиль 'external' загружен"
    else
        log ERROR "❌ Профиль 'external' не загружен"
        return 1
    fi
    
    # Проверка gateway
    local gateways=$(docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia status gateway sip_trunk" 2>/dev/null)
    
    if echo "$gateways" | grep -q "sip_trunk"; then
        log INFO "✅ Gateway 'sip_trunk' найден"
        log DEBUG "Статус gateway:"
        echo "$gateways" | while read -r line; do
            log DEBUG "  $line"
        done
    else
        log ERROR "❌ Gateway 'sip_trunk' не найден или не загружен"
        log INFO "Попытка перезагрузки конфигурации..."
        docker exec "$FREESWITCH_CONTAINER" fs_cli -x "reloadxml" >/dev/null 2>&1
        docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia profile external restart" >/dev/null 2>&1
        sleep 5
        
        local gateways_retry=$(docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia status gateway sip_trunk" 2>/dev/null)
        if echo "$gateways_retry" | grep -q "sip_trunk"; then
            log INFO "✅ Gateway 'sip_trunk' загружен после перезагрузки"
        else
            log ERROR "❌ Gateway 'sip_trunk' все еще не доступен"
            return 1
        fi
    fi
}

# Тестирование исходящего звонка
test_outbound_call() {
    local test_number="$1"
    log TITLE "📞 Тестирование исходящего звонка на $test_number..."
    
    # Создаем уникальный UUID для звонка
    local call_uuid=$(uuidgen)
    
    log INFO "Инициирование тестового звонка..."
    log DEBUG "UUID звонка: $call_uuid"
    
    # Команда для исходящего звонка
    local originate_cmd="originate {call_timeout=10,hangup_after_bridge=true}sofia/gateway/sip_trunk/${test_number} &echo"
    
    log DEBUG "Команда: $originate_cmd"
    
    # Выполняем звонок
    local call_result=$(docker exec "$FREESWITCH_CONTAINER" fs_cli -x "$originate_cmd" 2>&1)
    
    log DEBUG "Результат звонка:"
    echo "$call_result" | while read -r line; do
        log DEBUG "  $line"
    done
    
    # Анализ результата
    if echo "$call_result" | grep -qi "success"; then
        log INFO "✅ Тестовый звонок успешно инициирован"
        return 0
    elif echo "$call_result" | grep -qi "timeout"; then
        log WARN "⚠️ Тайм-аут при попытке звонка"
        return 1
    elif echo "$call_result" | grep -qi "no route"; then
        log ERROR "❌ Нет маршрута для номера $test_number"
        return 1
    elif echo "$call_result" | grep -qi "gateway.*down"; then
        log ERROR "❌ Gateway недоступен"
        return 1
    else
        log WARN "⚠️ Неопределенный результат звонка"
        return 1
    fi
}

# Мониторинг SIP трафика
monitor_sip_traffic() {
    log TITLE "📊 Мониторинг SIP трафика..."
    
    log INFO "Включение SIP трейсинга..."
    docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia global siptrace on" >/dev/null 2>&1
    
    log INFO "Мониторинг активен. Выполните тестовый звонок в другом терминале."
    log INFO "Нажмите Ctrl+C для остановки мониторинга."
    
    # Мониторинг логов в реальном времени
    docker logs -f "$FREESWITCH_CONTAINER" 2>&1 | grep -i sip | while read -r line; do
        log DEBUG "SIP: $line"
    done
}

# Диагностика проблем
diagnose_issues() {
    log TITLE "🩺 Диагностика проблем с SIP транком..."
    
    # Проверка конфигурационных файлов
    log INFO "Проверка конфигурации sofia.conf.xml..."
    if grep -q "62.141.121.197:5070" freeswitch/conf/autoload_configs/sofia.conf.xml; then
        log INFO "✅ IP и порт SIP транка найдены в конфигурации"
    else
        log ERROR "❌ IP и порт SIP транка НЕ найдены в конфигурации"
    fi
    
    # Проверка dialplan
    log INFO "Проверка dialplan..."
    if grep -q "sofia/gateway/sip_trunk" freeswitch/conf/dialplan/default.xml; then
        log INFO "✅ Маршрутизация через sip_trunk найдена в dialplan"
    else
        log ERROR "❌ Маршрутизация через sip_trunk НЕ найдена в dialplan"
    fi
    
    # Проверка переменных
    log INFO "Проверка переменных в vars.xml..."
    if grep -q "outbound_caller_id" freeswitch/conf/vars.xml; then
        log INFO "✅ Настройки Caller ID найдены"
    else
        log WARN "⚠️ Настройки Caller ID не найдены"
    fi
    
    # Проверка логов FreeSWITCH на ошибки
    log INFO "Проверка последних ошибок в логах FreeSWITCH..."
    local errors=$(docker logs "$FREESWITCH_CONTAINER" --tail=100 2>&1 | grep -i error | tail -5)
    
    if [ -n "$errors" ]; then
        log WARN "⚠️ Обнаружены ошибки в логах:"
        echo "$errors" | while read -r line; do
            log WARN "  $line"
        done
    else
        log INFO "✅ Критических ошибок в логах не найдено"
    fi
}

# Полный тест подключения
full_test() {
    log TITLE "🚀 Полный тест подключения к SIP транку"
    
    local errors=0
    
    # Последовательность тестов
    check_freeswitch || ((errors++))
    check_network_connectivity || ((errors++))
    check_sofia_configuration || ((errors++))
    
    # Тестирование звонков на разные номера
    for test_number in "${TEST_NUMBERS[@]}"; do
        if test_outbound_call "$test_number"; then
            log INFO "✅ Тест звонка на $test_number прошел успешно"
            break
        else
            log WARN "⚠️ Тест звонка на $test_number неуспешен"
            ((errors++))
        fi
    done
    
    # Результаты
    if [ $errors -eq 0 ]; then
        log TITLE "🎉 ВСЕ ТЕСТЫ ПРОЙДЕНЫ УСПЕШНО!"
        log INFO "SIP транк 62.141.121.197:5070 готов к работе"
    else
        log TITLE "⚠️ ОБНАРУЖЕНЫ ПРОБЛЕМЫ"
        log INFO "Количество ошибок: $errors"
        log INFO "Запустите './test-sip-trunk.sh diagnose' для подробной диагностики"
    fi
}

# Перезагрузка конфигурации FreeSWITCH
reload_config() {
    log TITLE "🔄 Перезагрузка конфигурации FreeSWITCH..."
    
    log INFO "Перезагрузка XML конфигурации..."
    docker exec "$FREESWITCH_CONTAINER" fs_cli -x "reloadxml"
    
    log INFO "Перезапуск Sofia профиля external..."
    docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia profile external restart"
    
    log INFO "Ожидание загрузки конфигурации..."
    sleep 5
    
    log INFO "✅ Конфигурация перезагружена"
}

# Функция помощи
show_help() {
    cat << EOF
🔗 Скрипт тестирования SIP транка 62.141.121.197:5070

Использование: $0 [действие]

Действия:
  test        - полный тест подключения (по умолчанию)
  check       - проверка FreeSWITCH и сети  
  sofia       - проверка конфигурации Sofia SIP
  call        - тестовый звонок на номер
  monitor     - мониторинг SIP трафика
  diagnose    - диагностика проблем
  reload      - перезагрузка конфигурации FreeSWITCH
  help        - показать эту справку

Примеры:
  $0                    # Полный тест
  $0 test               # То же самое
  $0 call 79001234567   # Тест звонка на конкретный номер
  $0 monitor            # Мониторинг SIP трафика

Требования:
  - FreeSWITCH контейнер должен быть запущен
  - Конфигурация должна быть применена

EOF
}

# Главная функция
main() {
    local action="${1:-test}"
    local phone_number="${2:-}"
    
    case "$action" in
        "test"|"")
            full_test
            ;;
        "check")
            check_freeswitch
            check_network_connectivity
            ;;
        "sofia")
            check_sofia_configuration
            ;;
        "call")
            if [ -z "$phone_number" ]; then
                log ERROR "Укажите номер телефона для тестового звонка"
                log INFO "Пример: $0 call 79001234567"
                exit 1
            fi
            check_freeswitch && test_outbound_call "$phone_number"
            ;;
        "monitor")
            check_freeswitch && monitor_sip_traffic
            ;;
        "diagnose")
            diagnose_issues
            ;;
        "reload")
            check_freeswitch && reload_config
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log ERROR "Неизвестное действие: $action"
            show_help
            exit 1
            ;;
    esac
}

# Обработка сигналов
trap 'log INFO "Получен сигнал завершения..."; exit 1' SIGINT SIGTERM

# Запуск
log TITLE "🔗 Тестирование SIP транка $SIP_TRUNK_IP:$SIP_TRUNK_PORT"
main "$@" 