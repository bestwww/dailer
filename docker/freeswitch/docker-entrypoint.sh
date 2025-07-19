#!/bin/bash

# 🚀 FreeSWITCH Docker EntryPoint
# Скрипт запуска FreeSWITCH в контейнере (готовые пакеты)

set -e

# 🎨 Функция для красивого логирования
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ENTRYPOINT] $1"
}

log "🐳 Запуск FreeSWITCH Docker контейнера..."

# 🔧 Проверяем что FreeSWITCH установлен
if ! command -v freeswitch >/dev/null 2>&1; then
    log "❌ FreeSWITCH не найден!"
    exit 1
fi

log "✅ FreeSWITCH найден: $(freeswitch -version | head -1)"

# 🗂️ Проверяем что все директории существуют
log "🗂️ Проверяем директории..."
mkdir -p /var/lib/freeswitch/storage
mkdir -p /var/lib/freeswitch/recordings  
mkdir -p /var/log/freeswitch
mkdir -p /etc/freeswitch

# 🔧 Устанавливаем правильные права
log "🔧 Настраиваем права доступа..."
chown -R freeswitch:freeswitch /var/lib/freeswitch /var/log/freeswitch /etc/freeswitch 2>/dev/null || true

# 🌐 Отображаем сетевую информацию
log "🌐 Сетевая информация:"
log "   Hostname: $(hostname)"
log "   IP адреса: $(hostname -I | tr ' ' ',')"

# 🔌 Отображаем открытые порты  
log "🔌 Открытые порты:"
log "   SIP: 5060/udp, 5060/tcp, 5080/udp, 5080/tcp"
log "   RTP: 16384-32768/udp"
log "   Event Socket: 8021/tcp"

# 🚀 Запуск FreeSWITCH
log "🚀 Запускаем FreeSWITCH..."

# Если передан аргумент "freeswitch", запускаем FreeSWITCH
if [ "$1" = "freeswitch" ]; then
    shift
    log "📞 FreeSWITCH готов к приему звонков!"
    exec freeswitch "$@"
elif [ "$1" = "fs_cli" ]; then
    # Если нужен CLI
    shift
    exec fs_cli "$@"
else
    # Любые другие команды
    log "🔧 Выполняем команду: $*"
    exec "$@"
fi 