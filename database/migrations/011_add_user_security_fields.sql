-- Миграция для добавления полей безопасности в таблицу users
-- Добавляет поля для отслеживания попыток входа, блокировки и двухфакторной аутентификации

-- Добавляем поля для отслеживания попыток входа
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS login_attempts INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS lockout_until TIMESTAMP,
ADD COLUMN IF NOT EXISTS password_changed_at TIMESTAMP DEFAULT NOW();

-- Добавляем поля для двухфакторной аутентификации
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS two_factor_secret VARCHAR(255),
ADD COLUMN IF NOT EXISTS two_factor_enabled BOOLEAN DEFAULT false;

-- Добавляем поле для хранения токена сессии
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS session_token VARCHAR(255);

-- Создаем индексы для полей безопасности
CREATE INDEX IF NOT EXISTS idx_users_login_attempts ON users(login_attempts);
CREATE INDEX IF NOT EXISTS idx_users_lockout_until ON users(lockout_until);
CREATE INDEX IF NOT EXISTS idx_users_session_token ON users(session_token);
CREATE INDEX IF NOT EXISTS idx_users_two_factor_enabled ON users(two_factor_enabled);

-- Комментарии для документации
COMMENT ON COLUMN users.login_attempts IS 'Количество неуспешных попыток входа';
COMMENT ON COLUMN users.lockout_until IS 'Время до которого пользователь заблокирован';
COMMENT ON COLUMN users.password_changed_at IS 'Время последнего изменения пароля';
COMMENT ON COLUMN users.two_factor_secret IS 'Секретный ключ для двухфакторной аутентификации';
COMMENT ON COLUMN users.two_factor_enabled IS 'Включена ли двухфакторная аутентификация';
COMMENT ON COLUMN users.session_token IS 'Токен текущей сессии пользователя'; 