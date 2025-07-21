# 🔍 Как найти существующий контейнер FreeSWITCH

## ⚡ Быстрые команды (выполните на тестовом сервере)

### 1. **Автоматический поиск (рекомендуется)**
```bash
./find-existing-freeswitch.sh
```

### 2. **Ручной поиск по шагам**

#### 🔍 **Поиск по названию:**
```bash
# Все контейнеры с freeswitch в названии
docker ps -a | grep -i freeswitch

# Конкретные названия
docker ps -a | grep -E "dialer_freeswitch|dailer_freeswitch|freeswitch"
```

#### 🔍 **Поиск по образу:**
```bash
# Контейнеры с образами FreeSWITCH/SignalWire
docker ps -a | grep -i -E "freeswitch|signalwire"
```

#### 🔍 **Поиск по SIP порту:**
```bash
# Контейнеры использующие порт 5060 (SIP)
docker ps -a | grep ":5060"
```

#### 🔍 **Все контейнеры проекта:**
```bash
# Все контейнеры проекта диалера
docker ps -a | grep -i -E "dialer|dailer"
```

---

## 📋 Вероятные названия контейнеров

По приоритету (наиболее вероятные):

1. **`dialer_freeswitch`** - стандартное название из docker-compose.yml
2. **`dailer_freeswitch`** - возможная опечатка в названии проекта
3. **`freeswitch`** - простое название
4. **`*_freeswitch_*`** - любые вариации с freeswitch

---

## ✅ Проверка найденного контейнера

### После того как нашли контейнер (например, `dialer_freeswitch`):

```bash
# Проверить статус контейнера
docker ps -f name=dialer_freeswitch

# Проверить что это действительно FreeSWITCH
docker exec dialer_freeswitch fs_cli -x "status"

# Проверить версию
docker exec dialer_freeswitch fs_cli -x "version"

# Посмотреть логи
docker logs --tail=20 dialer_freeswitch
```

### 🔍 **Проверка конфигурации Caller ID:**
```bash
# Проверить есть ли новый Caller ID (79058615815)
docker exec dialer_freeswitch find /usr/local/freeswitch/conf -name "*.xml" -exec grep -l "79058615815" {} \;

# Или проверить в файлах хоста
grep -r "79058615815" freeswitch/conf/ 2>/dev/null
```

---

## 🎯 Что делать после обнаружения

### ✅ **Если контейнер найден и работает:**
```bash
# Просто обновить конфигурацию
./update-config-only.sh
```

### ⚠️ **Если контейнер найден, но остановлен:**
```bash
# Запустить существующий контейнер
docker start НАЗВАНИЕ_КОНТЕЙНЕРА

# Затем обновить конфигурацию
./update-config-only.sh
```

### ❌ **Если контейнер не найден:**
```bash
# Вариант 1: Использовать готовый образ
docker pull signalwire/freeswitch:latest
docker compose -f docker-compose.no-build.yml up -d freeswitch

# Вариант 2: Запустить стандартную конфигурацию
docker compose up -d freeswitch

# Затем обновить конфигурацию
./update-config-only.sh
```

---

## 🔧 Полезные команды для анализа

### **Все контейнеры с подробной информацией:**
```bash
docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
```

### **Образы FreeSWITCH:**
```bash
docker images | grep -i -E "freeswitch|signalwire"
```

### **Docker сети:**
```bash
docker network ls | grep -E "dialer|dailer"
```

### **Docker тома:**
```bash
docker volume ls | grep -E "dialer|dailer|freeswitch"
```

---

## 💡 Автоматическое определение

Скрипт `find-existing-freeswitch.sh` автоматически:

1. 🔍 **Ищет контейнеры** по всем возможным критериям
2. 🎯 **Ранжирует по приоритету** (dialer_freeswitch в топе)
3. ✅ **Проверяет работоспособность** FreeSWITCH
4. 🔧 **Проверяет конфигурацию** Caller ID
5. 💾 **Сохраняет результат** в файл `.freeswitch_container`

---

## 📖 Сохранение результата

После выполнения `find-existing-freeswitch.sh` имя контейнера сохраняется:

```bash
# Посмотреть сохраненное имя
cat .freeswitch_container

# Использовать в командах
source .freeswitch_container
docker logs $FREESWITCH_CONTAINER
```

---

## 🚨 Возможные проблемы

### **Контейнер найден, но fs_cli не работает:**
- Контейнер может быть не FreeSWITCH
- FreeSWITCH еще не запустился (подождите 30 секунд)
- Проблемы с конфигурацией

### **Несколько контейнеров найдено:**
- Скрипт выберет наиболее подходящий по приоритету
- Проверьте каждый вручную: `docker exec НАЗВАНИЕ fs_cli -x "status"`

### **Контейнер не найден:**
- FreeSWITCH еще не был установлен
- Используется нестандартное имя
- Контейнер был удален

---

**🎯 ИТОГ:** Используйте `./find-existing-freeswitch.sh` для автоматического поиска или команды выше для ручного поиска. 