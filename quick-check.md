# 🚀 Быстрая диагностика тестового сервера

## 📋 Основные команды проверки

### 1. Быстрая проверка всех контейнеров
```bash
# Проверка статуса всех контейнеров
docker ps -a

# Проверка только запущенных контейнеров
docker ps

# Проверка через docker-compose
docker-compose ps
```

### 2. Проверка логов (основные сервисы)
```bash
# 🔴 БЭКЕНД - последние 50 строк
docker logs --tail 50 dialer_backend

# 🔵 ФРОНТЕНД - последние 50 строк  
docker logs --tail 50 dialer_frontend

# 🟡 БАЗА ДАННЫХ - последние 30 строк
docker logs --tail 30 dialer_postgres

# 🟢 REDIS - последние 20 строк
docker logs --tail 20 dialer_redis

# 🟠 FREESWITCH - последние 30 строк
docker logs --tail 30 dialer_freeswitch
```

### 3. Проверка в реальном времени
```bash
# Логи бэкенда в реальном времени
docker logs -f dialer_backend

# Логи фронтенда в реальном времени
docker logs -f dialer_frontend

# Все логи через docker-compose
docker-compose logs -f
```

### 4. Проверка ресурсов и производительности
```bash
# Использование ресурсов всеми контейнерами
docker stats

# Использование ресурсов одним контейнером
docker stats dialer_backend --no-stream
```

### 5. Проверка портов и сетей
```bash
# Проверка открытых портов на хосте
netstat -tulpn | grep -E ":(3000|5173|5432|6379|5060|8021)"

# Проверка Docker сетей
docker network ls

# Детали сети
docker network inspect dialer_v1_dialer_network
```

### 6. Проверка health check'ов
```bash
# Статус здоровья контейнеров
docker ps --format "table {{.Names}}\t{{.Status}}"

# Детальная информация о контейнере
docker inspect dialer_backend | grep -A 10 -B 5 Health
```

## 🔧 Команды для исправления проблем

### Перезапуск сервисов
```bash
# Перезапуск отдельного контейнера
docker restart dialer_backend
docker restart dialer_frontend

# Перезапуск через docker-compose
docker-compose restart backend
docker-compose restart frontend

# Полный перезапуск всех сервисов
docker-compose down && docker-compose up -d
```

### Пересборка при изменениях кода
```bash
# Пересборка и запуск бэкенда
docker-compose up -d --build backend

# Пересборка и запуск фронтенда
docker-compose up -d --build frontend

# Пересборка всех сервисов
docker-compose up -d --build
```

### Очистка при проблемах
```bash
# Остановка всех контейнеров
docker-compose down

# Очистка неиспользуемых образов
docker image prune -f

# Очистка неиспользуемых volume'ов (ОСТОРОЖНО!)
docker volume prune -f

# Полная очистка системы (ОЧЕНЬ ОСТОРОЖНО!)
docker system prune -a --volumes
```

## 🐛 Отладка приложений

### Вход в контейнеры для отладки
```bash
# Вход в контейнер бэкенда
docker exec -it dialer_backend bash

# Вход в контейнер фронтенда
docker exec -it dialer_frontend sh

# Вход в базу данных
docker exec -it dialer_postgres psql -U dialer_user -d dialer_db
```

### Проверка переменных окружения
```bash
# Переменные окружения бэкенда
docker exec dialer_backend printenv

# Проверка конкретной переменной
docker exec dialer_backend printenv DATABASE_URL
```

### Проверка файлов и томов
```bash
# Список томов
docker volume ls

# Детали тома с данными
docker volume inspect dialer_v1_postgres_data

# Проверка монтированных директорий
docker exec dialer_backend ls -la /app
```

## 🚨 Частые проблемы и решения

### 1. Порты заняты
```bash
# Проверка какой процесс использует порт
lsof -i :3000
lsof -i :5173

# Освобождение порта (осторожно!)
sudo kill -9 $(lsof -t -i:3000)
```

### 2. Проблемы с базой данных
```bash
# Проверка подключения к БД
docker exec dialer_backend npm run db:check

# Выполнение миграций
docker exec dialer_backend npm run migrate

# Проверка статуса БД
docker exec dialer_postgres pg_isready -U dialer_user
```

### 3. Проблемы с сетью
```bash
# Проверка доступности между контейнерами
docker exec dialer_backend ping postgres
docker exec dialer_frontend ping backend

# Проверка DNS внутри сети
docker exec dialer_backend nslookup postgres
```

## 📞 Проверка функциональности

### Основные endpoint'ы
```bash
# Проверка health check бэкенда
curl http://localhost:3000/health

# Проверка API бэкенда
curl http://localhost:3000/api/health

# Проверка фронтенда
curl http://localhost:5173

# Проверка с тестового сервера (замените IP)
curl http://YOUR_SERVER_IP:3000/health
curl http://YOUR_SERVER_IP:5173
```

### WebSocket соединения
```bash
# Проверка WebSocket (используйте браузер или wscat)
wscat -c ws://localhost:3000

# Тест с сервера
wscat -c ws://YOUR_SERVER_IP:3000
```

---

## 🔥 Экстренные команды

### Полный диагностический скрипт
```bash
# Запуск созданного скрипта диагностики
./debug-docker.sh
```

### Сбор всей диагностической информации
```bash
# Создание файла с полной диагностикой
{
  echo "=== DOCKER PS ==="
  docker ps -a
  echo "=== DOCKER STATS ==="
  docker stats --no-stream
  echo "=== COMPOSE STATUS ==="
  docker-compose ps
  echo "=== BACKEND LOGS ==="
  docker logs --tail 100 dialer_backend
  echo "=== FRONTEND LOGS ==="
  docker logs --tail 100 dialer_frontend
  echo "=== POSTGRES LOGS ==="
  docker logs --tail 50 dialer_postgres
} > diagnostic_$(date +%Y%m%d_%H%M%S).log
```

### Отправка логов для анализа
```bash
# Сохранение логов в файл для отправки разработчику
docker logs dialer_backend > backend_logs_$(date +%Y%m%d_%H%M%S).log
docker logs dialer_frontend > frontend_logs_$(date +%Y%m%d_%H%M%S).log
``` 