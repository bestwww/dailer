# 🚀 Быстрый тест Asterisk интеграции

## ⚡ **5-минутный тест**

### 1. **Установка зависимостей**
```bash
cd backend
npm install
```

### 2. **Запуск только Asterisk (без конфликтов)**
```bash
# Убедитесь что FreeSWITCH не запущен
docker compose down

# Запуск только с Asterisk
VOIP_PROVIDER=asterisk docker compose --profile asterisk up -d
```

### 3. **Проверка статуса**
```bash
# Проверяем что Asterisk запустился
docker ps | grep asterisk

# Проверяем логи
docker logs dialer_asterisk

# Ждем "Asterisk Ready"
```

### 4. **Тест AMI подключения**
```bash
# Подключение к AMI напрямую
telnet localhost 5038

# Должно показать:
# Asterisk Call Manager/9.0.0
# Action: Login
# Username: admin
# Secret: admin
# (нажать Enter дважды)
```

### 5. **Тест через диалер**
```bash
cd backend

# Тест Asterisk адаптера
npm run dev -- --script test-asterisk

# Должно показать:
# ✅ Подключение к Asterisk AMI успешно
# ✅ Статистика получена
# ✅ Команды работают

# Тест SIP trunk (62.141.121.197:5070)
npm run dev -- --script test-sip-trunk

# Должно показать:
# ✅ SIP endpoint trunk настроен
# ✅ SIP trunk правильно настроен на 62.141.121.197:5070
# ✅ Конфигурация готова для звонков
```

### 6. **Переключение обратно на FreeSWITCH**
```bash
# Останавливаем Asterisk
docker compose down

# Возвращаемся к FreeSWITCH
docker compose up -d

# Или явно указываем
VOIP_PROVIDER=freeswitch docker compose up -d
```

## 🎯 **Ожидаемые результаты:**

### ✅ **Успешный тест:**
```
🧪 Тестирование Asterisk адаптера
📋 Конфигурация Asterisk:
   Host: asterisk:5038
   User: admin

🔌 Тест 1: Подключение к Asterisk AMI
✅ Подключение к Asterisk AMI успешно

📊 Тест 2: Статус подключения
   Подключен: ✅
   Попытки переподключения: 0/10

📈 Тест 3: Статистика Asterisk
   Активные звонки: 0
   Активные каналы: 0
   Время работы: 123s
   Подключен: ✅
```

### ❌ **Если тест не прошел:**

**Ошибка подключения:**
```bash
# Проверьте что Asterisk запущен
docker logs dialer_asterisk

# Проверьте порты
netstat -tulpn | grep 5038

# Перезапустите Asterisk
docker compose restart asterisk
```

**Ошибка AMI:**
```bash
# Проверьте конфигурацию
docker exec dialer_asterisk cat /etc/asterisk/manager.conf

# Перезагрузите конфигурацию
docker exec dialer_asterisk asterisk -rx "module reload manager"
```

## 🔄 **Сравнение производительности:**

### **FreeSWITCH тест:**
```bash
VOIP_PROVIDER=freeswitch docker compose up -d
# Ваши существующие тесты
```

### **Asterisk тест:**
```bash
VOIP_PROVIDER=asterisk docker compose --profile asterisk up -d
npm run dev -- --script test-asterisk
```

## 💡 **Подсказки:**

1. **Первый запуск Asterisk может занять 1-2 минуты** - дождитесь "Asterisk Ready"
2. **Порты не должны конфликтовать** - Asterisk использует 5038, FreeSWITCH - 8021
3. **Логи помогают диагностировать проблемы** - `docker logs dialer_asterisk`
4. **AMI пользователь по умолчанию** - admin/admin (см. manager.conf)
5. **Переключение безопасно** - можно вернуться к FreeSWITCH в любой момент

---
**🎊 Если все тесты прошли - миграция готова к использованию!** 