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

---

## 🚀 Быстрое развертывание

### На тестовом сервере выполните:

```bash
# 1. Перейдите в директорию проекта
cd /path/to/dailer

# 2. Запустите автоматическое развертывание
./deploy-to-test-server.sh
```

**Готово!** 🎉 Скрипт автоматически:
- Скачает последние изменения
- Остановит и обновит сервисы
- Применит исправления FreeSWITCH
- Запустит систему с новыми настройками

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

### 3. Остановите сервисы:
```bash
docker compose down
```

### 4. Получите обновления:
```bash
git fetch origin
git pull origin main
```

### 5. Сделайте скрипты исполняемыми:
```bash
chmod +x *.sh
```

### 6. Запустите сервисы:
```bash
docker compose up -d
```

### 7. Проверьте статус (через 30-45 секунд):
```bash
docker compose ps
docker exec dialer_freeswitch fs_cli -x "status"
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

---

**✅ Статус:** Готово к развертыванию  
**📅 Дата создания:** 19 июля 2025  
**👨‍💻 Автор:** AI Assistant (Claude Sonnet 4) 