#!/bin/bash

# Скрипт для решения конфликта git merge на тестовом сервере
# Используется когда неотслеживаемые файлы мешают обновлению

echo "🔧 РЕШЕНИЕ КОНФЛИКТА GIT MERGE"
echo "==============================="

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
    log_error "Запустите скрипт из корневой директории проекта dailer!"
    exit 1
fi

log_info "Анализ состояния git..."

# 2. Показываем текущий статус
git status

# 3. Проверяем наличие проблемного файла
if [ -f "sync-server-updates.sh" ]; then
    log_info "Найден файл sync-server-updates.sh, который мешает merge"
    
    # Создаем резервную копию если файл содержит важные данные
    if [ -s "sync-server-updates.sh" ]; then
        log_info "Создание резервной копии файла..."
        cp sync-server-updates.sh sync-server-updates.sh.backup.$(date +%s)
        log_success "Резервная копия создана"
    fi
    
    # Удаляем проблемный файл
    log_info "Удаление файла sync-server-updates.sh..."
    rm -f sync-server-updates.sh
    log_success "Файл удален"
else
    log_info "Файл sync-server-updates.sh не найден"
fi

# 4. Проверяем другие неотслеживаемые файлы
UNTRACKED_FILES=$(git ls-files --others --exclude-standard)
if [ -n "$UNTRACKED_FILES" ]; then
    log_info "Найдены другие неотслеживаемые файлы:"
    echo "$UNTRACKED_FILES"
    
    echo ""
    read -p "Хотите удалить все неотслеживаемые файлы? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Удаление всех неотслеживаемых файлов..."
        git clean -fd
        log_success "Неотслеживаемые файлы удалены"
    else
        log_info "Неотслеживаемые файлы оставлены как есть"
    fi
fi

# 5. Пробуем выполнить git pull
log_info "Попытка выполнить git pull origin main..."
if git pull origin main; then
    log_success "Git pull выполнен успешно!"
else
    log_error "Git pull завершился с ошибкой"
    echo ""
    echo "🔍 ДОПОЛНИТЕЛЬНЫЕ ДЕЙСТВИЯ:"
    echo "=========================="
    echo "1. Проверьте статус: git status"
    echo "2. Если есть конфликты, разрешите их вручную"
    echo "3. Попробуйте: git reset --hard origin/main (ОСТОРОЖНО: удалит локальные изменения)"
    exit 1
fi

# 6. Показываем итоговый статус
echo ""
log_info "Проверка итогового состояния..."
git status

echo ""
echo "🎉 ГОТОВО К ПРОДОЛЖЕНИЮ!"
echo "========================"
echo "Теперь можно выполнить:"
echo "1. docker-compose restart freeswitch_host"
echo "2. ./diagnose-sip-detailed.sh"

log_success "Проблема с git решена!" 