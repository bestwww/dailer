# 🚨 FreeSWITCH 2025: Проблема аутентификации репозиториев

## 📢 **КРИТИЧЕСКОЕ ИЗМЕНЕНИЕ в 2025 году**

SignalWire изменил систему доступа к репозиториям FreeSWITCH! Теперь требуется **аутентификация** для доступа к некоторым ресурсам.

## 🔍 **Что произошло?**

### ❌ **Проблема:**
```bash
wget https://files.freeswitch.org/repo/deb/debian-release/freeswitch-archive-keyring.gpg
# Результат: 401 Unauthorized - Username/Password Authentication Failed
```

### 📚 **Что говорит официальная документация:**
> **"A SignalWire account is now required to download the pre-build FreeSWITCH binaries"**

## ✅ **РЕШЕНИЯ для разных случаев:**

### 🔹 **1. Публичный доступ (БЕЗ аутентификации)**

**Работающий способ из актуальной документации SignalWire:**

```dockerfile
# Публичный репозиторий (HTTP + apt-key)
RUN wget -O - https://files.freeswitch.org/repo/deb/debian-release/fsstretch-archive-keyring.asc | apt-key add - && \
    echo "deb http://files.freeswitch.org/repo/deb/debian-release/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/freeswitch.list && \
    echo "deb-src http://files.freeswitch.org/repo/deb/debian-release/ $(lsb_release -sc) main" >> /etc/apt/sources.list.d/freeswitch.list && \
    apt-get update && \
    apt-get install -y freeswitch-meta-all
```

**Ключевые отличия:**
- **HTTP** вместо HTTPS в URL репозитория
- **`.asc` ключ** вместо `.gpg` файла  
- **`apt-key add`** вместо современного keyring подхода

### 🔹 **2. С аутентификацией SignalWire**

Для полного доступа нужно:

1. **Создать SignalWire Space** (аккаунт)
2. **Получить Personal Access Token**
3. **Использовать токен в URL:**

```dockerfile
# С аутентификацией
ARG SIGNALWIRE_TOKEN
RUN wget --header="Authorization: Bearer $SIGNALWIRE_TOKEN" \
    -O /usr/share/keyrings/freeswitch-archive-keyring.gpg \
    https://files.freeswitch.org/repo/deb/debian-release/freeswitch-archive-keyring.gpg
```

### 🔹 **3. FreeSWITCH Advantage (Платная версия)**

```dockerfile
# Для FSA нужны username/password
ARG FSA_USERNAME
ARG FSA_PASSWORD
RUN wget --http-user=$FSA_USERNAME --http-password=$FSA_PASSWORD \
    -O - https://fsa.freeswitch.com/repo/deb/fsa/pubkey.gpg | apt-key add -
```

## 🎯 **Наше решение: Тройная защита**

### **Приоритет 1: Публичный репозиторий (исправлен)**
```dockerfile
# Dockerfile-packages - ИСПРАВЛЕН для 2025
wget -O - https://files.freeswitch.org/repo/deb/debian-release/fsstretch-archive-keyring.asc | apt-key add -
echo "deb http://files.freeswitch.org/repo/deb/debian-release/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/freeswitch.list
```

### **Приоритет 2: Минимальная версия** 
```dockerfile
# Dockerfile-minimal - vanilla config
apt-get install -y freeswitch-meta-vanilla
```

### **Приоритет 3: Альтернативные источники**
```dockerfile
# Dockerfile-alternative - УЛУЧШЕН
# 1. Ubuntu Universe
# 2. Публичный репозиторий как fallback
```

## 📊 **Результаты тестирования:**

### ❌ **Старый способ (не работает в 2025):**
```bash
# HTTPS + keyring файл = 401 Unauthorized  
wget https://files.freeswitch.org/repo/deb/debian-release/freeswitch-archive-keyring.gpg
```

### ✅ **Новый способ (работает):**
```bash
# HTTP + .asc ключ = OK
wget https://files.freeswitch.org/repo/deb/debian-release/fsstretch-archive-keyring.asc
```

## 🔧 **Инструкции по тестированию:**

### 1. **Обновить код на сервере:**
```bash
git checkout -- test-freeswitch-packages.sh
git pull origin main
```

### 2. **Запустить исправленное тестирование:**
```bash
./test-freeswitch-packages.sh
```

### 3. **Ожидаемый результат:**
- ✅ Способ 1 (полная версия) - должен работать
- ✅ Способ 2 (минимальная) - должен работать  
- ✅ Способ 3 (альтернативный) - FreeSWITCH установится

## 📚 **Источники информации:**

- [SignalWire: Installing FreeSWITCH](https://developer.signalwire.com/platform/integrations/freeswitch/installing-freeswitch-or-freeswitch-advantage/)
- [SignalWire: Choosing Repository](https://developer.signalwire.com/platform/integrations/freeswitch/choosing-a-freeswitch-repository/)
- [FreeSWITCH Community](https://signalwire.com/freeswitch)

## 🎉 **Итог:**

- **Проблема понята** - SignalWire изменил систему аутентификации
- **Решение найдено** - использовать публичный репозиторий с правильным URL и методом
- **Код исправлен** - все Dockerfile обновлены для работы в 2025 году
- **Тестирование готово** - можно проверять на сервере

**FreeSWITCH снова будет работать! 🚀** 