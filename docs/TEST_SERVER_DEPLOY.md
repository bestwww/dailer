# Инструкция для деплоя на тестовый сервер

## 🎯 Проблемы и исправления

### Выявленные проблемы на тестовом сервере:
1. **404 ошибки** - фронтенд обращается к `localhost:3000` вместо тестового сервера
2. **Отсутствовал роут авторизации** - добавлен `/backend/src/routes/auth.ts`  
3. **Бесконечные вызовы API** - удалены лишние `fetchCampaigns()` из methods start/pause/stop

### Внесенные исправления:
- ✅ Добавлена переменная `VITE_API_URL` в `.env.production`
- ✅ Создан роут авторизации `backend/src/routes/auth.ts`
- ✅ Удалены повторные вызовы API в campaigns store
- ✅ Обновлен `docker-compose.yml` для использования переменных окружения
- ✅ Исправлены дублирующиеся `/api/` префиксы в URL-ах

## 🚀 Инструкции для деплоя

### 1. На локальной машине:

```bash
# Добавить изменения в git
git add .
git commit -m "fix: исправлены дублирующиеся /api/ префиксы и настроена архитектура URL"
git push origin main
```

### 2. На тестовом сервере:

```bash
# Остановить контейнеры
cd /path/to/dailer_v1
docker-compose down

# Получить последние изменения
git pull origin main

# Создать .env файл (если его нет)
cp .env.production .env

# Запустить контейнеры
docker-compose up -d --build

# Проверить логи
docker-compose logs -f backend
docker-compose logs -f frontend
```

### 3. Переменные окружения для тестового сервера

В файле `.env` или `.env.production`:

```env
# === ФРОНТЕНД НАСТРОЙКИ ===
VITE_API_URL=http://46.173.16.147:3000
VITE_WS_URL=ws://46.173.16.147:3000

# === Основные настройки ===
NODE_ENV=production
PORT=3000

# Остальные переменные из .env.production...
```

> **⚠️ Важно**: `VITE_API_URL` должен быть БЕЗ `/api` на конце! 
> API сервис автоматически добавляет `/api` к базовому URL.

### 4. Проверка работоспособности

После деплоя проверить:

1. **Фронтенд доступен**: `http://46.173.16.147:5173`
2. **Бэкенд API**: `http://46.173.16.147:3000/api/health` (если есть health check)
3. **Авторизация**: Попробовать войти в систему
4. **API вызовы**: Проверить, что нет 404 ошибок в console браузера
5. **WebSocket**: Убедиться, что WebSocket подключается к правильному серверу

### 5. Отладка (если проблемы остались)

```bash
# Проверить переменные окружения в контейнере фронтенда
docker exec dialer_frontend env | grep VITE

# Проверить логи контейнеров
docker logs dialer_backend
docker logs dialer_frontend

# Проверить доступность API
curl http://46.173.16.147:3000/api/auth/status
```

## 📝 Что было исправлено

### 🏗️ Архитектура URL (главное исправление)

**Проблема**: Дублирующиеся `/api/` в URL-ах
- baseURL: `http://server:3000/api` 
- Методы: `/api/campaigns`
- Результат: `http://server:3000/api/api/campaigns` ❌

**Решение**: Единообразная архитектура
- baseURL: `http://server:3000/api` (формируется автоматически)
- Методы: `/campaigns` (без префикса `/api/`)
- Результат: `http://server:3000/api/campaigns` ✅

### backend/src/routes/auth.ts
- Создан новый файл роутов для авторизации
- Подключает контроллер auth.ts

### frontend/src/stores/campaigns.ts  
- Удалены лишние вызовы `await fetchCampaigns()` из методов:
  - `startCampaign()`
  - `pauseCampaign()` 
  - `stopCampaign()`

### .env.production
- Добавлена переменная `VITE_API_URL=http://46.173.16.147:3000/api`
- Добавлена переменная `VITE_WS_URL=ws://46.173.16.147:3000`

### docker-compose.yml
- Переменные окружения теперь читаются из .env файла
- `VITE_API_URL=${VITE_API_URL:-http://localhost:3000/api}`

## 🔧 Дополнительные настройки

### Если нужно изменить IP тестового сервера:
1. Обновить `VITE_API_URL` и `VITE_WS_URL` в `.env.production`
2. Пересобрать фронтенд: `docker-compose up -d --build frontend`

### Для production деплоя:
1. Использовать HTTPS: `VITE_API_URL=https://yourdomain.com/api`
2. Настроить SSL сертификаты
3. Обновить CORS настройки в backend 