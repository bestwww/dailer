# 🎯 Система автодозвона

Полнофункциональная система автоматического обзвона клиентов с интеграцией в Битрикс24.

## ✨ Основные возможности

- 🔄 **Автоматический обзвон** по базе контактов
- 🎵 **Проигрывание аудиороликов** с приветствием
- 📞 **Запись DTMF ответов** (1 - интересно, 2 - не интересно)
- 🤖 **AMD система** - определение и отсечение автоответчиков
- 📊 **Веб-интерфейс** для управления кампаниями
- 📈 **Статистика и аналитика** в реальном времени
- 🔗 **Интеграция с Битрикс24** - автоматическое создание лидов

## 🛠 Технологический стек

### Backend
- **FreeSWITCH** - телефонная платформа
- **Node.js + TypeScript** - API сервер
- **PostgreSQL** - база данных
- **Redis** - кеширование и очереди

### Frontend
- **Vue.js 3 + TypeScript** - веб-интерфейс
- **Vuetify** - UI компоненты
- **Pinia** - управление состоянием

### Инфраструктура
- **Docker + Docker Compose** - контейнеризация
- **ESL (Event Socket Library)** - интеграция с FreeSWITCH

## 🚀 Быстрый старт

### Предварительные требования

- Docker и Docker Compose
- Git
- Минимум 4GB RAM
- SIP провайдер для исходящих звонков

### 1. Клонирование проекта

```bash
git clone <repository-url> dialer_v1
cd dialer_v1
```

### 2. Настройка окружения

```bash
# Копируем файл с переменными окружения
cp .env.example .env

# Редактируем настройки (обязательно!)
nano .env
```

**Важно:** Обязательно укажите настройки вашего SIP провайдера в `.env` файле:
- `SIP_PROVIDER_HOST`
- `SIP_PROVIDER_USERNAME` 
- `SIP_PROVIDER_PASSWORD`
- `SIP_CALLER_ID_NUMBER`

### 3. Запуск системы

```bash
# Запуск всех сервисов
docker-compose up -d

# Просмотр логов
docker-compose logs -f

# Проверка статуса
docker-compose ps
```

### 4. Проверка работоспособности

После запуска будут доступны:

- **Веб-интерфейс**: http://localhost:5173
- **API**: http://localhost:3000
- **PostgreSQL**: localhost:5432
- **Redis**: localhost:6379
- **FreeSWITCH ESL**: localhost:8021

Логин по умолчанию:
- **Пользователь**: admin
- **Пароль**: admin123

## 📁 Структура проекта

```
dialer_v1/
├── backend/                 # Node.js + TypeScript API
│   ├── src/
│   │   ├── controllers/     # Контроллеры API
│   │   ├── services/        # Бизнес-логика
│   │   ├── models/          # Модели данных
│   │   └── config/          # Конфигурация
│   └── package.json
├── frontend/                # Vue.js приложение
│   ├── src/
│   │   ├── components/      # Компоненты Vue
│   │   ├── views/           # Страницы
│   │   ├── stores/          # Pinia stores
│   │   └── types/           # TypeScript типы
│   └── package.json
├── freeswitch/conf/         # Конфигурация FreeSWITCH
├── docker/                  # Docker файлы
├── database/migrations/     # SQL миграции
├── audio/                   # Аудиофайлы кампаний
└── docker-compose.yml       # Конфигурация Docker Compose
```

## 🔧 Настройка SIP провайдера

### 1. Редактирование FreeSWITCH конфигурации

Отредактируйте файл `freeswitch/conf/autoload_configs/sofia.conf.xml`:

```xml
<gateway name="provider">
  <param name="username" value="ваш_sip_логин"/>
  <param name="password" value="ваш_sip_пароль"/>
  <param name="realm" value="sip.провайдер.com"/>
  <param name="proxy" value="sip.провайдер.com"/>
  <param name="register" value="true"/>
</gateway>
```

### 2. Перезапуск FreeSWITCH

```bash
docker-compose restart freeswitch
```

## 📊 Использование системы

### 1. Создание кампании

1. Войдите в веб-интерфейс: http://localhost:5173
2. Перейдите в "Кампании" → "Создать новую"
3. Заполните название и описание
4. Загрузите аудиофайл с приветствием
5. Настройте параметры обзвона

### 2. Загрузка контактов

1. В кампании нажмите "Загрузить контакты"
2. Выберите CSV файл с колонками: phone, name (опционально)
3. Дождитесь импорта

### 3. Запуск кампании

1. Проверьте настройки кампании
2. Нажмите "Запустить кампанию"
3. Отслеживайте прогресс в real-time

### 4. Просмотр результатов

- **Дашборд** - общая статистика
- **Детали кампании** - подробные результаты
- **Отчеты** - экспорт данных

## 🔗 Интеграция с Битрикс24

### 1. Создание приложения в Битрикс24

1. Перейдите в "Приложения" → "Разработчикам"
2. Создайте новое приложение
3. Получите Client ID и Client Secret

### 2. Настройка в системе

Укажите в `.env` файле:
```env
BITRIX24_DOMAIN=ваш-портал.bitrix24.ru
BITRIX24_CLIENT_ID=ваш_client_id
BITRIX24_CLIENT_SECRET=ваш_client_secret
```

### 3. Авторизация

1. В веб-интерфейсе перейдите в "Настройки" → "Интеграции"
2. Нажмите "Подключить Битрикс24"
3. Завершите OAuth авторизацию

## 📈 Мониторинг и логи

### Просмотр логов

```bash
# Все сервисы
docker-compose logs -f

# Конкретный сервис
docker-compose logs -f backend
docker-compose logs -f freeswitch

# Последние записи
docker-compose logs --tail=100 backend
```

### Подключение к базе данных

```bash
# Подключение к PostgreSQL
docker-compose exec postgres psql -U dialer_user -d dialer_db

# Подключение к Redis
docker-compose exec redis redis-cli
```

## 🛠 Разработка

### Разработка backend

```bash
cd backend
npm install
npm run dev
```

### Разработка frontend

```bash
cd frontend
npm install
npm run dev
```

### Тестирование

```bash
# Backend тесты
cd backend
npm run test

# Frontend тесты
cd frontend
npm run test
```

## 🔒 Безопасность

### Production настройки

1. Смените пароли в `.env` файле
2. Настройте SSL сертификаты
3. Ограничьте доступ к портам
4. Включите firewall
5. Регулярно обновляйте зависимости

### Рекомендации

- Используйте сильные пароли
- Регулярно делайте backup базы данных
- Мониторьте логи на предмет подозрительной активности
- Ограничьте доступ к FreeSWITCH ESL

## 🐛 Решение проблем

### FreeSWITCH не запускается

```bash
# Проверьте логи
docker-compose logs freeswitch

# Проверьте конфигурацию
docker-compose exec freeswitch fs_cli -x "status"
```

### База данных не подключается

```bash
# Проверьте статус PostgreSQL
docker-compose exec postgres pg_isready

# Пересоздайте контейнер
docker-compose down postgres
docker-compose up -d postgres
```

### Backend не подключается к FreeSWITCH

1. Убедитесь что FreeSWITCH запущен
2. Проверьте настройки ESL в `event_socket.conf.xml`
3. Проверьте переменные окружения

## 📚 API Документация

### Основные endpoints

- `GET /api/campaigns` - список кампаний
- `POST /api/campaigns` - создание кампании
- `POST /api/campaigns/:id/contacts` - загрузка контактов
- `POST /api/campaigns/:id/start` - запуск кампании
- `GET /api/campaigns/:id/stats` - статистика кампании

Полная документация доступна по адресу: http://localhost:3000/api-docs

## 🤝 Поддержка

### Получение помощи

1. Проверьте документацию
2. Просмотрите известные проблемы
3. Создайте issue с описанием проблемы

### Внесение изменений

1. Fork проекта
2. Создайте feature branch
3. Внесите изменения
4. Создайте Pull Request

## 📄 Лицензия

Этот проект распространяется под лицензией MIT. См. файл LICENSE для подробностей. 