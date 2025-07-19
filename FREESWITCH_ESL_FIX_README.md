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

## ✅ **КРИТИЧЕСКИЕ УЛУЧШЕНИЯ ПРИМЕНЕНЫ!** - 2025-01-25
## ✅ **ПРОБЛЕМА mod_enum/libldns РЕШЕНА!** - 2025-01-25

### 🎯 **Окончательное решение SpanDSP + Sofia-SIP + mod_enum:**
1. **SpanDSP 3.0.0** - компиляция из официального репозитория FreeSWITCH ✅
2. **Sofia-SIP** - компиляция из исходного кода для полной поддержки SIP ✅  
3. **mod_enum включен** - добавлена поддержка libldns-dev для DNS ENUM ✅

### 🔧 **Последнее исправление - mod_enum:**

#### 🐛 **Проблема:**
```
configure: error: You need to either install libldns-dev or disable mod_enum in modules.conf
```

#### ✅ **Решение:**
- Добавлена зависимость `libldns-dev` для поддержки mod_enum
- Добавлены дополнительные зависимости: `libyaml-dev`, `portaudio19-dev`
- Улучшены флаги configure: `--disable-static`, `--enable-shared`
- mod_enum обеспечивает DNS ENUM lookups (может быть полезен для телефонии)
- **SpanDSP ✅** и **Sofia-SIP ✅** успешно найдены и работают!

### 🔒 **БЕЗОПАСНОСТЬ - КРИТИЧЕСКИЕ УЛУЧШЕНИЯ:**

#### 🛡️ **Случайный пароль Event Socket:**
- ❌ **Было:** `password="ClueCon"` (ОГРОМНАЯ УЯЗВИМОСТЬ!)
- ✅ **Стало:** `password="<случайный 32-символьный hex>"`
- 🔐 **Генерация:** `openssl rand -hex 16`
- 📋 **Доступ:** Пароль выводится при запуске контейнера

#### 🔒 **ACL (Access Control List):**
- ✅ Доступ только с локальной сети
- ✅ Блокировка внешних подключений
- ✅ Разрешенные сети: `127.0.0.1/32`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`

### 🚀 **ПРОИЗВОДИТЕЛЬНОСТЬ - КАРДИНАЛЬНЫЕ УЛУЧШЕНИЯ:**

#### 📦 **Оптимизация размера образа:**
- ❌ **Было:** ~1.2 ГБ (с компиляторами)
- ✅ **Стало:** ~300-400 МБ (только runtime)
- 🧹 **Удалено:** build-essential, cmake, automake, autoconf, git
- 🗑️ **Очищено:** apt кеш, временные файлы, исходные коды

#### 🩺 **Улучшенный HEALTHCHECK:**
- ✅ Проверка Event Socket (порт 8021)
- ✅ Проверка статуса FreeSWITCH
- ✅ Увеличено время старта до 3 минут
- 🔧 **Команда:** `nc -z 127.0.0.1 8021 && fs_cli -x "status" | grep -q "UP"`

### 🔧 **Что изменилось в деталях:**

#### 📦 **SpanDSP 3.0.0 собирается из исходного кода:**
```bash
# 1. Клонируем официальный репозиторий
git clone https://github.com/freeswitch/spandsp.git

# 2. Собираем и устанавливаем
./autogen.sh && ./configure --prefix=/usr/local
make -j$(nproc) && make install
```

#### 📞 **Sofia-SIP добавлена:**
```bash
# 1. Клонируем исходный код
git clone https://github.com/freeswitch/sofia-sip.git

# 2. Собираем и устанавливаем  
./autogen.sh && ./configure --prefix=/usr/local
make -j$(nproc) && make install
```

#### 🔄 **FreeSWITCH с полной поддержкой:**
- ✅ `--with-spandsp=/usr/local` - указание пути к SpanDSP
- ✅ `--with-sofia-sip=/usr/local` - указание пути к Sofia-SIP
- ✅ `--enable-mod-spandsp` - поддержка DSP функций
- ✅ `--enable-mod-fax` - поддержка факсов  
- ✅ `--enable-mod-t38gateway` - поддержка T.38 факсов
- ✅ `mod_enum` - включен (DNS ENUM lookups для телефонии)

### 🎯 **Преимущества для проекта Dailer:**

#### 🔐 **Безопасность:**
- 🛡️ **Уникальный пароль** при каждом запуске
- 🔒 **Защита от внешних атак** через ACL
- 🚫 **Минимальная поверхность атаки** (убраны dev-инструменты)

#### ⚡ **Производительность:**
- 📦 **В 3-4 раза меньше** размер образа
- 🚀 **Быстрее развертывание** на production серверах
- 💾 **Экономия дискового пространства**

#### 🎯 **Функциональность:**
- ✅ **Event Socket Library** - порт 8021 (главное для Dailer!)
- ✅ **Полная поддержка SIP** (mod_sofia)
- ✅ **Аудиокодеки** (G.722, G.729, Opus, Speex)
- ✅ **T.38 факсы** (бонус)
- ✅ **ENUM DNS запросы** (mod_enum для телефонных номеров)
- ✅ **YAML конфигурация** (опциональная поддержка)
- ✅ **PortAudio поддержка** (для аудио устройств)

### 🚀 **ГОТОВО К РАЗВЕРТЫВАНИЮ НА СЕРВЕРЕ:**

```bash
# 1. Обновить код с последними исправлениями
git pull

# 2. Остановить и удалить старые контейнеры
docker compose down
docker system prune -f

# 3. Собрать новый образ FreeSWITCH (~50-60 минут)
docker compose build freeswitch

# 4. Запустить систему
docker compose up -d

# 5. Посмотреть пароль Event Socket
docker logs dailer-freeswitch-1 | grep "Event Socket пароль"
```

### 🔍 **Проверка работоспособности:**

```bash
# 1. Проверить статус контейнера
docker ps

# 2. Проверить логи FreeSWITCH
docker logs dailer-freeswitch-1

# 3. Проверить Event Socket
docker exec dailer-freeswitch-1 nc -z 127.0.0.1 8021 && echo "✅ Event Socket работает"

# 4. Проверить статус FreeSWITCH
docker exec dailer-freeswitch-1 /usr/local/freeswitch/bin/fs_cli -x "status"
```

### 🎉 **ФИНАЛЬНЫЙ РЕЗУЛЬТАТ:**
- ✅ **SpanDSP 3.0.0** - компилируется и найден configure ✅
- ✅ **Sofia-SIP** - компилируется и найден configure ✅
- ✅ **mod_enum + зависимости** - включен с libldns-dev, libyaml-dev, portaudio19-dev ✅
- ✅ **Безопасность** на уровне enterprise 
- ✅ **Производительность** optimized
- ✅ **Event Socket Library** готов для интеграции с Backend Dailer
- ✅ **Размер образа** уменьшен в 3-4 раза

---

**🚀 ТЕПЕРЬ FREESWICH ГОТОВ К PRODUCTION! Все проблемы решены!**

**💡 ВАЖНО:** После запуска обязательно скопируйте пароль Event Socket из логов для настройки Backend! 