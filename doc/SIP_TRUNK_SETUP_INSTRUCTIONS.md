# 🔗 Инструкция по настройке SIP транка 62.141.121.197:5070

## 📋 Обзор

Настроен SIP транк для подключения FreeSWITCH к провайдеру:
- **IP**: 62.141.121.197
- **Порт**: 5070
- **Тип подключения**: Peer-to-peer (без аутентификации)
- **Протокол**: UDP

## 🚀 Быстрое применение на тестовом сервере

### Шаг 1: Обновление кода
```bash
# На тестовом сервере
cd /path/to/dailer
git pull origin main
```

### Шаг 2: Перезапуск FreeSWITCH с новой конфигурацией
```bash
# Остановить FreeSWITCH
docker-compose stop freeswitch

# Запустить с новой конфигурацией
docker-compose up -d freeswitch

# Проверить статус
docker logs dialer_freeswitch --tail=20
```

### Шаг 3: Тестирование подключения
```bash
# Полный тест SIP транка
./test-sip-trunk.sh test

# Или пошагово:
./test-sip-trunk.sh check      # Проверка FreeSWITCH и сети
./test-sip-trunk.sh sofia      # Проверка конфигурации Sofia SIP
./test-sip-trunk.sh call 79001234567  # Тестовый звонок
```

## ⚙️ Что было настроено

### 1. Sofia SIP Gateway
**Файл**: `freeswitch/conf/autoload_configs/sofia.conf.xml`

```xml
<gateway name="sip_trunk">
  <!-- Основные настройки подключения -->
  <param name="proxy" value="62.141.121.197:5070"/>
  <param name="realm" value="62.141.121.197"/>
  <param name="register" value="false"/>
  
  <!-- Без аутентификации (peer-to-peer) -->
  <param name="username" value=""/>
  <param name="password" value=""/>
  <param name="from-user" value="freeswitch"/>
  <param name="from-domain" value="62.141.121.197"/>
</gateway>
```

### 2. Dialplan маршрутизация
**Файл**: `freeswitch/conf/dialplan/default.xml`

Добавлен маршрут для исходящих звонков:
```xml
<extension name="outbound_calls">
  <condition field="destination_number" expression="^(\+?[1-9]\d{6,14})$">
    <action application="bridge" data="sofia/gateway/sip_trunk/${destination_number}"/>
  </condition>
</extension>
```

### 3. Переменные Caller ID
**Файл**: `freeswitch/conf/vars.xml`

```xml
<X-PRE-PROCESS cmd="set" data="outbound_caller_id_name=AutoDialer"/>
<X-PRE-PROCESS cmd="set" data="outbound_caller_id_number=+70000000000"/>
```

## 🔍 Диагностика проблем

### Проблема: Gateway не регистрируется
```bash
# Проверить статус gateway
docker exec dialer_freeswitch fs_cli -x "sofia status gateway sip_trunk"

# Перезагрузить конфигурацию
./test-sip-trunk.sh reload
```

### Проблема: Сетевая недоступность
```bash
# Проверить доступность IP
ping -c 3 62.141.121.197

# Проверить порт (может не отвечать, это нормально для SIP)
nc -z -v -w5 62.141.121.197 5070
```

### Проблема: Звонки не проходят
```bash
# Проверить маршрутизацию в dialplan
./test-sip-trunk.sh diagnose

# Мониторинг SIP трафика
./test-sip-trunk.sh monitor
```

## 📞 Тестирование звонков

### Ручное тестирование через fs_cli
```bash
# Подключиться к FreeSWITCH CLI
docker exec -it dialer_freeswitch fs_cli

# Выполнить тестовый звонок
originate sofia/gateway/sip_trunk/79001234567 &echo

# Посмотреть статус каналов
show channels

# Выйти из CLI
exit
```

### Автоматическое тестирование
```bash
# Тест звонка на конкретный номер
./test-sip-trunk.sh call 79001234567

# Полный тест с несколькими номерами
./test-sip-trunk.sh test
```

## 🛠️ Возможные проблемы и решения

### 1. **Аутентификация требуется**
**Симптомы**: 401/403 ошибки
**Решение**: Уточните у провайдера username/password и обновите конфигурацию:

```xml
<param name="username" value="your_username"/>
<param name="password" value="your_password"/>
<param name="register" value="true"/>
```

### 2. **Неправильный формат номеров**
**Симптомы**: "No route destination" ошибки
**Решение**: Уточните требуемый формат номеров (с +7, без +7, с 8 и т.д.)

### 3. **Codec несовместимость**
**Симптомы**: Звонки соединяются но нет звука
**Решение**: Уточните поддерживаемые codecs и обновите конфигурацию

### 4. **NAT проблемы**
**Симптомы**: Односторонний звук
**Решение**: Настройте правильные внешние IP адреса в vars.xml

### 5. **Блокировка портов**
**Симптомы**: Timeout при соединении
**Решение**: Проверьте firewall и откройте порты:
- 5070/UDP для SIP
- 16384-16394/UDP для RTP

## 📊 Мониторинг

### Логи FreeSWITCH
```bash
# Текущие логи
docker logs -f dialer_freeswitch

# Логи за последний час
docker logs dialer_freeswitch --since=1h | grep -i sip
```

### SIP трейсинг
```bash
# Включить детальное логирование SIP
docker exec dialer_freeswitch fs_cli -x "sofia global siptrace on"

# Выключить трейсинг
docker exec dialer_freeswitch fs_cli -x "sofia global siptrace off"
```

### Статистика звонков
```bash
# Активные каналы
docker exec dialer_freeswitch fs_cli -x "show channels"

# Статистика по gateway
docker exec dialer_freeswitch fs_cli -x "sofia status gateway sip_trunk"
```

## 🔄 Обновление конфигурации

Если нужно изменить настройки SIP транка:

1. **Отредактируйте конфигурацию** в соответствующих файлах
2. **Перезагрузите конфигурацию**:
   ```bash
   ./test-sip-trunk.sh reload
   ```
3. **Протестируйте изменения**:
   ```bash
   ./test-sip-trunk.sh test
   ```

## 📞 Интеграция с автодозвоном

После успешного тестирования SIP транка, система автодозвона будет автоматически использовать его для исходящих звонков. 

Убедитесь что в переменных окружения backend указаны правильные значения:
```env
SIP_PROVIDER_HOST=62.141.121.197
SIP_PROVIDER_PORT=5070
SIP_CALLER_ID_NUMBER=+70000000000
```

## ✅ Контрольный список

- [ ] Код обновлен на тестовом сервере
- [ ] FreeSWITCH перезапущен с новой конфигурацией
- [ ] Gateway "sip_trunk" загружен и доступен
- [ ] Сетевая доступность 62.141.121.197:5070 проверена
- [ ] Тестовые звонки проходят успешно
- [ ] Логи FreeSWITCH не содержат критических ошибок
- [ ] Интеграция с автодозвоном протестирована

## 📞 Следующие шаги

1. **Получить дополнительную информацию от провайдера**:
   - Требуется ли аутентификация?
   - Какой формат номеров использовать?
   - Какие codecs поддерживаются?
   - Есть ли особые требования к Caller ID?

2. **Протестировать с реальными номерами**:
   - Попробовать звонки на мобильные номера
   - Проверить качество звука
   - Убедиться в корректности Caller ID

3. **Оптимизировать настройки**:
   - Настроить подходящие таймауты
   - Оптимизировать codec настройки
   - Настроить правильные форматы номеров

---

**💡 Важно**: Если SIP транк требует специальную аутентификацию или имеет особые требования, обязательно свяжитесь с провайдером для получения полной документации. 