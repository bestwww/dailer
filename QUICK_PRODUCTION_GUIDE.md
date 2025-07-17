# ⚡ Быстрая инструкция: Решение падений на тестовом сервере

## 🚨 Если приложение упало - действуйте немедленно!

### 📞 Экстренное восстановление (3 минуты)

```bash
# 1. Перейдите в директорию проекта
cd /path/to/dailer

# 2. Быстрое восстановление
./emergency-recovery.sh quick

# ИЛИ полное восстановление (если quick не помогло)
./emergency-recovery.sh full
```

### 🔍 Диагностика проблемы (2 минуты)

```bash
# Проверить состояние системы
./production-monitoring.sh check

# Собрать логи для анализа
./production-monitoring.sh logs
```

### 🔄 Запуск мониторинга

```bash
# Постоянный мониторинг (запустить в screen/tmux)
./production-monitoring.sh monitor

# ИЛИ через screen
screen -S monitoring
./production-monitoring.sh monitor
# Ctrl+A, D для выхода из screen
```

## 🎯 Наиболее частые причины падений

### 1. 💾 Нехватка памяти (OOM Killer)
**Симптомы**: Контейнеры внезапно останавливаются
**Решение**:
```bash
# Проверить память
free -h
docker stats --no-stream

# Использовать production конфигурацию с лимитами
docker-compose -f docker-compose.production.yml up -d
```

### 2. 📝 Переполнение логов
**Симптомы**: Заполнен диск, медленная работа
**Решение**:
```bash
# Проверить размер логов
du -sh /var/lib/docker/containers/*/

# Очистить логи
docker system prune -f
./emergency-recovery.sh cleanup
```

### 3. 🔌 Проблемы с базой данных
**Симптомы**: Backend не может подключиться к PostgreSQL
**Решение**:
```bash
# Проверить БД
docker exec dialer_postgres pg_isready -U dialer_user -d dialer_db

# Перезапуск только БД
docker-compose restart postgres
```

### 4. 📞 Проблемы с FreeSWITCH
**Симптомы**: Звонки не проходят, высокое использование CPU
**Решение**:
```bash
# Проверить FreeSWITCH
docker exec dialer_freeswitch fs_cli -x "status"

# Перезапуск FreeSWITCH
docker-compose restart freeswitch
```

### 5. 🌐 Сетевые проблемы
**Симптомы**: Timeout между сервисами
**Решение**:
```bash
# Проверить сетевые соединения
docker network inspect dialer_dialer_network
docker exec dialer_backend ping -c 3 dialer_postgres
```

## 📊 Регулярное обслуживание

### Еженедельно (каждый понедельник)
```bash
# 1. Создать резервную копию
./emergency-recovery.sh backup

# 2. Очистить ненужные ресурсы
docker system prune -f

# 3. Проверить логи на ошибки
./production-monitoring.sh logs | grep -i error
```

### Ежемесячно
```bash
# 1. Обновить систему
git pull origin main
docker-compose down
docker-compose build --no-cache
docker-compose -f docker-compose.production.yml up -d

# 2. Проверить обновления образов
docker-compose pull
```

## 🚀 Улучшения стабильности

### 1. Замените docker-compose.yml на production версию
```bash
# Скопируйте текущий файл
cp docker-compose.yml docker-compose.yml.backup

# Используйте production конфигурацию
cp docker-compose.production.yml docker-compose.yml

# Перезапустите с новыми настройками
docker-compose down
docker-compose up -d
```

### 2. Настройте автоматический мониторинг
```bash
# Добавьте в crontab
crontab -e

# Добавьте строки:
# Проверка каждые 5 минут
*/5 * * * * /path/to/dailer/production-monitoring.sh alert

# Еженедельная очистка
0 2 * * 1 /path/to/dailer/emergency-recovery.sh cleanup
```

### 3. Настройте ротацию логов Docker
```bash
# Создайте /etc/docker/daemon.json
sudo tee /etc/docker/daemon.json << EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  }
}
EOF

# Перезапустите Docker
sudo systemctl restart docker
```

## 📱 Алерты и уведомления

### Настройка Email уведомлений
```bash
# Установите mail utils
sudo apt-get install mailutils

# Отредактируйте email в скриптах
sed -i 's/admin@company.com/ваш-email@domain.com/g' production-monitoring.sh
```

### Настройка Telegram уведомлений
```bash
# Получите токен бота у @BotFather
# Раскомментируйте строки в production-monitoring.sh:
# curl -X POST "https://api.telegram.org/bot<TOKEN>/sendMessage" \
#   -d "chat_id=<CHAT_ID>&text=$subject: $message"
```

## 🔧 Параметры для мониторинга

### Критические метрики:
- **CPU > 80%** - предупреждение
- **Memory > 85%** - предупреждение  
- **Disk > 90%** - критично
- **DB connections > 80** - предупреждение
- **Container restart** - уведомление

### Здоровые показатели:
- Все контейнеры в состоянии "healthy"
- Backend отвечает на `/health`
- Frontend доступен на порту 5173
- PostgreSQL принимает соединения
- Redis отвечает на ping

## 📋 Контрольный список при падении

- [ ] Запустил диагностику: `./production-monitoring.sh check`
- [ ] Собрал логи: `./production-monitoring.sh logs`
- [ ] Проверил дисковое пространство: `df -h`
- [ ] Проверил память: `free -h`
- [ ] Выполнил восстановление: `./emergency-recovery.sh`
- [ ] Проверил доступность: Backend + Frontend
- [ ] Запустил мониторинг: `./production-monitoring.sh monitor`
- [ ] Сохранил логи падения для анализа
- [ ] Обновил документацию с новыми находками

## 📞 Контакты экстренной поддержки

- **Разработчик**: [ваши контакты]
- **DevOps**: [контакты команды]
- **Журнал инцидентов**: `/logs/incidents/`

---

**💡 Совет**: Добавьте этот файл в закладки браузера и держите под рукой для быстрого доступа при проблемах! 