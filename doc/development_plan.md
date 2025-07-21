# План разработки системы автодозвона

## 🎯 Техническое задание

### Цель проекта
Создание системы автоматического обзвона клиентов с функциями:
- Автоматический обзвон по базе контактов
- Проигрывание приветственных аудиороликов
- Запись ответов клиентов (DTMF сигналы: 1 - интересно, 2 - не интересно)
- Определение и отсечение автоответчиков (AMD)
- Создание лидов в Битрикс24 для заинтересованных клиентов
- Веб-интерфейс для управления кампаниями и просмотра статистики

## 🛠 Технологический стек

### Backend
- **FreeSWITCH** - телефонная платформа
- **Node.js + TypeScript** - API сервер
- **Express.js** - веб-фреймворк
- **ESL (Event Socket Library)** - интеграция с FreeSWITCH
- **PostgreSQL** - основная база данных
- **Redis** - кеширование и очереди задач
- **Bull** - управление очередями
- **Socket.io** - real-time обновления

### Frontend
- **Vue.js 3** + **TypeScript**
- **Vuetify** - UI компоненты
- **Pinia** - управление состоянием
- **Vue Router** - маршрутизация
- **Axios** - HTTP клиент

### Инфраструктура
- **Docker** + **Docker Compose**
- **Nginx** - reverse proxy
- **PM2** - процесс-менеджер для Node.js
- **GitHub Actions** - CI/CD

### Интеграции
- **Битрикс24 REST API** - создание лидов
- **SIP провайдеры** - исходящие звонки

## 🏗 Архитектура системы

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Vue.js Web    │    │  Node.js + TS   │    │   FreeSWITCH    │
│   Dashboard     │◄──►│   API Server    │◄──►│   PBX System    │
│                 │    │                 │    │                 │
│ - Кампании      │    │ - REST API      │    │ - SIP Gateway   │
│ - Статистика    │    │ - WebSocket     │    │ - Call Routing  │
│ - Настройки     │    │ - ESL Client    │    │ - AMD Detection │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │                        │
                              ▼                        ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │   PostgreSQL    │    │  Audio Files    │
                       │                 │    │                 │
                       │ - Контакты      │    │ - Приветствия   │
                       │ - Кампании      │    │ - Промпты       │
                       │ - Статистика    │    │ - Записи        │
                       │ - Логи          │    └─────────────────┘
                       └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │     Redis       │
                       │                 │
                       │ - Очереди       │
                       │ - Кеш           │
                       │ - Сессии        │
                       └─────────────────┘
```

## 📋 Детальный план разработки

### Этап 1: Инфраструктура и базовая настройка (Неделя 1-2)

#### 1.1 Настройка окружения разработки
- [x] Создание Docker Compose конфигурации
- [x] Настройка PostgreSQL контейнера
- [x] Настройка Redis контейнера
- [x] Создание базовой структуры проекта

#### 1.2 Установка и настройка FreeSWITCH
- [x] Создание Dockerfile для FreeSWITCH
- [x] Базовая конфигурация FreeSWITCH
- [x] Настройка SIP профилей
- [x] Конфигурация dialplan
- [x] Настройка ESL (Event Socket Library)

#### 1.3 Проектирование базы данных
```sql
-- Основные таблицы
CREATE TABLE campaigns (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    audio_file_path VARCHAR(500),
    status VARCHAR(50) DEFAULT 'draft', -- draft, active, paused, completed
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE contacts (
    id SERIAL PRIMARY KEY,
    phone VARCHAR(20) NOT NULL,
    name VARCHAR(255),
    campaign_id INTEGER REFERENCES campaigns(id),
    status VARCHAR(50) DEFAULT 'pending', -- pending, called, completed, failed
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE call_results (
    id SERIAL PRIMARY KEY,
    contact_id INTEGER REFERENCES contacts(id),
    campaign_id INTEGER REFERENCES campaigns(id),
    call_status VARCHAR(50), -- answered, busy, no_answer, failed
    dtmf_response VARCHAR(10),
    call_duration INTEGER,
    is_answering_machine BOOLEAN DEFAULT FALSE,
    bitrix_lead_id INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);
```

#### Результат этапа:
- ✅ Работающее окружение разработки
- ✅ Настроенный FreeSWITCH с базовой конфигурацией
- ✅ Структура базы данных

---

### Этап 2: Backend Core (Неделя 3-4)

#### 2.1 Настройка Node.js + TypeScript проекта
- [x] Инициализация npm проекта
- [x] Настройка TypeScript конфигурации
- [x] Установка зависимостей (Express, ESL, PostgreSQL клиент)
- [x] Настройка ESLint + Prettier
- [x] Создание базовой структуры проекта

```typescript
// Структура проекта backend
src/
├── controllers/        // Контроллеры API
├── services/          // Бизнес-логика
├── models/            // Модели данных
├── config/            // Конфигурация
├── middleware/        // Middleware функции
├── utils/             // Утилиты
├── types/             // TypeScript типы
└── app.ts             // Точка входа
```

#### 2.2 Интеграция с FreeSWITCH через ESL
- [x] Создание ESL клиента
- [x] Обработка событий FreeSWITCH
- [x] Управление исходящими звонками
- [x] Обработка DTMF сигналов

```typescript
// Пример ESL клиента
import { Connection } from 'esl';

class FreeSwitchClient {
    private connection: Connection;

    async connect(): Promise<void> {
        this.connection = new Connection('127.0.0.1', 8021, 'ClueCon', () => {
            console.log('Connected to FreeSWITCH');
        });
    }

    async makeCall(phoneNumber: string, campaignId: number): Promise<void> {
        const command = `originate sofia/gateway/provider/${phoneNumber} &conference(${campaignId})`;
        await this.connection.api(command);
    }
}
```

#### 2.3 Создание API endpoints
- [x] CRUD операции для кампаний
- [x] Управление контактами
- [x] Загрузка аудиофайлов
- [x] Получение статистики

#### Результат этапа:
- ✅ Рабочий API сервер на TypeScript
- ✅ Интеграция с FreeSWITCH
- ✅ Базовые CRUD операции

---

### Этап 3: Диалер Engine (Неделя 5-6)

#### 3.1 Система управления кампаниями
- [x] Создание и управление кампаниями
- [x] Загрузка списков контактов (CSV, Excel)
- [x] Валидация номеров телефонов
- [x] Планировщик звонков

#### 3.2 Call Manager
- [x] Очередь исходящих звонков
- [x] Управление одновременными звонками
- [x] Retry логика для неуспешных звонков
- [x] Контроль скорости обзвона (calls per minute)

```typescript
// Пример Call Manager
class CallManager {
    private activeCallsCount = 0;
    private maxConcurrentCalls = 10;

    async processCallQueue(): Promise<void> {
        const pendingContacts = await this.getNextContacts();
        
        for (const contact of pendingContacts) {
            if (this.activeCallsCount < this.maxConcurrentCalls) {
                await this.initiateCall(contact);
                this.activeCallsCount++;
            }
        }
    }

    private async initiateCall(contact: Contact): Promise<void> {
        try {
            await this.freeSwitchClient.makeCall(contact.phone, contact.campaignId);
            await this.updateContactStatus(contact.id, 'calling');
        } catch (error) {
            await this.handleCallError(contact, error);
        }
    }
}
```

#### 3.3 AMD (Answering Machine Detection)
- [x] Настройка AMD в FreeSWITCH
- [x] Обработка результатов AMD
- [x] Логика действий при обнаружении автоответчика

#### Результат этапа:
- ✅ Работающий диалер с управлением очередями
- ✅ AMD система
- ✅ Контроль нагрузки и скорости обзвона

---

### Этап 4: Frontend разработка (Неделя 7-9)

#### 4.1 Настройка Vue.js проекта
- [x] Создание Vue 3 + TypeScript проекта
- [x] Настройка Element Plus для UI компонентов
- [x] Конфигурация Vue Router
- [x] Настройка Pinia для state management

#### 4.2 Основные компоненты интерфейса
- [x] Дашборд с общей статистикой
- [x] Управление кампаниями (CRUD)
- [x] Загрузка и управление аудиофайлами
- [x] Импорт контактов из файлов
- [x] Real-time мониторинг звонков

```vue
<!-- Пример компонента кампании -->
<template>
  <v-container>
    <v-card>
      <v-card-title>
        <span class="text-h6">Управление кампаниями</span>
        <v-spacer></v-spacer>
        <v-btn color="primary" @click="createCampaign">
          Создать кампанию
        </v-btn>
      </v-card-title>
      
      <v-data-table
        :headers="headers"
        :items="campaigns"
        :loading="loading"
        class="elevation-1"
      >
        <template v-slot:item.actions="{ item }">
          <v-icon small @click="editCampaign(item)">mdi-pencil</v-icon>
          <v-icon small @click="startCampaign(item)">mdi-play</v-icon>
        </template>
      </v-data-table>
    </v-card>
  </v-container>
</template>
```

#### 4.3 Real-time обновления
- [x] WebSocket подключение для live статистики
- [x] Уведомления о статусе звонков
- [x] Live обновление дашборда

#### Результат этапа:
- ✅ Полнофункциональный веб-интерфейс
- ✅ Real-time мониторинг
- ✅ Удобное управление кампаниями

---

### Этап 5: Интеграция с Битрикс24 (Неделя 10)

#### 5.1 Настройка Битрикс24 API
- [x] Создание приложения в Битрикс24
- [x] Настройка OAuth авторизации
- [x] Создание сервиса для работы с API

```typescript
// Пример интеграции с Битрикс24
class BitrixService {
    private accessToken: string;
    private baseUrl: string;

    async createLead(contactData: {
        name: string;
        phone: string;
        campaignName: string;
        dtmfResponse: string;
    }): Promise<number> {
        const leadData = {
            fields: {
                TITLE: `Лид из кампании: ${contactData.campaignName}`,
                NAME: contactData.name,
                PHONE: [{ VALUE: contactData.phone, VALUE_TYPE: 'WORK' }],
                SOURCE_ID: 'CALL',
                COMMENTS: `DTMF ответ: ${contactData.dtmfResponse}`
            }
        };

        const response = await axios.post(
            `${this.baseUrl}/crm.lead.add.json`,
            leadData,
            { headers: { 'Authorization': `Bearer ${this.accessToken}` }}
        );

        return response.data.result;
    }
}
```

#### 5.2 Автоматическое создание лидов
- [x] Условия для создания лидов (DTMF = 1)
- [x] Маппинг данных из системы в Битрикс24
- [x] Обработка ошибок интеграции
- [x] Логирование операций с CRM

#### Результат этапа:
- ✅ Рабочая интеграция с Битрикс24
- ✅ Автоматическое создание лидов

---

### Этап 6: Расширенная функциональность (Неделя 11-12)

#### 6.1 Система отчетов и аналитики
- [x] Детальная статистика по кампаниям
- [x] Графики и диаграммы (Chart.js)
- [x] Экспорт отчетов в CSV
- [x] Real-time статистика
- [x] Компоненты для визуализации данных
- [x] API endpoints для статистики
- [x] Frontend интерфейс с графиками

#### 6.2 Дополнительные функции
- [x] **Планировщик кампаний (cron jobs)** - ЗАВЕРШЕН ✅
- [x] **Черный список номеров** - ЗАВЕРШЕН ✅
- [ ] Webhook уведомления
- [ ] Настройки времени обзвона
- [ ] Поддержка часовых поясов

#### 6.3 Система логирования и мониторинга
- [ ] Структурированное логирование (Winston)
- [ ] Мониторинг производительности
- [ ] Алерты при ошибках
- [ ] Метрики системы

#### Результат этапа:
- ✅ Полнофункциональная система аналитики с графиками
- ✅ Real-time мониторинг и статистика
- ✅ Экспорт данных в различных форматах
- ⏳ Расширенное логирование и мониторинг (в процессе)

---

### Этап 7: Тестирование и оптимизация (Неделя 13-14)

#### 7.1 Автоматизированное тестирование
- [ ] Unit тесты для backend (Jest)
- [ ] Integration тесты для API
- [ ] E2E тесты для frontend (Cypress)
- [ ] Тестирование интеграций

#### 7.2 Оптимизация производительности
- [ ] Профилирование Node.js приложения
- [ ] Оптимизация SQL запросов
- [ ] Кеширование частых операций
- [ ] Оптимизация FreeSWITCH конфигурации

#### 7.3 Нагрузочное тестирование
- [ ] Тестирование под нагрузкой (Artillery.js)
- [ ] Проверка limits и bottlenecks
- [ ] Масштабирование компонентов

#### Результат этапа:
- Протестированная и оптимизированная система
- Документация по производительности

---

### Этап 8: Развертывание и документация (Неделя 15)

#### 8.1 Production развертывание
- [ ] Создание production Docker образов
- [ ] Настройка CI/CD pipeline
- [ ] Конфигурация Nginx
- [ ] SSL сертификаты
- [ ] Backup стратегия

#### 8.2 Документация
- [ ] API документация (Swagger)
- [ ] Руководство пользователя
- [ ] Инструкция по развертыванию
- [ ] Руководство администратора

#### 8.3 Security
- [ ] Аудит безопасности
- [ ] Rate limiting
- [ ] Input validation
- [ ] HTTPS enforcement

## 🔧 Конфигурация окружения

### Docker Compose файл
```yaml
version: '3.8'
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: dialer_db
      POSTGRES_USER: dialer_user
      POSTGRES_PASSWORD: secure_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  freeswitch:
    build: ./docker/freeswitch
    ports:
      - "5060:5060/udp"
      - "8021:8021"
    volumes:
      - ./freeswitch/conf:/usr/local/freeswitch/conf
      - ./audio:/usr/local/freeswitch/sounds/custom

  backend:
    build: ./backend
    depends_on:
      - postgres
      - redis
      - freeswitch
    environment:
      DATABASE_URL: postgresql://dialer_user:secure_password@postgres:5432/dialer_db
      REDIS_URL: redis://redis:6379
      FREESWITCH_HOST: freeswitch
    ports:
      - "3000:3000"

  frontend:
    build: ./frontend
    ports:
      - "8080:80"
    depends_on:
      - backend

volumes:
  postgres_data:
```

## 📊 Ключевые метрики проекта

- **Общее время разработки**: 15 недель
- **Команда**: 1-2 разработчика
- **Основные технологии**: 6 (FreeSWITCH, Node.js, TypeScript, Vue.js, PostgreSQL, Redis)
- **Интеграции**: 1 (Битрикс24)
- **Планируемая производительность**: до 100 одновременных звонков

## 🚀 Текущий статус

### ✅ Выполнено (12+ недель из 15 - 85% готовности):
- **Этап 1**: Инфраструктура и базовая настройка - ЗАВЕРШЕН ✅
- **Этап 2**: Backend Core - ЗАВЕРШЕН ✅
- **Этап 3**: Диалер Engine - ЗАВЕРШЕН ✅
- **Этап 4**: Frontend разработка - ЗАВЕРШЕН ✅
- **Этап 5**: Интеграция с Битрикс24 - ЗАВЕРШЕН ✅
- **Этап 6.1**: Система отчетов и аналитики - ЗАВЕРШЕН ✅
- **Этап 6.2.1**: Планировщик кампаний - ЗАВЕРШЕН ✅
- **Этап 6.2.2**: Черный список номеров - ЗАВЕРШЕН ✅
- **Этап 6.2.3**: Webhook уведомления - ЗАВЕРШЕН ✅
- **Этап 6.2.4**: Настройки времени обзвона и часовые пояса - ЗАВЕРШЕН ✅
- **Этап 6.3**: Система логирования и мониторинга - ЗАВЕРШЕН ✅

### ✅ Выполнено на данном этапе:
- **Этап 6.2.4**: Настройки времени обзвона и часовые пояса - ЗАВЕРШЕН ✅
- **Этап 6.3**: Система логирования и мониторинга - ЗАВЕРШЕН ✅

### 🔄 В процессе:
1. **Этап 7**: Тестирование и оптимизация

### 🎯 Следующие шаги:
1. **Этап 7**: Тестирование и оптимизация
2. **Этап 8**: Развертывание и документация

### 🎯 Основные достижения:
- ✅ Полнофункциональная система автодозвона
- ✅ Веб-интерфейс для управления кампаниями
- ✅ Автоматическая интеграция с Битрикс24
- ✅ Real-time мониторинг звонков
- ✅ AMD (определение автоответчиков)
- ✅ DTMF обработка пользовательского ввода
- ✅ **Детальная система аналитики с графиками и отчетами**
- ✅ **Экспорт статистики в CSV формате**
- ✅ **Real-time дашборд с живыми метриками**
- ✅ **Планировщик кампаний с поддержкой cron jobs**
- ✅ **Черный список номеров с автоматической блокировкой**
- ✅ **Webhook уведомления для внешних систем**

### 🔧 Реализованные компоненты аналитики:
- **Backend API**: 
  - `/api/stats/overview` - общая статистика
  - `/api/stats/campaign/:id` - детальная статистика по кампании
  - `/api/stats/compare` - сравнение кампаний
  - `/api/stats/export/campaign/:id` - экспорт в CSV
  - `/api/stats/realtime` - real-time метрики

- **Frontend компоненты**:
  - `BaseChart.vue` - базовый компонент для Chart.js
  - `CallsStatsChart.vue` - круговые диаграммы статистики
  - `TimeseriesChart.vue` - временные графики
  - `StatsCards.vue` - метрики в виде карточек
  - `StatisticsView.vue` - главная страница аналитики

- **Функции аналитики**:
  - Статистика звонков (общая и по кампаниям)
  - Временная динамика звонков
  - Анализ по дням недели и часам
  - Показатели конверсии и эффективности
  - Данные по автоответчикам и DTMF ответам
  - Статистика созданных лидов в Битрикс24

### 🔧 Реализованные компоненты планировщика:
- **Backend API**:
  - `POST /api/campaigns/:id/schedule` - планирование кампании
  - `DELETE /api/campaigns/:id/schedule` - отмена планирования
  - `GET /api/campaigns/scheduler/status` - статус планировщика
  - `GET /api/campaigns/scheduler/campaigns` - запланированные кампании
  - `POST /api/campaigns/scheduler/validate-cron` - валидация cron выражений

- **Сервис планировщика**:
  - `SchedulerService` - класс с поддержкой cron jobs
  - Планирование запуска/остановки кампаний
  - Повторяющиеся задачи с cron выражениями
  - Валидация cron выражений
  - Graceful shutdown при завершении работы

- **База данных**:
  - Таблица `campaigns` расширена полями планировщика
  - Таблица `scheduler_logs` для логирования
  - Индексы для оптимизации запросов
  - Триггеры для валидации данных

- **Функции планировщика**:
  - Одноразовые задачи (запуск/остановка в конкретное время)
  - Повторяющиеся задачи (по cron выражению)
  - Комбинированные задачи
  - Поддержка часовых поясов
  - Интеграция с диалер-сервисом

### 🔧 Реализованные компоненты черного списка:
- **Backend API**:
  - `GET /api/blacklist` - список записей с пагинацией и фильтрацией
  - `POST /api/blacklist` - добавление номера в черный список
  - `POST /api/blacklist/bulk` - массовое добавление номеров
  - `GET /api/blacklist/check/:phone` - проверка номера
  - `DELETE /api/blacklist/:id` - удаление записи
  - `GET /api/blacklist/stats` - статистика черного списка
  - `GET /api/blacklist/export/csv` - экспорт в CSV
  - `POST /api/blacklist/import/csv` - импорт из CSV

- **Модель данных**:
  - `BlacklistModel` - класс с полным CRUD функционалом
  - Автоматическая нормализация номеров телефонов
  - Поддержка временных блокировок с датой истечения
  - Массовые операции и импорт/экспорт
  - Система аудита всех изменений

- **База данных**:
  - Таблица `blacklist` с 10 оптимизированными индексами
  - Enum `blacklist_reason_type` с 9 типами причин
  - Автоматические триггеры нормализации номеров
  - Представления для статистики и активных записей
  - Таблица аудита для отслеживания изменений

- **Интеграция с диалером**:
  - Автоматическая проверка каждого номера перед звонком
  - Блокировка звонков на номера из черного списка
  - События `call:blocked` для real-time уведомлений
  - Увеличение счетчика попыток для статистики
  - Создание записей результатов с причиной блокировки

### 🔧 Реализованные компоненты webhook уведомлений:
- **Backend API**:
  - `GET /api/webhook/endpoints` - список webhook endpoints
  - `POST /api/webhook/endpoints` - создание нового endpoint
  - `PUT /api/webhook/endpoints/:id` - обновление endpoint
  - `DELETE /api/webhook/endpoints/:id` - удаление endpoint
  - `POST /api/webhook/endpoints/:id/test` - тестирование endpoint
  - `GET /api/webhook/stats` - статистика webhook доставок
  - `GET /api/webhook/event-types` - доступные типы событий

- **Webhook сервис**:
  - `WebhookService` - класс с полным функционалом отправки
  - Автоматическая retry логика с экспоненциальной задержкой
  - HMAC подписи для безопасности
  - Параллельная обработка множественных endpoints
  - Детальное логирование всех доставок
  - Graceful shutdown и управление очередями

- **База данных**:
  - Таблица `webhook_endpoints` с 5 оптимизированными индексами
  - Таблица `webhook_deliveries` с 10 индексами для аналитики
  - Представления для статистики endpoints и событий
  - Автоматические триггеры для обновления timestamps
  - Constraints для валидации данных

- **Интеграция с системой**:
  - Автоматические уведомления о всех событиях звонков
  - События кампаний (запуск, остановка, завершение)
  - Интеграция с диалер-сервисом для real-time событий
  - Поддержка 14 типов событий системы
  - Фильтрация по кампаниям и типам событий

- **Функции webhook**:
  - HTTP методы POST, PUT, PATCH
  - Настраиваемые заголовки и таймауты
  - Фильтрация по IP адресам
- Поддержка временных и постоянных endpoints
- Детальная статистика успешности доставок
- Экспорт логов доставки для анализа

### 🔧 Реализованные компоненты настроек времени обзвона:
- **TimezoneService**:
  - Поддержка 40+ часовых поясов мира
  - Автоматический учет летнего времени (DST)
  - Конвертация времени между часовыми поясами
  - Валидация настроек времени работы
  - Получение следующего рабочего времени для кампаний и контактов

- **Backend API**:
  - `GET /api/time-settings/timezones` - список поддерживаемых часовых поясов
  - `GET /api/time-settings/timezone/:timezone` - информация о часовом поясе
  - `PUT /api/time-settings/campaign/:id` - обновление настроек времени кампании
  - `GET /api/time-settings/campaign/:id/working-time` - проверка рабочего времени
  - `PUT /api/time-settings/contacts/timezone` - массовое обновление часовых поясов контактов
  - `GET /api/time-settings/stats` - статистика по часовым поясам
  - `POST /api/time-settings/validate` - валидация настроек времени

- **Обновленный DialerService**:
  - Автоматическая проверка рабочего времени с учетом часовых поясов контактов
  - Фильтрация контактов по рабочему времени перед звонками
  - Расчет времени следующего звонка с учетом рабочих часов
  - Поддержка ночных рабочих смен (переход через полночь)

- **База данных**:
  - Поля часовых поясов уже существуют в таблицах campaigns и contacts
  - Автоматическая валидация настроек времени работы
  - Индексы для оптимизации запросов по времени

- **Функции настроек времени**:
  - Настройка рабочих часов (начало и окончание работы)
  - Выбор рабочих дней недели (понедельник-воскресенье)
  - Индивидуальные часовые пояса для каждого контакта
  - Автоматический пропуск звонков в нерабочее время
  - Планирование следующих звонков на рабочее время
- Статистика по эффективности в разных часовых поясах

### 🔧 Реализованные компоненты системы мониторинга:
- **MonitoringService**:
  - Счетчики (Counters): HTTP запросы, звонки, лиды, webhook доставки, блокировки
  - Gauge метрики: активные звонки/кампании, использование памяти/CPU, подключения БД
  - Таймеры: время выполнения HTTP/SQL запросов, длительность звонков, доставка webhook
  - История метрик (до 10,000 записей) с автоматической ротацией
  - Health checks для компонентов системы

- **AlertingService**:
  - 8 правил алертов по умолчанию (память, ошибки, производительность, звонки)
  - Система каналов уведомлений (console, email, slack, webhook, telegram)
  - Подтверждение и разрешение алертов
  - Cooldown между повторными алертами
  - Автоматическая очистка старых алертов

- **Backend API endpoints**:
  - `GET /api/monitoring/metrics` - системные метрики
  - `GET /api/monitoring/metrics/:names` - конкретные метрики
  - `GET /api/monitoring/metrics/history` - история метрик
  - `GET /api/monitoring/metrics/prometheus` - экспорт в формате Prometheus
  - `GET /api/monitoring/health` - health checks
  - `GET /api/monitoring/health/simple` - простой health check для LB
  - `GET /api/monitoring/alerts` - управление алертами
  - `GET /api/monitoring/performance` - статистика производительности
  - `GET /api/monitoring/status` - статус системы мониторинга

- **HTTP Middleware для мониторинга**:
  - Автоматическое отслеживание всех HTTP запросов
  - Correlation ID для трассировки запросов
  - Мониторинг производительности и размера запросов/ответов
  - Детекция медленных запросов (>3 сек) и ошибок
  - Мониторинг безопасности (подозрительные паттерны)
  - Отслеживание rate limiting

- **Интеграция с существующими сервисами**:
  - DialerService: health checks для диалера и FreeSWITCH, отслеживание звонков
  - Автоматическое отслеживание создания лидов в Bitrix24
  - Мониторинг блокировок по черному списку
  - Отслеживание доставки webhook уведомлений

- **Функции мониторинга**:
  - Real-time метрики системы (uptime, память, CPU, активные звонки)
  - Автоматический сбор метрик каждые 30 секунд
  - Экспорт в формат Prometheus для интеграции с Grafana
  - Структурированное логирование с correlation ID
  - Детальная статистика производительности (min, max, avg, p95, p99)
  - Алерты для критических событий с настраиваемыми правилами

---

*Этот план может корректироваться в процессе разработки в зависимости от технических требований и обратной связи.* 