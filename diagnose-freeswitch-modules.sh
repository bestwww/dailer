#!/bin/bash

# 🔧🐛 Диагностика модулей FreeSWITCH 
# Исправляем ошибку CHAN_NOT_IMPLEMENTED

echo "🔧🐛 === ДИАГНОСТИКА МОДУЛЕЙ FREESWITCH ==="
echo

# Получаем ID контейнера FreeSWITCH
CONTAINER_ID=$(docker ps | grep freeswitch | awk '{print $1}' | head -1)

if [[ -z "$CONTAINER_ID" ]]; then
    echo "❌ FreeSWITCH контейнер не найден!"
    exit 1
fi

echo "🐳 FreeSWITCH контейнер: $CONTAINER_ID"

echo ""
echo "📊 === ПРОВЕРКА СТАТУСА FREESWITCH ==="

# Проверяем статус FreeSWITCH
echo "🔍 Статус FreeSWITCH:"
docker exec $CONTAINER_ID fs_cli -x "status"

echo ""
echo "📦 === ПРОВЕРКА ЗАГРУЖЕННЫХ МОДУЛЕЙ ==="

# Проверяем загруженные модули
echo "🔍 Загруженные модули:"
docker exec $CONTAINER_ID fs_cli -x "show modules" | head -20

echo ""
echo "🔍 Ищем важные модули:"

# Проверяем конкретные модули
MODULES_TO_CHECK=(
    "mod_loopback"
    "mod_sofia" 
    "mod_dptools"
    "mod_commands"
    "mod_conference"
    "mod_dialplan_xml"
)

for module in "${MODULES_TO_CHECK[@]}"; do
    status=$(docker exec $CONTAINER_ID fs_cli -x "show modules" | grep "$module" || echo "NOT_FOUND")
    if [[ "$status" != "NOT_FOUND" ]]; then
        echo "✅ $module - загружен"
    else
        echo "❌ $module - НЕ ЗАГРУЖЕН!"
    fi
done

echo ""
echo "🔧 === ИСПРАВЛЕНИЕ ПРОБЛЕМЫ CHAN_NOT_IMPLEMENTED ==="

# Пробуем загрузить недостающие модули
echo "📦 Загружаем критические модули..."

CRITICAL_MODULES=(
    "mod_loopback"
    "mod_sofia"
    "mod_dptools"
)

for module in "${CRITICAL_MODULES[@]}"; do
    echo "📦 Загружаем $module..."
    result=$(docker exec $CONTAINER_ID fs_cli -x "load $module" 2>&1)
    if echo "$result" | grep -qi "success\|ok\|already"; then
        echo "✅ $module загружен успешно"
    else
        echo "⚠️ $module: $result"
    fi
done

echo ""
echo "🔄 === ПЕРЕЗАГРУЗКА МОДУЛЕЙ ==="

# Перезагружаем модули
echo "🔄 Перезагружаем mod_sofia..."
docker exec $CONTAINER_ID fs_cli -x "reload mod_sofia"

echo "🔄 Перезагружаем XML..."
docker exec $CONTAINER_ID fs_cli -x "reloadxml"

echo ""
echo "📞 === АЛЬТЕРНАТИВНЫЕ СПОСОБЫ ТЕСТИРОВАНИЯ ==="

echo "🧪 Тестируем альтернативные каналы..."

# Тест 1: Loopback вместо null/null
echo ""
echo "📞 ТЕСТ 1: Loopback канал"
result1=$(docker exec $CONTAINER_ID fs_cli -x "originate loopback/1298 1298" 2>&1)
echo "Результат loopback: $result1"

# Тест 2: Sofia loopback
echo ""
echo "📞 ТЕСТ 2: Sofia loopback" 
result2=$(docker exec $CONTAINER_ID fs_cli -x "originate sofia/internal/1298@127.0.0.1 1298" 2>&1)
echo "Результат sofia loopback: $result2"

# Тест 3: Простой bridge
echo ""
echo "📞 ТЕСТ 3: Прямое воспроизведение"
result3=$(docker exec $CONTAINER_ID fs_cli -x "uuid_broadcast \$(fs_cli -x \"originate user/1000 1298\") /usr/local/freeswitch/sounds/custom/example_1_8k.wav both" 2>&1)
echo "Результат uuid_broadcast: $result3"

echo ""
echo "🔍 === ПРОВЕРКА ДИАЛПЛАНА ==="

# Проверяем что диалплан загружен
echo "📋 Проверяем диалплан..."
docker exec $CONTAINER_ID fs_cli -x "xml_locate dialplan" | grep -A5 -B5 "1298\|1297" || echo "Диалплан не найден"

echo ""
echo "🔧 === СОЗДАНИЕ РАБОЧЕГО ТЕСТОВОГО ДИАЛПЛАНА ==="

# Создаем простой рабочий диалплан
cat > /tmp/working_test_dialplan.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<include>
  <!-- Простой рабочий тест - номер 1299 -->
  <extension name="simple_wav_test_1299">
    <condition field="destination_number" expression="^1299$">
      <action application="answer"/>
      <action application="log" data="INFO === НАЧИНАЕМ ВОСПРОИЗВЕДЕНИЕ WAV ==="/>
      <action application="sleep" data="1000"/>
      <action application="playback" data="/usr/local/freeswitch/sounds/custom/example_1_8k.wav"/>
      <action application="log" data="INFO === ЗАВЕРШИЛИ ВОСПРОИЗВЕДЕНИЕ WAV ==="/>
      <action application="sleep" data="1000"/>
      <action application="hangup"/>
    </condition>
  </extension>

  <!-- Диагностический тест - номер 1300 -->
  <extension name="diagnostic_test_1300">
    <condition field="destination_number" expression="^1300$">
      <action application="answer"/>
      <action application="log" data="INFO === ДИАГНОСТИЧЕСКИЙ ТЕСТ ==="/>
      <action application="playback" data="tone_stream://%(2000,4000,440,480)"/>
      <action application="sleep" data="3000"/>
      <action application="hangup"/>
    </condition>
  </extension>
</include>
EOF

echo "📁 Копируем рабочий диалплан..."
docker cp /tmp/working_test_dialplan.xml $CONTAINER_ID:/usr/local/freeswitch/conf/dialplan/test/working_test.xml

# Обновляем default.xml
docker exec $CONTAINER_ID sh -c "
if ! grep -q 'working_test.xml' /usr/local/freeswitch/conf/dialplan/default.xml; then
    sed -i '/<\/context>/i\\  <X-PRE-PROCESS cmd=\"include\" data=\"test/working_test.xml\"/>' /usr/local/freeswitch/conf/dialplan/default.xml
fi
"

echo "🔄 Перезагружаем XML с новым диалпланом..."
docker exec $CONTAINER_ID fs_cli -x "reloadxml"

echo ""
echo "🧪 === ФИНАЛЬНЫЕ ТЕСТЫ ==="

echo ""
echo "📞 ТЕСТ ФИНАЛ 1: Простой рабочий номер (1299)"
final1=$(docker exec $CONTAINER_ID fs_cli -x "originate loopback/1299 1299" 2>&1)
echo "Результат: $final1"

echo ""
echo "📞 ТЕСТ ФИНАЛ 2: Диагностический тон (1300)"
final2=$(docker exec $CONTAINER_ID fs_cli -x "originate loopback/1300 1300" 2>&1)
echo "Результат: $final2"

echo ""
echo "📋 === ИТОГИ ДИАГНОСТИКИ ==="
echo ""

if echo "$final1" | grep -qi "success\|ok"; then
    echo "✅ ПРОБЛЕМА РЕШЕНА! Loopback канал работает"
    echo "🎵 Номер 1299 должен воспроизводить WAV файл"
    echo "📞 Номер 1300 воспроизводит диагностический тон"
    echo ""
    echo "🚀 РЕШЕНИЕ для реальных звонков:"
    echo "   Используйте команду:"
    echo "   docker exec $CONTAINER_ID fs_cli -x \"originate sofia/gateway/sip_trunk/79206054020 1299\""
else
    echo "❌ Проблема все еще существует"
    echo "🔧 Возможные причины:"
    echo "   1. FreeSWITCH не полностью инициализирован"
    echo "   2. Проблема с компиляцией модулей"
    echo "   3. Нужна полная перезагрузка контейнера"
    echo ""
    echo "🔄 Попробуйте перезагрузить контейнер:"
    echo "   docker compose restart freeswitch"
fi

echo ""
echo "📞 === КОМАНДЫ ДЛЯ ДАЛЬНЕЙШЕГО ТЕСТИРОВАНИЯ ==="
echo ""
echo "ВНУТРЕННИЕ ТЕСТЫ:"
echo "docker exec $CONTAINER_ID fs_cli -x \"originate loopback/1299 1299\"  # WAV тест"
echo "docker exec $CONTAINER_ID fs_cli -x \"originate loopback/1300 1300\"  # Тон тест"
echo ""
echo "РЕАЛЬНЫЙ ЗВОНОК с WAV:"
echo "docker exec $CONTAINER_ID fs_cli -x \"originate sofia/gateway/sip_trunk/79206054020 1299\"" 