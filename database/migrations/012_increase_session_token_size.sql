-- Миграция для увеличения размера поля session_token
-- JWT токены могут быть довольно длинными, особенно с дополнительными данными

-- Увеличиваем размер поля session_token с 255 до 1000 символов
ALTER TABLE users ALTER COLUMN session_token TYPE VARCHAR(1000);

-- Комментарий для документации
COMMENT ON COLUMN users.session_token IS 'JWT токен текущей сессии пользователя (до 1000 символов)'; 