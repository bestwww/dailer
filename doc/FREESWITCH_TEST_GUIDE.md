# 🧪 Руководство по тестированию контейнера `freeswitch-test`

## ⚡ Быстрый старт

### 1. **Автоматическое тестирование (рекомендуется)**
```bash
# Полное тестирование контейнера
./test-freeswitch-container.sh
```

### 2. **Обновление Caller ID**
```bash
# Автоматическое обновление Caller ID на 79058615815
./update-caller-id-freeswitch-test.sh
```

---

## 📋 Пошаговое тестирование

### 🔍 **ШАГ 1: Проверка контейнера**

```bash
# Проверить существование контейнера
docker ps -a | grep freeswitch-test

# Проверить статус
docker ps -f name=freeswitch-test

# Запустить если остановлен
docker start freeswitch-test
```

### 🔍 **ШАГ 2: Проверка FreeSWITCH**

```bash
# Проверить статус FreeSWITCH
docker exec freeswitch-test fs_cli -x "status"

# Проверить версию
docker exec freeswitch-test fs_cli -x "version"

# Посмотреть логи
docker logs --tail=20 freeswitch-test
```

### 🔍 **ШАГ 3: Проверка SIP**

```bash
# Статус SIP профилей
docker exec freeswitch-test fs_cli -x "sofia status"

# Статус SIP шлюзов
docker exec freeswitch-test fs_cli -x "sofia status gateway"

# Подробная информация по профилю
docker exec freeswitch-test fs_cli -x "sofia status profile internal"
```

### 🔍 **ШАГ 4: Проверка Caller ID**

```bash
# Поиск нового Caller ID в конфигурации
docker exec freeswitch-test find /usr/local/freeswitch/conf -name "*.xml" -exec grep -l "79058615815" {} \;

# Поиск в локальных файлах
grep -r "79058615815" freeswitch/conf/ 2>/dev/null
```

---

## ✅ Что должно работать

### ✅ **Контейнер**
- Контейнер должен быть запущен
- Порты 5060 (SIP) и 8021 (ESL) должны быть открыты
- Логи не должны содержать критических ошибок

### ✅ **FreeSWITCH**
- Команда `fs_cli -x "status"` должна показывать "UP"
- SIP профили `internal` и `external` должны быть RUNNING
- Конфигурация должна загружаться без ошибок

### ✅ **Caller ID**
- Новый Caller ID `79058615815` должен быть в конфигурации
- Файлы `vars.xml`, `dialplan/default.xml`, `sofia.conf.xml` должны содержать новый ID
- После `reloadxml` изменения должны применяться

---

## 🔧 Команды для быстрой диагностики

### **Все в одном:**
```bash
echo "=== КОНТЕЙНЕР ==="
docker ps -f name=freeswitch-test

echo "=== FREESWITCH СТАТУС ==="
docker exec freeswitch-test fs_cli -x "status"

echo "=== SIP ПРОФИЛИ ==="
docker exec freeswitch-test fs_cli -x "sofia status"

echo "=== CALLER ID ==="
docker exec freeswitch-test grep -r "79058615815" /usr/local/freeswitch/conf/ | head -3
```

### **Интерактивное подключение:**
```bash
# Подключиться к FreeSWITCH CLI
docker exec -it freeswitch-test fs_cli

# Зайти в контейнер
docker exec -it freeswitch-test /bin/bash
```

---

## 🎯 Тестирование звонков

### **Подготовка к тестированию:**

1. **Проверить SIP trunk:**
   ```bash
   docker exec freeswitch-test fs_cli -x "sofia status gateway sip_trunk"
   ```

2. **Проверить dialplan:**
   ```bash
   docker exec freeswitch-test fs_cli -x "xml_locate dialplan"
   ```

3. **Включить логирование (если нужно):**
   ```bash
   docker exec freeswitch-test fs_cli -x "console loglevel debug"
   ```

### **Тестовые команды:**

```bash
# Тест исходящего звонка (замените NUMBER на реальный номер)
docker exec freeswitch-test fs_cli -x "originate sofia/gateway/sip_trunk/NUMBER &echo"

# Проверить активные каналы
docker exec freeswitch-test fs_cli -x "show channels"

# Проверить CDR (если включен)
docker exec freeswitch-test fs_cli -x "show calls"
```

---

## 🚨 Возможные проблемы и решения

### **❌ Контейнер не запускается**
```bash
# Проверить логи ошибок
docker logs freeswitch-test

# Попробовать принудительный перезапуск
docker restart freeswitch-test
```

### **❌ FreeSWITCH не отвечает**
```bash
# Перезапустить FreeSWITCH в контейнере
docker exec freeswitch-test pkill -f freeswitch
docker restart freeswitch-test

# Подождать 30 секунд и проверить
sleep 30
docker exec freeswitch-test fs_cli -x "status"
```

### **❌ SIP профили не запускаются**
```bash
# Проверить конфигурацию SIP
docker exec freeswitch-test fs_cli -x "sofia status"

# Перезапустить профили
docker exec freeswitch-test fs_cli -x "sofia profile internal restart"
docker exec freeswitch-test fs_cli -x "sofia profile external restart"
```

### **❌ Caller ID не применяется**
```bash
# Обновить конфигурацию
./update-caller-id-freeswitch-test.sh

# Или вручную
docker cp freeswitch/conf/. freeswitch-test:/usr/local/freeswitch/conf/
docker exec freeswitch-test fs_cli -x "reloadxml"
```

---

## 📊 Мониторинг и логи

### **Постоянный мониторинг:**
```bash
# Следить за логами в реальном времени
docker logs -f freeswitch-test

# Следить за логами FreeSWITCH
docker exec freeswitch-test tail -f /usr/local/freeswitch/log/freeswitch.log
```

### **Статистика:**
```bash
# Показать статистику системы
docker exec freeswitch-test fs_cli -x "show status"

# Показать использование памяти
docker exec freeswitch-test fs_cli -x "status"

# Показать все модули
docker exec freeswitch-test fs_cli -x "show modules"
```

---

## 🎉 Готовность к production

### **Чек-лист перед запуском в production:**

- [ ] ✅ Контейнер `freeswitch-test` запускается без ошибок
- [ ] ✅ FreeSWITCH показывает статус "UP"
- [ ] ✅ SIP профили в состоянии "RUNNING"
- [ ] ✅ Caller ID `79058615815` применен во всех конфигурациях
- [ ] ✅ Тестовые звонки проходят успешно
- [ ] ✅ Логи не содержат критических ошибок
- [ ] ✅ Все необходимые порты открыты и доступны

### **Финальная команда:**
```bash
echo "🎉 КОНТЕЙНЕР ГОТОВ К ПРОДАКШЕНУ!" 
docker exec freeswitch-test fs_cli -x "status"
```

---

**🎯 ИТОГ:** Используйте `./test-freeswitch-container.sh` для полного автоматического тестирования или выполняйте команды выше по шагам для детальной диагностики. 