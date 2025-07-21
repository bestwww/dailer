# 🌐 Решение проблемы сетевой доступности SIP транка

## 📋 Проблема
После успешного исправления конфигурации FreeSWITCH профиль `external` запущен, но gateway `sip_trunk` находится в статусе DOWN из-за сетевой недоступности SIP сервера `62.141.121.197:5070` из контейнера FreeSWITCH.

## ✅ Что уже исправлено
- ✅ Профиль 'external' запущен (RUNNING)
- ✅ Gateway 'sip_trunk' найден и настроен
- ✅ София успешно перезагружена
- ✅ Конфигурация создана в контейнере

## ❌ Текущая проблема
```
DEBUG: State    NOREG
DEBUG: Status   DOWN
ERROR: ❌ Gateway недоступен
DEBUG: Результат звонка: -ERR GATEWAY_DOWN
```

## 🚀 РЕШЕНИЕ: Host Networking

### На тестовом сервере выполните:

```bash
# 1. Перейти в директорию проекта
cd ~/dailer

# 2. Получить последние изменения
git pull origin main

# 3. БЫСТРОЕ РЕШЕНИЕ: Запустить автоматическое исправление (финальная версия)
./quick-fix-sip-network-v3.sh

# 4. Протестировать звонок
./test-sip-trunk.sh call 79206054020
```

## 🔧 Что делает скрипт `quick-fix-sip-network-v3.sh`:

**ФИНАЛЬНОЕ РЕШЕНИЕ в v3:**
- ✅ **Отдельный Docker Compose файл** - полностью избегает конфликт networks
- ✅ **Отдельный контейнер** с host networking (`dialer_freeswitch_host`)
- ✅ **Скрипт управления** `manage-freeswitch-host.sh`
- ✅ **Проверка портов** и автоматическая диагностика
- ✅ **Принудительный рестарт gateway** при необходимости

**Основные функции:**

1. **Останавливает** текущий контейнер FreeSWITCH
2. **Создает** `docker-compose.override.yml` с host networking
3. **Обновляет** конфигурацию Sofia для работы без NAT  
4. **Запускает** FreeSWITCH с прямым доступом к сети хоста
5. **Тестирует** доступность SIP сервера

## 📝 Альтернативный метод (ручной):

### Шаг 1: Остановка FreeSWITCH
```bash
docker compose stop freeswitch
docker compose rm -f freeswitch
```

### Шаг 2: Создание конфигурации с host networking
```bash
cat > docker-compose.override.yml << 'EOF'
version: '3.8'

services:
  freeswitch:
    network_mode: host
    ports: []
    environment:
      - FREESWITCH_IP_ADDRESS=0.0.0.0
      - FREESWITCH_SIP_PORT=5060
      - FREESWITCH_EVENT_SOCKET_PORT=8021
    command: freeswitch -nonat -nonatmap -u freeswitch -g freeswitch
EOF
```

### Шаг 3: Запуск с новой конфигурацией
```bash
docker compose up -d freeswitch
```

### Шаг 4: Перезагрузка Sofia
```bash
# Ждем запуска (30 секунд)
sleep 30

# Перезагружаем конфигурацию
CONTAINER=$(docker ps --filter name=freeswitch --format "{{.Names}}" | head -1)
docker exec $CONTAINER fs_cli -x "reloadxml"
docker exec $CONTAINER fs_cli -x "sofia profile external restart"
```

## 🧪 Тестирование

### Проверка статуса:
```bash
./test-sip-trunk.sh status
```

### Тестовый звонок:
```bash
./test-sip-trunk.sh call 79206054020
```

### Проверка логов:
```bash
docker compose logs -f freeswitch
```

## 🔍 Диагностика (при необходимости)

Если проблемы продолжаются, запустите полную диагностику:
```bash
./fix-network-connectivity.sh
```

Этот скрипт выполнит:
- Анализ Docker сетей
- Проверку контейнера FreeSWITCH
- Тестирование сетевой доступности
- Проверку DNS и маршрутизации
- Предложит дополнительные решения

## 📋 Важные изменения

### После применения host networking:
- FreeSWITCH использует сеть хоста напрямую
- SIP порт 5060 доступен на хосте
- Event Socket порт 8021 доступен на хосте
- Нет ограничений Docker сети для исходящих подключений

### Файлы конфигурации:
- `docker-compose.freeswitch-host.yml` - отдельный compose файл с host networking
- `manage-freeswitch-host.sh` - скрипт управления FreeSWITCH host networking
- `freeswitch/conf/autoload_configs/sofia.conf.xml` - обновлена для host networking

### Управление FreeSWITCH с host networking:
```bash
# Запуск
./manage-freeswitch-host.sh start

# Остановка  
./manage-freeswitch-host.sh stop

# Перезапуск
./manage-freeswitch-host.sh restart

# Логи
./manage-freeswitch-host.sh logs

# Статус
./manage-freeswitch-host.sh status

# Возврат к обычной сети
./manage-freeswitch-host.sh revert
```

## 🔄 Возврат к bridge сети (при необходимости)

Если потребуется вернуться к обычной Docker сети:
```bash
# Автоматический возврат
./manage-freeswitch-host.sh revert

# Или вручную:
docker compose -f docker-compose.freeswitch-host.yml stop freeswitch-host
docker compose -f docker-compose.freeswitch-host.yml rm -f freeswitch-host
docker compose up -d freeswitch
```

## ✅ Ожидаемый результат

После применения решения:
- Gateway `sip_trunk` в статусе UP или готов к работе
- Исходящие звонки работают без ошибки GATEWAY_DOWN
- FreeSWITCH имеет прямой доступ к SIP серверу `62.141.121.197:5070`

## 🆘 При проблемах

1. Проверьте логи host FreeSWITCH: `./manage-freeswitch-host.sh logs`
2. Проверьте статус: `./manage-freeswitch-host.sh status`
3. Убедитесь что порт 5060 свободен на хосте: `netstat -tulpn | grep 5060`
4. Проверьте доступность SIP сервера с хоста: `ping 62.141.121.197`
5. Для полной диагностики: `./fix-network-connectivity.sh`
6. Контейнер должен называться: `dialer_freeswitch_host` 