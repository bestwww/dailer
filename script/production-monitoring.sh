#!/bin/bash

# 🔍 Скрипт мониторинга системы автодозвона для тестового сервера
# Автор: AI Assistant  
# Назначение: Непрерывный мониторинг Docker контейнеров и системных ресурсов
# Использование: ./production-monitoring.sh [режим]
# Режимы: 
#   check     - разовая проверка (по умолчанию)
#   monitor   - непрерывный мониторинг
#   logs      - сбор логов для диагностики
#   alert     - проверка с отправкой алертов

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Конфигурация
SERVICES=("dialer_backend" "dialer_postgres" "dialer_redis" "dialer_freeswitch" "dialer_frontend")
LOG_DIR="./monitoring_logs"
ALERT_EMAIL="admin@company.com"  # Замените на ваш email
MONITORING_INTERVAL=300  # 5 минут
MAX_CPU_PERCENT=80
MAX_MEMORY_PERCENT=85
DISK_THRESHOLD=90

# Создаем директорию для логов
mkdir -p "$LOG_DIR"

# Функция логирования с временной меткой
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
        *)     echo "[$timestamp] $level: $message" ;;
    esac
}

# Функция отправки алертов
send_alert() {
    local subject="$1"
    local message="$2"
    
    log ERROR "ALERT: $subject"
    echo "$message" | tee -a "$LOG_DIR/alerts_$(date +%Y%m%d).log"
    
    # Отправка email (требует настройки mail)
    # echo "$message" | mail -s "$subject" "$ALERT_EMAIL" 2>/dev/null || true
    
    # Можно добавить отправку в Telegram/Slack
    # curl -X POST "https://api.telegram.org/bot<TOKEN>/sendMessage" -d "chat_id=<CHAT_ID>&text=$subject: $message"
}

# Проверка состояния контейнеров
check_containers() {
    log INFO "Проверка состояния Docker контейнеров..."
    
    local failed_services=()
    
    for service in "${SERVICES[@]}"; do
        if docker ps --filter "name=$service" --filter "status=running" --format "{{.Names}}" | grep -q "^$service$"; then
            log INFO "✅ $service - работает"
        else
            log ERROR "❌ $service - НЕ РАБОТАЕТ!"
            failed_services+=("$service")
            
            # Проверяем, остановлен ли контейнер или завершился с ошибкой
            local container_status=$(docker ps -a --filter "name=$service" --format "{{.Status}}")
            log ERROR "   Статус: $container_status"
        fi
    done
    
    if [ ${#failed_services[@]} -gt 0 ]; then
        local alert_msg="Обнаружены неработающие сервисы: ${failed_services[*]}"
        send_alert "Docker Services Down" "$alert_msg"
        return 1
    fi
    
    return 0
}

# Проверка использования ресурсов
check_resources() {
    log INFO "Проверка использования ресурсов..."
    
    # Проверка использования CPU и памяти контейнерами
    while IFS= read -r line; do
        if [[ $line == *"CONTAINER"* ]]; then
            continue  # Пропускаем заголовок
        fi
        
        local name=$(echo "$line" | awk '{print $1}')
        local cpu=$(echo "$line" | awk '{print $2}' | sed 's/%//')
        local mem_usage=$(echo "$line" | awk '{print $3}')
        local mem_percent=$(echo "$line" | awk '{print $4}' | sed 's/%//')
        
        # Проверяем превышение лимитов
        if (( $(echo "$cpu > $MAX_CPU_PERCENT" | bc -l) )); then
            log WARN "⚠️ $name: Высокое использование CPU: ${cpu}%"
        fi
        
        if (( $(echo "$mem_percent > $MAX_MEMORY_PERCENT" | bc -l) )); then
            log WARN "⚠️ $name: Высокое использование памяти: ${mem_percent}% ($mem_usage)"
            send_alert "High Memory Usage" "$name использует ${mem_percent}% памяти"
        fi
        
        log DEBUG "$name: CPU=${cpu}%, MEM=${mem_percent}% ($mem_usage)"
        
    done < <(docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}")
}

# Проверка дискового пространства
check_disk_space() {
    log INFO "Проверка дискового пространства..."
    
    # Проверка основного диска
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    log DEBUG "Использование диска /: ${disk_usage}%"
    
    if [ "$disk_usage" -gt "$DISK_THRESHOLD" ]; then
        log WARN "⚠️ Мало места на диске: ${disk_usage}%"
        send_alert "Low Disk Space" "Использование диска: ${disk_usage}%"
    fi
    
    # Проверка размера Docker данных
    local docker_size=$(docker system df --format "table {{.Type}}\t{{.Size}}" | grep -v TYPE)
    log DEBUG "Размер Docker данных:"
    echo "$docker_size" | while read -r line; do
        log DEBUG "  $line"
    done
    
    # Проверка логов контейнеров
    local large_logs=$(docker ps --format "{{.Names}}" | xargs -I {} sh -c 'size=$(docker logs {} 2>&1 | wc -c); if [ $size -gt 100000000 ]; then echo "{}: ${size} bytes"; fi' 2>/dev/null)
    
    if [ -n "$large_logs" ]; then
        log WARN "⚠️ Обнаружены большие логи контейнеров:"
        echo "$large_logs" | while read -r line; do
            log WARN "  $line"
        done
    fi
}

# Проверка подключений к базе данных
check_database_connections() {
    log INFO "Проверка соединений с базой данных..."
    
    if docker exec dialer_postgres psql -U dialer_user -d dialer_db -c "SELECT 1;" >/dev/null 2>&1; then
        log INFO "✅ Подключение к PostgreSQL работает"
        
        # Количество активных соединений
        local connections=$(docker exec dialer_postgres psql -U dialer_user -d dialer_db -t -c "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null | xargs)
        log DEBUG "Активных соединений к БД: $connections"
        
        # Проверка на превышение лимита соединений
        if [ "$connections" -gt 80 ]; then
            log WARN "⚠️ Много активных соединений к БД: $connections"
        fi
    else
        log ERROR "❌ Не удается подключиться к PostgreSQL"
        send_alert "Database Connection Failed" "PostgreSQL недоступна"
    fi
}

# Проверка Redis
check_redis() {
    log INFO "Проверка Redis..."
    
    if docker exec dialer_redis redis-cli -a redis_password_123 ping >/dev/null 2>&1; then
        log INFO "✅ Redis работает"
        
        # Информация о памяти Redis
        local redis_memory=$(docker exec dialer_redis redis-cli -a redis_password_123 info memory 2>/dev/null | grep used_memory_human | cut -d: -f2 | tr -d '\r')
        log DEBUG "Использование памяти Redis: $redis_memory"
    else
        log ERROR "❌ Redis недоступен"
        send_alert "Redis Connection Failed" "Redis недоступен"
    fi
}

# Сбор подробных логов для диагностики
collect_diagnostic_logs() {
    log INFO "Сбор диагностических логов..."
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local diag_dir="$LOG_DIR/diagnostic_$timestamp"
    mkdir -p "$diag_dir"
    
    # Системная информация
    {
        echo "=== SYSTEM INFO ==="
        date
        uptime
        free -h
        df -h
        echo ""
        
        echo "=== DOCKER INFO ==="
        docker version
        docker info
        echo ""
        
        echo "=== CONTAINER STATUS ==="
        docker ps -a
        echo ""
        
        echo "=== RESOURCE USAGE ==="
        docker stats --no-stream
        echo ""
        
        echo "=== NETWORK INFO ==="
        docker network ls
        docker network inspect dialer_dialer_network
        
    } > "$diag_dir/system_info.log"
    
    # Логи сервисов
    for service in "${SERVICES[@]}"; do
        log INFO "Собираем логи для $service..."
        docker logs "$service" --since=24h > "$diag_dir/${service}_logs.log" 2>&1 || true
    done
    
    # Системные логи
    journalctl --since="24 hours ago" | grep -i docker > "$diag_dir/system_docker_logs.log" 2>&1 || true
    
    # Проверка на OOM killer
    dmesg | grep -i "killed process" > "$diag_dir/oom_killer.log" 2>&1 || true
    
    log INFO "Диагностические логи сохранены в: $diag_dir"
    echo "$diag_dir"
}

# Основная функция проверки
run_check() {
    log INFO "🔍 Запуск проверки системы автодозвона..."
    
    local errors=0
    
    # Проверяем каждый компонент
    check_containers || ((errors++))
    check_resources || ((errors++))
    check_disk_space || ((errors++))
    check_database_connections || ((errors++))
    check_redis || ((errors++))
    
    if [ $errors -eq 0 ]; then
        log INFO "✅ Все проверки пройдены успешно"
        return 0
    else
        log ERROR "❌ Обнаружено $errors проблем"
        return 1
    fi
}

# Непрерывный мониторинг
run_monitoring() {
    log INFO "🔄 Запуск непрерывного мониторинга (интервал: ${MONITORING_INTERVAL}с)..."
    log INFO "Для остановки нажмите Ctrl+C"
    
    # Создаем лог-файл для мониторинга
    local monitor_log="$LOG_DIR/monitoring_$(date +%Y%m%d).log"
    
    while true; do
        {
            echo "=================================="
            echo "Проверка в $(date)"
            echo "=================================="
            
            if run_check; then
                echo "Статус: ОК"
            else
                echo "Статус: ПРОБЛЕМЫ ОБНАРУЖЕНЫ"
            fi
            
            echo ""
        } | tee -a "$monitor_log"
        
        sleep $MONITORING_INTERVAL
    done
}

# Функция помощи
show_help() {
    cat << EOF
🔍 Скрипт мониторинга системы автодозвона

Использование: $0 [режим]

Режимы:
  check     - разовая проверка всех компонентов (по умолчанию)
  monitor   - непрерывный мониторинг каждые 5 минут
  logs      - сбор диагностических логов
  alert     - проверка с отправкой алертов
  help      - показать эту справку

Примеры:
  $0                    # Разовая проверка
  $0 check              # То же самое
  $0 monitor            # Непрерывный мониторинг
  $0 logs               # Собрать логи для диагностики

Логи сохраняются в: $LOG_DIR/

EOF
}

# Главная функция
main() {
    local mode="${1:-check}"
    
    case "$mode" in
        "check"|"")
            run_check
            ;;
        "monitor")
            run_monitoring
            ;;
        "logs")
            collect_diagnostic_logs
            ;;
        "alert")
            if ! run_check; then
                send_alert "System Check Failed" "Обнаружены проблемы в системе автодозвона. Требуется проверка."
            fi
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log ERROR "Неизвестный режим: $mode"
            show_help
            exit 1
            ;;
    esac
}

# Обработка сигналов для graceful shutdown
trap 'log INFO "Получен сигнал завершения, останавливаем мониторинг..."; exit 0' SIGINT SIGTERM

# Запуск
main "$@" 