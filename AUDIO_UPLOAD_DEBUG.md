# 🎵 Диагностика проблем загрузки аудиофайлов

## 🚨 Проблема

На тестовом сервере аудиофайлы не сохраняются в настройках кампании. Файл выбирается, но после отправки формы аудиофайл остается пустым.

## 🔍 Диагностика

### 1. Автоматическая диагностика
```bash
# На тестовом сервере запустите:
git pull origin main
chmod +x debug-audio-upload.sh
./debug-audio-upload.sh http://YOUR_SERVER_IP:3000
```

### 2. Быстрая проверка
```bash
# Проверка контейнеров
docker ps -a | grep dialer

# Проверка логов backend
docker logs --tail 50 dialer_backend | grep -i audio

# Проверка endpoint'а
curl http://localhost:3000/api/health
```

## 🔧 Основные причины и решения

### 1. Папка для загрузки недоступна
**Симптомы:** Ошибки доступа к файловой системе
```bash
# Решение:
docker exec dialer_backend mkdir -p /app/audio
docker exec dialer_backend chmod 755 /app/audio
docker-compose restart backend
```

### 2. Проблемы с volume'ами Docker
**Симптомы:** Файлы не сохраняются между перезапусками
```bash
# Проверка volume'ов:
docker volume ls | grep dialer
docker inspect dialer_v1_audio_volume

# Пересоздание с правильными volume'ами:
docker-compose down
docker-compose up -d --build
```

### 3. Превышение лимитов размера файла
**Симптомы:** Большие файлы не загружаются
```bash
# Проверка переменных окружения:
docker exec dialer_backend printenv | grep AUDIO
```

### 4. Проблемы с CORS или network
**Симптомы:** Запросы не доходят до сервера
```bash
# Проверка сети:
docker network ls
docker network inspect dialer_v1_dialer_network

# Тест connectivity:
docker exec dialer_frontend ping backend
```

### 5. Ошибки multer middleware
**Симптомы:** 400/500 ошибки при загрузке
```bash
# Детальные логи:
docker logs -f dialer_backend | grep -E "(multer|upload|audio)"
```

## 🎯 Пошаговая диагностика

### Шаг 1: Проверка инфраструктуры
```bash
# 1. Все контейнеры запущены?
docker ps

# 2. Backend здоров?
curl http://localhost:3000/health

# 3. Папка audio существует?
docker exec dialer_backend ls -la /app/audio
```

### Шаг 2: Тест загрузки
```bash
# Создаем тестовый файл
echo "test audio" > test.mp3

# Тестируем общий endpoint
curl -X POST -F "audio=@test.mp3" http://localhost:3000/api/audio/upload

# Тестируем endpoint кампании (замените 1 на ID существующей кампании)
curl -X POST -F "audio=@test.mp3" http://localhost:3000/api/campaigns/1/audio
```

### Шаг 3: Анализ логов
```bash
# Логи во время загрузки
docker logs -f dialer_backend &

# В другом терминале повторите загрузку файла через UI
# Анализируйте логи на предмет ошибок
```

## 📋 Чек-лист решения

- [ ] Backend контейнер запущен и здоров
- [ ] Папка `/app/audio` существует и доступна для записи  
- [ ] Volume'ы корректно смонтированы
- [ ] Endpoint'ы `/api/audio/upload` и `/api/campaigns/:id/audio` отвечают
- [ ] Нет ошибок CORS в браузере
- [ ] Multer middleware корректно обрабатывает файлы
- [ ] База данных доступна для обновления кампаний
- [ ] Переменные окружения для аудио настроены

## 🚀 Быстрое исправление

```bash
# Комплексное решение:
cd /path/to/your/project
git pull origin main
docker-compose down
docker-compose up -d --build
./debug-audio-upload.sh
```

## 📞 Детальные логи в браузере

После обновления кода вы увидите в консоли браузера:

✅ **Успешная загрузка:**
```
🎵 Начинаем загрузку аудиофайла для кампании: 1
📈 Прогресс загрузки: 50%
📈 Прогресс загрузки: 100%
✅ Ответ сервера - статус: 200
✅ Аудиофайл успешно загружен
```

❌ **При ошибках:**
```
❌ Ошибка загрузки аудиофайла: [детальное описание]
❌ Статус ответа: 500
❌ Данные ответа: {error: "описание ошибки"}
```

## 🔗 Полезные ссылки

- `debug-docker.sh` - общая диагностика контейнеров
- `debug-audio-upload.sh` - специализированная диагностика аудио
- `quick-check.md` - быстрые команды для проверки

## 💡 Дополнительные советы

1. **Размер файлов:** Лимит 10MB по умолчанию
2. **Форматы:** Поддерживаются MP3, WAV, M4A
3. **Кодировка:** Поддерживается кириллица в именах файлов
4. **Таймауты:** Увеличен таймаут до 30 секунд для больших файлов
5. **Прогресс:** Добавлен индикатор прогресса загрузки

---

*Последнее обновление: $(date '+%Y-%m-%d %H:%M:%S')* 