#!/bin/bash

# 🚨 Скрипт экстренного восстановления системы автодозвона
# Автор: AI Assistant
# Назначение: Быстрое восстановление упавших сервисов на тестовом сервере
# Использование: ./emergency-recovery.sh [действие]

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Конфигурация
COMPOSE_FILE="docker-compose.yml"
PRODUCTION_COMPOSE_FILE="docker-compose.production.yml"
BACKUP_DIR="./backups"
LOG_DIR="./emergency_logs"
SERVICES=("dialer_backend" "dialer_postgres" "dialer_redis" "dialer_freeswitch" "dialer_frontend")

# Создаем директории
mkdir -p "$BACKUP_DIR" "$LOG_DIR"

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
        TITLE) echo -e "${BOLD}${BLUE}[$timestamp]${NC} ${BOLD}$message${NC}" ;;
        *)     echo "[$timestamp] $level: $message" ;;
    esac
}

# Создание резервной копии важных данных
create_backup() {
    log TITLE "📦 Создание резервной копии..."
    
    local backup_timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$BACKUP_DIR/emergency_backup_$backup_timestamp"
    
    mkdir -p "$backup_path"
    
    # Резервная копия базы данных
    if docker ps --filter "name=dialer_postgres" --filter "status=running" | grep -q dialer_postgres; then
        log INFO "Создание резервной копии PostgreSQL..."
        docker exec dialer_postgres pg_dump -U dialer_user -d dialer_db > "$backup_path/postgres_backup.sql" || log WARN "Не удалось создать резервную копию БД"
    fi
    
    # Резервная копия Redis
    if docker ps --filter "name=dialer_redis" --filter "status=running" | grep -q dialer_redis; then
        log INFO "Создание резервной копии Redis..."
        docker exec dialer_redis redis-cli -a redis_password_123 --rdb - > "$backup_path/redis_backup.rdb" 2>/dev/null || log WARN "Не удалось создать резервную копию Redis"
    fi
    
    # Резервная копия конфигураций
    log INFO "Резервная копия конфигураций..."
    cp -r ./freeswitch/conf "$backup_path/" 2>/dev/null || log WARN "Не удалось скопировать конфигурацию FreeSWITCH"
    cp .env "$backup_path/" 2>/dev/null || log WARN "Файл .env не найден"
    cp docker-compose.yml "$backup_path/" 2>/dev/null || log WARN "docker-compose.yml не найден"
    
    log INFO "✅ Резервная копия создана: $backup_path"
    echo "$backup_path"
}

# Сбор диагностической информации перед восстановлением
collect_pre_recovery_info() {
    log TITLE "🔍 Сбор диагностической информации..."
    
    local info_file="$LOG_DIR/pre_recovery_$(date +%Y%m%d_%H%M%S).log"
    
    {
        echo "=== PRE-RECOVERY DIAGNOSTIC INFO ==="
        echo "Timestamp: $(date)"
        echo "User: $(whoami)"
        echo "Working directory: $(pwd)"
        echo ""
        
        echo "=== SYSTEM RESOURCES ==="
        free -h
        df -h
        echo ""
        
        echo "=== DOCKER STATUS ==="
        docker version 2>/dev/null || echo "Docker недоступен"
        docker ps -a 2>/dev/null || echo "Не удается получить статус контейнеров"
        echo ""
        
        echo "=== SERVICE STATUS ==="
        for service in "${SERVICES[@]}"; do
            echo "--- $service ---"
            if docker ps --filter "name=$service" --format "{{.Names}}: {{.Status}}" | grep -q "$service"; then
                docker ps --filter "name=$service" --format "{{.Names}}: {{.Status}}"
                # Последние 20 строк логов
                echo "Последние логи:"
                docker logs "$service" --tail=20 2>&1 | head -20
            else
                echo "$service: КОНТЕЙНЕР НЕ НАЙДЕН"
            fi
            echo ""
        done
        
        echo "=== NETWORK STATUS ==="
        docker network ls 2>/dev/null || echo "Не удается получить список сетей"
        netstat -tuln | grep -E "(3000|5432|6379|5060|8021)" 2>/dev/null || echo "Не удается проверить порты"
        
    } > "$info_file"
    
    log INFO "✅ Диагностическая информация сохранена: $info_file"
}

# Быстрая диагностика проблем
quick_diagnosis() {
    log TITLE "🩺 Быстрая диагностика проблем..."
    
    local issues=()
    
    # Проверка Docker
    if ! docker --version >/dev/null 2>&1; then
        issues+=("Docker недоступен")
    fi
    
    # Проверка дискового пространства
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 90 ]; then
        issues+=("Мало места на диске: ${disk_usage}%")
    fi
    
    # Проверка памяти
    local mem_available=$(free | grep Mem | awk '{print ($7/$2) * 100.0}')
    if (( $(echo "$mem_available < 10" | bc -l) )); then
        issues+=("Мало свободной памяти: ${mem_available}%")
    fi
    
    # Проверка статуса сервисов
    local down_services=()
    for service in "${SERVICES[@]}"; do
        if ! docker ps --filter "name=$service" --filter "status=running" | grep -q "$service"; then
            down_services+=("$service")
        fi
    done
    
    if [ ${#down_services[@]} -gt 0 ]; then
        issues+=("Неработающие сервисы: ${down_services[*]}")
    fi
    
    # Вывод результатов
    if [ ${#issues[@]} -eq 0 ]; then
        log INFO "✅ Критических проблем не обнаружено"
        return 0
    else
        log WARN "⚠️ Обнаружены проблемы:"
        for issue in "${issues[@]}"; do
            log WARN "  - $issue"
        done
        return 1
    fi
}

# Очистка ресурсов перед восстановлением
cleanup_resources() {
    log TITLE "🧹 Очистка ресурсов..."
    
    # Остановка всех контейнеров проекта
    log INFO "Остановка контейнеров..."
    docker-compose down 2>/dev/null || log WARN "Не удалось остановить через docker-compose"
    
    # Принудительная остановка контейнеров
    for service in "${SERVICES[@]}"; do
        if docker ps -q --filter "name=$service" | grep -q .; then
            log INFO "Принудительная остановка $service..."
            docker stop "$service" 2>/dev/null || true
            docker rm "$service" 2>/dev/null || true
        fi
    done
    
    # Очистка неиспользуемых образов и volumes
    log INFO "Очистка Docker ресурсов..."
    docker system prune -f 2>/dev/null || log WARN "Не удалось выполнить очистку Docker"
    
    # Удаление оборванных volumes (осторожно!)
    # docker volume prune -f 2>/dev/null || log WARN "Не удалось очистить volumes"
    
    log INFO "✅ Очистка завершена"
}

# Проверка и восстановление прав доступа
fix_permissions() {
    log TITLE "🔐 Исправление прав доступа..."
    
    # Права на папку audio
    if [ -d "./audio" ]; then
        log INFO "Исправление прав для папки audio..."
        sudo chown -R 1001:1001 ./audio/ 2>/dev/null || log WARN "Не удалось изменить владельца audio/"
        sudo chmod -R 755 ./audio/ 2>/dev/null || log WARN "Не удалось изменить права audio/"
    fi
    
    # Права на папку логов
    if [ -d "./backend/logs" ]; then
        log INFO "Исправление прав для папки логов..."
        sudo chown -R 1001:1001 ./backend/logs/ 2>/dev/null || log WARN "Не удалось изменить владельца logs/"
        sudo chmod -R 755 ./backend/logs/ 2>/dev/null || log WARN "Не удалось изменить права logs/"
    fi
    
    # Создание недостающих директорий
    mkdir -p ./audio ./backend/logs 2>/dev/null || true
    
    log INFO "✅ Права доступа исправлены"
}

# Восстановление сервисов
restore_services() {
    log TITLE "🚀 Восстановление сервисов..."
    
    local compose_file="$COMPOSE_FILE"
    
    # Выбор конфигурации
    if [ -f "$PRODUCTION_COMPOSE_FILE" ]; then
        log INFO "Использование production конфигурации..."
        compose_file="$PRODUCTION_COMPOSE_FILE"
    fi
    
    # Восстановление в правильном порядке
    log INFO "Запуск базы данных и Redis..."
    docker-compose -f "$compose_file" up -d postgres redis
    
    # Ожидание готовности БД
    log INFO "Ожидание готовности PostgreSQL..."
    local retries=0
    while [ $retries -lt 30 ]; do
        if docker exec dialer_postgres pg_isready -U dialer_user -d dialer_db >/dev/null 2>&1; then
            log INFO "✅ PostgreSQL готов"
            break
        fi
        sleep 2
        ((retries++))
    done
    
    if [ $retries -eq 30 ]; then
        log ERROR "❌ PostgreSQL не удалось запустить за 60 секунд"
        return 1
    fi
    
    # Запуск FreeSWITCH
    log INFO "Запуск FreeSWITCH..."
    docker-compose -f "$compose_file" up -d freeswitch
    sleep 10  # Даем время на запуск
    
    # Запуск backend
    log INFO "Запуск backend..."
    docker-compose -f "$compose_file" up -d backend
    
    # Ожидание готовности backend
    log INFO "Ожидание готовности backend..."
    retries=0
    while [ $retries -lt 30 ]; do
        if curl -f http://localhost:3000/health >/dev/null 2>&1; then
            log INFO "✅ Backend готов"
            break
        fi
        sleep 2
        ((retries++))
    done
    
    # Запуск frontend
    log INFO "Запуск frontend..."
    docker-compose -f "$compose_file" up -d frontend
    
    log INFO "✅ Все сервисы запущены"
}

# Проверка восстановления
verify_recovery() {
    log TITLE "✅ Проверка восстановления..."
    
    local all_ok=true
    
    # Проверка каждого сервиса
    for service in "${SERVICES[@]}"; do
        if docker ps --filter "name=$service" --filter "status=running" | grep -q "$service"; then
            log INFO "✅ $service - работает"
        else
            log ERROR "❌ $service - НЕ РАБОТАЕТ"
            all_ok=false
        fi
    done
    
    # Проверка health checks
    log INFO "Проверка health checks..."
    sleep 30  # Даем время на прогрев
    
    local unhealthy_services=()
    for service in "${SERVICES[@]}"; do
        local health=$(docker inspect --format='{{.State.Health.Status}}' "$service" 2>/dev/null)
        if [ "$health" = "unhealthy" ]; then
            unhealthy_services+=("$service")
        fi
    done
    
    if [ ${#unhealthy_services[@]} -gt 0 ]; then
        log WARN "⚠️ Сервисы с проблемами health check: ${unhealthy_services[*]}"
    fi
    
    # Проверка доступности endpoints
    if curl -f http://localhost:3000/health >/dev/null 2>&1; then
        log INFO "✅ Backend API доступен"
    else
        log ERROR "❌ Backend API недоступен"
        all_ok=false
    fi
    
    if curl -f http://localhost:5173 >/dev/null 2>&1; then
        log INFO "✅ Frontend доступен"
    else
        log ERROR "❌ Frontend недоступен"
        all_ok=false
    fi
    
    if $all_ok; then
        log INFO "🎉 Восстановление прошло успешно!"
        return 0
    else
        log ERROR "❌ Восстановление завершено с ошибками"
        return 1
    fi
}

# Полное восстановление
full_recovery() {
    log TITLE "🚨 ПОЛНОЕ ЭКСТРЕННОЕ ВОССТАНОВЛЕНИЕ"
    log INFO "Начинаем процедуру полного восстановления системы..."
    
    # Последовательность действий
    collect_pre_recovery_info
    create_backup
    quick_diagnosis
    cleanup_resources
    fix_permissions
    restore_services
    verify_recovery
    
    if [ $? -eq 0 ]; then
        log TITLE "🎉 ВОССТАНОВЛЕНИЕ ЗАВЕРШЕНО УСПЕШНО!"
        log INFO "Система готова к работе."
    else
        log TITLE "⚠️ ВОССТАНОВЛЕНИЕ ЗАВЕРШЕНО С ПРЕДУПРЕЖДЕНИЯМИ"
        log INFO "Некоторые компоненты могут работать нестабильно."
        log INFO "Проверьте логи для получения дополнительной информации."
    fi
}

# Быстрый перезапуск только упавших сервисов
quick_restart() {
    log TITLE "⚡ Быстрый перезапуск упавших сервисов"
    
    local down_services=()
    
    # Находим упавшие сервисы
    for service in "${SERVICES[@]}"; do
        if ! docker ps --filter "name=$service" --filter "status=running" | grep -q "$service"; then
            down_services+=("$service")
        fi
    done
    
    if [ ${#down_services[@]} -eq 0 ]; then
        log INFO "✅ Все сервисы работают, перезапуск не требуется"
        return 0
    fi
    
    log INFO "Обнаружены неработающие сервисы: ${down_services[*]}"
    
    # Перезапуск только упавших сервисов
    for service in "${down_services[@]}"; do
        local service_name=${service#dialer_}  # Убираем префикс dialer_
        log INFO "Перезапуск $service_name..."
        docker-compose restart "$service_name" 2>/dev/null || log WARN "Не удалось перезапустить $service_name"
    done
    
    # Проверка результата
    sleep 10
    local still_down=()
    for service in "${down_services[@]}"; do
        if ! docker ps --filter "name=$service" --filter "status=running" | grep -q "$service"; then
            still_down+=("$service")
        fi
    done
    
    if [ ${#still_down[@]} -eq 0 ]; then
        log INFO "✅ Все сервисы успешно перезапущены"
    else
        log WARN "⚠️ Не удалось перезапустить: ${still_down[*]}"
        log INFO "Рекомендуется выполнить полное восстановление"
    fi
}

# Функция помощи
show_help() {
    cat << EOF
🚨 Скрипт экстренного восстановления системы автодозвона

Использование: $0 [действие]

Действия:
  full        - полное восстановление с резервным копированием (по умолчанию)
  quick       - быстрый перезапуск только упавших сервисов
  diagnosis   - только диагностика без восстановления
  backup      - создание резервной копии
  cleanup     - очистка ресурсов Docker
  permissions - исправление прав доступа
  help        - показать эту справку

Примеры:
  $0                    # Полное восстановление
  $0 full               # То же самое
  $0 quick              # Быстрый перезапуск
  $0 diagnosis          # Только диагностика

⚠️ ВНИМАНИЕ: Полное восстановление остановит все сервисы на время процедуры!

EOF
}

# Главная функция
main() {
    local action="${1:-full}"
    
    case "$action" in
        "full"|"")
            full_recovery
            ;;
        "quick")
            quick_diagnosis
            quick_restart
            ;;
        "diagnosis")
            collect_pre_recovery_info
            quick_diagnosis
            ;;
        "backup")
            create_backup
            ;;
        "cleanup")
            cleanup_resources
            ;;
        "permissions")
            fix_permissions
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

# Проверка прав root для некоторых операций
check_sudo() {
    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        log WARN "Некоторые операции могут требовать права sudo"
        log INFO "При необходимости введите пароль..."
    fi
}

# Обработка сигналов
trap 'log INFO "Получен сигнал завершения..."; exit 1' SIGINT SIGTERM

# Запуск
log TITLE "🚨 Система экстренного восстановления автодозвона"
check_sudo
main "$@" 