# 🔧 Решение git merge конфликта

## 🚨 Проблема
При выполнении `git pull origin main` на тестовом сервере возникает ошибка:
```
error: The following untracked working tree files would be overwritten by merge:
        sync-server-updates.sh
Please move or remove them before you merge.
Aborting
```

## ✅ Быстрое решение

### Вариант 1: Автоматическое решение (рекомендуется)
```bash
# Сначала получите скрипт решения проблемы
curl -O https://raw.githubusercontent.com/bestwww/dailer/main/fix-git-merge-conflict.sh
chmod +x fix-git-merge-conflict.sh

# Запустите скрипт
./fix-git-merge-conflict.sh
```

### Вариант 2: Ручное решение
```bash
# 1. Удалите проблемный файл (создав резервную копию если нужно)
mv sync-server-updates.sh sync-server-updates.sh.backup

# 2. Выполните git pull
git pull origin main

# 3. Если есть другие неотслеживаемые файлы
git clean -fd  # Удалит все неотслеживаемые файлы
```

### Вариант 3: Принудительное обновление (ОСТОРОЖНО!)
```bash
# Это удалит все локальные изменения!
git reset --hard origin/main
git pull origin main
```

## 🚀 После решения проблемы

Выполните обновление системы:
```bash
# 1. Перезапустите FreeSWITCH
docker-compose restart freeswitch_host

# 2. Проверьте SIP подключение
./diagnose-sip-detailed.sh
```

## 🔍 Проверка результата

Убедитесь что git pull прошел успешно:
```bash
git status
# Должно показывать: "Your branch is up to date with 'origin/main'"
```

## 📝 Что делать дальше

После успешного обновления кода:
1. Проверьте что все контейнеры работают: `docker ps`
2. Перезапустите FreeSWITCH: `docker-compose restart freeswitch_host`
3. Запустите диагностику SIP: `./diagnose-sip-detailed.sh`
4. Протестируйте звонки через систему автодозвона

## ⚠️ Предотвращение в будущем

Чтобы избежать подобных проблем:
1. Не создавайте файлы в корневой директории проекта
2. Используйте `.gitignore` для исключения временных файлов
3. Регулярно выполняйте `git status` перед `git pull` 