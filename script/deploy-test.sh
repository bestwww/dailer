#!/bin/bash

# Скрипт для деплоя на тестовый сервер
# Использование: ./deploy-test.sh

set -e

echo "🚀 Начинаем деплой на тестовый сервер..."

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция для вывода с цветом
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка что мы в правильной директории
if [ ! -f "docker-compose.yml" ]; then
    print_error "docker-compose.yml не найден. Запустите скрипт из корневой директории проекта."
    exit 1
fi

# Остановка контейнеров
print_status "Остановка контейнеров..."
docker-compose down

# Получение последних изменений
print_status "Получение изменений из git..."
git pull origin main

# Проверка наличия .env файла
if [ ! -f ".env" ]; then
    print_warning ".env файл не найден. Копируем из .env.production..."
    cp .env.production .env
else
    print_status ".env файл найден."
fi

# Проверка ключевых переменных окружения
if ! grep -q "VITE_API_URL=http://46.173.16.147:3000/api" .env; then
    print_warning "VITE_API_URL может быть настроен неправильно. Проверьте .env файл."
fi

# Сборка и запуск контейнеров
print_status "Сборка и запуск контейнеров..."
docker-compose up -d --build

# Ожидание запуска сервисов
print_status "Ожидание запуска сервисов..."
sleep 10

# Проверка статуса контейнеров
print_status "Проверка статуса контейнеров..."
docker-compose ps

# Проверка логов на наличие ошибок
print_status "Проверка логов backend..."
if docker-compose logs backend | grep -i error | tail -5; then
    print_warning "Найдены ошибки в логах backend. Проверьте полные логи: docker-compose logs backend"
fi

print_status "Проверка логов frontend..."
if docker-compose logs frontend | grep -i error | tail -5; then
    print_warning "Найдены ошибки в логах frontend. Проверьте полные логи: docker-compose logs frontend"
fi

# Проверка доступности сервисов
print_status "Проверка доступности сервисов..."

# Проверка backend
if curl -s -f http://localhost:3000/api/health > /dev/null 2>&1; then
    print_status "✅ Backend API доступен"
else
    print_warning "⚠️  Backend API может быть недоступен"
fi

# Проверка frontend
if curl -s -f http://localhost:5173 > /dev/null 2>&1; then
    print_status "✅ Frontend доступен"
else
    print_warning "⚠️  Frontend может быть недоступен"
fi

echo ""
print_status "🎉 Деплой завершен!"
echo ""
print_status "📍 Ссылки для проверки:"
echo "   Frontend: http://46.173.16.147:5173"
echo "   Backend API: http://46.173.16.147:3000/api"
echo ""
print_status "📋 Команды для отладки:"
echo "   Логи всех сервисов: docker-compose logs -f"
echo "   Логи backend: docker-compose logs -f backend"
echo "   Логи frontend: docker-compose logs -f frontend"
echo "   Перезапуск: docker-compose restart"
echo "   Остановка: docker-compose down"
echo ""

# Проверка переменных окружения в контейнере (если контейнер запущен)
if docker ps | grep -q dialer_frontend; then
    print_status "Проверка переменных окружения в frontend контейнере:"
    docker exec dialer_frontend env | grep VITE || print_warning "VITE переменные не найдены"
fi 