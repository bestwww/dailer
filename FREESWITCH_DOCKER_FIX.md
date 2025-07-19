# 🔧 Исправление ошибки сборки FreeSWITCH Docker

## 🐛 Проблема
При сборке Docker-контейнера FreeSWITCH возникала ошибка:
```
configure: error: You need to either install libldns-dev or disable mod_enum in modules.conf
```

## ✅ Решение
Добавлены недостающие зависимости в `docker/freeswitch/Dockerfile`:
- `libldns-dev` - development-версия для сборки
- `libldns3` - runtime-версия для работы

## 🚀 Инструкции для тестирования на сервере

### 1. Обновите код на тестовом сервере
```bash
git pull origin main
```

### 2. Запустите тестирование
```bash
# Отредактируйте путь в скрипте на реальный путь к проекту
nano test-freeswitch-docker.sh

# Запустите тестирование
./test-freeswitch-docker.sh
```

### 3. Ожидаемый результат
- ✅ Сборка завершается без ошибок (15-30 минут)
- ✅ Контейнер запускается успешно
- ✅ Event Socket доступен на порту 8021
- ✅ Размер образа ~250-300MB

## 🔍 Проверка вручную

### Сборка контейнера
```bash
cd docker/freeswitch
docker build -t dailer-freeswitch:test .
```

### Запуск для тестирования
```bash
docker run --rm -d --name freeswitch-test \
    -p 5060:5060/udp \
    -p 8021:8021 \
    dailer-freeswitch:test
```

### Проверка Event Socket
```bash
# Проверка подключения
nc -z localhost 8021

# Получение пароля Event Socket
docker logs freeswitch-test | grep "Event Socket пароль"
```

### Остановка тестового контейнера
```bash
docker stop freeswitch-test
```

## 📋 Изменения в коде
- ✅ Добавлена зависимость `libldns-dev` в Dockerfile
- ✅ Добавлена зависимость `libldns3` в Dockerfile  
- ✅ Создан скрипт автоматического тестирования
- ✅ Модуль `mod_enum` остается отключенным для стабильности

## 💡 Примечания
- Configure-скрипт FreeSWITCH проверяет наличие библиотек даже для отключенных модулей
- Добавление libldns решает проблему без включения mod_enum
- Размер образа остается минимальным благодаря правильной очистке

## 🔄 Следующие шаги
1. Протестировать сборку на тестовом сервере
2. Убедиться в корректной работе Event Socket
3. Интегрировать в production docker-compose.yml 