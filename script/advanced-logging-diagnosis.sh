#!/bin/bash

# 🔍 УГЛУБЛЕННАЯ ДИАГНОСТИКА ПРОБЛЕМЫ ЛОГИРОВАНИЯ FREESWITCH
# Файл создан, модуль загружен, но логи не записываются

CONTAINER_NAME="freeswitch-test"

echo "🔍 УГЛУБЛЕННАЯ ДИАГНОСТИКА ПРОБЛЕМЫ ЛОГИРОВАНИЯ"
echo "=============================================="
echo ""

echo "📊 ТЕКУЩЕЕ СОСТОЯНИЕ:"
echo "- ✅ Файл freeswitch.log создан"
echo "- ✅ Модуль mod_logfile загружен"  
echo "- ✅ Конфигурация по официальной документации"
echo "- ❌ Логи НЕ записываются в файл"
echo ""

# ЭТАП 1: Детальная проверка прав доступа
echo "📋 ЭТАП 1: ПРОВЕРКА ПРАВ ДОСТУПА"
echo "================================"

echo ""
echo "1. 📁 Права директории логов..."
docker exec "$CONTAINER_NAME" ls -la /usr/local/freeswitch/log/

echo ""
echo "2. 👤 Пользователь FreeSWITCH..."
FS_USER=$(docker exec "$CONTAINER_NAME" ps aux | grep freeswitch | head -1 | awk '{print $1}')
echo "FreeSWITCH запущен от пользователя: $FS_USER"

echo ""
echo "3. 🔧 Владелец файла логов..."
docker exec "$CONTAINER_NAME" ls -la /usr/local/freeswitch/log/freeswitch.log

echo ""
echo "4. 📁 Проверяем права записи..."
docker exec "$CONTAINER_NAME" touch /usr/local/freeswitch/log/test_write.txt
if docker exec "$CONTAINER_NAME" test -f /usr/local/freeswitch/log/test_write.txt; then
    echo "✅ Права записи есть"
    docker exec "$CONTAINER_NAME" rm /usr/local/freeswitch/log/test_write.txt
else
    echo "❌ Нет прав записи"
fi

# ЭТАП 2: Проверка конфигурации
echo ""
echo "📋 ЭТАП 2: ПРОВЕРКА ЗАГРУЖЕННОЙ КОНФИГУРАЦИИ"
echo "==========================================="

echo ""
echo "1. 📄 Проверяем что logfile.conf.xml загружен..."
if docker exec "$CONTAINER_NAME" test -f /usr/local/freeswitch/conf/autoload_configs/logfile.conf.xml; then
    echo "✅ logfile.conf.xml существует"
    
    echo ""
    echo "📋 Содержимое logfile.conf.xml:"
    docker exec "$CONTAINER_NAME" cat /usr/local/freeswitch/conf/autoload_configs/logfile.conf.xml
else
    echo "❌ logfile.conf.xml отсутствует"
fi

echo ""
echo "2. 🔍 Проверяем скомпилированный конфиг..."
if docker exec "$CONTAINER_NAME" test -f /usr/local/freeswitch/log/freeswitch.xml.fsxml; then
    echo "✅ Скомпилированный конфиг существует"
    
    echo ""
    echo "📋 Поиск logfile в скомпилированном конфиге:"
    docker exec "$CONTAINER_NAME" grep -A 10 -B 5 "logfile.conf" /usr/local/freeswitch/log/freeswitch.xml.fsxml
else
    echo "❌ Скомпилированный конфиг отсутствует"
fi

# ЭТАП 3: Принудительная генерация логов
echo ""
echo "📋 ЭТАП 3: ПРИНУДИТЕЛЬНАЯ ГЕНЕРАЦИЯ ЛОГОВ"
echo "========================================"

echo ""
echo "1. 🔧 Прямая команда логирования..."
# Пробуем прямые команды логирования
docker exec "$CONTAINER_NAME" fs_cli -x "log DEBUG === ТЕСТ ЛОГИРОВАНИЯ ==="
docker exec "$CONTAINER_NAME" fs_cli -x "log INFO === ИНФОРМАЦИОННОЕ СООБЩЕНИЕ ==="
docker exec "$CONTAINER_NAME" fs_cli -x "log CRIT === КРИТИЧЕСКОЕ СООБЩЕНИЕ ==="

echo ""
echo "2. 📊 Проверяем после прямых команд..."
LOG_SIZE_AFTER=$(docker exec "$CONTAINER_NAME" wc -l /usr/local/freeswitch/log/freeswitch.log | cut -d' ' -f1)
echo "Размер лога после команд: $LOG_SIZE_AFTER строк"

if [[ "$LOG_SIZE_AFTER" -gt 0 ]]; then
    echo "✅ Логирование работает!"
    echo ""
    echo "📋 Содержимое:"
    docker exec "$CONTAINER_NAME" cat /usr/local/freeswitch/log/freeswitch.log
else
    echo "❌ Логи все еще не записываются"
fi

# ЭТАП 4: Альтернативный метод - fsctl
echo ""
echo "📋 ЭТАП 4: АЛЬТЕРНАТИВНЫЕ МЕТОДЫ ЛОГИРОВАНИЯ"
echo "=========================================="

echo ""
echo "1. 🔧 Команды fsctl..."
docker exec "$CONTAINER_NAME" fs_cli -x "fsctl log_uuid on"
docker exec "$CONTAINER_NAME" fs_cli -x "fsctl debug_level 7"

echo ""
echo "2. 🔧 Reconfigure..."
docker exec "$CONTAINER_NAME" fs_cli -x "reloadxml"

echo ""
echo "3. 🔧 Перезагрузка модуля с другим подходом..."
docker exec "$CONTAINER_NAME" fs_cli -x "unload mod_logfile"
sleep 2
docker exec "$CONTAINER_NAME" fs_cli -x "load mod_logfile"

echo ""
echo "4. 📊 Проверяем после альтернативных методов..."
LOG_SIZE_ALT=$(docker exec "$CONTAINER_NAME" wc -l /usr/local/freeswitch/log/freeswitch.log | cut -d' ' -f1)
echo "Размер лога после альтернативных методов: $LOG_SIZE_ALT строк"

# ЭТАП 5: Создание простейшей конфигурации
echo ""
echo "📋 ЭТАП 5: МИНИМАЛЬНАЯ КОНФИГУРАЦИЯ"
echo "================================="

echo ""
echo "1. 📄 Создаем самую простую конфигурацию..."

# Создаем МИНИМАЛЬНУЮ конфигурацию logfile
cat > /tmp/minimal_logfile.conf.xml << 'EOF'
<configuration name="logfile.conf" description="File Logging">
  <settings>
    <param name="logfile" value="/usr/local/freeswitch/log/freeswitch.log"/>
  </settings>
  <profiles>
    <profile name="default">
      <settings>
        <param name="logfile" value="/usr/local/freeswitch/log/freeswitch.log"/>
      </settings>
      <mappings>
        <map name="all" value="debug,info,notice,warning,err,crit,alert"/>
      </mappings>
    </profile>
  </profiles>
</configuration>
EOF

echo "✅ Минимальная конфигурация создана"

echo ""
echo "2. 📄 Устанавливаем минимальную конфигурацию..."
docker cp /tmp/minimal_logfile.conf.xml "$CONTAINER_NAME:/usr/local/freeswitch/conf/autoload_configs/logfile.conf.xml"

echo ""
echo "3. 🔄 Быстрая перезагрузка..."
docker exec "$CONTAINER_NAME" fs_cli -x "reloadxml"
docker exec "$CONTAINER_NAME" fs_cli -x "reload mod_logfile"

echo ""
echo "4. 🧪 Тест с минимальной конфигурацией..."
docker exec "$CONTAINER_NAME" fs_cli -x "log CRIT === ТЕСТ МИНИМАЛЬНОЙ КОНФИГУРАЦИИ ==="

sleep 2

LOG_SIZE_MIN=$(docker exec "$CONTAINER_NAME" wc -l /usr/local/freeswitch/log/freeswitch.log | cut -d' ' -f1)
echo "Размер лога после минимальной конфигурации: $LOG_SIZE_MIN строк"

# ЭТАП 6: Создание нового файла логов
echo ""
echo "📋 ЭТАП 6: НОВЫЙ ФАЙЛ ЛОГОВ"
echo "=========================="

echo ""
echo "1. 🗑️  Удаляем старый файл..."
docker exec "$CONTAINER_NAME" rm -f /usr/local/freeswitch/log/freeswitch.log

echo ""
echo "2. 📄 Создаем новый с другими правами..."
docker exec "$CONTAINER_NAME" touch /usr/local/freeswitch/log/freeswitch.log
docker exec "$CONTAINER_NAME" chmod 666 /usr/local/freeswitch/log/freeswitch.log

echo ""
echo "3. 👤 Устанавливаем владельца..."
docker exec "$CONTAINER_NAME" chown root:root /usr/local/freeswitch/log/freeswitch.log

echo ""
echo "4. 🔧 Перезагружаем модуль..."
docker exec "$CONTAINER_NAME" fs_cli -x "reload mod_logfile"

echo ""
echo "5. 🧪 Тест с новым файлом..."
docker exec "$CONTAINER_NAME" fs_cli -x "log CRIT === ТЕСТ НОВОГО ФАЙЛА ==="

sleep 2

LOG_SIZE_NEW=$(docker exec "$CONTAINER_NAME" wc -l /usr/local/freeswitch/log/freeswitch.log | cut -d' ' -f1)
echo "Размер лога с новым файлом: $LOG_SIZE_NEW строк"

# ЭТАП 7: Альтернативный путь к логу
echo ""
echo "📋 ЭТАП 7: АЛЬТЕРНАТИВНЫЙ ПУТЬ"
echo "============================="

echo ""
echo "1. 📄 Создаем конфигурацию с другим путем..."

cat > /tmp/alt_path_logfile.conf.xml << 'EOF'
<configuration name="logfile.conf" description="File Logging">
  <settings>
    <param name="logfile" value="/tmp/freeswitch_test.log"/>
  </settings>
  <profiles>
    <profile name="default">
      <settings>
        <param name="logfile" value="/tmp/freeswitch_test.log"/>
      </settings>
      <mappings>
        <map name="all" value="debug,info,notice,warning,err,crit,alert"/>
      </mappings>
    </profile>
  </profiles>
</configuration>
EOF

echo ""
echo "2. 📄 Устанавливаем конфигурацию с альтернативным путем..."
docker cp /tmp/alt_path_logfile.conf.xml "$CONTAINER_NAME:/usr/local/freeswitch/conf/autoload_configs/logfile.conf.xml"

echo ""
echo "3. 🔄 Перезагружаем..."
docker exec "$CONTAINER_NAME" fs_cli -x "reloadxml"
docker exec "$CONTAINER_NAME" fs_cli -x "reload mod_logfile"

echo ""
echo "4. 🧪 Тест с альтернативным путем..."
docker exec "$CONTAINER_NAME" fs_cli -x "log CRIT === ТЕСТ АЛЬТЕРНАТИВНОГО ПУТИ ==="

sleep 2

echo ""
echo "5. 📊 Проверяем альтернативный файл..."
if docker exec "$CONTAINER_NAME" test -f /tmp/freeswitch_test.log; then
    ALT_LOG_SIZE=$(docker exec "$CONTAINER_NAME" wc -l /tmp/freeswitch_test.log | cut -d' ' -f1)
    echo "✅ Альтернативный файл создан! Размер: $ALT_LOG_SIZE строк"
    
    if [[ "$ALT_LOG_SIZE" -gt 0 ]]; then
        echo ""
        echo "📋 Содержимое альтернативного лога:"
        docker exec "$CONTAINER_NAME" cat /tmp/freeswitch_test.log
    fi
else
    echo "❌ Альтернативный файл не создан"
fi

# ЭТАП 8: Результаты диагностики
echo ""
echo "📋 ЭТАП 8: РЕЗУЛЬТАТЫ ДИАГНОСТИКИ"
echo "================================"

echo ""
echo "🔍 ПРОВЕРЕННЫЕ МЕТОДЫ:"

# Проверяем все файлы логов
echo ""
echo "1. 📊 Основной лог (freeswitch.log):"
if docker exec "$CONTAINER_NAME" test -f /usr/local/freeswitch/log/freeswitch.log; then
    MAIN_SIZE=$(docker exec "$CONTAINER_NAME" wc -l /usr/local/freeswitch/log/freeswitch.log | cut -d' ' -f1)
    echo "   Размер: $MAIN_SIZE строк"
else
    echo "   ❌ Файл не существует"
fi

echo ""
echo "2. 📊 Альтернативный лог (/tmp/freeswitch_test.log):"
if docker exec "$CONTAINER_NAME" test -f /tmp/freeswitch_test.log; then
    ALT_SIZE=$(docker exec "$CONTAINER_NAME" wc -l /tmp/freeswitch_test.log | cut -d' ' -f1)
    echo "   Размер: $ALT_SIZE строк"
    
    if [[ "$ALT_SIZE" -gt 0 ]]; then
        echo "   ✅ АЛЬТЕРНАТИВНЫЙ ПУТЬ РАБОТАЕТ!"
    fi
else
    echo "   ❌ Файл не существует"
fi

echo ""
echo "3. 📊 Консольный вывод (проверяем что FreeSWITCH вообще генерирует логи):"
echo "Последние сообщения в консоли:"
docker exec "$CONTAINER_NAME" fs_cli -x "version" 2>&1 | head -5

# ЭТАП 9: Рекомендации
echo ""
echo "📋 ЭТАП 9: РЕКОМЕНДАЦИИ"
echo "======================"

echo ""
if docker exec "$CONTAINER_NAME" test -f /tmp/freeswitch_test.log; then
    ALT_FINAL_SIZE=$(docker exec "$CONTAINER_NAME" wc -l /tmp/freeswitch_test.log | cut -d' ' -f1)
    
    if [[ "$ALT_FINAL_SIZE" -gt 0 ]]; then
        echo "🎉 ПРОБЛЕМА РЕШЕНА! АЛЬТЕРНАТИВНЫЙ ПУТЬ РАБОТАЕТ!"
        echo ""
        echo "✅ РАБОЧАЯ КОНФИГУРАЦИЯ:"
        echo "- Путь к логу: /tmp/freeswitch_test.log"
        echo "- Логирование работает корректно"
        echo "- DTMF мониторинг можно настраивать"
        echo ""
        echo "🔧 СЛЕДУЮЩИЕ ШАГИ:"
        echo "1. Настроить DTMF диалплан с логированием в /tmp/freeswitch_test.log"
        echo "2. Протестировать DTMF события"
        echo "3. Настроить вебхуки для опций 1 и 2"
        echo ""
        echo "📝 КОМАНДА ДЛЯ DTMF МОНИТОРИНГА:"
        echo "docker exec $CONTAINER_NAME tail -f /tmp/freeswitch_test.log | grep -E '(CRIT|DTMF|ОБРАБОТЧИК|ВЕБХУК)'"
        
    else
        echo "❌ ПРОБЛЕМА ОСТАЕТСЯ: Файл создается, но логи не пишутся"
        echo ""
        echo "🔧 ВОЗМОЖНЫЕ ПРИЧИНЫ:"
        echo "1. Проблема с Docker volume mapping"
        echo "2. FreeSWITCH собран без поддержки mod_logfile"
        echo "3. Системная проблема с правами доступа"
        echo "4. Несовместимость версии FreeSWITCH с конфигурацией"
        echo ""
        echo "💡 АЛЬТЕРНАТИВНЫЕ РЕШЕНИЯ:"
        echo "1. Использовать syslog вместо файлового логирования"
        echo "2. Перехватывать логи из консоли"
        echo "3. Использовать Event Socket для мониторинга DTMF"
        echo "4. Пересобрать FreeSWITCH с правильными опциями"
    fi
else
    echo "❌ КРИТИЧЕСКАЯ ПРОБЛЕМА: Файлы логов не создаются вообще"
    echo ""
    echo "🔧 ТРЕБУЕТСЯ:"
    echo "1. Проверка сборки FreeSWITCH"
    echo "2. Возможно переход на другой Docker image"
    echo "3. Использование Event Socket для DTMF"
fi

echo ""
echo "🔍 ДИАГНОСТИКА ЗАВЕРШЕНА!"
echo "========================" 