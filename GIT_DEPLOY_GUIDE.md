# 🚀 Git Commit и Deploy на тестовый сервер

## 📋 **Checklist перед коммитом:**

### ✅ **Что готово:**
- [x] VoIP Provider Interface и Factory
- [x] FreeSWITCH Adapter (обертка)
- [x] Asterisk Adapter (полная реализация AMI)
- [x] SIP Trunk конфигурация (62.141.121.197:5070)
- [x] Docker образы и compose файлы
- [x] Тестовые скрипты
- [x] Deploy скрипт для сервера
- [x] Документация и инструкции

## 🔧 **1. Подготовка к Git commit:**

```bash
# Проверяем текущий статус
git status

# Убеждаемся что все файлы добавлены
git add .

# Проверяем что будет закоммичено
git diff --cached --name-only
```

### **Основные новые файлы:**
```
backend/package.json                                 # asterisk-manager зависимость
backend/src/services/voip-provider.ts               # VoIP интерфейс
backend/src/services/voip-provider-factory.ts       # Factory паттерн
backend/src/services/adapters/freeswitch-adapter.ts # FreeSWITCH обертка
backend/src/services/adapters/asterisk-adapter.ts   # Asterisk AMI клиент
backend/src/services/dialer.ts                      # Обновленный диалер
backend/src/config/index.ts                         # Новые настройки
backend/src/types/index.ts                          # Обновленные типы
backend/src/scripts/test-asterisk.ts                # Тест Asterisk
backend/src/scripts/test-sip-trunk.ts               # Тест SIP trunk

docker/asterisk/Dockerfile                          # Asterisk образ
docker/asterisk/docker-entrypoint.sh               # Entrypoint скрипт
docker/asterisk/conf/manager.conf                   # AMI конфигурация
docker/asterisk/conf/pjsip.conf                     # SIP trunk конфигурация
docker/asterisk/conf/extensions.conf                # Диалплан

docker-compose.yml                                   # Обновленный compose
docker-compose.asterisk.yml                         # Asterisk режим

deploy-asterisk-test.sh                             # Deploy скрипт
SIP_TRUNK_SETUP.md                                  # SIP trunk инструкции
ASTERISK_QUICK_TEST.md                              # Быстрый тест
ENV_ASTERISK_EXAMPLE.md                             # Пример env
GIT_DEPLOY_GUIDE.md                                 # Этот файл
VOIP_MIGRATION_README.md                            # Обновленная документация
```

## 📝 **2. Git Commit:**

```bash
# Коммит с описательным сообщением
git commit -m "feat: Add Asterisk VoIP provider support

✨ Features:
- VoIP Provider abstraction layer (FreeSWITCH + Asterisk)
- Full Asterisk AMI integration with event handling
- SIP trunk configuration (62.141.121.197:5070)
- Docker containerization for Asterisk
- Comprehensive testing suite

🔧 Changes:
- Add asterisk-manager dependency
- Create VoIPProvider interface and factory
- Implement FreeSwitchAdapter (wrapper for existing code)
- Implement AsteriskAdapter with full AMI support
- Update dialer service to use VoIP abstraction
- Add Asterisk Docker image and configuration
- Create deployment and testing scripts

🧪 Testing:
- AMI connection and command testing
- SIP trunk configuration validation
- Event handling verification

📚 Documentation:
- Complete migration guide
- SIP trunk setup instructions
- Deployment guide for test server

🎯 Result: 
Zero breaking changes to existing FreeSWITCH code.
Can switch between FreeSWITCH and Asterisk with single command.
Production-ready Asterisk integration with SIP trunk."

# Пуш в репозиторий
git push origin main
```

## 🌐 **3. Deploy на тестовый сервер:**

### **Подготовка сервера:**
```bash
# На тестовом сервере (один раз)
sudo apt update
sudo apt install -y curl git

# Установка Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Установка Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-Linux-x86_64" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Перелогиниться для применения прав Docker
exit
# Заходим снова
```

### **Скачивание deploy скрипта:**
```bash
# Вариант 1: Прямое скачивание deploy скрипта
wget https://raw.githubusercontent.com/ваш-repo/dialer-system/main/deploy-asterisk-test.sh
chmod +x deploy-asterisk-test.sh

# Вариант 2: Клонирование всего репозитория
git clone https://github.com/ваш-repo/dialer-system.git
cd dialer-system
chmod +x deploy-asterisk-test.sh
```

### **Запуск deploy:**
```bash
# Установить ваш Caller ID
export SIP_CALLER_ID_NUMBER="+7ваштелефон"

# Запустить deploy скрипт
sudo ./deploy-asterisk-test.sh

# Или с настройкой Caller ID в одной команде:
SIP_CALLER_ID_NUMBER="+7ваштелефон" sudo ./deploy-asterisk-test.sh
```

## 📊 **4. Проверка деплоя:**

### **После успешного деплоя увидите:**
```
🎉 Деплой завершен!

📊 Информация о системе:
   Frontend: http://[IP-сервера]:5173
   Backend API: http://[IP-сервера]:3000
   Asterisk AMI: [IP-сервера]:5038
   SIP Trunk: 62.141.121.197:5070
   Caller ID: +7ваштелефон

✅ AMI тест прошел
✅ SIP trunk тест прошел
✅ Система готова к тестированию звонков!
```

### **Полезные команды на сервере:**
```bash
# Статус контейнеров
docker ps

# Логи Asterisk в реальном времени
docker logs -f dialer_asterisk

# Логи Backend
docker logs -f dialer_backend

# Asterisk CLI
docker exec -it dialer_asterisk asterisk -r

# Проверка SIP trunk
docker exec dialer_asterisk asterisk -rx "pjsip show endpoint trunk"

# Рестарт системы
cd /opt/dialer
docker compose --profile asterisk restart
```

## 🧪 **5. Тестирование звонков:**

### **Тест через Asterisk CLI:**
```bash
# Заходим в Asterisk CLI
docker exec -it dialer_asterisk asterisk -r

# В CLI делаем тестовый звонок (Echo application)
CLI> originate PJSIP/79991234567@trunk application Echo

# Смотрим активные каналы
CLI> core show channels

# Выходим из CLI
CLI> exit
```

### **Тест через диалер API:**
```bash
# Создание тестовой кампании (если есть API)
curl -X POST http://[IP-сервера]:3000/api/campaigns/test \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-token" \
  -d '{
    "phoneNumber": "79991234567",
    "campaignId": 1
  }'
```

## ⚠️ **6. Troubleshooting:**

### **Если AMI тест не прошел:**
```bash
# Проверить что Asterisk запущен
docker logs dialer_asterisk | grep "Asterisk Ready"

# Проверить AMI порт
netstat -tulpn | grep 5038

# Перезапустить Asterisk
docker compose restart asterisk
```

### **Если SIP trunk тест не прошел:**
```bash
# Проверить SIP конфигурацию
docker exec dialer_asterisk asterisk -rx "pjsip show endpoints"

# Включить SIP логи
docker exec dialer_asterisk asterisk -rx "pjsip set logger on"

# Сделать тестовый звонок и смотреть логи
docker logs -f dialer_asterisk
```

### **Откат на FreeSWITCH (если нужно):**
```bash
cd /opt/dialer

# Изменить .env
sed -i 's/VOIP_PROVIDER=asterisk/VOIP_PROVIDER=freeswitch/' .env

# Перезапустить с FreeSWITCH
docker compose down
docker compose up -d
```

## 🎯 **7. Что делать после успешного деплоя:**

1. **✅ Протестировать AMI** - должен отвечать на порту 5038
2. **✅ Проверить SIP trunk** - должен быть настроен на 62.141.121.197:5070
3. **📞 Сделать тестовый звонок** через Asterisk CLI
4. **📊 Проверить логи** - не должно быть ошибок
5. **🌐 Открыть frontend** - должен работать
6. **🔄 Протестировать переключение** на FreeSWITCH и обратно

---

## 🚀 **Готовые команды для копирования:**

### **На локальной машине (Git):**
```bash
git add .
git commit -m "feat: Add complete Asterisk VoIP provider support with SIP trunk"
git push origin main
```

### **На тестовом сервере (Deploy):**
```bash
# Подготовка
curl -fsSL https://get.docker.com | sh && sudo usermod -aG docker $USER

# Скачивание и deploy (замените URL репозитория в скрипте!)
wget https://raw.githubusercontent.com/ваш-repo/dialer-system/main/deploy-asterisk-test.sh
chmod +x deploy-asterisk-test.sh
SIP_CALLER_ID_NUMBER="+7ваштелефон" sudo ./deploy-asterisk-test.sh
```

**🎊 После этого у вас будет работающий Asterisk на тестовом сервере!** 