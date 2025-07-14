-- Инициализация схемы базы данных для системы автодозвона
-- Создание таблиц для кампаний, контактов и результатов звонков

-- Включаем расширения PostgreSQL
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Таблица кампаний автодозвона
CREATE TABLE IF NOT EXISTS campaigns (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    
    -- Настройки аудио
    audio_file_path VARCHAR(500),
    audio_file_name VARCHAR(255),
    audio_duration INTEGER DEFAULT 0, -- в секундах
    
    -- Статус кампании
    status VARCHAR(50) DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'paused', 'completed', 'cancelled')),
    
    -- Настройки обзвона
    max_concurrent_calls INTEGER DEFAULT 5,
    calls_per_minute INTEGER DEFAULT 30,
    retry_attempts INTEGER DEFAULT 3,
    retry_delay INTEGER DEFAULT 300, -- в секундах
    
    -- Настройки времени работы
    work_time_start TIME DEFAULT '09:00:00',
    work_time_end TIME DEFAULT '18:00:00',
    work_days INTEGER[] DEFAULT ARRAY[1,2,3,4,5], -- дни недели (1=понедельник)
    timezone VARCHAR(50) DEFAULT 'Europe/Moscow',
    
    -- Битрикс24 интеграция
    bitrix_create_leads BOOLEAN DEFAULT true,
    bitrix_responsible_id INTEGER,
    bitrix_source_id VARCHAR(50) DEFAULT 'CALL',
    
    -- Метаданные
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    created_by INTEGER,
    
    -- Статистика (денормализация для быстрого доступа)
    total_contacts INTEGER DEFAULT 0,
    completed_calls INTEGER DEFAULT 0,
    successful_calls INTEGER DEFAULT 0,
    failed_calls INTEGER DEFAULT 0,
    interested_responses INTEGER DEFAULT 0,
    
    -- Индексы для поиска
    UNIQUE(name)
);

-- Таблица контактов для кампаний
CREATE TABLE IF NOT EXISTS contacts (
    id SERIAL PRIMARY KEY,
    campaign_id INTEGER NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
    
    -- Контактная информация
    phone VARCHAR(20) NOT NULL,
    name VARCHAR(255),
    email VARCHAR(255),
    company VARCHAR(255),
    
    -- Статус обработки
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'calling', 'completed', 'failed', 'blacklisted', 'do_not_call')),
    
    -- Попытки звонков
    call_attempts INTEGER DEFAULT 0,
    last_call_at TIMESTAMP,
    next_call_at TIMESTAMP,
    
    -- Результат последнего звонка
    last_call_result VARCHAR(50),
    last_call_duration INTEGER,
    last_dtmf_response VARCHAR(10),
    
    -- Флаги
    is_answering_machine BOOLEAN DEFAULT false,
    is_interested BOOLEAN DEFAULT false,
    
    -- Битрикс24 интеграция
    bitrix_lead_id INTEGER,
    bitrix_contact_id INTEGER,
    
    -- Дополнительные данные (JSON для гибкости)
    additional_data JSONB DEFAULT '{}',
    
    -- Метаданные
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    imported_at TIMESTAMP DEFAULT NOW(),
    
    -- Индексы для оптимизации запросов
    UNIQUE(campaign_id, phone)
);

-- Таблица результатов звонков (детальная история)
CREATE TABLE IF NOT EXISTS call_results (
    id SERIAL PRIMARY KEY,
    contact_id INTEGER NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
    campaign_id INTEGER NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
    
    -- Информация о звонке
    call_uuid VARCHAR(255), -- UUID звонка от FreeSWITCH
    phone_number VARCHAR(20) NOT NULL,
    
    -- Результаты звонка
    call_status VARCHAR(50) NOT NULL CHECK (call_status IN ('answered', 'busy', 'no_answer', 'failed', 'cancelled', 'blacklisted')),
    call_duration INTEGER DEFAULT 0, -- в секундах
    ring_duration INTEGER DEFAULT 0, -- время до ответа
    
    -- DTMF ответ пользователя
    dtmf_response VARCHAR(10),
    dtmf_timestamp TIMESTAMP,
    
    -- AMD результаты
    is_answering_machine BOOLEAN DEFAULT false,
    amd_confidence DECIMAL(3,2), -- уверенность AMD (0.00-1.00)
    amd_detection_time INTEGER, -- время обнаружения в мс
    
    -- Битрикс24 интеграция
    bitrix_lead_id INTEGER,
    bitrix_lead_created BOOLEAN DEFAULT false,
    bitrix_error TEXT,
    
    -- Аудио записи (если включены)
    recording_file_path VARCHAR(500),
    recording_duration INTEGER,
    
    -- Технические данные
    caller_id_name VARCHAR(255),
    caller_id_number VARCHAR(20),
    hangup_cause VARCHAR(100),
    
    -- Качество звонка
    audio_quality_score DECIMAL(3,2),
    network_quality VARCHAR(20),
    
    -- Дополнительные данные
    additional_data JSONB DEFAULT '{}',
    
    -- Метаданные
    created_at TIMESTAMP DEFAULT NOW(),
    call_started_at TIMESTAMP,
    call_answered_at TIMESTAMP,
    call_ended_at TIMESTAMP
);

-- Таблица для черного списка номеров (создается в миграции 005)
-- CREATE TABLE IF NOT EXISTS blacklist (...) - перенесено в 005_create_blacklist_table.sql

-- Таблица пользователей системы
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    
    -- Роли и права
    role VARCHAR(50) DEFAULT 'user' CHECK (role IN ('admin', 'manager', 'user', 'viewer')),
    permissions JSONB DEFAULT '{}',
    
    -- Информация о пользователе
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(20),
    
    -- Статус аккаунта
    is_active BOOLEAN DEFAULT true,
    is_verified BOOLEAN DEFAULT false,
    last_login_at TIMESTAMP,
    
    -- Настройки
    timezone VARCHAR(50) DEFAULT 'Europe/Moscow',
    language VARCHAR(10) DEFAULT 'ru',
    
    -- Метаданные
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Таблица настроек системы
CREATE TABLE IF NOT EXISTS system_settings (
    id SERIAL PRIMARY KEY,
    setting_key VARCHAR(100) NOT NULL UNIQUE,
    setting_value TEXT,
    setting_type VARCHAR(20) DEFAULT 'string' CHECK (setting_type IN ('string', 'number', 'boolean', 'json')),
    description TEXT,
    is_public BOOLEAN DEFAULT false,
    updated_by INTEGER REFERENCES users(id),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Создание индексов для оптимизации производительности

-- Индексы для таблицы campaigns
CREATE INDEX IF NOT EXISTS idx_campaigns_status ON campaigns(status);
CREATE INDEX IF NOT EXISTS idx_campaigns_created_at ON campaigns(created_at);

-- Индексы для таблицы contacts
CREATE INDEX IF NOT EXISTS idx_contacts_campaign_id ON contacts(campaign_id);
CREATE INDEX IF NOT EXISTS idx_contacts_status ON contacts(status);
CREATE INDEX IF NOT EXISTS idx_contacts_phone ON contacts(phone);
CREATE INDEX IF NOT EXISTS idx_contacts_next_call_at ON contacts(next_call_at);
CREATE INDEX IF NOT EXISTS idx_contacts_status_next_call ON contacts(status, next_call_at) WHERE status = 'pending';

-- Индексы для таблицы call_results
CREATE INDEX IF NOT EXISTS idx_call_results_contact_id ON call_results(contact_id);
CREATE INDEX IF NOT EXISTS idx_call_results_campaign_id ON call_results(campaign_id);
CREATE INDEX IF NOT EXISTS idx_call_results_call_status ON call_results(call_status);
CREATE INDEX IF NOT EXISTS idx_call_results_created_at ON call_results(created_at);
CREATE INDEX IF NOT EXISTS idx_call_results_phone ON call_results(phone_number);

-- Индексы для таблицы blacklist (создаются в миграции 005)
-- CREATE INDEX IF NOT EXISTS idx_blacklist_phone ON blacklist(phone); - перенесено в 005_create_blacklist_table.sql

-- Индексы для таблицы users
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- Функция для автоматического обновления updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Триггеры для автоматического обновления updated_at
CREATE TRIGGER update_campaigns_updated_at BEFORE UPDATE ON campaigns
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_contacts_updated_at BEFORE UPDATE ON contacts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Функция для обновления статистики кампании
CREATE OR REPLACE FUNCTION update_campaign_stats()
RETURNS TRIGGER AS $$
BEGIN
    -- Обновляем статистику кампании при изменении результатов звонков
    UPDATE campaigns 
    SET 
        completed_calls = (
            SELECT COUNT(*) 
            FROM call_results 
            WHERE campaign_id = NEW.campaign_id 
            AND call_status IN ('answered', 'busy', 'no_answer')
        ),
        successful_calls = (
            SELECT COUNT(*) 
            FROM call_results 
            WHERE campaign_id = NEW.campaign_id 
            AND call_status = 'answered'
        ),
        interested_responses = (
            SELECT COUNT(*) 
            FROM call_results 
            WHERE campaign_id = NEW.campaign_id 
            AND dtmf_response = '1'
        ),
        updated_at = NOW()
    WHERE id = NEW.campaign_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Триггер для автоматического обновления статистики
CREATE TRIGGER update_campaign_statistics AFTER INSERT OR UPDATE ON call_results
    FOR EACH ROW EXECUTE FUNCTION update_campaign_stats();

-- Вставка базовых настроек системы
INSERT INTO system_settings (setting_key, setting_value, setting_type, description, is_public) VALUES
    ('max_concurrent_calls', '10', 'number', 'Максимальное количество одновременных звонков', false),
    ('default_calls_per_minute', '30', 'number', 'Количество звонков в минуту по умолчанию', false),
    ('default_retry_attempts', '3', 'number', 'Количество попыток дозвона по умолчанию', false),
    ('amd_enabled', 'true', 'boolean', 'Включить определение автоответчика', false),
    ('bitrix_integration_enabled', 'false', 'boolean', 'Включить интеграцию с Битрикс24', true),
    ('system_timezone', 'Europe/Moscow', 'string', 'Часовой пояс системы', true),
    ('call_recording_enabled', 'false', 'boolean', 'Включить запись звонков', false)
ON CONFLICT (setting_key) DO NOTHING;

-- Создание пользователя администратора по умолчанию
-- Пароль: admin123 (хэшированный)
INSERT INTO users (username, email, password_hash, role, first_name, last_name, is_active, is_verified) VALUES
    ('admin', 'admin@dialer.local', crypt('admin123', gen_salt('bf')), 'admin', 'System', 'Administrator', true, true)
ON CONFLICT (username) DO NOTHING;

-- Комментарии к таблицам
COMMENT ON TABLE campaigns IS 'Кампании автодозвона';
COMMENT ON TABLE contacts IS 'Контакты для обзвона в рамках кампаний';
COMMENT ON TABLE call_results IS 'Детальные результаты всех звонков';
-- COMMENT ON TABLE blacklist IS 'Черный список номеров телефонов'; - перенесено в 005_create_blacklist_table.sql
COMMENT ON TABLE users IS 'Пользователи системы';
COMMENT ON TABLE system_settings IS 'Настройки системы';

-- Завершение инициализации
SELECT 'Database schema initialized successfully' AS result; 