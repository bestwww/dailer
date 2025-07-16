# 🚨 КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ: Права доступа на хост-системе

## Проблема
❌ **EACCES: permission denied** - папка `/app/audio` принадлежит `root:988`, а процесс Node.js работает под `nodeuser`

## 🚀 БЫСТРОЕ РЕШЕНИЕ (2 минуты)

### На тестовом сервере выполните:

```bash
# 1. Загрузить новый скрипт
./host-permissions-fix.sh
```

**ИЛИ если скрипт не работает, выполните вручную:**

```bash
# 1. Остановить контейнеры
docker-compose down

# 2. Исправить права на хост-системе
sudo chown -R 1001:1001 ./audio/
sudo chmod -R 755 ./audio/

# 3. Запустить контейнеры
docker-compose up -d --build backend

# 4. Проверить результат
docker exec dialer_backend ls -la /app/audio/
docker exec dialer_backend touch /app/audio/test.txt
```

## 🔍 Диагностика проблемы

**Причина ошибки:**
- Volume `./audio` смонтирован с правами хост-системы
- Нельзя изменить права ВНУТРИ контейнера командой `docker exec`
- Нужно изменить права НА ХОСТ-СИСТЕМЕ

**Как это исправлено:**
1. ✅ Остановка контейнеров
2. ✅ Установка владельца `1001:1001` (nodeuser:nodejs)
3. ✅ Установка прав `755`
4. ✅ Пересборка backend с правильными правами

## 📋 Проверка успешности

После исправления:
```bash
# Должно показать: drwxr-xr-x nodeuser nodejs
docker exec dialer_backend ls -la /app/audio/

# Должно работать без ошибок
docker exec dialer_backend touch /app/audio/test.txt
```

## 🧪 Тест загрузки

```bash
# Тест через API
curl -X POST -F "audio=@test.mp3" http://localhost:3000/api/campaigns/1/audio
# Ожидаемый результат: {"success":true,...}
```

## ⚠️ Если проблема остается

1. Проверить, что Docker volume не cached:
   ```bash
   docker volume ls
   docker volume inspect dailer_v1_audio_data 2>/dev/null || echo "Volume не найден"
   ```

2. Полная очистка и пересборка:
   ```bash
   docker-compose down -v
   docker system prune -f
   sudo rm -rf ./audio
   mkdir -p ./audio
   sudo chown -R 1001:1001 ./audio/
   sudo chmod -R 755 ./audio/
   docker-compose up -d --build
   ```

## 🎯 Результат

✅ Файлы аудио сохраняются в `./audio/campaign-audio-*.mp3`  
✅ Веб-интерфейс показывает "Аудиофайл успешно загружен"  
✅ Нет ошибок EACCES в логах 