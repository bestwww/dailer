# 📞 Настройка SIP Trunk (62.141.121.197:5070)

## ✅ **Что уже настроено:**

### **1. PJSIP конфигурация** (`docker/asterisk/conf/pjsip.conf`)
```ini
[trunk]
type=endpoint
transport=udp_transport
context=campaign-calls
disallow=all
allow=ulaw,alaw,g729
direct_media=no
rtp_symmetric=yes
force_rport=yes
rewrite_contact=yes
outbound_proxy=sip:62.141.121.197:5070

[trunk_identify]
type=identify
endpoint=trunk
match=62.141.121.197
```

### **2. Docker переменные** (`docker compose`)
```yaml
environment:
  - SIP_PROVIDER_HOST=62.141.121.197
  - SIP_PROVIDER_PORT=5070
  - SIP_CALLER_ID_NUMBER=${SIP_CALLER_ID_NUMBER:-+70000000000}
```

### **3. Asterisk адаптер** (`backend/src/services/adapters/asterisk-adapter.ts`)
```typescript
Channel: `PJSIP/${normalizedNumber}@trunk`  // Использует настроенный trunk
CallerID: process.env.SIP_CALLER_ID_NUMBER  // Из переменной окружения
```

## 🚀 **Тестирование SIP Trunk:**

### **1. Запуск Asterisk:**
```bash
# Остановить FreeSWITCH если запущен
docker compose down

# Запустить с Asterisk
SIP_CALLER_ID_NUMBER=+7123456789 VOIP_PROVIDER=asterisk docker compose --profile asterisk up -d
```

### **2. Проверка конфигурации:**
```bash
# Логи Asterisk
docker logs dialer_asterisk

# PJSIP статус
docker exec dialer_asterisk asterisk -rx "pjsip show endpoints"
docker exec dialer_asterisk asterisk -rx "pjsip show transports"

# Показать endpoint trunk
docker exec dialer_asterisk asterisk -rx "pjsip show endpoint trunk"
```

### **3. Тест через диалер:**
```bash
cd backend

# Тест подключения к AMI
npm run dev -- --script test-asterisk

# При успешном AMI тесте увидите:
# ✅ Подключение к Asterisk AMI успешно
# ✅ Команды работают
```

### **4. Тест исходящего звонка:**
```bash
# В Asterisk CLI (если нужно протестировать напрямую)
docker exec -it dialer_asterisk asterisk -r

# В CLI Asterisk:
# originate PJSIP/1234567890@trunk application Echo

# Или через диалер (если есть тестовая кампания):
# curl -X POST http://localhost:3000/api/campaigns/test-call \
#   -H "Content-Type: application/json" \
#   -d '{"phoneNumber": "1234567890", "campaignId": 1}'
```

## 🔧 **Диагностика проблем:**

### **Проблема: "No route to destination"**
```bash
# Проверить что trunk настроен
docker exec dialer_asterisk asterisk -rx "pjsip show endpoint trunk"

# Должно показать:
# Endpoint: trunk/trunk    Not in use    0 of inf
# OutboundProxy: sip:62.141.121.197:5070
```

### **Проблема: "Authentication failure"**
```bash
# Убедиться что auth не настроен (для trunk без регистрации)
docker exec dialer_asterisk asterisk -rx "pjsip show auths"

# НЕ должно показывать trunk auth
```

### **Проблема: Нет аудио (RTP)**
```bash
# Проверить RTP настройки
docker exec dialer_asterisk asterisk -rx "rtp show settings"

# Убедиться что порты 10000-10020 открыты в docker-compose.yml
```

### **Проблема: SIP пакеты не доходят**
```bash
# Проверить что Asterisk слушает на правильном порту
docker exec dialer_asterisk asterisk -rx "pjsip show transports"

# Должно показать:
# Transport: udp_transport    UDP      0      0.0.0.0:5060
```

## 📊 **Проверка статистики:**

### **SIP сообщения:**
```bash
# Включить SIP debug
docker exec dialer_asterisk asterisk -rx "pjsip set logger on"

# Сделать тестовый звонок
# Посмотреть SIP трафик в логах
docker logs dialer_asterisk

# Выключить debug
docker exec dialer_asterisk asterisk -rx "pjsip set logger off"
```

### **Активные звонки:**
```bash
# Показать активные звонки
docker exec dialer_asterisk asterisk -rx "core show calls"

# Показать каналы
docker exec dialer_asterisk asterisk -rx "core show channels"
```

## ⚙️ **Дополнительные настройки:**

### **Изменить Caller ID:**
```bash
# В docker-compose.yml или .env файле:
SIP_CALLER_ID_NUMBER=+7123456789 docker compose --profile asterisk up -d
```

### **Добавить кодеки:**
```ini
# В pjsip.conf, секция [trunk]:
allow=ulaw,alaw,g729,g722
```

### **NAT настройки (если нужно):**
```bash
# Указать внешний IP
EXTERNAL_IP=ваш_внешний_ip docker compose --profile asterisk up -d
```

## 🎯 **Готовые команды для быстрого старта:**

```bash
# 1. Остановить FreeSWITCH
docker compose down

# 2. Запустить Asterisk с вашим Caller ID
SIP_CALLER_ID_NUMBER=+7123456789 VOIP_PROVIDER=asterisk docker compose --profile asterisk up -d

# 3. Дождаться запуска (1-2 минуты)
docker logs -f dialer_asterisk

# 4. Проверить AMI
cd backend && npm run dev -- --script test-asterisk

# 5. Проверить SIP trunk
docker exec dialer_asterisk asterisk -rx "pjsip show endpoint trunk"
```

---
**✅ SIP Trunk готов для звонков на 62.141.121.197:5070!** 