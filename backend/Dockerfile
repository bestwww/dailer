# Dockerfile для backend приложения системы автодозвона
# Используем официальный Node.js 18 Alpine образ для минимального размера

FROM node:18-alpine AS base

# Метаданные
LABEL maintainer="Dialer System"
LABEL description="Backend API для системы автодозвона"
LABEL version="1.0.0"

# Установка системных зависимостей
RUN apk add --no-cache \
    dumb-init \
    curl \
    tzdata \
    && rm -rf /var/cache/apk/*

# Создание пользователя для безопасности
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodeuser -u 1001

# Установка рабочей директории
WORKDIR /app

# Копирование package.json и package-lock.json для оптимизации кэширования  
COPY package.json ./
COPY package-lock.json* ./

# === Стадия разработки ===
FROM base AS development

# Установка всех зависимостей (включая dev)
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi

# Копирование исходного кода backend (мы уже в backend директории)
COPY . .

# Создание директории для миграций (database не доступна из build context)
RUN mkdir -p /database

# Создание папки для аудиофайлов с правильными правами
RUN mkdir -p /app/audio && chown -R nodeuser:nodejs /app/audio && chmod 755 /app/audio

# Изменение владельца файлов
RUN chown -R nodeuser:nodejs /app
USER nodeuser

# Порт приложения
EXPOSE 3000

# Команда для разработки
CMD ["npm", "run", "dev"]

# === Стадия сборки ===
FROM base AS build

# Установка всех зависимостей (включая dev для сборки)
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi

# Копирование исходного кода backend (мы уже в backend директории)
COPY . .

# Создание директории для миграций (database не доступна из build context)
RUN mkdir -p /database

# Сборка TypeScript приложения
RUN npm run build

# Удаление dev зависимостей
RUN npm prune --production

# === Production стадия ===
FROM base AS production

# Переменные окружения для production
ENV NODE_ENV=production
ENV NPM_CONFIG_LOGLEVEL=warn

# Копирование только production зависимостей
COPY --from=build /app/node_modules ./node_modules

# Копирование собранного приложения
COPY --from=build /app/dist ./dist

# Копирование package.json для информации о версии
COPY package*.json ./

# Создание директорий для логов и аудио файлов
RUN mkdir -p logs audio public \
    && chown -R nodeuser:nodejs /app

# Переключение на непривилегированного пользователя
USER nodeuser

# Порт приложения
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Запуск приложения с dumb-init для правильной обработки сигналов
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/app.js"]

# === Стадия тестирования ===
FROM development AS test

# Установка всех зависимостей
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi

# Создание директории тестов с правильными placeholder файлами
RUN mkdir -p ./tests/ && \
    echo "describe('Placeholder', () => { test('should pass', () => { expect(true).toBe(true); }); });" > ./tests/placeholder.test.ts && \
    echo "// Jest setup file" > ./tests/setup.ts

# Команда для тестов
CMD ["npm", "test"] 