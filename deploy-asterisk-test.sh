#!/bin/bash

# 🚀 Деплой Asterisk на тестовый сервер
# Скрипт для развертывания системы с поддержкой Asterisk

set -e  # Остановить при ошибке

# 🎨 Цвета для логов
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# 🔧 Переменные
REPO_URL="https://github.com/ваш-репозиторий/dialer-system.git"  # ЗАМЕНИТЕ на ваш репозиторий
PROJECT_DIR="/opt/dialer"
BACKUP_DIR="/opt/dialer-backup-$(date +%Y%m%d-%H%M%S)"
CALLER_ID=${SIP_CALLER_ID_NUMBER:-"+7123456789"}

log "🚀 Начало деплоя Asterisk на тестовый сервер"
log "📞 Caller ID: $CALLER_ID"

# ===============================
# 1. ПРОВЕРКА СИСТЕМЫ
# ===============================

log "🔍 Проверка системы..."

# Проверка Docker
if ! command -v docker &> /dev/null; then
    error "Docker не установлен!"
    info "Установите Docker: curl -fsSL https://get.docker.com | sh"
    exit 1
fi

# Проверка Docker Compose
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    error "Docker Compose не установлен!"
    info "Установите Docker Compose"
    exit 1
fi

# Проверка Git
if ! command -v git &> /dev/null; then
    error "Git не установлен!"
    info "Установите Git: apt-get install git"
    exit 1
fi

log "✅ Система готова"

# ===============================
# 2. БЭКАП СУЩЕСТВУЮЩЕЙ СИСТЕМЫ
# ===============================

if [ -d "$PROJECT_DIR" ]; then
    log "💾 Создание бэкапа существующей системы..."
    
    # Остановить контейнеры
    cd "$PROJECT_DIR"
    docker compose down || warn "Не удалось остановить контейнеры"
    
    # Создать бэкап
    sudo cp -r "$PROJECT_DIR" "$BACKUP_DIR"
    log "✅ Бэкап создан: $BACKUP_DIR"
fi

# ===============================
# 3. СКАЧИВАНИЕ КОДА
# ===============================

log "📥 Скачивание последней версии кода..."

# Клонирование или обновление
if [ -d "$PROJECT_DIR" ]; then
    cd "$PROJECT_DIR"
    git fetch origin
    git reset --hard origin/main
    log "✅ Код обновлен"
else
    sudo git clone "$REPO_URL" "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    log "✅ Код скачан"
fi

# Права доступа
sudo chown -R $USER:$USER "$PROJECT_DIR"

# ===============================
# 4. ПОДГОТОВКА ОКРУЖЕНИЯ
# ===============================

log "⚙️ Настройка окружения для Asterisk..."

# Создание .env файла для тестового сервера
cat > .env << EOF
# ===== ASTERISK CONFIGURATION =====
VOIP_PROVIDER=asterisk
SIP_CALLER_ID_NUMBER=${CALLER_ID}

# ===== SIP TRUNK =====
SIP_PROVIDER_HOST=62.141.121.197
SIP_PROVIDER_PORT=5070
EXTERNAL_IP=auto

# ===== ASTERISK AMI =====
ASTERISK_HOST=asterisk
ASTERISK_PORT=5038
ASTERISK_USERNAME=admin
ASTERISK_PASSWORD=admin

# ===== DATABASE =====
DATABASE_URL=postgresql://dialer_user:secure_password_123@postgres:5432/dialer_db
REDIS_URL=redis://:redis_password_123@redis:6379

# ===== APP SETTINGS =====
NODE_ENV=production
PORT=3000
JWT_SECRET=e556e588ee21e16ed4485a2c94149363ec8c85c881801895ecce9d786d41084e445fca510a8cf7d6fe771e65d956e23d1e0b40b6b82029b1920bb034c17a5149

# ===== MONITORING =====
LOG_LEVEL=info
MONITORING_ENABLED=true

# ===== DIALER SETTINGS =====
MAX_CONCURRENT_CALLS=10
CALLS_PER_MINUTE=30
EOF

log "✅ .env файл создан"

# ===============================
# 5. СБОРКА И ЗАПУСК
# ===============================

log "🏗️ Сборка Docker образов..."

# Остановить существующие контейнеры
docker compose down || warn "Контейнеры уже остановлены"

# Очистка старых образов (опционально)
# docker system prune -f

# Сборка образов
log "📦 Сборка Asterisk образа..."
docker compose build asterisk

log "📦 Сборка backend образа..."
docker compose build backend

log "📦 Сборка frontend образа..."
docker compose build frontend

log "✅ Образы собраны"

# ===============================
# 6. ЗАПУСК ASTERISK СИСТЕМЫ
# ===============================

log "🚀 Запуск системы с Asterisk..."

# Запуск с Asterisk профилем
docker compose --profile asterisk up -d

log "✅ Контейнеры запущены"

# ===============================
# 7. ПРОВЕРКА ЗДОРОВЬЯ
# ===============================

log "🏥 Проверка здоровья системы..."

# Ждем запуска
sleep 30

# Проверка контейнеров
log "📋 Статус контейнеров:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Проверка логов Asterisk
log "📋 Последние логи Asterisk:"
docker logs --tail 20 dialer_asterisk

# Проверка backend
if curl -f http://localhost:3000/health >/dev/null 2>&1; then
    log "✅ Backend отвечает"
else
    warn "Backend может быть еще не готов"
fi

# ===============================
# 8. ТЕСТИРОВАНИЕ
# ===============================

log "🧪 Запуск тестов..."

# Тест AMI подключения
log "📞 Тест AMI подключения..."
if docker exec dialer_backend npm run dev -- --script test-asterisk; then
    log "✅ AMI тест прошел"
else
    warn "AMI тест не прошел"
fi

# Тест SIP trunk
log "📞 Тест SIP trunk..."
if docker exec dialer_backend npm run dev -- --script test-sip-trunk; then
    log "✅ SIP trunk тест прошел"
else
    warn "SIP trunk тест не прошел"
fi

# ===============================
# 9. ФИНАЛЬНАЯ ИНФОРМАЦИЯ
# ===============================

log "🎉 Деплой завершен!"
info ""
info "📊 Информация о системе:"
info "   Frontend: http://$(hostname -I | awk '{print $1}'):5173"
info "   Backend API: http://$(hostname -I | awk '{print $1}'):3000"
info "   Asterisk AMI: $(hostname -I | awk '{print $1}'):5038"
info "   SIP Trunk: 62.141.121.197:5070"
info "   Caller ID: $CALLER_ID"
info ""
info "🔧 Полезные команды:"
info "   Логи Asterisk: docker logs -f dialer_asterisk"
info "   Логи Backend: docker logs -f dialer_backend"
info "   Asterisk CLI: docker exec -it dialer_asterisk asterisk -r"
info "   SIP статус: docker exec dialer_asterisk asterisk -rx \"pjsip show endpoints\""
info "   Перезапуск: docker compose --profile asterisk restart"
info ""
info "💾 Бэкап сохранен: $BACKUP_DIR"
info ""
log "✅ Система готова к тестированию звонков!"

# Показать активные каналы
info "📞 Проверка SIP endpoint:"
docker exec dialer_asterisk asterisk -rx "pjsip show endpoint trunk" || warn "Не удалось проверить SIP endpoint"

log "🎯 ГОТОВО! Asterisk запущен и готов к тестированию." 