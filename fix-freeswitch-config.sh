#!/bin/bash

# Скрипт для принудительного обновления конфигурации FreeSWITCH
# Используется когда конфигурация не применилась после git pull

echo "🔧 ОБНОВЛЕНИЕ КОНФИГУРАЦИИ FREESWITCH"
echo "====================================="

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 1. Проверяем, что мы в правильной директории
if [ ! -f "docker-compose.yml" ]; then
    log_error "Запустите скрипт из корневой директории проекта dailer!"
    exit 1
fi

# 2. Проверяем состояние FreeSWITCH
log_info "Проверка состояния FreeSWITCH контейнера..."
if ! docker ps | grep -q "dialer_freeswitch_host"; then
    log_error "Контейнер dialer_freeswitch_host не запущен!"
    exit 1
fi

log_success "Контейнер FreeSWITCH запущен"

# 3. Показываем текущую конфигурацию gateway
log_info "Текущая конфигурация SIP gateway:"
docker exec dialer_freeswitch_host fs_cli -x "sofia status gateway sip_trunk" | head -20

# 4. Проверяем конфигурационный файл
log_info "Проверка файла конфигурации sofia.conf.xml..."
if grep -q 'username.*FreeSWITCH' freeswitch/conf/autoload_configs/sofia.conf.xml; then
    log_warn "Обнаружена старая конфигурация с username=FreeSWITCH"
    log_info "Файл нужно обновить..."
else
    log_success "Конфигурационный файл корректен"
fi

# 5. Перезагружаем конфигурацию XML
log_info "Перезагрузка XML конфигурации FreeSWITCH..."
docker exec dialer_freeswitch_host fs_cli -x "reloadxml"
sleep 2

# 6. Перезапускаем Sofia SIP профиль
log_info "Перезапуск Sofia SIP профиля external..."
docker exec dialer_freeswitch_host fs_cli -x "sofia profile external restart"
sleep 5

# 7. Проверяем результат
log_info "Проверка обновленной конфигурации gateway..."
GATEWAY_STATUS=$(docker exec dialer_freeswitch_host fs_cli -x "sofia status gateway sip_trunk")
echo "$GATEWAY_STATUS"

# 8. Анализируем статус
if echo "$GATEWAY_STATUS" | grep -q "Username.*FreeSWITCH"; then
    log_error "Конфигурация все еще содержит старые данные!"
    log_info "Требуется полный перезапуск контейнера..."
    
    # Полный перезапуск FreeSWITCH
    log_info "Выполнение полного перезапуска FreeSWITCH..."
    docker-compose restart freeswitch_host
    
    log_info "Ожидание запуска FreeSWITCH (30 секунд)..."
    sleep 30
    
    # Проверяем снова
    log_info "Проверка после перезапуска..."
    docker exec dialer_freeswitch_host fs_cli -x "sofia status gateway sip_trunk" | head -20
    
else
    log_success "Конфигурация успешно обновлена!"
fi

# 9. Тестовый звонок
log_info "Выполнение тестового звонка..."
TEST_RESULT=$(docker exec dialer_freeswitch_host fs_cli -x "originate sofia/gateway/sip_trunk/+79206054020 &echo" 2>&1)
echo "Результат: $TEST_RESULT"

if echo "$TEST_RESULT" | grep -q "INTERWORKING"; then
    log_warn "Ошибка INTERWORKING - возможная проблема с форматом номера"
    echo ""
    echo "🔍 РЕКОМЕНДАЦИИ:"
    echo "================"
    echo "1. Проверьте формат номера: +79206054020"
    echo "2. Попробуйте без '+': 79206054020"
    echo "3. Попробуйте с кодом страны: 79206054020"
    echo "4. Свяжитесь с провайдером для уточнения формата"
    
elif echo "$TEST_RESULT" | grep -q "SUCCESS\|ANSWER"; then
    log_success "Тестовый звонок успешен!"
else
    log_warn "Неожиданный результат тестового звонка"
fi

echo ""
echo "🎯 СЛЕДУЮЩИЕ ДЕЙСТВИЯ:"
echo "====================="
echo "1. Если ошибка INTERWORKING сохраняется - уточните формат номера у провайдера"
echo "2. Попробуйте разные форматы номеров при тестировании"
echo "3. Проверьте что Caller ID (+79058615815) соответствует требованиям"

log_success "Обновление конфигурации завершено!" 