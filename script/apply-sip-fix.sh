#!/bin/bash

# Скрипт для применения исправлений SIP на тестовом сервере
# Запускать ПОСЛЕ получения учетных данных от провайдера

echo "🔧 ПРИМЕНЕНИЕ ИСПРАВЛЕНИЙ SIP"
echo "============================"

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 1. Проверяем, что мы в правильной директории
if [ ! -f "docker-compose.yml" ]; then
    log_error "Запустите скрипт из корневой директории проекта!"
    exit 1
fi

# 2. Проверяем наличие конфигурационных файлов
if [ ! -f "freeswitch/conf/autoload_configs/sofia.conf.xml" ]; then
    log_error "Файл sofia.conf.xml не найден!"
    exit 1
fi

# 3. Показываем текущее состояние
log_info "Проверка текущей конфигурации..."
if grep -q "register.*true" freeswitch/conf/autoload_configs/sofia.conf.xml; then
    log_error "ВНИМАНИЕ: В конфигурации включена регистрация, но провайдер работает без аутентификации!"
    echo "Убедитесь что register=\"false\" в sofia.conf.xml"
    exit 1
fi

log_success "Конфигурация настроена для работы без аутентификации (по IP whitelist)"

# 4. Коммитим изменения в git
log_info "Добавление изменений в git..."
git add freeswitch/conf/autoload_configs/sofia.conf.xml
git add freeswitch/conf/vars.xml
git add diagnose-sip-detailed.sh
git add SIP_SETUP_INSTRUCTIONS.md
git add apply-sip-fix.sh

git commit -m "fix: Настройка SIP для работы без аутентификации (по IP whitelist)

- Обновлена конфигурация SIP gateway для работы без регистрации
- Провайдер работает по IP whitelist без username/password
- Добавлен детальный скрипт диагностики SIP
- Создана инструкция по настройке SIP
- IP 46.173.16.147 добавлен в whitelist провайдера"

# 5. Пушим изменения
log_info "Отправка изменений в репозиторий..."
git push origin main

log_success "Изменения отправлены в git!"

echo ""
echo "🚀 СЛЕДУЮЩИЕ ШАГИ НА ТЕСТОВОМ СЕРВЕРЕ:"
echo "====================================="
echo "1. git pull origin main"
echo "2. docker-compose restart freeswitch_host"
echo "3. ./diagnose-sip-detailed.sh"
echo ""
echo "📞 ИНФОРМАЦИЯ ОТ ПРОВАЙДЕРА:"
echo "============================"
echo "✅ IP 46.173.16.147 добавлен в whitelist"
echo "✅ Аутентификация не требуется (работа по IP)"
echo "✅ Можно передавать любой Caller ID номер"
echo ""
log_success "Исправления применены успешно!" 