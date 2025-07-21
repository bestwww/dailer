# 🚨 Устранение проблем с FreeSWITCH на тестовом сервере

## 🎯 Выявленные проблемы

На основе диагностики обнаружены следующие проблемы:

1. **❌ Профиль 'external' не загружен** - основная причина недоступности SIP транка
2. **❌ Gateway 'sip_trunk' недоступен** - следствие проблемы с профилем
3. **⚠️ Сетевая недоступность из контейнера** - возможные проблемы с Docker сетью

## ⚡ Быстрое исправление

### На тестовом сервере выполните:

```bash
# 1. Обновить код с исправлениями
cd ~/dailer
git reset --hard origin/main  # Сбросить локальные изменения
git pull origin main

# 2. Запустить автоматическое исправление
./fix-freeswitch-issues.sh
```

Скрипт автоматически:
- 🔍 Проверит конфигурационные файлы
- 📋 Проанализирует логи FreeSWITCH
- ⚙️ Перезагрузит конфигурацию Sofia SIP
- 🔄 Перезапустит контейнер если необходимо
- 🌐 Исправит сетевые проблемы
- 🧪 Протестирует исправления

## 🔧 Ручное исправление (если автоматическое не помогло)

### Шаг 1: Проверка и перезапуск FreeSWITCH

```bash
# Остановить FreeSWITCH
docker-compose stop freeswitch

# Удалить контейнер
docker rm dialer_freeswitch

# Запустить заново
docker-compose up -d freeswitch

# Проверить логи запуска
docker logs dialer_freeswitch --tail=50
```

### Шаг 2: Проверка конфигурации

```bash
# Подключиться к FreeSWITCH CLI
docker exec -it dialer_freeswitch fs_cli

# В CLI выполнить:
sofia status
sofia status profile external
sofia status gateway sip_trunk
quit
```

### Шаг 3: Ручная перезагрузка конфигурации

```bash
# Перезагрузить XML конфигурацию
docker exec dialer_freeswitch fs_cli -x "reloadxml"

# Перезапустить профиль external
docker exec dialer_freeswitch fs_cli -x "sofia profile external restart"

# Подождать 10 секунд и проверить
sleep 10
docker exec dialer_freeswitch fs_cli -x "sofia status"
```

### Шаг 4: Тестирование

```bash
# Запустить полный тест
./test-sip-trunk.sh test

# Или тестовый звонок
./test-sip-trunk.sh call 79001234567
```

## 🔍 Диагностика специфических проблем

### Проблема: "INVALID_GATEWAY"

**Причины:**
- Gateway не загружен
- Неправильное имя gateway в dialplan
- Профиль external не запущен

**Решение:**
```bash
# Проверить статус gateway
docker exec dialer_freeswitch fs_cli -x "sofia status gateway sip_trunk"

# Если gateway не найден, перезагрузить конфигурацию
docker exec dialer_freeswitch fs_cli -x "reloadxml"
docker exec dialer_freeswitch fs_cli -x "sofia profile external restart"
```

### Проблема: Профиль external не загружается

**Возможные причины:**
- Ошибки в sofia.conf.xml
- Конфликт портов
- Проблемы с правами доступа к файлам

**Решение:**
```bash
# Проверить синтаксис конфигурации
docker exec dialer_freeswitch fs_cli -x "xml_locate configuration sofia.conf"

# Проверить логи на ошибки
docker logs dialer_freeswitch 2>&1 | grep -i -E "(error|sofia|external)"

# Проверить занятость портов
netstat -tuln | grep 5060
```

### Проблема: Сетевая недоступность

**Симптомы:**
- IP недоступен из контейнера
- Timeout при попытке звонков

**Решение:**
```bash
# Проверить DNS в контейнере
docker exec dialer_freeswitch nslookup 8.8.8.8

# Проверить маршрутизацию
docker exec dialer_freeswitch ip route

# Проверить Docker сеть
docker network inspect dialer_dialer_network

# Пересоздать сеть если необходимо
docker-compose down
docker-compose up -d
```

## 🛠️ Дополнительные команды диагностики

### Мониторинг SIP трафика

```bash
# Включить SIP трейсинг
docker exec dialer_freeswitch fs_cli -x "sofia global siptrace on"

# Мониторинг в реальном времени
docker logs -f dialer_freeswitch | grep -i sip

# Выключить трейсинг
docker exec dialer_freeswitch fs_cli -x "sofia global siptrace off"
```

### Проверка активных каналов

```bash
# Показать активные каналы
docker exec dialer_freeswitch fs_cli -x "show channels"

# Показать статистику вызовов
docker exec dialer_freeswitch fs_cli -x "show calls"

# Статус всех профилей Sofia
docker exec dialer_freeswitch fs_cli -x "sofia status"
```

### Детальная диагностика gateway

```bash
# Подробная информация о gateway
docker exec dialer_freeswitch fs_cli -x "sofia status gateway sip_trunk"

# Перезапуск конкретного gateway
docker exec dialer_freeswitch fs_cli -x "sofia profile external killgw sip_trunk"
docker exec dialer_freeswitch fs_cli -x "sofia profile external rescan"
```

## ⚠️ Возможные причины проблем

### 1. **Ошибки в конфигурации**
- Неправильный синтаксис XML
- Неверные параметры gateway
- Конфликты в настройках портов

### 2. **Проблемы с правами доступа**
- Файлы конфигурации недоступны для чтения
- Проблемы с монтированием volumes

### 3. **Сетевые проблемы**
- Блокировка портов firewall
- Проблемы с Docker сетью
- NAT конфигурация

### 4. **Ресурсные ограничения**
- Недостаток памяти
- Превышение лимитов CPU
- Заполнение дискового пространства

## 🎯 Следующие шаги после исправления

1. **Протестировать SIP транк:**
   ```bash
   ./test-sip-trunk.sh test
   ```

2. **Запустить мониторинг:**
   ```bash
   ./production-monitoring.sh monitor
   ```

3. **Проверить интеграцию с автодозвоном:**
   - Создать тестовую кампанию
   - Загрузить тестовые номера
   - Запустить кампанию

4. **Настроить алерты:**
   - Настроить уведомления при падении сервисов
   - Мониторинг доступности SIP транка

## 📞 Если проблемы не решены

Если автоматическое исправление не помогло:

1. **Соберите диагностическую информацию:**
   ```bash
   ./fix-freeswitch-issues.sh > freeswitch_diagnosis.log 2>&1
   ```

2. **Проверьте логи всех сервисов:**
   ```bash
   ./production-monitoring.sh logs
   ```

3. **Свяжитесь с технической поддержкой** с приложением логов

---

**💡 Важно**: После любых изменений в конфигурации FreeSWITCH всегда выполняйте `reloadxml` и перезапуск соответствующих профилей, а не только restart контейнера. 