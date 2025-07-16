# 🚨 ЭКСТРЕННОЕ ИСПРАВЛЕНИЕ: Права доступа к аудиофайлам

## ❌ **ВЫЯВЛЕННАЯ ПРОБЛЕМА**
```json
{"success":false,"error":"EACCES: permission denied, open '/app/audio/campaign-audio-*.mp3'"}
```

**Причина:** Папка `/app/audio` принадлежит `root`, а Node.js запущен под `nodeuser`

## ⚡ **БЫСТРОЕ РЕШЕНИЕ (2 минуты)**

### 1. На тестовом сервере выполните:
```bash
# Обновить код
git pull origin main

# Исправить права доступа
./fix-audio-permissions.sh
```

### 2. Если скрипт недоступен, выполните вручную:
```bash
# Исправить права доступа к папке
docker exec dialer_backend chown -R nodeuser:nodejs /app/audio
docker exec dialer_backend chmod -R 755 /app/audio

# Проверить исправление
docker exec dialer_backend ls -la /app/audio
```

### 3. Тест загрузки:
```bash
# Создать тестовый файл
echo "test audio" > test.mp3

# Протестировать загрузку
curl -X POST -F "audio=@test.mp3" http://localhost:3000/api/campaigns/1/audio
```

## ✅ **ОЖИДАЕМЫЙ РЕЗУЛЬТАТ**

**Вместо:**
```json
{"success":false,"error":"EACCES: permission denied"}
```

**Должно быть:**
```json
{"success":true,"data":{...},"message":"Аудио файл загружен успешно"}
```

## 🔧 **ДОЛГОСРОЧНОЕ РЕШЕНИЕ**

Для предотвращения проблемы в будущем:

```bash
# Пересобрать контейнеры с исправленным Dockerfile
docker-compose down
docker-compose up -d --build
```

## 📊 **ПРОВЕРКА РЕШЕНИЯ**

После исправления:

### В логах backend:
```
✅ Uploaded audio for campaign 1: filename.mp3
```

### В браузере:
```
🎵 Начинаем загрузку аудиофайла для кампании: 1
📈 Прогресс загрузки: 100%
✅ Аудиофайл "filename.mp3" успешно загружен
```

## 🆘 **ЕСЛИ НЕ РАБОТАЕТ**

### Дополнительные команды:
```bash
# Проверить пользователя в контейнере
docker exec dialer_backend whoami
docker exec dialer_backend id

# Создать папку заново
docker exec dialer_backend rm -rf /app/audio
docker exec dialer_backend mkdir -p /app/audio
docker exec dialer_backend chown nodeuser:nodejs /app/audio
docker exec dialer_backend chmod 755 /app/audio

# Перезапустить backend
docker-compose restart backend
```

### Проверить логи:
```bash
docker logs -f dialer_backend | grep -i audio
```

---

## 🎯 **ИТОГ**

✅ **Проблема:** Права доступа к папке `/app/audio`  
✅ **Решение:** Изменить владельца на `nodeuser:nodejs`  
✅ **Время решения:** 2 минуты  
✅ **Результат:** Аудиофайлы загружаются успешно  

**Запустите `./fix-audio-permissions.sh` и проблема будет решена!** 