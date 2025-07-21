# 🚨 СРОЧНОЕ ИСПРАВЛЕНИЕ FreeSWITCH

## ⚡ Проблема на тестовом сервере:
- ❌ Профиль 'external' не загружается (0 profiles)
- ❌ Gateway 'sip_trunk' недоступен  
- ❌ Ошибка "INVALID_GATEWAY" при звонках
- ⚠️ Docker Compose v2 не поддерживается старым скриптом

## 🚀 СРОЧНОЕ РЕШЕНИЕ (3 минуты):

### На тестовом сервере выполните:

```bash
# 1. Обновить код
cd ~/dailer
git pull origin main

# 2. Запустить улучшенный скрипт исправления
./fix-freeswitch-issues-v2.sh
```

## 🔧 Что делает новый скрипт v2.0:

1. **Автоопределение Docker Compose** - работает с v1 и v2
2. **Проверка XML синтаксиса** - находит ошибки в конфигурации
3. **Глубокая диагностика** - проверяет процессы и модули FreeSWITCH
4. **Принудительный запуск Sofia** - пытается запустить профиль external
5. **Минимальная конфигурация** - создает рабочую конфигурацию как fallback
6. **Полная очистка** - пересоздает контейнеры если нужно

## 📋 Если скрипт не помогает:

### Ручное исправление:

```bash
# 1. Полная очистка
cd ~/dailer
docker compose down
docker rm -f dialer_freeswitch
docker volume prune -f

# 2. Перезапуск
docker compose up -d freeswitch

# 3. Ожидание загрузки
sleep 30

# 4. Проверка
docker exec dialer_freeswitch fs_cli -x "sofia status"
```

### Если модуль mod_sofia не загружается:

```bash
# Подключиться к FreeSWITCH CLI
docker exec -it dialer_freeswitch fs_cli

# В CLI выполнить:
load mod_sofia
sofia profile external start
quit
```

## ✅ Проверка результата:

```bash
# Проверить что профиль external загружен
docker exec dialer_freeswitch fs_cli -x "sofia status"

# Должно показать external профиль и gateway sip_trunk

# Тест SIP транка
./test-sip-trunk.sh test
```

## 🎯 Ожидаемый результат:

```
Name        Type                                       Data      State
=================================================================================================
external    profile   sip:mod_sofia@192.168.1.100:5060      RUNNING (0)
=================================================================================================
1 profiles 1 aliases
```

## 📞 Если все еще не работает:

1. **Покажите результат:**
   ```bash
   ./fix-freeswitch-issues-v2.sh > fix_result.log 2>&1
   cat fix_result.log
   ```

2. **Проверьте логи FreeSWITCH:**
   ```bash
   docker logs dialer_freeswitch --tail=50
   ```

3. **Свяжитесь с поддержкой** с приложением логов

---

**💡 Важно**: Новый скрипт автоматически создает backup конфигурации перед изменениями! 