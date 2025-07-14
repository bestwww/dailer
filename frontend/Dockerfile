# Multi-stage Dockerfile для Vue.js приложения

# Development stage
FROM node:18-alpine AS development

WORKDIR /app

# Копируем package файлы (и package.json и package-lock.json если есть)
COPY package.json ./
COPY package-lock.json* ./

# Устанавливаем зависимости (используем npm ci если есть lock файл, иначе npm install)
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi

# Копируем исходный код
COPY . .

# Открываем порт для Vite dev server
EXPOSE 5173

# Запускаем dev server с привязкой к 0.0.0.0
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0", "--port", "5173"]

# Production build stage
FROM node:18-alpine AS builder

WORKDIR /app

# Копируем package файлы (и package.json и package-lock.json если есть)
COPY package.json ./
COPY package-lock.json* ./

# Устанавливаем зависимости (используем npm ci если есть lock файл, иначе npm install)
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi

# Копируем исходный код
COPY . .

# Собираем production версию
RUN npm run build

# Production stage
FROM nginx:alpine AS production

# Копируем собранные файлы
COPY --from=builder /app/dist /usr/share/nginx/html

# Создаем конфигурацию nginx
RUN echo 'server {\
    listen 80;\
    server_name localhost;\
    root /usr/share/nginx/html;\
    index index.html;\
\
    location / {\
        try_files $uri $uri/ /index.html;\
    }\
\
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {\
        expires 1y;\
        add_header Cache-Control "public, immutable";\
    }\
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"] 