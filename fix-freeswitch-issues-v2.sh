#!/bin/bash

# 🔧 Скрипт исправления проблем FreeSWITCH v2.0
# Автор: AI Assistant
# Назначение: Исправлена поддержка docker compose v2 и глубокая диагностика Sofia SIP
# Использование: ./fix-freeswitch-issues-v2.sh

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

# Определение команды Docker Compose
DOCKER_COMPOSE_CMD=""
if command -v docker-compose >/dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker-compose"
elif docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker compose"
else
    echo "❌ Docker Compose не найден!"
    exit 1
fi

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

# Проверка синтаксиса XML конфигурации
check_xml_syntax() {
    log TITLE "📝 Проверка синтаксиса XML конфигурации..."
    
    local xml_files=(
        "freeswitch/conf/freeswitch.xml"
        "freeswitch/conf/vars.xml"
        "freeswitch/conf/autoload_configs/sofia.conf.xml"
        "freeswitch/conf/dialplan/default.xml"
    )
    
    local syntax_errors=0
    
    for xml_file in "${xml_files[@]}"; do
        if [ -f "$xml_file" ]; then
            log INFO "Проверка $xml_file..."
            if xmllint --noout "$xml_file" 2>/dev/null; then
                log INFO "✅ $xml_file - синтаксис корректен"
            else
                log ERROR "❌ $xml_file - синтаксические ошибки XML!"
                xmllint --noout "$xml_file" 2>&1 | head -5 | while read -r line; do
                    log ERROR "  $line"
                done
                ((syntax_errors++))
            fi
        else
            log WARN "⚠️ $xml_file не найден"
            ((syntax_errors++))
        fi
    done
    
    if [ $syntax_errors -eq 0 ]; then
        log SUCCESS "✅ Все XML файлы имеют корректный синтаксис"
        return 0
    else
        log ERROR "❌ Обнаружены синтаксические ошибки в $syntax_errors файлах"
        return 1
    fi
}

# Глубокая диагностика FreeSWITCH
deep_freeswitch_diagnosis() {
    log TITLE "🔬 Глубокая диагностика FreeSWITCH..."
    
    # Проверка что FreeSWITCH вообще запущен
    if ! docker ps --filter "name=$FREESWITCH_CONTAINER" --filter "status=running" | grep -q "$FREESWITCH_CONTAINER"; then
        log ERROR "❌ FreeSWITCH контейнер не запущен!"
        return 1
    fi
    
    # Проверка что процесс FreeSWITCH работает в контейнере
    local fs_processes=$(docker exec "$FREESWITCH_CONTAINER" ps aux | grep freeswitch | grep -v grep | wc -l)
    log INFO "Количество процессов FreeSWITCH: $fs_processes"
    
    if [ "$fs_processes" -eq 0 ]; then
        log ERROR "❌ Процесс FreeSWITCH не запущен в контейнере!"
        return 1
    fi
    
    # Проверка доступности fs_cli
    if docker exec "$FREESWITCH_CONTAINER" fs_cli -x "status" >/dev/null 2>&1; then
        log INFO "✅ fs_cli доступен"
    else
        log ERROR "❌ fs_cli недоступен - FreeSWITCH не отвечает"
        return 1
    fi
    
    # Проверка статуса модулей
    local modules_status=$(docker exec "$FREESWITCH_CONTAINER" fs_cli -x "show modules" 2>/dev/null)
    
    if echo "$modules_status" | grep -q "mod_sofia"; then
        log INFO "✅ Модуль mod_sofia загружен"
    else
        log ERROR "❌ Модуль mod_sofia НЕ загружен!"
        return 1
    fi
    
    # Проверка логов на критические ошибки
    local critical_errors=$(docker logs "$FREESWITCH_CONTAINER" --tail=100 2>&1 | grep -i -E "(fatal|critical|segfault|core dump)" | wc -l)
    
    if [ "$critical_errors" -gt 0 ]; then
        log ERROR "❌ Обнаружены критические ошибки в логах FreeSWITCH!"
        docker logs "$FREESWITCH_CONTAINER" --tail=100 2>&1 | grep -i -E "(fatal|critical|segfault|core dump)" | while read -r line; do
            log ERROR "  $line"
        done
        return 1
    fi
    
    return 0
}

# Диагностика Sofia SIP
diagnose_sofia_sip() {
    log TITLE "🔍 Диагностика Sofia SIP..."
    
    # Проверка загрузки модуля sofia
    local sofia_loaded=$(docker exec "$FREESWITCH_CONTAINER" fs_cli -x "show modules" 2>/dev/null | grep "mod_sofia" | wc -l)
    
    if [ "$sofia_loaded" -eq 0 ]; then
        log ERROR "❌ Модуль mod_sofia не загружен!"
        
        # Попытка загрузить модуль
        log INFO "Попытка загрузки модуля mod_sofia..."
        if docker exec "$FREESWITCH_CONTAINER" fs_cli -x "load mod_sofia" >/dev/null 2>&1; then
            log INFO "✅ Модуль mod_sofia загружен"
        else
            log ERROR "❌ Не удалось загрузить модуль mod_sofia"
            return 1
        fi
    else
        log INFO "✅ Модуль mod_sofia загружен"
    fi
    
    # Проверка конфигурации Sofia
    local sofia_config=$(docker exec "$FREESWITCH_CONTAINER" fs_cli -x "xml_locate configuration sofia.conf" 2>/dev/null)
    
    if echo "$sofia_config" | grep -q "configuration"; then
        log INFO "✅ Конфигурация Sofia найдена"
    else
        log ERROR "❌ Конфигурация Sofia не найдена или повреждена"
        return 1
    fi
    
    # Проверка профилей Sofia
    local sofia_profiles=$(docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia status" 2>/dev/null)
    
    log DEBUG "Sofia Status Output:"
    echo "$sofia_profiles" | while read -r line; do
        log DEBUG "  $line"
    done
    
    # Попытка принудительного запуска профиля external
    log INFO "Попытка принудительного запуска профиля external..."
    docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia profile external start" >/dev/null 2>&1
    
    sleep 3
    
    # Повторная проверка
    local sofia_profiles_retry=$(docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia status" 2>/dev/null)
    
    if echo "$sofia_profiles_retry" | grep -q "external"; then
        log SUCCESS "✅ Профиль external запущен"
        return 0
    else
        log ERROR "❌ Профиль external все еще не запущен"
        return 1
    fi
}

# Исправление Docker Compose команд
restart_freeswitch_container() {
    log TITLE "🔄 Полный перезапуск FreeSWITCH контейнера..."
    
    log INFO "Используемая команда Docker Compose: $DOCKER_COMPOSE_CMD"
    
    # Остановка контейнера
    log INFO "Остановка FreeSWITCH контейнера..."
    if $DOCKER_COMPOSE_CMD stop freeswitch; then
        log INFO "✅ FreeSWITCH остановлен"
    else
        log ERROR "❌ Ошибка при остановке FreeSWITCH"
        return 1
    fi
    
    # Удаление контейнера
    log INFO "Удаление контейнера..."
    docker rm "$FREESWITCH_CONTAINER" 2>/dev/null || true
    
    sleep 3
    
    # Запуск контейнера
    log INFO "Запуск FreeSWITCH контейнера..."
    if $DOCKER_COMPOSE_CMD up -d freeswitch; then
        log INFO "✅ FreeSWITCH запущен"
    else
        log ERROR "❌ Ошибка при запуске FreeSWITCH"
        return 1
    fi
    
    # Ожидание полной загрузки
    log INFO "Ожидание полной загрузки FreeSWITCH..."
    sleep 20
    
    # Проверка что контейнер запустился
    if docker ps --filter "name=$FREESWITCH_CONTAINER" --filter "status=running" | grep -q "$FREESWITCH_CONTAINER"; then
        log INFO "✅ FreeSWITCH контейнер запущен и работает"
    else
        log ERROR "❌ FreeSWITCH контейнер не запустился"
        return 1
    fi
    
    # Проверка что FreeSWITCH отвечает на команды
    local retries=0
    while [ $retries -lt 15 ]; do
        if docker exec "$FREESWITCH_CONTAINER" fs_cli -x "status" >/dev/null 2>&1; then
            log INFO "✅ FreeSWITCH отвечает на команды"
            break
        fi
        sleep 2
        ((retries++))
    done
    
    if [ $retries -eq 15 ]; then
        log ERROR "❌ FreeSWITCH не отвечает на команды после перезапуска"
        return 1
    fi
    
    return 0
}

# Полная очистка и пересоздание
complete_reset() {
    log TITLE "🧹 Полная очистка и пересоздание FreeSWITCH..."
    
    # Остановка всех сервисов
    log INFO "Остановка всех сервисов..."
    $DOCKER_COMPOSE_CMD down 2>/dev/null || true
    
    # Удаление контейнеров
    log INFO "Удаление контейнеров..."
    docker rm -f "$FREESWITCH_CONTAINER" 2>/dev/null || true
    
    # Очистка volumes (осторожно!)
    log INFO "Очистка Docker volumes..."
    docker volume prune -f 2>/dev/null || true
    
    # Пересоздание сети
    log INFO "Пересоздание Docker сети..."
    docker network prune -f 2>/dev/null || true
    
    # Запуск только FreeSWITCH
    log INFO "Запуск FreeSWITCH..."
    if $DOCKER_COMPOSE_CMD up -d freeswitch; then
        log INFO "✅ FreeSWITCH запущен"
    else
        log ERROR "❌ Ошибка при запуске FreeSWITCH"
        return 1
    fi
    
    # Ожидание загрузки
    log INFO "Ожидание полной загрузки..."
    sleep 30
    
    return 0
}

# Создание минимальной тестовой конфигурации
create_minimal_config() {
    log TITLE "⚙️ Создание минимальной тестовой конфигурации Sofia..."
    
    # Создаем резервную копию
    cp freeswitch/conf/autoload_configs/sofia.conf.xml freeswitch/conf/autoload_configs/sofia.conf.xml.backup
    
    # Создаем минимальную конфигурацию
    cat > freeswitch/conf/autoload_configs/sofia.conf.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<configuration name="sofia.conf" description="Sofia Endpoint">
  <global_settings>
    <param name="log-level" value="0"/>
    <param name="auto-restart" value="false"/>
    <param name="debug-presence" value="0"/>
  </global_settings>

  <profiles>
    <profile name="external">
      <gateways>
        <gateway name="sip_trunk">
          <param name="proxy" value="62.141.121.197:5070"/>
          <param name="realm" value="62.141.121.197"/>
          <param name="register" value="false"/>
          <param name="username" value=""/>
          <param name="password" value=""/>
          <param name="from-user" value="freeswitch"/>
          <param name="from-domain" value="62.141.121.197"/>
          <param name="retry-seconds" value="30"/>
          <param name="caller-id-in-from" value="true"/>
          <param name="ping" value="25"/>
        </gateway>
      </gateways>
      
      <settings>
        <param name="context" value="public"/>
        <param name="rfc2833-pt" value="101"/>
        <param name="sip-port" value="5060"/>
        <param name="dialplan" value="XML"/>
        <param name="rtp-ip" value="auto"/>
        <param name="sip-ip" value="auto"/>
        <param name="ext-rtp-ip" value="auto"/>
        <param name="ext-sip-ip" value="auto"/>
        <param name="rtp-timeout-sec" value="300"/>
        <param name="rtp-hold-timeout-sec" value="1800"/>
        <param name="inbound-codec-prefs" value="PCMU,PCMA,GSM"/>
        <param name="outbound-codec-prefs" value="PCMU,PCMA,GSM"/>
        <param name="auth-calls" value="false"/>
        <param name="dtmf-duration" value="2000"/>
        <param name="dtmf-type" value="rfc2833"/>
        <param name="session-timeout" value="1800"/>
        <param name="caller-id-type" value="rpid"/>
        <param name="aggressive-nat-detection" value="true"/>
        <param name="max-proceeding" value="1000"/>
      </settings>
    </profile>
  </profiles>
</configuration>
EOF
    
    log INFO "✅ Минимальная конфигурация Sofia создана"
}

# Основная функция исправления v2
main_fix_v2() {
    log TITLE "🔧 ИСПРАВЛЕНИЕ ПРОБЛЕМ FREESWITCH v2.0"
    
    local step=1
    
    # Шаг 1: Проверка XML синтаксиса
    log TITLE "Шаг $((step++)): Проверка синтаксиса XML конфигурации"
    if ! check_xml_syntax; then
        log ERROR "Обнаружены ошибки в XML. Создаем минимальную конфигурацию..."
        create_minimal_config
    fi
    
    # Шаг 2: Глубокая диагностика FreeSWITCH
    log TITLE "Шаг $((step++)): Глубокая диагностика FreeSWITCH"
    if ! deep_freeswitch_diagnosis; then
        log ERROR "Критические проблемы с FreeSWITCH"
    fi
    
    # Шаг 3: Диагностика Sofia SIP
    log TITLE "Шаг $((step++)): Диагностика Sofia SIP"
    if diagnose_sofia_sip; then
        log SUCCESS "Sofia SIP работает корректно!"
        return 0
    fi
    
    # Шаг 4: Перезапуск контейнера
    log TITLE "Шаг $((step++)): Перезапуск FreeSWITCH контейнера"
    if restart_freeswitch_container && diagnose_sofia_sip; then
        log SUCCESS "Проблема решена перезапуском контейнера!"
        return 0
    fi
    
    # Шаг 5: Полная очистка и пересоздание
    log TITLE "Шаг $((step++)): Полная очистка и пересоздание"
    if complete_reset && diagnose_sofia_sip; then
        log SUCCESS "Проблема решена полной очисткой!"
        return 0
    fi
    
    # Финальная проверка
    log TITLE "Финальная проверка с минимальной конфигурацией"
    create_minimal_config
    restart_freeswitch_container
    
    if diagnose_sofia_sip; then
        log SUCCESS "🎉 ВСЕ ПРОБЛЕМЫ ИСПРАВЛЕНЫ С МИНИМАЛЬНОЙ КОНФИГУРАЦИЕЙ!"
        log INFO "Вы можете восстановить полную конфигурацию из backup файла"
        return 0
    else
        log ERROR "❌ Не удалось исправить проблемы даже с минимальной конфигурацией"
        return 1
    fi
}

# Запуск
log TITLE "🔧 Диагностика и исправление FreeSWITCH v2.0"
log INFO "Docker Compose команда: $DOCKER_COMPOSE_CMD"
main_fix_v2 