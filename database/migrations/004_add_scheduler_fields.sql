-- Миграция 004: Добавление полей планировщика кампаний
-- Дата: 2024-01-XX
-- Описание: Добавляет поля для поддержки планировщика кампаний с cron jobs

-- Добавление полей планировщика в таблицу campaigns
ALTER TABLE campaigns
ADD COLUMN is_scheduled BOOLEAN DEFAULT FALSE,
ADD COLUMN scheduled_start TIMESTAMP WITH TIME ZONE,
ADD COLUMN scheduled_stop TIMESTAMP WITH TIME ZONE,
ADD COLUMN is_recurring BOOLEAN DEFAULT FALSE,
ADD COLUMN cron_expression VARCHAR(100);

-- Добавление индексов для оптимизации поиска запланированных кампаний
CREATE INDEX idx_campaigns_scheduled ON campaigns(is_scheduled) WHERE is_scheduled = TRUE;
CREATE INDEX idx_campaigns_scheduled_start ON campaigns(scheduled_start) WHERE scheduled_start IS NOT NULL;
CREATE INDEX idx_campaigns_scheduled_stop ON campaigns(scheduled_stop) WHERE scheduled_stop IS NOT NULL;
CREATE INDEX idx_campaigns_recurring ON campaigns(is_recurring) WHERE is_recurring = TRUE;

-- Добавление комментариев к полям
COMMENT ON COLUMN campaigns.is_scheduled IS 'Является ли кампания запланированной';
COMMENT ON COLUMN campaigns.scheduled_start IS 'Планируемое время запуска кампании';
COMMENT ON COLUMN campaigns.scheduled_stop IS 'Планируемое время остановки кампании';
COMMENT ON COLUMN campaigns.is_recurring IS 'Является ли расписание повторяющимся';
COMMENT ON COLUMN campaigns.cron_expression IS 'Cron выражение для повторяющихся запусков';

-- Добавление проверочных ограничений
ALTER TABLE campaigns
ADD CONSTRAINT chk_scheduled_logic CHECK (
    (is_scheduled = FALSE) OR 
    (is_scheduled = TRUE AND (scheduled_start IS NOT NULL OR is_recurring = TRUE))
);

ALTER TABLE campaigns
ADD CONSTRAINT chk_recurring_logic CHECK (
    (is_recurring = FALSE) OR 
    (is_recurring = TRUE AND cron_expression IS NOT NULL)
);

-- Проверка, что время остановки после времени запуска (если оба указаны)
ALTER TABLE campaigns
ADD CONSTRAINT chk_scheduled_times CHECK (
    (scheduled_start IS NULL OR scheduled_stop IS NULL) OR
    (scheduled_stop > scheduled_start)
);

-- Обновление существующих кампаний (установка значений по умолчанию)
UPDATE campaigns 
SET 
    is_scheduled = FALSE,
    is_recurring = FALSE
WHERE 
    is_scheduled IS NULL OR is_recurring IS NULL;

-- Создание функции для валидации cron выражений (базовая проверка)
CREATE OR REPLACE FUNCTION validate_cron_expression(cron_expr TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    -- Базовая проверка на количество частей (должно быть 5)
    IF array_length(string_to_array(cron_expr, ' '), 1) != 5 THEN
        RETURN FALSE;
    END IF;
    
    -- Простая проверка на корректность символов
    IF cron_expr ~ '^[0-9\*\-,/\s]+$' THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Добавление триггера для валидации cron выражений
CREATE OR REPLACE FUNCTION validate_campaign_scheduler()
RETURNS TRIGGER AS $$
BEGIN
    -- Проверка cron выражения при включении повторяющегося расписания
    IF NEW.is_recurring = TRUE AND NEW.cron_expression IS NOT NULL THEN
        IF NOT validate_cron_expression(NEW.cron_expression) THEN
            RAISE EXCEPTION 'Некорректное cron выражение: %', NEW.cron_expression;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_campaign_scheduler
    BEFORE INSERT OR UPDATE ON campaigns
    FOR EACH ROW
    EXECUTE FUNCTION validate_campaign_scheduler();

-- Создание представления для активных запланированных кампаний
CREATE VIEW v_scheduled_campaigns AS
SELECT 
    c.*,
    CASE 
        WHEN c.is_recurring = TRUE THEN 'recurring'
        WHEN c.scheduled_start IS NOT NULL AND c.scheduled_start > NOW() THEN 'pending_start'
        WHEN c.scheduled_stop IS NOT NULL AND c.scheduled_stop > NOW() THEN 'pending_stop'
        ELSE 'inactive'
    END as schedule_status
FROM campaigns c
WHERE c.is_scheduled = TRUE;

-- Добавление комментария к представлению
COMMENT ON VIEW v_scheduled_campaigns IS 'Представление для отображения запланированных кампаний с их статусом';

-- Создание функции для получения следующего времени выполнения cron
CREATE OR REPLACE FUNCTION get_next_cron_execution(cron_expr TEXT)
RETURNS TIMESTAMP AS $$
BEGIN
    -- Это упрощенная версия, в реальности используется библиотека node-cron
    -- Возвращаем текущее время + 1 час как заглушку
    RETURN NOW() + INTERVAL '1 hour';
END;
$$ LANGUAGE plpgsql;

-- Добавление индекса для быстрого поиска по статусу и времени
CREATE INDEX idx_campaigns_scheduler_status ON campaigns(status, is_scheduled, scheduled_start, scheduled_stop);

-- Вставка примера настройки планировщика в системные настройки
INSERT INTO system_settings (setting_key, setting_value, setting_type, description, is_public)
VALUES 
    ('scheduler_enabled', 'true', 'boolean', 'Включен ли планировщик кампаний', false),
    ('scheduler_check_interval', '60', 'number', 'Интервал проверки планировщика в секундах', false),
    ('max_scheduled_campaigns', '100', 'number', 'Максимальное количество запланированных кампаний', false)
ON CONFLICT (setting_key) DO NOTHING;

-- Создание таблицы для логов планировщика
CREATE TABLE IF NOT EXISTS scheduler_logs (
    id SERIAL PRIMARY KEY,
    campaign_id INTEGER REFERENCES campaigns(id) ON DELETE CASCADE,
    action_type VARCHAR(50) NOT NULL, -- 'start', 'stop', 'recurring_start'
    scheduled_time TIMESTAMP WITH TIME ZONE NOT NULL,
    executed_time TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) NOT NULL DEFAULT 'pending', -- 'pending', 'executed', 'failed', 'skipped'
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Добавление индексов для таблицы логов
CREATE INDEX idx_scheduler_logs_campaign ON scheduler_logs(campaign_id);
CREATE INDEX idx_scheduler_logs_scheduled_time ON scheduler_logs(scheduled_time);
CREATE INDEX idx_scheduler_logs_status ON scheduler_logs(status);

-- Добавление комментариев к таблице логов
COMMENT ON TABLE scheduler_logs IS 'Логи выполнения планировщика кампаний';
COMMENT ON COLUMN scheduler_logs.action_type IS 'Тип действия планировщика';
COMMENT ON COLUMN scheduler_logs.scheduled_time IS 'Запланированное время выполнения';
COMMENT ON COLUMN scheduler_logs.executed_time IS 'Фактическое время выполнения';
COMMENT ON COLUMN scheduler_logs.status IS 'Статус выполнения задачи';
COMMENT ON COLUMN scheduler_logs.error_message IS 'Сообщение об ошибке (если есть)';

-- Добавление прав доступа (если используется RBAC)
-- INSERT INTO permissions (name, description, resource, action)
-- VALUES 
--     ('campaigns.schedule', 'Планировать кампании', 'campaigns', 'schedule'),
--     ('campaigns.schedule.view', 'Просмотр расписания кампаний', 'campaigns', 'schedule_view')
-- ON CONFLICT (name) DO NOTHING;

-- Финальная проверка структуры
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'campaigns' AND column_name IN (
    'is_scheduled', 'scheduled_start', 'scheduled_stop', 'is_recurring', 'cron_expression'
);

-- Проверка созданных индексов
SELECT indexname, tablename, indexdef
FROM pg_indexes
WHERE tablename = 'campaigns' AND indexname LIKE 'idx_campaigns_schedul%';

-- Проверка созданных ограничений
SELECT constraint_name, constraint_type
FROM information_schema.table_constraints
WHERE table_name = 'campaigns' AND constraint_name LIKE 'chk_%';

-- Вывод информации о миграции
SELECT 'Миграция 004: Планировщик кампаний успешно применена' as status; 