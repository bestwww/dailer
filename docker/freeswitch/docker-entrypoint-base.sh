#!/bin/bash

# 🐳 FreeSWITCH Docker EntryPoint - БАЗОВЫЙ ОБРАЗ
# Информационный скрипт для ручной установки FreeSWITCH

set -e

# 🎨 Функция логирования
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [BASE-IMAGE] $1"
}

log "🐳 FreeSWITCH Base Docker контейнер запущен"
log ""
log "ℹ️  Это базовый образ БЕЗ FreeSWITCH!"
log "🔧 FreeSWITCH требует ручной установки"
log ""

# 🔍 Проверяем есть ли FreeSWITCH
if command -v freeswitch >/dev/null 2>&1; then
    log "✅ FreeSWITCH найден: $(which freeswitch)"
    if [ "$1" = "freeswitch" ]; then
        shift
        log "🚀 Запускаем FreeSWITCH..."
        exec freeswitch "$@"
    fi
else
    log "📋 ИНСТРУКЦИИ ПО УСТАНОВКЕ FreeSWITCH:"
    log ""
    log "🔧 Вариант 1 - Готовые пакеты (рекомендуется):"
    log "   apt-get update"
    log "   apt-get install -y software-properties-common"
    log "   add-apt-repository universe"
    log "   apt-get update" 
    log "   apt-get install -y freeswitch freeswitch-mod-*"
    log ""
    log "🔧 Вариант 2 - Официальный репозиторий:"
    log "   # Добавляем GPG ключ"
    log "   wget -O- https://files.freeswitch.org/repo/deb/freeswitch_archive_g0.pub | gpg --dearmor -o /etc/apt/keyrings/freeswitch.gpg"
    log "   # Добавляем репозиторий"
    log "   echo 'deb [signed-by=/etc/apt/keyrings/freeswitch.gpg] http://files.freeswitch.org/repo/deb/debian-release/ jammy main' > /etc/apt/sources.list.d/freeswitch.list"
    log "   apt-get update && apt-get install -y freeswitch"
    log ""
    log "🔧 Вариант 3 - Сборка из исходников:"
    log "   cd /usr/src"
    log "   git clone https://github.com/signalwire/freeswitch.git"
    log "   cd freeswitch && ./bootstrap.sh && ./configure && make && make install"
    log ""
    log "🔧 Вариант 4 - Snap пакет:"
    log "   apt-get install -y snapd"
    log "   snap install freeswitch"
    log ""
fi

# 🌐 Показываем сетевую информацию
log "🌐 Информация о контейнере:"
log "   Hostname: $(hostname)"
log "   IP: $(hostname -I | tr ' ' ',' || echo 'unknown')"
log "   OS: $(lsb_release -d | cut -f2- || echo 'Ubuntu')"

# 🔌 Порты
log "🔌 Открытые порты для FreeSWITCH:"
log "   SIP: 5060/udp, 5060/tcp"
log "   RTP: 16384-32768/udp"
log "   Event Socket: 8021/tcp"

# 🗂️ Директории
log "🗂️ Готовые директории:"
log "   Конфиг: /etc/freeswitch"
log "   Логи: /var/log/freeswitch"
log "   Данные: /var/lib/freeswitch"
log "   Бинарники: /usr/local/freeswitch"

log ""
log "💡 После установки FreeSWITCH выполните:"
log "   freeswitch -nonat -c"
log "   # или для запуска в фоне:"
log "   freeswitch -nc"
log ""

# 🚀 Запуск команды
if [ "$1" = "bash" ] || [ "$1" = "sh" ]; then
    log "🚀 Запускаем интерактивную оболочку..."
    exec "$@"
elif [ -z "$1" ]; then
    log "🚀 Запускаем bash по умолчанию..."
    exec bash
else
    log "🚀 Выполняем команду: $*"
    exec "$@"
fi 