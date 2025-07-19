#!/bin/bash

# 🐳 FreeSWITCH Docker Entrypoint - ГОТОВЫЙ ОБРАЗ
# Точка входа для готового образа FreeSWITCH

# 🎨 Функция для логирования с временной меткой
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ENTRYPOINT-READY] $1"
}

log "🐳 Запуск FreeSWITCH Docker (готовый образ)..."

# 🔍 Проверяем наличие FreeSWITCH
if command -v freeswitch >/dev/null 2>&1; then
    log "✅ FreeSWITCH найден!"
    
    # Показываем версию FreeSWITCH
    freeswitch -version | head -3 || log "⚠️ Не удалось получить версию FreeSWITCH"
    
    # 🔧 Проверяем конфигурацию
    if [ -d "/usr/local/freeswitch/conf" ]; then
        log "✅ Конфигурационная директория найдена"
        
        # Проверяем ключевые файлы конфигурации
        if [ -f "/usr/local/freeswitch/conf/freeswitch.xml" ]; then
            log "✅ Основной файл конфигурации найден"
        else
            log "⚠️ Основной файл конфигурации не найден"
        fi
        
        if [ -d "/usr/local/freeswitch/conf/autoload_configs" ]; then
            log "✅ Директория автозагрузки модулей найдена"
        else
            log "⚠️ Директория автозагрузки модулей не найдена"
        fi
    else
        log "⚠️ Конфигурационная директория не найдена"
    fi
    
    # 🗂️ Проверяем и создаем необходимые директории
    mkdir -p /var/lib/freeswitch/storage
    mkdir -p /var/lib/freeswitch/recordings  
    mkdir -p /var/log/freeswitch
    
    # 👤 Проверяем пользователя freeswitch
    if id "freeswitch" &>/dev/null; then
        log "✅ Пользователь freeswitch существует"
        
        # Устанавливаем права доступа
        chown -R freeswitch:freeswitch /var/lib/freeswitch 2>/dev/null || true
        chown -R freeswitch:freeswitch /var/log/freeswitch 2>/dev/null || true
        chown -R freeswitch:freeswitch /usr/local/freeswitch/conf 2>/dev/null || true
    else
        log "⚠️ Пользователь freeswitch не существует, создаем..."
        useradd --system --home-dir /var/lib/freeswitch --shell /bin/false freeswitch
    fi
    
    log "🚀 Запускаем FreeSWITCH..."
    
    # Если первый аргумент - freeswitch, запускаем FreeSWITCH
    if [ "$1" = "freeswitch" ]; then
        shift  # убираем первый аргумент
        exec freeswitch "$@"
    else
        # Запускаем любую другую команду
        exec "$@"
    fi
    
else
    log "❌ FreeSWITCH не найден в готовом образе!"
    log "🔍 Проверяем систему..."
    
    # Диагностика
    which freeswitch || log "freeswitch не найден в PATH"
    ls -la /usr/local/freeswitch/ 2>/dev/null || log "Директория /usr/local/freeswitch не найдена"
    ls -la /usr/bin/freeswitch* 2>/dev/null || log "FreeSWITCH не найден в /usr/bin/"
    ls -la /usr/sbin/freeswitch* 2>/dev/null || log "FreeSWITCH не найден в /usr/sbin/"
    
    log "⚠️ FreeSWITCH недоступен в готовом образе. Возможные причины:"
    log "   1. Образ поврежден или неправильный"
    log "   2. FreeSWITCH установлен в нестандартном месте"
    log "   3. Проблемы с правами доступа"
    
    # Пытаемся запустить то, что передали в параметрах
    if [ $# -gt 0 ]; then
        log "🔄 Попытка выполнить команду: $*"
        exec "$@"
    else
        log "❌ Нет команды для выполнения, завершаем с ошибкой"
        exit 1
    fi
fi 