# Backend API - Система автодозвона

Backend API для системы автодозвона на базе Node.js + TypeScript + Express.js с интеграцией FreeSWITCH и Битрикс24.

## 🏗 Архитектура

```
backend/
├── src/
│   ├── app.ts              # Главный файл приложения
│   ├── config/             # Конфигурация приложения
│   │   ├── index.ts        # Основные настройки
│   │   └── database.ts     # Настройки PostgreSQL
│   ├── controllers/        # API контроллеры
│   │   ├── auth.ts         # Аутентификация
│   │   ├── campaigns.ts    # Управление кампаниями
│   │   ├── contacts.ts     # Управление контактами
│   │   ├── calls.ts        # Результаты звонков
│   │   ├── stats.ts        # Статистика
│   │   ├── settings.ts     # Настройки системы
│   │   └── bitrix.ts       # Интеграция Битрикс24
│   ├── services/           # Бизнес-логика
│   │   ├── dialer.ts       # Диалер engine
│   │   ├── freeswitch.ts   # FreeSWITCH ESL клиент
│   │   ├── bitrix24.ts     # Битрикс24 API
│   │   └── queue.ts        # Очереди задач
│   ├── models/             # Модели данных
│   │   ├── campaign.ts     # Модель кампании
│   │   ├── contact.ts      # Модель контакта
│   │   ├── call-result.ts  # Модель результата звонка
│   │   └── user.ts         # Модель пользователя
│   ├── middleware/         # Express middleware
│   │   ├── auth.ts         # Проверка аутентификации
│   │   ├── validation.ts   # Валидация данных
│   │   └── error.ts        # Обработка ошибок
│   ├── utils/              # Утилиты
│   │   ├── logger.ts       # Система логирования
│   │   ├── crypto.ts       # Криптографические функции
│   │   └── helpers.ts      # Вспомогательные функции
│   └── types/              # TypeScript типы
│       └── index.ts        # Основные интерфейсы
├── tests/                  # Тесты
├── public/                 # Статические файлы
├── audio/                  # Аудио файлы
├── logs/                   # Логи приложения
├── package.json           # Зависимости Node.js
├── tsconfig.json          # Конфигурация TypeScript
├── Dockerfile             # Docker образ
├── .dockerignore          # Исключения Docker
└── README.md              # Документация
```

## 🚀 Технологический стек

### Основные технологии
- **Node.js 18+** - Runtime окружение
- **TypeScript 5+** - Статическая типизация
- **Express.js 4** - Web фреймворк
- **PostgreSQL** - Основная база данных
- **Redis** - Кэширование и очереди

### FreeSWITCH интеграция
- **ESL (Event Socket Library)** - Управление звонками
- **AMD (Answering Machine Detection)** - Определение автоответчиков
- **DTMF** - Обработка тональных сигналов

### Библиотеки и зависимости
- **winston** - Логирование
- **joi** - Валидация данных
- **bcryptjs** - Хеширование паролей
- **jsonwebtoken** - JWT аутентификация
- **socket.io** - WebSocket соединения
- **bull** - Очереди задач
- **axios** - HTTP клиент для API
- **multer** - Загрузка файлов

## ⚙️ Настройка и запуск

### 1. Переменные окружения

Скопируйте `.env.example` в `.env` и настройте переменные:

```bash
# Копирование файла настроек
cp .env.example .env
```

### 2. Основные настройки (.env)

```env
# Сервер
NODE_ENV=development
PORT=3000

# База данных PostgreSQL
DATABASE_URL=postgresql://dialer_user:dialer_password@localhost:5432/dialer_db

# Redis
REDIS_URL=redis://localhost:6379

# FreeSWITCH ESL
FREESWITCH_HOST=localhost
FREESWITCH_PORT=8021
FREESWITCH_PASSWORD=ClueCon

# JWT
JWT_SECRET=your-super-secret-jwt-key-minimum-32-characters-long
JWT_EXPIRES_IN=24h

# Файлы
AUDIO_UPLOAD_PATH=./audio
AUDIO_MAX_SIZE=10485760
SUPPORTED_AUDIO_FORMATS=wav,mp3,aiff

# Диалер
MAX_CONCURRENT_CALLS=10
CALLS_PER_MINUTE=30
DEFAULT_RETRY_ATTEMPTS=3
DEFAULT_RETRY_DELAY=300

# AMD (Answering Machine Detection)
AMD_ENABLED=true
AMD_TIMEOUT=5000
AMD_SILENCE_TIMEOUT=1000

# Битрикс24 (опционально)
BITRIX24_DOMAIN=your-domain.bitrix24.ru
BITRIX24_CLIENT_ID=your_client_id
BITRIX24_CLIENT_SECRET=your_client_secret
BITRIX24_REDIRECT_URI=http://localhost:3000/api/bitrix/callback

# Логирование
LOG_LEVEL=info
LOG_FILE_PATH=./logs/app.log
```

### 3. Установка зависимостей

```bash
# Установка NPM пакетов
npm install

# Или с использованием yarn
yarn install
```

### 4. Разработка

```bash
# Запуск в режиме разработки
npm run dev

# Запуск с отладкой
npm run dev:debug

# Проверка типов TypeScript
npm run typecheck

# Линтинг кода
npm run lint

# Форматирование кода
npm run format
```

### 5. Production сборка

```bash
# Сборка TypeScript
npm run build

# Запуск production версии
npm start

# Или через Docker
docker build -t dialer-backend .
docker run -p 3000:3000 --env-file .env dialer-backend
```

## 📁 API Endpoints

### Аутентификация

- `POST /api/auth/login` - Вход в систему
- `GET /api/auth/me` - Получение данных пользователя
- `POST /api/auth/refresh` - Обновление токена
- `POST /api/auth/logout` - Выход из системы

### Кампании

- `GET /api/campaigns` - Список кампаний
- `POST /api/campaigns` - Создание кампании
- `GET /api/campaigns/:id` - Получение кампании
- `PUT /api/campaigns/:id` - Обновление кампании
- `DELETE /api/campaigns/:id` - Удаление кампании
- `POST /api/campaigns/:id/start` - Запуск кампании
- `POST /api/campaigns/:id/pause` - Остановка кампании

### Контакты

- `GET /api/contacts` - Список контактов
- `POST /api/contacts` - Создание контакта
- `POST /api/contacts/bulk` - Массовое создание
- `POST /api/contacts/import` - Импорт из файла
- `GET /api/contacts/:id` - Получение контакта
- `PUT /api/contacts/:id` - Обновление контакта
- `DELETE /api/contacts/:id` - Удаление контакта

### Результаты звонков

- `GET /api/calls` - Список результатов
- `GET /api/calls/:id` - Результат звонка
- `GET /api/calls/campaign/:id` - Результаты кампании

### Статистика

- `GET /api/stats/campaigns` - Статистика кампаний
- `GET /api/stats/campaigns/:id` - Статистика кампании
- `GET /api/stats/dashboard` - Общая статистика

### Настройки

- `GET /api/settings` - Получение настроек
- `PUT /api/settings` - Обновление настроек

### Битрикс24

- `GET /api/bitrix/auth` - OAuth авторизация
- `POST /api/bitrix/webhook` - Webhook события
- `GET /api/bitrix/leads` - Список лидов

## 🔐 Аутентификация

API использует JWT токены для аутентификации. После успешного входа клиент получает токен, который нужно передавать в заголовке:

```
Authorization: Bearer <jwt-token>
```

### Роли пользователей

- **admin** - Полный доступ ко всем функциям
- **manager** - Управление кампаниями и контактами
- **user** - Просмотр кампаний и результатов
- **viewer** - Только просмотр статистики

### Права доступа (permissions)

- `campaigns_create` - Создание кампаний
- `campaigns_edit` - Редактирование кампаний
- `campaigns_delete` - Удаление кампаний
- `contacts_import` - Импорт контактов
- `settings_manage` - Управление настройками
- `users_manage` - Управление пользователями

## 📊 Логирование

Система использует Winston для структурированного логирования:

- **Консольный вывод** (development)
- **Файловые логи с ротацией** (production)
- **Отдельные файлы для ошибок**
- **Специализированные логи** (звонки, безопасность, производительность)

### Уровни логирования

- `error` - Критические ошибки
- `warn` - Предупреждения
- `info` - Информационные сообщения
- `http` - HTTP запросы
- `debug` - Отладочная информация

## 🔧 FreeSWITCH интеграция

### ESL (Event Socket Library)

Backend подключается к FreeSWITCH через ESL для:

- Инициации исходящих звонков
- Получения событий звонков
- Управления каналами связи
- Обработки DTMF сигналов

### Поддерживаемые события

- `CHANNEL_CREATE` - Создание канала
- `CHANNEL_ANSWER` - Ответ на звонок
- `CHANNEL_HANGUP` - Завершение звонка
- `DTMF` - Тональные сигналы
- `AMD_RESULT` - Результат определения автоответчика

## 🎯 Битрикс24 интеграция

### OAuth 2.0 авторизация

```javascript
// Получение ссылки на авторизацию
GET /api/bitrix/auth

// Обработка callback после авторизации
GET /api/bitrix/callback?code=...
```

### Создание лидов

При заинтересованном ответе (DTMF "1") автоматически создается лид в Битрикс24 с информацией:

- Номер телефона
- Время звонка
- Кампания
- Результат DTMF

## 🧪 Тестирование

```bash
# Запуск всех тестов
npm test

# Запуск тестов в watch режиме
npm run test:watch

# Покрытие кода тестами
npm run test:coverage
```

## 📈 Мониторинг

### Health Check

```bash
curl http://localhost:3000/health
```

Возвращает статус приложения, базы данных и использование памяти.

### Метрики производительности

- Время выполнения SQL запросов
- Статистика подключений к БД
- Количество активных звонков
- Использование памяти

## 🐳 Docker

### Development

```bash
# Сборка и запуск
docker-compose up --build backend

# Только backend сервис
docker-compose up backend
```

### Production

```bash
# Сборка production образа
docker build --target production -t dialer-backend:latest .

# Запуск контейнера
docker run -d \
  --name dialer-backend \
  -p 3000:3000 \
  --env-file .env \
  dialer-backend:latest
```

## 🔧 Troubleshooting

### Частые проблемы

1. **Ошибка подключения к PostgreSQL**
   ```bash
   # Проверка доступности БД
   psql -h localhost -U dialer_user -d dialer_db
   ```

2. **Ошибка подключения к FreeSWITCH**
   ```bash
   # Проверка ESL порта
   telnet localhost 8021
   ```

3. **Проблемы с JWT токенами**
   - Проверьте `JWT_SECRET` в .env
   - Убедитесь в правильности времени сервера

4. **Ошибки импорта модулей**
   ```bash
   # Переустановка зависимостей
   rm -rf node_modules package-lock.json
   npm install
   ```

### Логи ошибок

```bash
# Просмотр логов приложения
tail -f logs/app.log

# Просмотр только ошибок
tail -f logs/error.log

# Docker логи
docker logs -f dialer-backend
```

## 🤝 Разработка

### Структура коммитов

Используйте conventional commits:

```
feat: добавить поддержку AMD в диалере
fix: исправить ошибку валидации контактов
docs: обновить API документацию
test: добавить тесты для auth контроллера
```

### Code Style

- ESLint + Prettier для форматирования
- Комментарии на русском языке
- TypeScript strict mode
- Функциональное программирование

## 📚 Дополнительная документация

- [API Documentation](http://localhost:3000/api-docs) - Swagger UI (в development режиме)
- [FreeSWITCH ESL](https://freeswitch.org/confluence/display/FREESWITCH/Event+Socket+Library) - Документация ESL
- [Битрикс24 REST API](https://dev.1c-bitrix.ru/rest_help/) - Документация Битрикс24 API 