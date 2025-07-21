#!/bin/bash

# 🔍 Диагностика FreeSWITCH Event Socket Library (ESL)
# Скрипт для решения проблемы: "FreeSWITCH not connected - please check Event Socket configuration"

echo "🔍 FreeSWITCH ESL Диагностика"
echo "=================================="

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для логирования
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

# 1. Проверка статуса контейнеров
echo -e "\n📋 1. Проверка статуса контейнеров"
log_info "Проверяем статус всех контейнеров..."
docker ps -a | grep dialer

# 2. Проверка FreeSWITCH
echo -e "\n🎙️ 2. Проверка FreeSWITCH"
log_info "Статус FreeSWITCH..."
docker exec dialer_freeswitch fs_cli -x "show status" 2>/dev/null || log_error "FreeSWITCH недоступен"

# 3. Проверка Event Socket
echo -e "\n🔌 3. Проверка Event Socket"
log_info "Проверяем Event Socket сокеты..."
docker exec dialer_freeswitch fs_cli -x "show sockets" 2>/dev/null || log_error "Event Socket недоступен"

# 4. Проверка портов
echo -e "\n🌐 4. Проверка сетевых портов"
log_info "Проверяем порт 8021 в FreeSWITCH..."
docker exec dialer_freeswitch netstat -tulpn | grep 8021 || log_warning "Порт 8021 не найден"

# 5. Проверка переменных окружения
echo -e "\n⚙️ 5. Проверка переменных окружения Backend"
log_info "Проверяем настройки FreeSWITCH в backend..."
echo "FREESWITCH_HOST: $(docker exec dialer_backend printenv FREESWITCH_HOST)"
echo "FREESWITCH_PORT: $(docker exec dialer_backend printenv FREESWITCH_PORT)" 
echo "FREESWITCH_PASSWORD: $(docker exec dialer_backend printenv FREESWITCH_PASSWORD | sed 's/./*/g')"

# 6. Проверка сетевого соединения
echo -e "\n🌐 6. Проверка сетевого соединения"
log_info "Проверяем подключение backend -> freeswitch..."
if docker exec dialer_backend ping -c 3 freeswitch > /dev/null 2>&1; then
    log_success "Ping до FreeSWITCH успешен"
else
    log_error "Ping до FreeSWITCH не работает"
fi

# 7. Проверка Telnet к Event Socket
echo -e "\n🔗 7. Тест Event Socket подключения"
log_info "Тестируем telnet подключение к Event Socket..."
timeout 5 docker exec dialer_backend bash -c "echo 'auth ClueCon' | telnet freeswitch 8021" 2>/dev/null | grep -q "Content-Type: auth/request" && log_success "Event Socket отвечает" || log_error "Event Socket не отвечает"

# 8. Проверка Docker сети
echo -e "\n🔧 8. Проверка Docker сети"
log_info "Проверяем Docker сеть..."
docker network inspect dailer_dialer_network | grep -A 5 -B 5 "freeswitch\|backend" | grep "IPv4Address" || log_warning "Проблемы с сетью"

# 9. Проверка логов FreeSWITCH на ошибки
echo -e "\n📋 9. Последние ошибки FreeSWITCH"
log_info "Проверяем логи FreeSWITCH на ошибки..."
docker logs --tail 20 dialer_freeswitch 2>&1 | grep -i -E "(error|fail|fatal)" || log_success "Ошибок в логах FreeSWITCH не найдено"

# 10. Проверка логов Backend на ошибки ESL
echo -e "\n📋 10. Ошибки ESL в Backend"
log_info "Проверяем логи backend на ошибки ESL..."
docker logs --tail 50 dialer_backend 2>&1 | grep -i -E "(freeswitch|esl|event socket)" | tail -10

echo -e "\n🔧 ДИАГНОСТИКА ЗАВЕРШЕНА"
echo "=================================="

# Рекомендации по исправлению
echo -e "\n💡 РЕКОМЕНДАЦИИ ПО ИСПРАВЛЕНИЮ:"

echo "1. Если Event Socket не отвечает:"
echo "   docker compose restart freeswitch"

echo "2. Если проблемы с сетью:"
echo "   docker compose down && docker compose up -d"

echo "3. Если FreeSWITCH не запущен:"
echo "   docker compose up -d freeswitch"

echo "4. Для полной перезагрузки:"
echo "   docker compose down && docker compose up -d --build"

echo -e "\n📋 Следующие шаги:"
echo "   - Выполните рекомендуемые команды"
echo "   - Проверьте логи: docker logs -f dialer_backend"
echo "   - Запустите скрипт повторно для проверки" 