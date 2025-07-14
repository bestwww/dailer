-- Миграция 005: Создание таблицы черного списка номеров
-- Дата: 2024-01-XX
-- Описание: Создает таблицу blacklist для управления заблокированными номерами

-- Создание типа enum для причин блокировки
CREATE TYPE blacklist_reason_type AS ENUM (
    'user_request',         -- Запрос пользователя
    'complaint',            -- Жалоба
    'invalid_number',       -- Некорректный номер
    'do_not_call_registry', -- Реестр "не звонить"
    'fraud_suspected',      -- Подозрение на мошенничество
    'repeated_no_answer',   -- Многократное отсутствие ответа
    'operator_decision',    -- Решение оператора
    'auto_detected',        -- Автоматически обнаружен
    'other'                 -- Другая причина
);

-- Создание таблицы черного списка
CREATE TABLE IF NOT EXISTS blacklist (
    id SERIAL PRIMARY KEY,
    
    -- Номер телефона (основной ключ для поиска)
    phone VARCHAR(20) NOT NULL,
    
    -- Причины блокировки
    reason TEXT,                              -- Описание причины
    reason_type blacklist_reason_type NOT NULL, -- Тип причины
    
    -- Метаданные добавления
    added_by INTEGER,                         -- ID пользователя, который добавил
    added_by_name VARCHAR(255),               -- Имя добавившего (для кеширования)
    source VARCHAR(100) DEFAULT 'manual',     -- Источник добавления
    
    -- Статус записи
    is_active BOOLEAN DEFAULT TRUE,           -- Активна ли запись
    expires_at TIMESTAMP WITH TIME ZONE,     -- Дата истечения (для временной блокировки)
    
    -- Статистика попыток
    last_attempt_at TIMESTAMP WITH TIME ZONE, -- Последняя попытка звонка
    attempt_count INTEGER DEFAULT 0,          -- Количество попыток звонков
    
    -- Дополнительная информация
    notes TEXT,                               -- Дополнительные заметки
    
    -- Временные метки
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Создание индексов для оптимизации поиска
CREATE UNIQUE INDEX IF NOT EXISTS idx_blacklist_phone ON blacklist(phone);
CREATE INDEX IF NOT EXISTS idx_blacklist_phone_active ON blacklist(phone, is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_blacklist_reason_type ON blacklist(reason_type);
CREATE INDEX IF NOT EXISTS idx_blacklist_active ON blacklist(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_blacklist_expires_at ON blacklist(expires_at) WHERE expires_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_blacklist_added_by ON blacklist(added_by) WHERE added_by IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_blacklist_source ON blacklist(source);
CREATE INDEX IF NOT EXISTS idx_blacklist_created_at ON blacklist(created_at);
CREATE INDEX IF NOT EXISTS idx_blacklist_last_attempt ON blacklist(last_attempt_at) WHERE last_attempt_at IS NOT NULL;

-- Создание составного индекса для быстрой проверки активных записей
CREATE INDEX IF NOT EXISTS idx_blacklist_active_check ON blacklist(phone, is_active, expires_at) 
WHERE is_active = TRUE;

-- Комментарии к таблице и полям
COMMENT ON TABLE blacklist IS 'Черный список номеров телефонов для блокировки звонков';
COMMENT ON COLUMN blacklist.phone IS 'Номер телефона в международном формате';
COMMENT ON COLUMN blacklist.reason IS 'Описание причины блокировки';
COMMENT ON COLUMN blacklist.reason_type IS 'Тип причины блокировки из предопределенного списка';
COMMENT ON COLUMN blacklist.added_by IS 'ID пользователя, который добавил номер в черный список';
COMMENT ON COLUMN blacklist.added_by_name IS 'Имя пользователя для быстрого отображения';
COMMENT ON COLUMN blacklist.source IS 'Источник добавления (manual, import, auto, campaign_id)';
COMMENT ON COLUMN blacklist.is_active IS 'Активна ли запись (для soft delete)';
COMMENT ON COLUMN blacklist.expires_at IS 'Дата и время истечения блокировки';
COMMENT ON COLUMN blacklist.last_attempt_at IS 'Время последней попытки звонка на заблокированный номер';
COMMENT ON COLUMN blacklist.attempt_count IS 'Количество попыток звонков на заблокированный номер';
COMMENT ON COLUMN blacklist.notes IS 'Дополнительные заметки о блокировке';

-- Создание триггера для обновления updated_at
CREATE OR REPLACE FUNCTION update_blacklist_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_blacklist_updated_at
    BEFORE UPDATE ON blacklist
    FOR EACH ROW
    EXECUTE FUNCTION update_blacklist_updated_at();

-- Создание функции для нормализации номера телефона
CREATE OR REPLACE FUNCTION normalize_phone_number(phone_input TEXT)
RETURNS TEXT AS $$
BEGIN
    -- Удаляем все символы кроме цифр и плюса
    phone_input := regexp_replace(phone_input, '[^\d+]', '', 'g');
    
    -- Если номер начинается с 8, заменяем на +7
    IF phone_input ~ '^8' THEN
        phone_input := '+7' || substring(phone_input, 2);
    END IF;
    
    -- Если номер начинается с 7 (без +), добавляем +
    IF phone_input ~ '^7' AND NOT phone_input ~ '^\+7' THEN
        phone_input := '+' || phone_input;
    END IF;
    
    -- Если номер не имеет кода страны, добавляем +7
    IF NOT phone_input ~ '^\+' THEN
        phone_input := '+7' || phone_input;
    END IF;
    
    RETURN phone_input;
END;
$$ LANGUAGE plpgsql;

-- Создание триггера для нормализации номера телефона при вставке/обновлении
CREATE OR REPLACE FUNCTION normalize_blacklist_phone()
RETURNS TRIGGER AS $$
BEGIN
    NEW.phone = normalize_phone_number(NEW.phone);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_blacklist_normalize_phone
    BEFORE INSERT OR UPDATE ON blacklist
    FOR EACH ROW
    EXECUTE FUNCTION normalize_blacklist_phone();

-- Создание функции для проверки истекших записей
CREATE OR REPLACE FUNCTION check_blacklist_expiry(phone_number TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    is_blocked BOOLEAN := FALSE;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM blacklist 
        WHERE phone = normalize_phone_number(phone_number)
        AND is_active = TRUE 
        AND (expires_at IS NULL OR expires_at > NOW())
    ) INTO is_blocked;
    
    RETURN is_blocked;
END;
$$ LANGUAGE plpgsql;

-- Создание функции для автоматической очистки истекших записей
CREATE OR REPLACE FUNCTION cleanup_expired_blacklist_entries()
RETURNS INTEGER AS $$
DECLARE
    deactivated_count INTEGER;
BEGIN
    UPDATE blacklist 
    SET is_active = FALSE,
        updated_at = NOW()
    WHERE expires_at IS NOT NULL 
    AND expires_at <= NOW() 
    AND is_active = TRUE;
    
    GET DIAGNOSTICS deactivated_count = ROW_COUNT;
    
    -- Логирование
    IF deactivated_count > 0 THEN
        INSERT INTO system_logs (level, message, context) 
        VALUES ('info', 'Deactivated expired blacklist entries', 
                json_build_object('count', deactivated_count, 'timestamp', NOW()));
    END IF;
    
    RETURN deactivated_count;
END;
$$ LANGUAGE plpgsql;

-- Создание представления для активных записей черного списка
CREATE VIEW v_active_blacklist AS
SELECT 
    id,
    phone,
    reason,
    reason_type,
    added_by,
    added_by_name,
    source,
    expires_at,
    last_attempt_at,
    attempt_count,
    notes,
    created_at,
    updated_at,
    CASE 
        WHEN expires_at IS NULL THEN 'permanent'
        WHEN expires_at > NOW() THEN 'temporary'
        ELSE 'expired'
    END as expiry_status
FROM blacklist 
WHERE is_active = TRUE;

-- Комментарий к представлению
COMMENT ON VIEW v_active_blacklist IS 'Активные записи черного списка с информацией о типе блокировки';

-- Создание представления для статистики черного списка
CREATE VIEW v_blacklist_stats AS
SELECT 
    COUNT(*) as total_entries,
    COUNT(CASE WHEN is_active = TRUE THEN 1 END) as active_entries,
    COUNT(CASE WHEN is_active = FALSE THEN 1 END) as inactive_entries,
    COUNT(CASE WHEN expires_at IS NOT NULL AND expires_at <= NOW() THEN 1 END) as expired_entries,
    COUNT(CASE WHEN expires_at IS NULL THEN 1 END) as permanent_entries,
    COUNT(CASE WHEN DATE(last_attempt_at) = CURRENT_DATE THEN 1 END) as attempts_today,
    SUM(attempt_count) as total_attempts,
    COUNT(CASE WHEN DATE(created_at) = CURRENT_DATE THEN 1 END) as added_today
FROM blacklist;

-- Комментарий к представлению статистики
COMMENT ON VIEW v_blacklist_stats IS 'Статистика черного списка для дашборда';

-- Добавление ограничений
ALTER TABLE blacklist 
ADD CONSTRAINT chk_blacklist_phone_format 
CHECK (phone ~ '^\+\d{1,15}$');

ALTER TABLE blacklist 
ADD CONSTRAINT chk_blacklist_attempt_count 
CHECK (attempt_count >= 0);

ALTER TABLE blacklist 
ADD CONSTRAINT chk_blacklist_expires_future 
CHECK (expires_at IS NULL OR expires_at > created_at);

-- Создание таблицы для истории изменений черного списка (аудит)
CREATE TABLE IF NOT EXISTS blacklist_audit (
    id SERIAL PRIMARY KEY,
    blacklist_id INTEGER NOT NULL,
    action VARCHAR(20) NOT NULL, -- 'INSERT', 'UPDATE', 'DELETE'
    old_values JSONB,
    new_values JSONB,
    changed_by INTEGER,
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Индексы для аудита
CREATE INDEX IF NOT EXISTS idx_blacklist_audit_blacklist_id ON blacklist_audit(blacklist_id);
CREATE INDEX IF NOT EXISTS idx_blacklist_audit_action ON blacklist_audit(action);
CREATE INDEX IF NOT EXISTS idx_blacklist_audit_changed_at ON blacklist_audit(changed_at);

-- Функция для аудита изменений
CREATE OR REPLACE FUNCTION blacklist_audit_function()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO blacklist_audit (blacklist_id, action, old_values)
        VALUES (OLD.id, TG_OP, row_to_json(OLD));
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO blacklist_audit (blacklist_id, action, old_values, new_values)
        VALUES (NEW.id, TG_OP, row_to_json(OLD), row_to_json(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO blacklist_audit (blacklist_id, action, new_values)
        VALUES (NEW.id, TG_OP, row_to_json(NEW));
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Создание триггера для аудита
CREATE TRIGGER trg_blacklist_audit
    AFTER INSERT OR UPDATE OR DELETE ON blacklist
    FOR EACH ROW
    EXECUTE FUNCTION blacklist_audit_function();

-- Вставка примеров типовых записей (для демонстрации)
INSERT INTO blacklist (phone, reason, reason_type, source, notes) VALUES
('+79999999999', 'Тестовый номер для разработки', 'other', 'manual', 'Используется для тестирования системы'),
('+78888888888', 'Номер службы поддержки', 'user_request', 'manual', 'Не звонить на внутренние номера'),
('+77777777777', 'Временная блокировка на 1 день', 'complaint', 'manual', 'Жалоба от клиента')
ON CONFLICT (phone) DO NOTHING;

-- Обновление записи с истечением для демонстрации
UPDATE blacklist 
SET expires_at = NOW() + INTERVAL '1 day' 
WHERE phone = '+77777777777';

-- Добавление настроек планировщика очистки в системные настройки
INSERT INTO system_settings (setting_key, setting_value, setting_type, description, is_public)
VALUES 
    ('blacklist_cleanup_enabled', 'true', 'boolean', 'Включена ли автоматическая очистка истекших записей черного списка', false),
    ('blacklist_cleanup_interval', '3600', 'number', 'Интервал очистки истекших записей в секундах (по умолчанию 1 час)', false),
    ('blacklist_retention_days', '365', 'number', 'Количество дней хранения неактивных записей черного списка', false),
    ('blacklist_auto_add_threshold', '5', 'number', 'Количество неудачных попыток для автоматического добавления в черный список', false)
ON CONFLICT (setting_key) DO NOTHING;

-- Финальная проверка структуры
SELECT 
    'Таблица blacklist создана' as status,
    COUNT(*) as initial_records
FROM blacklist;

-- Проверка созданных индексов
SELECT 
    indexname,
    tablename,
    indexdef
FROM pg_indexes 
WHERE tablename = 'blacklist'
ORDER BY indexname;

-- Проверка созданных функций
SELECT 
    proname as function_name,
    proargnames as arguments
FROM pg_proc 
WHERE proname LIKE '%blacklist%' OR proname LIKE '%normalize_phone%'
ORDER BY proname;

-- Вывод информации о миграции
SELECT 'Миграция 005: Черный список номеров успешно применена' as status; 