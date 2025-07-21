#!/bin/bash

# 🔧 Исправление FreeSWITCH Event Socket Library (ESL)
# Скрипт для автоматического исправления проблем подключения

echo "🔧 Исправление FreeSWITCH ESL"
echo "=============================="

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 1. Сборка и перезапуск FreeSWITCH с собственным образом
echo -e "\n🔄 1. Сборка и перезапуск FreeSWITCH с безопасным образом"
log_info "Собираем собственный безопасный образ FreeSWITCH..."
docker compose build freeswitch
log_info "Перезапускаем FreeSWITCH..."
docker compose up -d freeswitch

# Ожидание запуска
sleep 10

# 2. Проверка статуса после перезапуска
echo -e "\n✅ 2. Проверка статуса FreeSWITCH"
if docker exec dialer_freeswitch fs_cli -x "show status" > /dev/null 2>&1; then
    log_success "FreeSWITCH запущен успешно"
else
    log_error "FreeSWITCH не отвечает"
    
    echo -e "\n🔄 Попытка полной перезагрузки..."
    docker compose down
    sleep 5
    docker compose up -d
    sleep 15
fi

# 3. Проверка Event Socket
echo -e "\n🔌 3. Проверка Event Socket"
log_info "Проверяем доступность Event Socket..."

# Ожидание запуска Event Socket
sleep 5

# Тест подключения
if timeout 10 docker exec dialer_backend bash -c "echo 'auth ClueCon' | telnet freeswitch 8021" 2>/dev/null | grep -q "Content-Type: auth/request"; then
    log_success "Event Socket доступен"
else
    log_warning "Event Socket не отвечает, применяем дополнительные исправления..."
    
    # 4. Проверка конфигурации Event Socket
    echo -e "\n⚙️ 4. Проверка конфигурации Event Socket"
    log_info "Проверяем конфигурацию event_socket.conf.xml..."
    
    # Перезагрузка модуля Event Socket
    docker exec dialer_freeswitch fs_cli -x "reload mod_event_socket" || log_warning "Не удалось перезагрузить mod_event_socket"
    
    sleep 3
    
    # Повторная проверка
    if timeout 10 docker exec dialer_backend bash -c "echo 'auth ClueCon' | telnet freeswitch 8021" 2>/dev/null | grep -q "Content-Type: auth/request"; then
        log_success "Event Socket теперь доступен"
    else
        log_error "Event Socket все еще недоступен"
    fi
fi

# 5. Перезапуск Backend для переподключения
echo -e "\n🔄 5. Перезапуск Backend"
log_info "Перезапускаем backend для переподключения к FreeSWITCH..."
docker compose restart backend

sleep 10

# 6. Финальная проверка
echo -e "\n✅ 6. Финальная проверка"
log_info "Проверяем подключение backend к FreeSWITCH..."

# Ждем несколько секунд для установления соединения
sleep 5

# Проверяем логи backend на успешное подключение
if docker logs --tail 20 dialer_backend 2>&1 | grep -q "Connected to FreeSWITCH successfully"; then
    log_success "✅ FreeSWITCH ESL подключение восстановлено!"
    echo -e "\n🎉 ПРОБЛЕМА РЕШЕНА!"
    echo "================================"
    echo "✅ FreeSWITCH Event Socket работает"
    echo "✅ Backend подключен к FreeSWITCH"
    echo "✅ Звонки должны теперь работать"
else
    log_warning "Подключение еще не установлено, проверяем детали..."
    
    echo -e "\n📋 Последние логи backend:"
    docker logs --tail 10 dialer_backend 2>&1 | grep -i freeswitch
    
    echo -e "\n💡 Дополнительные действия:"
    echo "1. Проверьте переменные окружения:"
    echo "   docker exec dialer_backend printenv | grep FREESWITCH"
    echo ""
    echo "2. Проверьте сетевое соединение:"
    echo "   docker exec dialer_backend ping freeswitch"
    echo ""
    echo "3. Проверьте порты FreeSWITCH:"
    echo "   docker exec dialer_freeswitch netstat -tulpn | grep 8021"
    echo ""
    echo "4. Если ничего не помогает, выполните полную перезагрузку:"
    echo "   docker compose down && docker system prune -f && docker compose up -d --build"
fi

echo -e "\n📋 Мониторинг подключения:"
echo "Для мониторинга соединения выполните:"
echo "docker logs -f dialer_backend | grep -i freeswitch" 