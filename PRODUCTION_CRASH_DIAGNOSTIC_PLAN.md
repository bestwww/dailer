# 🔍 План диагностики падений приложения на тестовом сервере

## 🚨 Описание проблемы

- **Среда**: Тестовый сервер (production-like)
- **Симптомы**: Приложение периодически падает (уже 2 раза)
- **Решение**: Перезапуск Docker контейнеров помогает
- **Частота**: Не определена, требует мониторинга

## 🎯 Цели диагностики

1. **Выявить причину падений** - что именно вызывает сбой
2. **Определить паттерн** - когда и при каких условиях происходят падения
3. **Предотвратить будущие падения** - настроить автоматическое восстановление
4. **Оптимизировать стабильность** - улучшить мониторинг и алерты

## 🔧 План действий

### 📊 Этап 1: Немедленная диагностика (5-10 минут)

#### 1.1 Проверка текущего состояния
```bash
# Статус всех контейнеров
docker ps -a
docker-compose ps

# Использование ресурсов
docker stats --no-stream
```

#### 1.2 Сбор логов последней сессии
```bash
# Логи всех сервисов за последние 2 часа
docker-compose logs --since=2h > crash_logs_$(date +%Y%m%d_%H%M).log

# Системные логи
journalctl --since="2 hours ago" | grep -i docker > system_logs_$(date +%Y%m%d_%H%M).log
```

#### 1.3 Проверка дискового пространства
```bash
# Проверка места на диске
df -h
du -sh /var/lib/docker/

# Размер логов Docker
docker system df
```

### 🔬 Этап 2: Глубокая диагностика (15-20 минут)

#### 2.1 Анализ логов по сервисам
```bash
# Backend - ошибки и OOM
docker logs dialer_backend --since=24h | grep -i -E "(error|out of memory|fatal|crash|killed)"

# PostgreSQL - проблемы с БД
docker logs dialer_postgres --since=24h | grep -i -E "(error|fatal|connection|lock)"

# FreeSWITCH - телефонные проблемы  
docker logs dialer_freeswitch --since=24h | grep -i -E "(error|fatal|crash)"

# Redis - проблемы с кешем
docker logs dialer_redis --since=24h | grep -i -E "(error|out of memory|fatal)"
```

#### 2.2 Проверка памяти и процессов
```bash
# История использования памяти
sar -r 1 10

# Проверка swap
swapon -s
free -h

# Проверка процессов, которые могли быть убиты OOM Killer
dmesg | grep -i "killed process"
journalctl -k | grep -i "out of memory"
```

#### 2.3 Сетевая диагностика
```bash
# Проверка сетевых соединений
netstat -tuln | grep -E "(3000|5432|6379|5060|8021)"

# Проверка Docker сетей
docker network inspect dialer_dialer_network
```

### 📈 Этап 3: Настройка мониторинга (20-30 минут)

#### 3.1 Улучшение health checks
- Добавить проверки памяти в health checks
- Настроить более частые проверки для критических сервисов
- Добавить проверки соединений между сервисами

#### 3.2 Настройка ротации логов
```bash
# Ограничение размера логов Docker
# В /etc/docker/daemon.json:
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  }
}
```

#### 3.3 Мониторинг ресурсов
- Настройка алертов при превышении лимитов памяти/CPU
- Мониторинг размера логов
- Отслеживание количества соединений к БД

### 🛡️ Этап 4: Профилактические меры (15-20 минут)

#### 4.1 Оптимизация restart policies
```yaml
# В docker-compose.yml для критических сервисов:
restart: unless-stopped
deploy:
  restart_policy:
    condition: on-failure
    delay: 5s
    max_attempts: 3
    window: 120s
```

#### 4.2 Добавление лимитов ресурсов
```yaml
# Пример для backend:
deploy:
  resources:
    limits:
      memory: 1G
      cpus: '0.50'
    reservations:
      memory: 512M
      cpus: '0.25'
```

#### 4.3 Настройка graceful shutdown
- Настройка корректного завершения процессов
- Таймауты для graceful shutdown
- Сохранение состояния перед перезапуском

## 🎯 Возможные причины падений

### 💾 1. Утечки памяти
**Симптомы**: Постепенное увеличение использования RAM
**Проверка**: 
```bash
# Мониторинг памяти Node.js процесса
docker exec dialer_backend node -e "console.log(process.memoryUsage())"
```

### 📝 2. Переполнение логов
**Симптомы**: Заполнение диска, медленная работа I/O
**Проверка**:
```bash
du -sh /var/lib/docker/containers/*/
```

### 🔌 3. Проблемы с соединениями БД
**Симптомы**: Connection pool exhausted, timeout'ы
**Проверка**:
```bash
# Количество активных соединений
docker exec dialer_postgres psql -U dialer_user -d dialer_db -c "SELECT count(*) FROM pg_stat_activity;"
```

### 📞 4. Проблемы FreeSWITCH
**Симптомы**: Высокое использование CPU, memory leaks
**Проверка**:
```bash
docker exec dialer_freeswitch fs_cli -x "show channels"
docker exec dialer_freeswitch fs_cli -x "status"
```

### 🌐 5. Сетевые проблемы
**Симптомы**: Timeout'ы между сервисами, потерянные соединения
**Проверка**:
```bash
# Проверка связности между контейнерами
docker exec dialer_backend ping -c 3 dialer_postgres
docker exec dialer_backend ping -c 3 dialer_redis
```

## 🚀 Инструменты для мониторинга

### 📊 Скрипт непрерывного мониторинга
```bash
#!/bin/bash
# monitoring_loop.sh - запускать в фоне для отслеживания
while true; do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] Checking system status..."
    
    # Проверка контейнеров
    docker ps --format "table {{.Names}}\t{{.Status}}" | grep -v "Up"
    
    # Проверка ресурсов
    docker stats --no-stream --format "{{.Name}}: CPU {{.CPUPerc}}, MEM {{.MemUsage}}"
    
    sleep 300  # Проверка каждые 5 минут
done
```

### 📱 Алерты при падении
```bash
#!/bin/bash
# alert_on_crash.sh
check_service() {
    if ! docker ps --filter "name=$1" --filter "status=running" | grep -q $1; then
        echo "ALERT: Service $1 is down!" | mail -s "Docker Service Down" admin@company.com
        # Или отправка в Telegram/Slack
    fi
}

for service in dialer_backend dialer_postgres dialer_redis dialer_freeswitch; do
    check_service $service
done
```

## 📋 Чек-лист для тестового сервера

- [ ] Собраны логи последних падений
- [ ] Проверено дисковое пространство  
- [ ] Настроена ротация логов Docker
- [ ] Добавлены лимиты ресурсов для контейнеров
- [ ] Улучшены health checks
- [ ] Настроен мониторинг ресурсов
- [ ] Настроены алерты при падениях
- [ ] Добавлены graceful shutdown handlers
- [ ] Протестирована автоматическая перезагрузка
- [ ] Документированы процедуры восстановления

## 🔄 Процедура при обнаружении падения

1. **Немедленно собрать логи** перед перезапуском
2. **Проверить системные ресурсы** (память, диск, CPU)
3. **Сохранить дамп состояния** критических сервисов
4. **Перезапустить сервисы** с полным логированием
5. **Проанализировать собранные данные**
6. **Обновить этот план** на основе новых данных

## 📞 Контакты для экстренных ситуаций

- **Основной разработчик**: [ваши контакты]
- **DevOps команда**: [контакты команды]
- **Лог-файлы сохранять в**: `/logs/crashes/` 