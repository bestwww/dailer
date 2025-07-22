#!/bin/bash

# 🆕 Asterisk Docker EntryPoint
# Скрипт запуска Asterisk в контейнере

set -e

# 🎨 Функция для красивого логирования
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ASTERISK] $1"
}

log "🐳 Запуск Asterisk Docker контейнера..."

# 🔧 Проверяем что Asterisk установлен
if ! command -v asterisk >/dev/null 2>&1; then
    log "❌ Asterisk не найден!"
    exit 1
fi

log "✅ Asterisk найден: $(asterisk -V | head -1)"

# 🗂️ Проверяем что все директории существуют
log "🗂️ Проверяем директории..."
mkdir -p /var/lib/asterisk
mkdir -p /var/log/asterisk
mkdir -p /var/spool/asterisk
mkdir -p /etc/asterisk

# 🔧 Устанавливаем правильные права
log "🔧 Настраиваем права доступа..."
chown -R asterisk:asterisk /var/lib/asterisk /var/log/asterisk /var/spool/asterisk /etc/asterisk 2>/dev/null || true

# 🌐 Отображаем сетевую информацию
log "🌐 Сетевая информация:"
log "   Hostname: $(hostname)"
log "   IP адреса: $(hostname -I | tr ' ' ',')"

# 🔌 Отображаем открытые порты  
log "🔌 Открытые порты:"
log "   SIP: 5060/udp, 5060/tcp"
log "   RTP: 10000-20000/udp"
log "   AMI: 5038/tcp"
log "   ARI: 8088/tcp"

# 🚀 Запуск Asterisk
log "🚀 Запускаем Asterisk..."

# Если передан аргумент "asterisk", запускаем Asterisk
if [ "$1" = "asterisk" ]; then
    shift
    log "📞 Asterisk готов к приему звонков!"
    exec asterisk -U asterisk -G asterisk "$@"
elif [ "$1" = "asterisk-cli" ]; then
    # Если нужен CLI
    shift
    exec asterisk -r "$@"
else
    log "🔧 Выполняем команду: $*"
    exec "$@"
fi 