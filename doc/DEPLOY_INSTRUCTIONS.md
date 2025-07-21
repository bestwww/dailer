# 🚀 Инструкции по развертыванию системы автодозвона

## 📋 Требования к серверу

### Минимальные требования:
- **ОС:** Ubuntu 22.04 LTS или выше
- **RAM:** 4GB (рекомендуется 8GB)
- **CPU:** 2 cores (рекомендуется 4 cores)  
- **Диск:** 40GB SSD (рекомендуется 100GB)
- **Сеть:** Белый IP адрес для SIP

### Рекомендуемые характеристики:
- **RAM:** 8-16GB для 100+ одновременных звонков
- **CPU:** 4-8 cores
- **Диск:** 100GB+ SSD

## 🛠️ Шаг 1: Подготовка сервера Ubuntu

```bash
# Обновляем систему
sudo apt update && sudo apt upgrade -y

# Устанавливаем необходимые пакеты
sudo apt install -y curl wget git ufw htop nano

# Настраиваем firewall
sudo ufw allow ssh
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 3000    # Backend API
sudo ufw allow 5173    # Frontend (dev)
sudo ufw allow 5060/udp # SIP
sudo ufw allow 8021    # FreeSWITCH ESL
sudo ufw allow 16384:16394/udp # RTP медиа
sudo ufw --force enable
```

## 🐳 Шаг 2: Установка Docker

```bash
# Удаляем старые версии Docker
sudo apt remove -y docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc

# Добавляем официальный репозиторий Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Устанавливаем Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Добавляем пользователя в группу docker
sudo usermod -aG docker $USER

# Перелогиниваемся или выполняем
newgrp docker

# Проверяем установку
docker --version
docker compose version
```

## 📦 Шаг 3: Клонирование проекта

```bash
# Клонируем проект
git clone https://your-repo-url/dailer_v1.git
cd dailer_v1

# Создаем production конфигурацию
cp .env.production .env

# Редактируем настройки под ваш SIP провайдер
nano .env
```

### ⚙️ Обязательные настройки в .env:

```bash
# Замените на данные вашего SIP провайдера
SIP_PROVIDER_HOST=sip.your-provider.com
SIP_PROVIDER_USERNAME=your_sip_login  
SIP_PROVIDER_PASSWORD=your_sip_password
SIP_CALLER_ID_NUMBER=+7XXXXXXXXXX

# Измените пароли безопасности
DATABASE_URL=postgresql://dialer_user:CHANGE_DB_PASSWORD@postgres:5432/dialer_db
REDIS_URL=redis://:CHANGE_REDIS_PASSWORD@redis:6379
JWT_SECRET=CHANGE_JWT_SECRET_TO_STRONG_PASSWORD

# Укажите ваш домен
CORS_ORIGIN=http://your-server-ip:5173,http://your-domain.com
```

## 🚀 Шаг 4: Запуск системы

```bash
# Создаем необходимые директории
mkdir -p audio backend/logs

# Запускаем все сервисы
docker compose up -d

# Проверяем статус контейнеров
docker compose ps

# Следим за логами
docker compose logs -f
```

## 📊 Шаг 5: Проверка работоспособности

### Проверка контейнеров:
```bash
# Все контейнеры должны быть в статусе "Up"
docker compose ps

# Проверка логов
docker compose logs postgres
docker compose logs freeswitch  
docker compose logs backend
docker compose logs frontend
```

### Проверка доступности сервисов:
```bash
# Backend API (должен возвращать статус)
curl http://localhost:3000/health

# FreeSWITCH status
docker compose exec freeswitch fs_cli -x "status"

# Frontend (веб-интерфейс)
curl http://localhost:5173
```

### Веб-интерфейсы:
- **Frontend:** http://your-server-ip:5173
- **Backend API:** http://your-server-ip:3000/api

## 🔧 Шаг 6: Настройка FreeSWITCH для SIP провайдера

### Настройка SIP профиля:
```bash
# Редактируем конфигурацию SIP
nano freeswitch/conf/autoload_configs/sofia.conf.xml

# Перезапускаем FreeSWITCH
docker compose restart freeswitch
```

### Проверка SIP регистрации:
```bash
# Подключаемся к FreeSWITCH CLI
docker compose exec freeswitch fs_cli

# Проверяем статус SIP профилей
sofia status

# Проверяем регистрацию на провайдере
sofia status gateway your_provider_gateway
```

## 🔄 Обновление системы

```bash
# Получаем последние изменения
git pull origin main

# Пересобираем и перезапускаем
docker compose down
docker compose build --no-cache
docker compose up -d
```

## 🛠️ Полезные команды

### Управление контейнерами:
```bash
# Остановка всех сервисов
docker compose down

# Полная остановка с удалением volumes (ВНИМАНИЕ: удалятся данные БД!)
docker compose down -v

# Пересборка образов
docker compose build --no-cache

# Просмотр логов конкретного сервиса
docker compose logs -f backend
docker compose logs -f freeswitch

# Подключение к контейнеру
docker compose exec backend bash
docker compose exec freeswitch bash
```

### Мониторинг:
```bash
# Мониторинг ресурсов
docker stats

# Проверка дискового пространства
df -h

# Проверка использования памяти
free -h

# Сетевые подключения
ss -tulpn
```

## 🆘 Решение проблем

### Проблема: Контейнер не запускается
```bash
# Проверяем логи
docker compose logs service_name

# Проверяем статус
docker compose ps
```

### Проблема: FreeSWITCH не регистрируется на SIP провайдере
```bash
# Проверяем конфигурацию
docker compose exec freeswitch fs_cli -x "sofia status"

# Проверяем connectivity
docker compose exec freeswitch ping sip.your-provider.com
```

### Проблема: Недоступен веб-интерфейс
```bash
# Проверяем firewall
sudo ufw status

# Проверяем, слушает ли порт
ss -tulpn | grep :5173
```

## 📞 Тестирование звонков

### Создание тестовой кампании:
1. Откройте http://your-server-ip:5173
2. Войдите в систему  
3. Создайте тестовую кампанию
4. Добавьте тестовые номера
5. Запустите кампанию

### Мониторинг звонков:
```bash
# Логи звонков в реальном времени
docker compose logs -f freeswitch | grep DTMF
docker compose logs -f backend | grep "Call"
```

## 🔒 Безопасность

1. **Измените все пароли** в .env файле
2. **Настройте SSL сертификаты** для HTTPS
3. **Ограничьте доступ** к портам через firewall
4. **Регулярно обновляйте** систему и Docker образы
5. **Настройте резервное копирование** базы данных

---

💡 **Поддержка:** При возникновении проблем проверьте логи контейнеров и файл конфигурации .env 