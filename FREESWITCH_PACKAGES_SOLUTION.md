# 🚀 FreeSWITCH Docker - ГОТОВЫЕ ПАКЕТЫ (ЛУЧШЕЕ РЕШЕНИЕ!)

## 💡 Решение проблемы сборки из исходников

Вместо **сложной сборки из исходников** (с множеством ошибок зависимостей) используем **готовые пакеты** из официального репозитория SignalWire.

## 🎯 Преимущества нового подхода

| Сборка из исходников | **Готовые пакеты** |
|---------------------|-------------------|
| ❌ 30+ минут сборки | ✅ **3-5 минут** |
| ❌ Множество ошибок зависимостей | ✅ **Стабильная установка** |
| ❌ Сложное обслуживание | ✅ **Простое обновление** |
| ❌ Большой размер образа | ✅ **Оптимизированный размер** |
| ❌ Проблемы с libldns, mod_verto и т.д. | ✅ **Готовая конфигурация** |

## 📦 Новые файлы

### 1. `docker/freeswitch/Dockerfile-packages`
- Установка FreeSWITCH из официального репозитория Debian
- Только необходимые модули для дайлера
- Оптимизированная конфигурация

### 2. `docker/freeswitch/docker-entrypoint.sh`
- Правильный запуск FreeSWITCH в контейнере
- Автоматическая настройка прав доступа
- Диагностическая информация

### 3. `test-freeswitch-packages.sh`
- Автоматическое тестирование сборки и запуска
- Проверка Event Socket (критично для интеграции!)
- Полная диагностика работоспособности

## 🚀 Инструкции для тестирования

### 1. На тестовом сервере:

```bash
# Обновляем код
git pull origin main

# Редактируем путь в скрипте
nano test-freeswitch-packages.sh
# Измените: cd /path/to/dailer на реальный путь

# Запускаем тестирование
./test-freeswitch-packages.sh
```

### 2. Ручная сборка (если нужно):

```bash
cd docker/freeswitch

# Сборка из готовых пакетов
docker build -f Dockerfile-packages -t dailer-freeswitch:packages .

# Запуск
docker run -d \
  --name freeswitch \
  -p 5060:5060/udp \
  -p 5060:5060/tcp \
  -p 8021:8021/tcp \
  dailer-freeswitch:packages

# Проверка
docker exec freeswitch fs_cli -x "status"
```

## 🔧 Что устанавливается

### Основные компоненты:
- **freeswitch** - основной пакет
- **freeswitch-meta-bare** - минимальный набор
- **freeswitch-conf-vanilla** - базовая конфигурация

### Критичные модули для дайлера:
- **freeswitch-mod-event-socket** - интеграция с Backend
- **freeswitch-mod-sofia** - SIP протокол
- **freeswitch-mod-dptools** - dialplan инструменты
- **freeswitch-mod-commands** - команды управления

### Аудио кодеки:
- **freeswitch-mod-sndfile** - файлы аудио
- **freeswitch-mod-tone-stream** - генерация тонов
- **freeswitch-mod-native-file** - воспроизведение файлов

## 🔌 Открытые порты

- **5060/udp, 5060/tcp** - SIP сигналинг
- **5080/udp, 5080/tcp** - Альтернативный SIP
- **16384-32768/udp** - RTP медиа
- **8021/tcp** - Event Socket (для Backend)

## 🏥 Диагностика

### Проверка работы:
```bash
# Статус FreeSWITCH
docker exec freeswitch fs_cli -x "status"

# Event Socket
telnet localhost 8021

# Логи
docker logs freeswitch
```

### Healthcheck:
Контейнер включает автоматический healthcheck каждые 30 секунд.

## 🎉 Результат

✅ **Быстрая сборка** (3-5 минут)  
✅ **Стабильная работа** (проверенные пакеты)  
✅ **Event Socket** готов для интеграции  
✅ **Все необходимые модули** для дайлера  
✅ **Простое обслуживание** и обновление  

## 🔄 Обновление docker-compose

После успешного тестирования можно обновить `docker-compose.yml`:

```yaml
services:
  freeswitch:
    build:
      context: ./docker/freeswitch
      dockerfile: Dockerfile-packages  # ← новый Dockerfile
    # остальная конфигурация...
``` 