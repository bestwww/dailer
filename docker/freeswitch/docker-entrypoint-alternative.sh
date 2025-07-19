#!/bin/bash

# 🚀 FreeSWITCH Docker EntryPoint - АЛЬТЕРНАТИВНАЯ ВЕРСИЯ
# Работает с различными способами установки FreeSWITCH

set -e

# 🎨 Функция логирования
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ENTRYPOINT-ALT] $1"
}

log "🐳 Запуск FreeSWITCH Docker (альтернативная версия)..."

# 🔍 Проверяем наличие FreeSWITCH в различных местах
FREESWITCH_BIN=""

if command -v freeswitch >/dev/null 2>&1; then
    FREESWITCH_BIN="freeswitch"
    log "✅ FreeSWITCH найден в PATH: $(which freeswitch)"
elif [ -f "/usr/local/freeswitch/bin/freeswitch" ]; then
    FREESWITCH_BIN="/usr/local/freeswitch/bin/freeswitch"
    log "✅ FreeSWITCH найден: $FREESWITCH_BIN"
elif [ -f "/usr/bin/freeswitch" ]; then
    FREESWITCH_BIN="/usr/bin/freeswitch"
    log "✅ FreeSWITCH найден: $FREESWITCH_BIN"
else
    log "❌ FreeSWITCH не найден!"
    log "🔍 Попытка поиска FreeSWITCH в системе..."
    find / -name "freeswitch" -type f -executable 2>/dev/null | head -5
    log "⚠️ FreeSWITCH не установлен. Возможные варианты:"
    log "   1. Установить вручную в runtime"
    log "   2. Использовать другой Docker образ"
    log "   3. Собрать из исходников"
    exit 1
fi

# 📊 Показываем информацию о FreeSWITCH
log "📊 Информация о FreeSWITCH:"
if $FREESWITCH_BIN -version >/dev/null 2>&1; then
    log "   Версия: $($FREESWITCH_BIN -version | head -1)"
    log "   Путь: $FREESWITCH_BIN"
else
    log "   ⚠️ Не удается получить версию FreeSWITCH"
fi

# 🗂️ Создаем директории
log "🗂️ Настраиваем директории..."
mkdir -p /var/lib/freeswitch/storage
mkdir -p /var/lib/freeswitch/recordings  
mkdir -p /var/log/freeswitch
mkdir -p /etc/freeswitch

# 🔧 Права доступа
log "🔧 Настраиваем права доступа..."
if id "freeswitch" >/dev/null 2>&1; then
    chown -R freeswitch:freeswitch /var/lib/freeswitch /var/log/freeswitch /etc/freeswitch 2>/dev/null || true
    log "✅ Права для пользователя freeswitch установлены"
else
    log "⚠️ Пользователь freeswitch не найден, используем root"
fi

# 🌐 Сетевая информация
log "🌐 Сетевая информация:"
log "   Hostname: $(hostname)"
log "   IP: $(hostname -I | tr ' ' ',' || echo 'unknown')"

# 🔌 Порты
log "🔌 Открытые порты:"
log "   SIP: 5060/udp, 5060/tcp, 5080/udp, 5080/tcp"
log "   RTP: 16384-32768/udp"
log "   Event Socket: 8021/tcp"

# 🚀 Запуск
log "🚀 Запускаем FreeSWITCH..."

if [ "$1" = "freeswitch" ]; then
    shift
    log "📞 FreeSWITCH готов к работе!"
    exec $FREESWITCH_BIN "$@"
elif [ "$1" = "fs_cli" ]; then
    shift
    # Ищем fs_cli
    if command -v fs_cli >/dev/null 2>&1; then
        exec fs_cli "$@"
    else
        log "❌ fs_cli не найден"
        exit 1
    fi
else
    log "🔧 Выполняем команду: $*"
    exec "$@"
fi 