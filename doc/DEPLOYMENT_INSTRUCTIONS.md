# 🚀 Инструкции по развертыванию на тестовом сервере

## 📋 Что нового в этом обновлении

### ✅ Исправления:
- **🔧 Устранена ошибка PROTOCOL_ERROR** в FreeSWITCH
- **📞 Унифицирован Caller ID** на `79058615815`
- **🛠️ Исправлена маршрутизация** SIP звонков через gateway
- **🎯 Обновлены настройки** Sofia SIP и диалплана

### 🆕 Новые файлы:
- `fix-freeswitch-protocol-error.sh` - автоматическое исправление ошибок
- `apply-caller-id-change.sh` - применение изменений Caller ID
- `FREESWITCH_PROTOCOL_ERROR_FIX.md` - полная документация решения
- `CALLER_ID_CHANGE_LOG.md` - лог изменений
- `update-config-only.sh` - ⭐ **НОВОЕ**: обновление только конфигурации БЕЗ пересборки

---

## ⚡ Быстрое обновление (РЕКОМЕНДУЕТСЯ для работающих систем)

### ✅ Если FreeSWITCH уже работает на сервере:

```bash
# 1. Перейдите в директорию проекта
cd /path/to/dailer

# 2. Запустите БЫСТРОЕ обновление (БЕЗ пересборки образов)
./update-config-only.sh
```

**🎯 Преимущества:**
- ⚡ **Быстро** - без пересборки Docker образов
- 🛡️ **Безопасно** - не затрагивает работающие сервисы
- 🎯 **Точечно** - обновляет только конфигурацию FreeSWITCH
- ✅ **Проверено** - тестирует результат автоматически

---

## 🚀 Полное развертывание (для новых установок)

### ⚠️ ВНИМАНИЕ: Пересобирает ВСЕ образы (долго!)

```bash
# 1. Перейдите в директорию проекта
cd /path/to/dailer

# 2. Запустите полное развертывание (пересобирает образы)
./deploy-to-test-server.sh
```

**❗ Когда использовать:**
- 🆕 Первая установка на сервере
- 🔄 Обновились Dockerfile или зависимости
- 🔧 Нужна пересборка всех сервисов

---

## 📝 Ручное развертывание (альтернативный способ)

### 1. Подключитесь к тестовому серверу:
```bash
ssh user@ваш-тестовый-сервер
```

### 2. Перейдите в директорию проекта:
```bash
cd /path/to/dailer  # замените на правильный путь
```

### 3. Выберите способ обновления:

#### 🚀 Быстрое обновление (рекомендуется):
```bash
# Получите обновления
git pull origin main

# Остановите только FreeSWITCH
docker compose stop freeswitch

# Запустите FreeSWITCH с новой конфигурацией
docker compose up -d freeswitch
```

#### 🔄 Полное обновление:
```bash
# Остановите все сервисы
docker compose down

# Получите обновления
git pull origin main

# Пересоберите образы (ДОЛГО!)
docker compose build

# Запустите все сервисы
docker compose up -d
```

---

## 🔍 Проверка развертывания

### Проверьте что FreeSWITCH работает:
```bash
# Статус FreeSWITCH
docker exec dialer_freeswitch fs_cli -x "status"

# Статус SIP gateway
docker exec dialer_freeswitch fs_cli -x "sofia status gateway sip_trunk"

# Проверка Caller ID в конфигурации
grep "79058615815" freeswitch/conf/dialplan/default.xml
```

### Тестовый звонок:
```bash
docker exec dialer_freeswitch fs_cli -x "originate sofia/gateway/sip_trunk/79206054020 &echo"
```

### Проверка логов:
```bash
# Все сервисы
docker compose logs -f

# Только FreeSWITCH
docker logs -f dialer_freeswitch

# Только backend
docker logs -f dialer_backend
```

---

## 🌐 Доступ к сервисам

После успешного развертывания будут доступны:

- **Frontend:** `http://ИП_СЕРВЕРА:8080`
- **Backend API:** `http://ИП_СЕРВЕРА:3000`
- **FreeSWITCH Event Socket:** `ИП_СЕРВЕРА:8021`

---

## 🎯 Ожидаемые результаты

### ✅ До исправления:
- ❌ Ошибка `PROTOCOL_ERROR` при звонках
- ❌ Несоответствие Caller ID в конфигурации

### ✅ После исправления:
- ✅ Стабильная работа исходящих звонков
- ✅ Унифицированный Caller ID: `79058615815`
- ✅ Правильная маршрутизация через SIP gateway
- ✅ Отсутствие ошибок PROTOCOL_ERROR

---

## 📊 Сравнение скриптов развертывания

| Скрипт | Время | Пересборка | Риск | Когда использовать |
|--------|-------|------------|------|-------------------|
| `update-config-only.sh` | ⚡ 1-2 мин | ❌ НЕТ | 🟢 Низкий | ✅ Работающие системы |
| `deploy-to-test-server.sh` | ⏳ 15-30 мин | ✅ ДА | 🟡 Средний | 🆕 Новые установки |

---

## 🔧 Устранение проблем

### Если FreeSWITCH не запускается:
```bash
# Проверить логи
docker logs dialer_freeswitch

# Перезапустить контейнер
docker compose restart freeswitch

# Применить исправления вручную
./fix-freeswitch-protocol-error.sh
```

### Если SIP gateway не работает:
```bash
# Проверить статус
docker exec dialer_freeswitch fs_cli -x "sofia status"

# Перезагрузить Sofia
docker exec dialer_freeswitch fs_cli -x "sofia profile external restart"
```

### Если возникают ошибки PROTOCOL_ERROR:
```bash
# Применить исправления
./apply-caller-id-change.sh

# Включить SIP трассировку для диагностики
docker exec dialer_freeswitch fs_cli -x "sofia profile external siptrace on"
```

### Если Docker пытается собрать из исходников:
```bash
# ❌ НЕ используйте deploy-to-test-server.sh если система уже работает
# ✅ Используйте вместо этого:
./update-config-only.sh
```

---

## 📞 Контакты и поддержка

- **Документация:** `FREESWITCH_PROTOCOL_ERROR_FIX.md`
- **Лог изменений:** `CALLER_ID_CHANGE_LOG.md`
- **Скрипты диагностики:** `fix-freeswitch-protocol-error.sh`

---

## ⚠️ Важные заметки

1. **Сетевые требования:** Убедитесь что сервер может достичь `62.141.121.197:5070`
2. **Caller ID:** Убедитесь что `79058615815` разрешен у SIP-провайдера
3. **Мониторинг:** Регулярно проверяйте логи первые 24 часа после развертывания
4. **Резервное копирование:** Все изменения сохранены в git
5. **Выбор скрипта:** Для работающих систем используйте `update-config-only.sh`

---

**✅ Статус:** Готово к развертыванию  
**📅 Дата обновления:** 19 июля 2025  
**👨‍💻 Автор:** AI Assistant (Claude Sonnet 4) 