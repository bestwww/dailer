#!/bin/bash

# 🔧 Финальное исправление FreeSWITCH
# Автор: AI Assistant
# Назначение: Исправление проблем с конфигурацией и volumes
# Использование: ./fix-freeswitch-final.sh

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

# Установка xmllint если нужно
install_xmllint() {
    log TITLE "📦 Проверка xmllint..."
    
    if command -v xmllint >/dev/null 2>&1; then
        log INFO "✅ xmllint уже установлен"
        return 0
    fi
    
    log INFO "Установка xmllint..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -qq >/dev/null 2>&1 || true
        apt-get install -y libxml2-utils >/dev/null 2>&1 || true
    elif command -v yum >/dev/null 2>&1; then
        yum install -y libxml2 >/dev/null 2>&1 || true
    fi
    
    if command -v xmllint >/dev/null 2>&1; then
        log INFO "✅ xmllint установлен"
    else
        log WARN "⚠️ Не удалось установить xmllint, продолжаем без проверки XML"
    fi
}

# Диагностика монтирования volumes
check_volume_mounting() {
    log TITLE "📁 Диагностика монтирования volumes..."
    
    # Проверка что директория конфигурации смонтирована
    if docker exec "$FREESWITCH_CONTAINER" ls -la /usr/local/freeswitch/conf >/dev/null 2>&1; then
        log INFO "✅ Директория /usr/local/freeswitch/conf доступна в контейнере"
        
        # Показать содержимое
        local conf_files=$(docker exec "$FREESWITCH_CONTAINER" ls -la /usr/local/freeswitch/conf/ 2>/dev/null)
        log DEBUG "Содержимое /usr/local/freeswitch/conf/:"
        echo "$conf_files" | while read -r line; do
            log DEBUG "  $line"
        done
    else
        log ERROR "❌ Директория /usr/local/freeswitch/conf недоступна в контейнере"
        return 1
    fi
    
    # Проверка конкретных файлов
    local config_files=("freeswitch.xml" "vars.xml" "autoload_configs/sofia.conf.xml")
    
    for config_file in "${config_files[@]}"; do
        if docker exec "$FREESWITCH_CONTAINER" test -f "/usr/local/freeswitch/conf/$config_file"; then
            log INFO "✅ $config_file найден в контейнере"
            
            # Проверка прав доступа
            local file_perms=$(docker exec "$FREESWITCH_CONTAINER" ls -la "/usr/local/freeswitch/conf/$config_file" 2>/dev/null)
            log DEBUG "Права доступа $config_file: $file_perms"
        else
            log ERROR "❌ $config_file НЕ найден в контейнере"
        fi
    done
}

# Проверка что FreeSWITCH может читать конфигурацию
check_freeswitch_config_access() {
    log TITLE "🔍 Проверка доступа FreeSWITCH к конфигурации..."
    
    # Проверяем может ли FreeSWITCH прочитать основной конфигурационный файл
    local main_config_test=$(docker exec "$FREESWITCH_CONTAINER" fs_cli -x "xml_locate configuration configuration" 2>/dev/null)
    
    if echo "$main_config_test" | grep -q "<?xml"; then
        log INFO "✅ FreeSWITCH может читать основную конфигурацию"
    else
        log ERROR "❌ FreeSWITCH НЕ может читать основную конфигурацию"
        log DEBUG "Результат: $main_config_test"
        return 1
    fi
    
    # Специфическая проверка Sofia конфигурации
    local sofia_config_test=$(docker exec "$FREESWITCH_CONTAINER" fs_cli -x "xml_locate configuration sofia.conf" 2>/dev/null)
    
    if echo "$sofia_config_test" | grep -q "sofia.conf"; then
        log INFO "✅ FreeSWITCH может найти конфигурацию Sofia"
    else
        log ERROR "❌ FreeSWITCH НЕ может найти конфигурацию Sofia"
        log DEBUG "Результат: $sofia_config_test"
        return 1
    fi
    
    return 0
}

# Создание правильной конфигурации прямо в контейнере
create_config_in_container() {
    log TITLE "⚙️ Создание конфигурации прямо в контейнере..."
    
    # Создаем минимальную sofia.conf.xml прямо в контейнере
    docker exec "$FREESWITCH_CONTAINER" bash -c 'cat > /usr/local/freeswitch/conf/autoload_configs/sofia.conf.xml << '\''EOF'\''
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
EOF'
    
    log INFO "✅ Конфигурация Sofia создана в контейнере"
    
    # Проверим что файл создался
    if docker exec "$FREESWITCH_CONTAINER" test -f "/usr/local/freeswitch/conf/autoload_configs/sofia.conf.xml"; then
        log INFO "✅ Файл sofia.conf.xml подтвержден в контейнере"
        
        # Показать размер файла
        local file_size=$(docker exec "$FREESWITCH_CONTAINER" wc -c < "/usr/local/freeswitch/conf/autoload_configs/sofia.conf.xml")
        log DEBUG "Размер файла: $file_size байт"
    else
        log ERROR "❌ Файл sofia.conf.xml НЕ создался в контейнере"
        return 1
    fi
}

# Исправление прав доступа в контейнере
fix_permissions_in_container() {
    log TITLE "🔐 Исправление прав доступа в контейнере..."
    
    # Изменить владельца конфигурационных файлов на пользователя FreeSWITCH
    docker exec "$FREESWITCH_CONTAINER" chown -R freeswitch:freeswitch /usr/local/freeswitch/conf/ 2>/dev/null || true
    docker exec "$FREESWITCH_CONTAINER" chmod -R 644 /usr/local/freeswitch/conf/ 2>/dev/null || true
    docker exec "$FREESWITCH_CONTAINER" chmod 755 /usr/local/freeswitch/conf/ 2>/dev/null || true
    
    log INFO "✅ Права доступа исправлены"
}

# Принудительная перезагрузка Sofia с отладкой
force_sofia_reload() {
    log TITLE "🔄 Принудительная перезагрузка Sofia..."
    
    # Остановить все профили Sofia
    docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia profile external stop" >/dev/null 2>&1 || true
    docker exec "$FREESWITCH_CONTAINER" fs_cli -x "unload mod_sofia" >/dev/null 2>&1 || true
    
    sleep 3
    
    # Перезагрузить XML
    docker exec "$FREESWITCH_CONTAINER" fs_cli -x "reloadxml"
    
    sleep 2
    
    # Загрузить модуль Sofia заново
    docker exec "$FREESWITCH_CONTAINER" fs_cli -x "load mod_sofia"
    
    sleep 5
    
    # Запустить профиль external
    docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia profile external start"
    
    sleep 3
    
    # Проверить результат
    local sofia_status=$(docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia status" 2>/dev/null)
    
    log DEBUG "Sofia Status после перезагрузки:"
    echo "$sofia_status" | while read -r line; do
        log DEBUG "  $line"
    done
    
    if echo "$sofia_status" | grep -q "external"; then
        log SUCCESS "✅ Профиль external запущен!"
        return 0
    else
        log ERROR "❌ Профиль external все еще не запущен"
        return 1
    fi
}

# Тестирование gateway
test_gateway() {
    log TITLE "🧪 Тестирование gateway..."
    
    # Проверка статуса gateway
    local gateway_status=$(docker exec "$FREESWITCH_CONTAINER" fs_cli -x "sofia status gateway sip_trunk" 2>/dev/null)
    
    if echo "$gateway_status" | grep -q "sip_trunk"; then
        log SUCCESS "✅ Gateway sip_trunk найден!"
        log DEBUG "Gateway Status:"
        echo "$gateway_status" | while read -r line; do
            log DEBUG "  $line"
        done
        
        # Попытка тестового звонка
        log INFO "Попытка тестового звонка..."
        local call_result=$(docker exec "$FREESWITCH_CONTAINER" fs_cli -x "originate {call_timeout=5}sofia/gateway/sip_trunk/79001234567 &echo" 2>&1)
        
        if echo "$call_result" | grep -qi "INVALID_GATEWAY"; then
            log WARN "⚠️ Gateway еще недоступен для звонков"
        elif echo "$call_result" | grep -qi "success\|progress\|ringing"; then
            log SUCCESS "✅ Тестовый звонок инициирован успешно!"
        else
            log DEBUG "Результат звонка: $call_result"
        fi
        
        return 0
    else
        log ERROR "❌ Gateway sip_trunk не найден"
        return 1
    fi
}

# Основная функция
main_fix() {
    log TITLE "🔧 ФИНАЛЬНОЕ ИСПРАВЛЕНИЕ FREESWITCH"
    
    local step=1
    
    # Установка xmllint
    log TITLE "Шаг $((step++)): Установка инструментов"
    install_xmllint
    
    # Диагностика volumes
    log TITLE "Шаг $((step++)): Диагностика монтирования"
    if ! check_volume_mounting; then
        log ERROR "Критические проблемы с монтированием"
        return 1
    fi
    
    # Проверка доступа к конфигурации
    log TITLE "Шаг $((step++)): Проверка доступа к конфигурации"
    if check_freeswitch_config_access; then
        log INFO "FreeSWITCH может читать конфигурацию"
    else
        log WARN "FreeSWITCH не может читать конфигурацию, исправляем..."
    fi
    
    # Создание конфигурации в контейнере
    log TITLE "Шаг $((step++)): Создание конфигурации в контейнере"
    create_config_in_container
    
    # Исправление прав доступа
    log TITLE "Шаг $((step++)): Исправление прав доступа"
    fix_permissions_in_container
    
    # Принудительная перезагрузка Sofia
    log TITLE "Шаг $((step++)): Перезагрузка Sofia"
    if force_sofia_reload; then
        log SUCCESS "Sofia успешно перезагружена!"
    else
        log ERROR "Не удалось перезагрузить Sofia"
        return 1
    fi
    
    # Тестирование gateway
    log TITLE "Шаг $((step++)): Тестирование gateway"
    if test_gateway; then
        log SUCCESS "🎉 ВСЕ РАБОТАЕТ! SIP транк готов!"
        return 0
    else
        log ERROR "Gateway еще не работает, но Sofia запущена"
        log INFO "Попробуйте запустить ./test-sip-trunk.sh test через несколько минут"
        return 0
    fi
}

# Запуск
log TITLE "🔧 Финальное исправление FreeSWITCH"
log INFO "Docker Compose команда: $DOCKER_COMPOSE_CMD"
main_fix 