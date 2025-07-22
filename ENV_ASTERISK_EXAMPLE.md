# 🔧 Переменные окружения для Asterisk

## 📝 **Создайте .env файл:**

```bash
# Создать .env файл в корне проекта
cp ENV_ASTERISK_EXAMPLE.md .env
# Или скопировать содержимое ниже
```

## ⚙️ **Содержимое .env файла:**

```bash
# ===== VoIP PROVIDER =====
VOIP_PROVIDER=asterisk

# ===== SIP TRUNK SETTINGS =====
# Ваш SIP провайдер (уже настроен)
SIP_PROVIDER_HOST=62.141.121.197
SIP_PROVIDER_PORT=5070

# Caller ID (ЗАМЕНИТЕ на ваш номер!)
SIP_CALLER_ID_NUMBER=+7123456789

# Внешний IP (оставьте auto для автоопределения)
EXTERNAL_IP=auto

# ===== ASTERISK AMI =====
ASTERISK_HOST=asterisk
ASTERISK_PORT=5038
ASTERISK_USERNAME=admin
ASTERISK_PASSWORD=admin

# ===== FREESWITCH (для возврата) =====
FREESWITCH_HOST=freeswitch
FREESWITCH_PORT=8021
FREESWITCH_PASSWORD=ClueCon

# ===== DATABASE =====
DATABASE_URL=postgresql://dialer_user:secure_password_123@postgres:5432/dialer_db
REDIS_URL=redis://:redis_password_123@redis:6379

# ===== APP SETTINGS =====
NODE_ENV=development
PORT=3000
JWT_SECRET=e556e588ee21e16ed4485a2c94149363ec8c85c881801895ecce9d786d41084e445fca510a8cf7d6fe771e65d956e23d1e0b40b6b82029b1920bb034c17a5149

# ===== DIALER SETTINGS =====
MAX_CONCURRENT_CALLS=10
CALLS_PER_MINUTE=30
LOG_LEVEL=info

# ===== MONITORING =====
MONITORING_ENABLED=true
CORS_ORIGIN=http://localhost:5173

# ===== FILE UPLOAD =====
REQUEST_TIMEOUT=120000
BODY_PARSER_LIMIT=50mb
UPLOAD_TIMEOUT=300000
AUDIO_UPLOAD_PATH=/app/audio
AUDIO_MAX_SIZE=52428800
SUPPORTED_AUDIO_FORMATS=mp3,wav,m4a

# ===== FRONTEND =====
VITE_API_URL=http://localhost:3000
VITE_WS_URL=ws://localhost:3000
```

## 🚀 **Быстрый запуск с .env:**

```bash
# 1. Создать .env файл с настройками выше
echo "VOIP_PROVIDER=asterisk" > .env
echo "SIP_CALLER_ID_NUMBER=+7ВАШТЕЛЕФОН" >> .env

# 2. Запустить с переменными из .env
docker compose --profile asterisk up -d

# 3. Проверить
cd backend && npm run dev -- --script test-asterisk
```

## 🔄 **Переключение провайдеров:**

### **На Asterisk:**
```bash
# В .env файле:
VOIP_PROVIDER=asterisk

# Запуск:
docker compose --profile asterisk up -d
```

### **Обратно на FreeSWITCH:**
```bash
# В .env файле:
VOIP_PROVIDER=freeswitch

# Запуск:
docker compose up -d
```

## ⚠️ **Важные настройки:**

1. **SIP_CALLER_ID_NUMBER** - замените на ваш реальный номер
2. **EXTERNAL_IP** - укажите внешний IP если за NAT
3. **LOG_LEVEL=debug** - для подробных логов при отладке
4. Остальные настройки можно оставить по умолчанию

---
**💡 После создания .env файла перезапустите контейнеры!** 