#!/bin/bash

# 📞🎵 Тестирование звонков с WAV файлами
# Обновляет FreeSWITCH для использования WAV и тестирует вызовы

echo "📞🎵 === ТЕСТИРОВАНИЕ ЗВОНКОВ С WAV ФАЙЛАМИ ==="
echo

# Получаем ID контейнера FreeSWITCH
CONTAINER_ID=$(docker ps | grep freeswitch | awk '{print $1}' | head -1)

if [[ -z "$CONTAINER_ID" ]]; then
    echo "❌ FreeSWITCH контейнер не найден!"
    echo "🚀 Запускаем FreeSWITCH..."
    docker compose up -d freeswitch
    sleep 15
    CONTAINER_ID=$(docker ps | grep freeswitch | awk '{print $1}' | head -1)
fi

echo "🐳 FreeSWITCH контейнер: $CONTAINER_ID"

# Проверяем наличие WAV файлов
echo ""
echo "📂 === ПРОВЕРКА WAV ФАЙЛОВ ==="

if [[ ! -f "audio/example_1.wav" ]]; then
    echo "❌ WAV файлы не найдены!"
    echo "🔧 Сначала запустите: ./convert-audio-to-wav.sh"
    exit 1
fi

echo "✅ Найдены WAV файлы:"
ls -lh audio/*.wav 2>/dev/null

# Создаем папку для аудио в контейнере
echo ""
echo "📁 === НАСТРОЙКА АУДИО В FREESWITCH ==="

echo "📁 Создаём папку custom в FreeSWITCH..."
docker exec $CONTAINER_ID mkdir -p /usr/local/freeswitch/sounds/custom

# Копируем все WAV файлы
echo "📥 Копируем WAV файлы в FreeSWITCH..."
for wav_file in audio/*.wav; do
    if [[ -f "$wav_file" ]]; then
        filename=$(basename "$wav_file")
        echo "📥 Копируем $filename..."
        docker cp "$wav_file" $CONTAINER_ID:/usr/local/freeswitch/sounds/custom/
    fi
done

# Проверяем что файлы скопировались
echo ""
echo "🔍 Проверяем файлы в контейнере:"
docker exec $CONTAINER_ID ls -la /usr/local/freeswitch/sounds/custom/ | grep -E "\.(wav|mp3)"

# Создаем обновленный диалплан для WAV
echo ""
echo "📝 === ОБНОВЛЕНИЕ ДИАЛПЛАНА ДЛЯ WAV ==="

cat > /tmp/wav_test_dialplan.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<include>
  <!-- WAV Тест - номер 1298 -->
  <extension name="wav_test_1298">
    <condition field="destination_number" expression="^1298$">
      <action application="answer"/>
      <action application="sleep" data="1000"/>
      <action application="playback" data="/usr/local/freeswitch/sounds/custom/example_1.wav"/>
      <action application="sleep" data="2000"/>
      <action application="playback" data="/usr/local/freeswitch/sounds/custom/example_1_8k.wav"/>
      <action application="sleep" data="2000"/>
      <action application="hangup"/>
    </condition>
  </extension>

  <!-- WAV Тест HD качества - номер 1297 -->
  <extension name="wav_test_hd_1297">
    <condition field="destination_number" expression="^1297$">
      <action application="answer"/>
      <action application="sleep" data="1000"/>
      <action application="playback" data="/usr/local/freeswitch/sounds/custom/example_1_16k.wav"/>
      <action application="sleep" data="3000"/>
      <action application="hangup"/>
    </condition>
  </extension>

  <!-- Реальный звонок с WAV - обновленный -->
  <extension name="call_79206054020_with_wav">
    <condition field="destination_number" expression="^test_wav_real$">
      <action application="set" data="execute_on_answer=playback:/usr/local/freeswitch/sounds/custom/example_1_8k.wav"/>
      <action application="bridge" data="sofia/gateway/sip_trunk/79206054020"/>
    </condition>
  </extension>
</include>
EOF

echo "📁 Копируем диалплан WAV в FreeSWITCH..."
docker cp /tmp/wav_test_dialplan.xml $CONTAINER_ID:/usr/local/freeswitch/conf/dialplan/test/wav_test.xml

# Обновляем default.xml для включения WAV тестов
echo "📝 Обновляем default.xml..."
docker exec $CONTAINER_ID sh -c "
if ! grep -q 'wav_test.xml' /usr/local/freeswitch/conf/dialplan/default.xml; then
    sed -i '/<\/context>/i\\  <X-PRE-PROCESS cmd=\"include\" data=\"test/wav_test.xml\"/>' /usr/local/freeswitch/conf/dialplan/default.xml
fi
"

# Перезагружаем XML конфигурацию
echo "🔄 Перезагружаем XML в FreeSWITCH..."
docker exec $CONTAINER_ID fs_cli -x "reloadxml"

echo ""
echo "📞 === АВТОМАТИЧЕСКИЕ ТЕСТЫ WAV ==="

# Функция тестирования
test_wav_call() {
    local number=$1
    local description=$2
    
    echo ""
    echo "📞 Тестируем $number - $description"
    echo "⏱️ Совершаем вызов..."
    
    # Делаем вызов и записываем результат
    result=$(docker exec $CONTAINER_ID fs_cli -x "originate null/null $number" 2>&1)
    
    if echo "$result" | grep -qi "success\|ok\|answered"; then
        echo "✅ Вызов успешен - аудио должно проигрываться"
    elif echo "$result" | grep -qi "busy\|failed\|error"; then
        echo "❌ Вызов не удался: $result"
    else
        echo "⚠️ Неясный результат: $result"
    fi
    
    sleep 3
}

# Тестируем WAV файлы
test_wav_call "1298" "Тест обычного и 8kHz WAV"
test_wav_call "1297" "Тест HD (16kHz) WAV"

echo ""
echo "📋 === МЕНЮ ТЕСТИРОВАНИЯ WAV ==="
echo ""

while true; do
    echo "🎵 === ТЕСТЫ WAV ФАЙЛОВ ==="
    echo ""
    echo "ВНУТРЕННИЕ ТЕСТЫ (безопасно):"
    echo "  1) 📞 Тест 1298 - воспроизведение обычного и 8kHz WAV"
    echo "  2) 📞 Тест 1297 - воспроизведение HD (16kHz) WAV"
    echo ""
    echo "РЕАЛЬНЫЕ ЗВОНКИ:"
    echo "  3) 📞 Звонок на 79206054020 с WAV (8kHz)"
    echo "  4) 📞 Пользовательский номер с WAV"
    echo ""
    echo "ДИАГНОСТИКА:"
    echo "  5) 🔍 Проверить файлы в FreeSWITCH"
    echo "  6) 📊 Показать кодеки FreeSWITCH"
    echo "  7) 📜 Показать логи"
    echo ""
    echo "  0) 🚪 Выход"
    echo ""
    
    read -p "🎯 Выберите тест (0-7): " choice
    
    case $choice in
        1)
            echo "📞 Тестируем воспроизведение WAV файлов..."
            docker exec $CONTAINER_ID fs_cli -x "originate null/null 1298"
            ;;
        2)
            echo "📞 Тестируем HD WAV..."
            docker exec $CONTAINER_ID fs_cli -x "originate null/null 1297"
            ;;
        3)
            echo "📞 Звоним на ваш номер с WAV..."
            echo "⚠️ ВНИМАНИЕ: Реальный вызов - потратит деньги!"
            read -p "Продолжить? (y/N): " confirm
            if [[ $confirm == [yY] ]]; then
                docker exec $CONTAINER_ID fs_cli -x "originate null/null test_wav_real"
            fi
            ;;
        4)
            read -p "📱 Введите номер: " custom_number
            echo "📞 Звоним на $custom_number с WAV..."
            echo "⚠️ ВНИМАНИЕ: Реальный вызов!"
            read -p "Продолжить? (y/N): " confirm
            if [[ $confirm == [yY] ]]; then
                docker exec $CONTAINER_ID fs_cli -x "originate sofia/gateway/sip_trunk/$custom_number 1298"
            fi
            ;;
        5)
            echo "🔍 Файлы в FreeSWITCH:"
            docker exec $CONTAINER_ID find /usr/local/freeswitch/sounds -name "*.wav" -o -name "*.mp3" | head -10
            docker exec $CONTAINER_ID ls -la /usr/local/freeswitch/sounds/custom/
            ;;
        6)
            echo "📊 Кодеки FreeSWITCH:"
            docker exec $CONTAINER_ID fs_cli -x "show codec" | head -20
            ;;
        7)
            echo "📜 Последние логи FreeSWITCH:"
            docker logs $CONTAINER_ID | tail -20
            ;;
        0)
            echo "👋 Выход из тестирования WAV"
            break
            ;;
        *)
            echo "❌ Неверный выбор!"
            ;;
    esac
    
    echo ""
    read -p "📡 Нажмите Enter для продолжения..."
    echo ""
done

echo ""
echo "📋 === ИТОГИ ТЕСТИРОВАНИЯ WAV ==="
echo ""
echo "✅ WAV файлы настроены в FreeSWITCH"
echo "📞 Доступные тестовые номера:"
echo "   1298 - тест обычного и 8kHz WAV"
echo "   1297 - тест HD (16kHz) WAV"
echo ""
echo "🎯 Если WAV работает, а MP3 нет - проблема в кодеках MP3"
echo "🎯 Если WAV тоже не работает - проблема в настройках воспроизведения" 