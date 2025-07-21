#!/bin/bash

# 📞 Скрипт тестирования звонков системы автодозвона
# Тестирует как внутренние номера, так и реальные звонки

set -e

echo "📞 === ТЕСТИРОВАНИЕ СИСТЕМЫ АВТОДОЗВОНА ==="
echo

# Функция для логирования
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [TEST] $1"
}

# Функция для проверки статуса FreeSWITCH
check_freeswitch() {
    log "🔍 Проверяем статус FreeSWITCH..."
    
    # Проверяем что контейнер запущен
    if ! docker ps | grep -q freeswitch; then
        log "❌ FreeSWITCH контейнер не запущен!"
        log "🚀 Запускаем FreeSWITCH..."
        docker compose up -d freeswitch
        sleep 10
    fi
    
    # Проверяем Event Socket
    if docker exec $(docker ps | grep freeswitch | awk '{print $1}') nc -z 127.0.0.1 8021; then
        log "✅ Event Socket доступен (порт 8021)"
    else
        log "❌ Event Socket недоступен!"
        return 1
    fi
    
    # Проверяем статус FreeSWITCH
    log "📊 Статус FreeSWITCH:"
    docker exec $(docker ps | grep freeswitch | awk '{print $1}') fs_cli -x "status" || true
}

# Функция для тестового звонка
test_call() {
    local number=$1
    local description=$2
    
    log "📞 Тестовый звонок на $number ($description)"
    
    # Выполняем звонок через FreeSWITCH
    local container_id=$(docker ps | grep freeswitch | awk '{print $1}')
    
    # Команда для originate
    local cmd="originate user/$number &echo"
    
    log "🔧 Выполняем команду: $cmd"
    
    # Логируем результат
    if timeout 30 docker exec $container_id fs_cli -x "$cmd"; then
        log "✅ Звонок на $number выполнен успешно"
    else
        log "❌ Звонок на $number завершился ошибкой"
    fi
    
    echo "----------------------------------------"
}

# Функция для реального звонка
test_real_call() {
    local number=$1
    
    log "📞 РЕАЛЬНЫЙ звонок на номер $number"
    log "⚠️  ВНИМАНИЕ: Это будет реальный звонок через SIP-провайдера!"
    
    read -p "Продолжить? (y/N): " confirm
    
    if [[ $confirm != [yY] ]]; then
        log "⏹️  Реальный звонок отменен пользователем"
        return
    fi
    
    # Выполняем реальный звонок
    local container_id=$(docker ps | grep freeswitch | awk '{print $1}')
    
    # Команда для originate с реальным номером
    local cmd="originate sofia/gateway/sip_trunk/$number &echo"
    
    log "🔧 Выполняем РЕАЛЬНЫЙ звонок: $cmd"
    
    # Показываем логи в реальном времени
    log "📱 Следите за логами звонка..."
    timeout 60 docker logs -f $container_id &
    local logs_pid=$!
    
    # Выполняем звонок
    if timeout 30 docker exec $container_id fs_cli -x "$cmd"; then
        log "✅ Реальный звонок на $number выполнен"
    else
        log "❌ Реальный звонок на $number завершился ошибкой"
    fi
    
    # Останавливаем отслеживание логов
    kill $logs_pid 2>/dev/null || true
    
    echo "----------------------------------------"
}

# Функция для показа логов FreeSWITCH
show_logs() {
    log "📋 Показываем последние логи FreeSWITCH..."
    local container_id=$(docker ps | grep freeswitch | awk '{print $1}')
    
    echo
    echo "=== ПОСЛЕДНИЕ 20 СТРОК ЛОГОВ ==="
    docker logs --tail 20 $container_id
    
    echo
    echo "=== МОНИТОРИНГ ЛОГОВ В РЕАЛЬНОМ ВРЕМЕНИ ==="
    echo "Нажмите Ctrl+C для остановки..."
    docker logs -f $container_id
}

# Функция для проверки SIP-транка
check_sip_trunk() {
    log "🔗 Проверяем состояние SIP-транка..."
    local container_id=$(docker ps | grep freeswitch | awk '{print $1}')
    
    log "📊 Статус Sofia профилей:"
    docker exec $container_id fs_cli -x "sofia status"
    
    echo
    log "🌐 Состояние gateway:"
    docker exec $container_id fs_cli -x "sofia status gateway sip_trunk"
}

# Основное меню
show_menu() {
    echo
    echo "📞 === МЕНЮ ТЕСТИРОВАНИЯ ЗВОНКОВ ==="
    echo
    echo "БЕЗОПАСНОЕ ТЕСТИРОВАНИЕ (внутренние номера):"
    echo "  1) Тест 1204 - имитация ответа человека (заинтересован)"
    echo "  2) Тест 1205 - имитация автоответчика"  
    echo "  3) Тест 1206 - имитация недоступного номера"
    echo
    echo "РЕАЛЬНЫЕ ЗВОНКИ (через SIP-провайдера):"
    echo "  4) Звонок на 79206054020 (ваш номер)"
    echo "  5) Звонок на другой номер (ввести вручную)"
    echo
    echo "ДИАГНОСТИКА:"
    echo "  6) Проверить статус FreeSWITCH"
    echo "  7) Проверить SIP-транк"
    echo "  8) Показать логи FreeSWITCH"
    echo "  9) Тестировать аудиофайл example_1.mp3"
    echo
    echo "  0) Выход"
    echo
}

# Функция для тестирования аудиофайла
test_audio_file() {
    log "🎵 Тестируем аудиофайл example_1.mp3..."
    
    local container_id=$(docker ps | grep freeswitch | awk '{print $1}')
    
    # Проверяем, что файл существует в контейнере
    log "🔍 Проверяем наличие аудиофайла в контейнере..."
    
    if docker exec $container_id test -f /usr/local/freeswitch/sounds/custom/example_1.mp3; then
        log "✅ Файл example_1.mp3 найден в контейнере"
        
        # Тестируем воспроизведение
        log "▶️  Тестируем воспроизведение аудиофайла..."
        local cmd="originate loopback/1204 &playback(/usr/local/freeswitch/sounds/custom/example_1.mp3)"
        
        if docker exec $container_id fs_cli -x "$cmd"; then
            log "✅ Аудиофайл успешно протестирован"
        else
            log "❌ Ошибка при тестировании аудиофайла"
        fi
    else
        log "❌ Файл example_1.mp3 не найден в контейнере"
        log "📁 Доступные файлы в /usr/local/freeswitch/sounds/:"
        docker exec $container_id find /usr/local/freeswitch/sounds -name "*.mp3" -o -name "*.wav" | head -10
    fi
}

# Основной цикл
main() {
    log "🚀 Запуск системы тестирования звонков..."
    
    # Первоначальная проверка
    check_freeswitch
    
    while true; do
        show_menu
        read -p "Выберите опцию (0-9): " choice
        
        case $choice in
            1)
                test_call "1204" "имитация ответа человека"
                ;;
            2)
                test_call "1205" "имитация автоответчика"
                ;;
            3)
                test_call "1206" "имитация недоступного номера"
                ;;
            4)
                test_real_call "79206054020"
                ;;
            5)
                read -p "Введите номер телефона (формат 79XXXXXXXXX): " custom_number
                if [[ $custom_number =~ ^[78][0-9]{10}$ ]]; then
                    test_real_call "$custom_number"
                else
                    log "❌ Неверный формат номера! Используйте 79XXXXXXXXX"
                fi
                ;;
            6)
                check_freeswitch
                ;;
            7)
                check_sip_trunk
                ;;
            8)
                show_logs
                ;;
            9)
                test_audio_file
                ;;
            0)
                log "👋 Завершение тестирования"
                exit 0
                ;;
            *)
                log "❌ Неверный выбор, попробуйте снова"
                ;;
        esac
        
        echo
        read -p "Нажмите Enter для продолжения..."
    done
}

# Запуск
main "$@" 