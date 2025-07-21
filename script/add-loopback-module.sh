#!/bin/bash

# 🔧 Добавление loopback модуля для внутренних тестов IVR
# Исправляем CHAN_NOT_IMPLEMENTED для loopback

CONTAINER_NAME="freeswitch-test"

echo "🔧 ДОБАВЛЕНИЕ LOOPBACK МОДУЛЯ"
echo "============================="
echo ""

echo "📋 Добавляем loopback модуль в конфигурацию..."

# Добавляем loopback в modules.conf.xml
sed -i '/mod_commands/a\    <load module="mod_loopback"/>' freeswitch/conf/autoload_configs/modules.conf.xml

echo "✅ Loopback модуль добавлен в конфигурацию"

echo ""
echo "🔄 Перезагружаем модули в FreeSWITCH..."

# Загружаем loopback модуль в FreeSWITCH
docker exec "$CONTAINER_NAME" fs_cli -x "load mod_loopback"

echo ""
echo "🧪 Тестируем loopback..."

# Тест loopback
LOOPBACK_TEST=$(docker exec "$CONTAINER_NAME" fs_cli -x "originate loopback/ivr_menu &echo" 2>&1)
echo "Результат теста loopback: $LOOPBACK_TEST"

if echo "$LOOPBACK_TEST" | grep -q "+OK"; then
    echo "✅ Loopback работает!"
else
    echo "⚠️ Loopback требует дополнительной настройки: $LOOPBACK_TEST"
fi

echo ""
echo "🎯 ИТОГОВЫЕ ТЕСТЫ"
echo "================"

echo ""
echo "1. Тест IVR через loopback:"
echo "docker exec $CONTAINER_NAME fs_cli -x 'originate loopback/ivr_menu &echo'"

echo ""
echo "2. Тест исходящего звонка:"  
echo "docker exec $CONTAINER_NAME fs_cli -x 'originate sofia/gateway/sip_trunk/79206054020 &transfer:ivr_menu'"

echo ""
echo "✅ Готово!" 