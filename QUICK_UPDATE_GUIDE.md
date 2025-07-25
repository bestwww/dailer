# ⚡ Быстрое обновление FreeSWITCH на тестовом сервере

## 🎯 ПРОБЛЕМА РЕШЕНА!
Теперь есть **умные скрипты** которые НЕ пересобирают Docker образы из исходников.

---

## 🚀 Быстрое обновление (1-2 минуты)

### На тестовом сервере выполните:

```bash
# 1. Перейдите в директорию проекта
cd /path/to/dailer

# 2. Получите обновления
git pull origin main

# 3. Сначала ДИАГНОСТИКА (опционально)
./check-freeswitch-setup.sh

# 4. Быстрое обновление БЕЗ пересборки
./update-config-only.sh
```

**🎉 Готово!** Всего 1-2 минуты вместо 15-30 минут сборки.

---

## 🔍 Что делает скрипт update-config-only.sh

✅ **Автоматически находит** контейнер FreeSWITCH (любое имя)  
✅ **Останавливает только FreeSWITCH** (остальные сервисы работают)  
✅ **Обновляет конфигурацию** с новым Caller ID: `79058615815`  
✅ **Запускает БЕЗ build** команд  
✅ **Тестирует результат** автоматически  

---

## 🛠️ Альтернативные варианты

### Если возникают проблемы:

#### 🔍 **Диагностика:**
```bash
./check-freeswitch-setup.sh
```

#### 🐳 **Использование готового образа:**
```bash
# Скачать готовый образ
docker pull signalwire/freeswitch:latest

# Запустить с альтернативной конфигурацией
docker compose -f docker-compose.no-build.yml up -d freeswitch
```

#### 🔧 **Ручное обновление:**
```bash
# Найти контейнер FreeSWITCH
docker ps -a | grep freeswitch

# Остановить, обновить код, запустить
docker stop КОНТЕЙНЕР_НАЗВАНИЕ
git pull origin main
docker start КОНТЕЙНЕР_НАЗВАНИЕ
```

---

## 📊 Ожидаемый результат

После выполнения `./update-config-only.sh`:

- ✅ **Caller ID обновлен:** `79058615815`
- ✅ **Исправлена ошибка PROTOCOL_ERROR**
- ✅ **Обновлены команды:** `docker compose`
- ✅ **Правильная маршрутизация:** через `sofia/gateway/sip_trunk`
- ✅ **Время выполнения:** 1-2 минуты
- ✅ **Остальные сервисы:** продолжают работать

---

## 🔧 Проверка результата

```bash
# Статус FreeSWITCH
docker exec КОНТЕЙНЕР_НАЗВАНИЕ fs_cli -x "status"

# Проверка Caller ID
grep "79058615815" freeswitch/conf/dialplan/default.xml

# Тестовый звонок
docker exec КОНТЕЙНЕР_НАЗВАНИЕ fs_cli -x "originate sofia/gateway/sip_trunk/79206054020 &echo"

# Логи
docker logs -f КОНТЕЙНЕР_НАЗВАНИЕ
```

---

## ⚠️ Важные замечания

1. **НЕ используйте** `./deploy-to-test-server.sh` на работающих системах (долго!)
2. **Используйте** `./update-config-only.sh` для быстрого обновления
3. **Проверьте** что Caller ID `79058615815` разрешен у провайдера
4. **Мониторьте** логи первые 10-15 минут после обновления

---

## 🆘 Если что-то пошло не так

```bash
# Восстановить старую конфигурацию
git checkout HEAD~1 -- freeswitch/conf/

# Перезапустить FreeSWITCH
docker restart КОНТЕЙНЕР_НАЗВАНИЕ

# Применить исправления заново
./fix-freeswitch-protocol-error.sh
```

---

**✅ Проблема решена!** Теперь обновление FreeSWITCH занимает 1-2 минуты вместо 15-30 минут.

**📞 Caller ID унифицирован:** `79058615815`  
**🔧 PROTOCOL_ERROR исправлен**  
**⚡ БЕЗ пересборки образов** 