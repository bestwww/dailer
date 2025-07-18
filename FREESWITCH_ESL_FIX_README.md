# 🔧 Исправление проблемы FreeSWITCH Event Socket

## 🚨 **ПРОБЛЕМА ВЫЯВЛЕНА:**
```
❌ ERROR in makeCall: FreeSWITCH not connected - please check Event Socket configuration
```

## ⚡ **БЫСТРОЕ РЕШЕНИЕ** (2 минуты)

### **Шаг 1: Обновите код на тестовом сервере**
```bash
git pull origin main
chmod +x debug-freeswitch-esl.sh
chmod +x fix-freeswitch-esl.sh
```

### **🔒 ВАЖНО: Теперь используется СОБСТВЕННЫЙ безопасный образ FreeSWITCH!**
- ✅ **Безопасность**: Никаких backdoor'ов от сторонних разработчиков
- ✅ **Стабильность**: Проверенная конфигурация Event Socket
- ✅ **Контроль**: Полный контроль над компонентами образа

### **Шаг 2: Запустите диагностику**
```bash
./debug-freeswitch-esl.sh
```

### **Шаг 3: Примените исправления**
```bash
./fix-freeswitch-esl.sh
```

### **Шаг 4: Проверьте результат**
```bash
# Должно показать: "✅ Connected to FreeSWITCH successfully"
docker logs --tail 20 dialer_backend | grep -i freeswitch
```

---

## 🔍 **РУЧНАЯ ДИАГНОСТИКА** (если скрипты не работают)

Выполните команды одну за другой и поделитесь результатами:

### **1. Проверка Event Socket в FreeSWITCH**
```bash
docker exec dialer_freeswitch fs_cli -x "show sockets"
```

### **2. Проверка портов**
```bash
docker exec dialer_freeswitch netstat -tulpn | grep 8021
```

### **3. Проверка переменных окружения**
```bash
docker exec dialer_backend printenv | grep FREESWITCH
```

### **4. Тест сетевого соединения**
```bash
docker exec dialer_backend ping -c 3 freeswitch
```

### **5. Тест Event Socket подключения**
```bash
docker exec dialer_backend bash -c "echo 'auth ClueCon' | telnet freeswitch 8021"
```

---

## 🎯 **ОЖИДАЕМЫЙ РЕЗУЛЬТАТ**

**После исправления вы должны увидеть в логах:**
```
✅ Connected to FreeSWITCH successfully
📞 Making call to +79206054020 (ID: 26)
✅ Originate command sent successfully via ESL
```

**И звонки должны проходить без ошибки:**
```
❌ FreeSWITCH not connected  <-- НЕ ДОЛЖНО БЫТЬ
✅ Call started successfully  <-- ДОЛЖНО БЫТЬ
```

---

## 🆘 **ЕСЛИ ПРОБЛЕМА НЕ РЕШЕНА**

### **Расширенная диагностика:**
```bash
# Полные логи FreeSWITCH
docker logs --tail 100 dialer_freeswitch

# Полные логи Backend
docker logs --tail 100 dialer_backend

# Проверка Docker сети
docker network inspect dailer_dialer_network | grep -A 10 -B 10 "freeswitch\|backend"
```

### **Кардинальное решение:**
```bash
# Полная перезагрузка системы
docker compose down
docker system prune -f
docker compose up -d --build

# Ожидание запуска (2-3 минуты)
sleep 180

# Проверка результата
docker logs --tail 20 dialer_backend | grep -i freeswitch
```

---

## 📝 **ТЕХНИЧЕСКАЯ ИНФОРМАЦИЯ**

**Причина проблемы:** Backend не может подключиться к FreeSWITCH через Event Socket Library (ESL)

**Компоненты:**
- **FreeSWITCH**: Сервер VoIP для совершения звонков
- **Event Socket**: API для управления FreeSWITCH (порт 8021)
- **Backend**: Node.js приложение, управляющее звонками

**Нормальный поток:**
1. Backend подключается к FreeSWITCH ESL (порт 8021)
2. Аутентификация через пароль "ClueCon"
3. Подписка на события FreeSWITCH
4. Отправка команд для совершения звонков

---

## ✅ **ПОСЛЕ ИСПРАВЛЕНИЯ**

1. **Commit изменения в git:**
   ```bash
   git add .
   git commit -m "fix: исправлена проблема подключения FreeSWITCH Event Socket"
   git push origin main
   ```

2. **Тестирование звонков:**
   - Запустите кампанию в интерфейсе
   - Проверьте, что звонки инициируются без ошибок
   - Мониторьте логи: `docker logs -f dialer_backend`

3. **Мониторинг системы:**
   ```bash
   # Постоянный мониторинг
   watch -n 5 'docker ps --format "table {{.Names}}\t{{.Status}}"'
   ```

---

**🎉 После успешного исправления звонки должны работать стабильно!** 

# FreeSWITCH Event Socket Library (ESL) - Исправления

## ✅ **ПРОБЛЕМА SpanDSP РЕШЕНА ОКОНЧАТЕЛЬНО!** - 2025-01-25
## ✅ **ПРОБЛЕМА Sofia-SIP РЕШЕНА!** - 2025-01-25

### 🎯 **Окончательное решение:**
Компиляция SpanDSP 3.0.0 из официального репозитория FreeSWITCH: `https://github.com/freeswitch/spandsp`

### 🔧 **Что изменилось:**

#### 📦 **SpanDSP 3.0.0 собирается из исходного кода:**
```bash
# 1. Клонируем официальный репозиторий
git clone https://github.com/freeswitch/spandsp.git

# 2. Собираем и устанавливаем
./bootstrap && ./configure --prefix=/usr/local
make -j$(nproc) && make install
```

#### 🔄 **FreeSWITCH с полной поддержкой SpanDSP:**
- ✅ `--enable-mod-spandsp` - поддержка DSP функций
- ✅ `--enable-mod-fax` - поддержка факсов  
- ✅ `--enable-mod-t38gateway` - поддержка T.38 факсов
- ✅ `--with-spandsp=/usr/local` - указание пути к SpanDSP

#### 📚 **Добавленные зависимости:**
- `libtiff-dev` - для работы с изображениями факсов
- `libaudiofile-dev` - аудио файлы
- `libfftw3-dev` - математические преобразования FFT
- **`libsofia-sip-ua-dev`** - SIP протокол (КРИТИЧЕСКИ ВАЖНО!)

### ✅ **Полная функциональность восстановлена:**
- ✅ Event Socket Library (порт 8021) 
- ✅ **SIP протокол (Sofia-SIP)** 
- ✅ Аудиокодеки (G.722, G.729, Speex, Opus)
- ✅ **T.38 факсы** 
- ✅ **DSP модуль SpanDSP**
- ✅ **Расширенные аудио функции**

### 🚀 **Для развертывания на сервере:**

```bash
# 1. Обновляем код
git pull

# 2. Очищаем Docker (ВАЖНО!)
docker system prune -f

# 3. Собираем новый образ FreeSWITCH (45-50 минут)
docker compose build freeswitch

# 4. Запускаем систему
docker compose up -d
```

### ⏱️ **Время сборки:**
- SpanDSP: ~10-15 минут
- FreeSWITCH: ~35-40 минут  
- **Общее время: ~50-55 минут**

### 🛡️ **Безопасность:**
- ✅ Компиляция из официальных исходников FreeSWITCH
- ✅ Нет зависимости от сторонних Docker образов
- ✅ Полный контроль над процессом сборки
- ✅ Проверенная совместимость SpanDSP и FreeSWITCH

---

## 📋 **История проблемы:**

### 🐛 **Первоначальная проблема:**
```
configure: error: *** *** SpanDSP >= 3.0.0 required ***
```

### 🐛 **Вторая проблема:**
```
configure: error: no usable sofia-sip; please install sofia-sip-ua devel package or equivalent
```

### ❌ **Неудачные попытки:**
1. Поиск пакетов SpanDSP в Debian 12 - не найдены
2. Отключение модулей SpanDSP - потеря функциональности
3. Попытки установки из старых репозиториев - конфликты версий

### ✅ **Успешное решение:**
Использование официального репозитория SpanDSP от FreeSWITCH + добавление Sofia-SIP обеспечивает:
- 🎯 Точную совместимость версий
- 🔧 Полную функциональность
- 🛡️ Максимальную безопасность
- ⚡ Стабильную работу

**Создано командой Dailer для обеспечения безопасности и стабильности системы автодозвона.** 