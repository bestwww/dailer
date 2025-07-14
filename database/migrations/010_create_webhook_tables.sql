-- Миграция для создания таблиц webhook уведомлений
-- Версия: 010
-- Описание: Создание таблиц для webhook endpoints и логов доставки

-- Создание таблицы webhook_endpoints
CREATE TABLE IF NOT EXISTS webhook_endpoints (
    id SERIAL PRIMARY KEY,
    
    -- Основная информация
    url VARCHAR(1000) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    secret VARCHAR(500),
    
    -- Настройки фильтрации
    event_types JSONB NOT NULL DEFAULT '[]',
    campaign_ids JSONB, -- NULL означает все кампании
    
    -- Настройки retry и таймаутов
    max_retries INTEGER DEFAULT 3,
    retry_delay INTEGER DEFAULT 5000, -- в миллисекундах
    timeout INTEGER DEFAULT 30000, -- в миллисекундах
    
    -- Статистика
    total_sent INTEGER DEFAULT 0,
    total_delivered INTEGER DEFAULT 0,
    total_failed INTEGER DEFAULT 0,
    last_sent_at TIMESTAMP,
    last_failed_at TIMESTAMP,
    last_error TEXT,
    
    -- Настройки безопасности
    allowed_ips JSONB,
    http_method VARCHAR(10) DEFAULT 'POST' CHECK (http_method IN ('POST', 'PUT', 'PATCH')),
    custom_headers JSONB,
    
    -- Метаданные
    created_by INTEGER,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    -- Ограничения
    CONSTRAINT webhook_endpoints_url_check CHECK (url ~ '^https?://'),
    CONSTRAINT webhook_endpoints_max_retries_check CHECK (max_retries >= 0 AND max_retries <= 10),
    CONSTRAINT webhook_endpoints_retry_delay_check CHECK (retry_delay >= 1000 AND retry_delay <= 300000),
    CONSTRAINT webhook_endpoints_timeout_check CHECK (timeout >= 5000 AND timeout <= 120000)
);

-- Создание индексов для webhook_endpoints
CREATE INDEX IF NOT EXISTS idx_webhook_endpoints_active ON webhook_endpoints (is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_webhook_endpoints_event_types ON webhook_endpoints USING GIN (event_types);
CREATE INDEX IF NOT EXISTS idx_webhook_endpoints_campaign_ids ON webhook_endpoints USING GIN (campaign_ids);
CREATE INDEX IF NOT EXISTS idx_webhook_endpoints_created_at ON webhook_endpoints (created_at);
CREATE INDEX IF NOT EXISTS idx_webhook_endpoints_stats ON webhook_endpoints (total_sent, total_failed, last_sent_at);

-- Создание таблицы webhook_deliveries
CREATE TABLE IF NOT EXISTS webhook_deliveries (
    id SERIAL PRIMARY KEY,
    
    -- Связь с endpoint
    webhook_endpoint_id INTEGER NOT NULL REFERENCES webhook_endpoints(id) ON DELETE CASCADE,
    
    -- Информация о событии
    event_id VARCHAR(255) NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    
    -- Данные HTTP запроса
    request_url VARCHAR(1000) NOT NULL,
    request_method VARCHAR(10) NOT NULL,
    request_headers JSONB NOT NULL DEFAULT '{}',
    request_body TEXT NOT NULL,
    
    -- Данные HTTP ответа
    response_status_code INTEGER,
    response_headers JSONB,
    response_body TEXT,
    
    -- Информация о доставке
    attempt_number INTEGER DEFAULT 1,
    processing_time INTEGER, -- в миллисекундах
    
    -- Статус доставки
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'delivered', 'failed')),
    error TEXT,
    
    -- Времена
    sent_at TIMESTAMP,
    delivered_at TIMESTAMP,
    failed_at TIMESTAMP,
    next_retry_at TIMESTAMP,
    
    -- Метаданные
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    -- Ограничения
    CONSTRAINT webhook_deliveries_attempt_number_check CHECK (attempt_number >= 1 AND attempt_number <= 20),
    CONSTRAINT webhook_deliveries_processing_time_check CHECK (processing_time >= 0),
    CONSTRAINT webhook_deliveries_status_code_check CHECK (response_status_code >= 100 AND response_status_code <= 599),
    CONSTRAINT webhook_deliveries_timestamps_check CHECK (
        (status = 'delivered' AND delivered_at IS NOT NULL) OR
        (status = 'failed' AND failed_at IS NOT NULL) OR
        (status = 'pending')
    )
);

-- Создание индексов для webhook_deliveries
CREATE INDEX IF NOT EXISTS idx_webhook_deliveries_endpoint_id ON webhook_deliveries(webhook_endpoint_id);
CREATE INDEX IF NOT EXISTS idx_webhook_deliveries_event_type ON webhook_deliveries(event_type);
CREATE INDEX IF NOT EXISTS idx_webhook_deliveries_status ON webhook_deliveries(status);
CREATE INDEX IF NOT EXISTS idx_webhook_deliveries_created_at ON webhook_deliveries(created_at);
CREATE INDEX IF NOT EXISTS idx_webhook_deliveries_next_retry ON webhook_deliveries(next_retry_at) WHERE next_retry_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_webhook_deliveries_event_id ON webhook_deliveries(event_id);
CREATE INDEX IF NOT EXISTS idx_webhook_deliveries_failed_retries ON webhook_deliveries(webhook_endpoint_id, status, attempt_number) WHERE status = 'failed';

-- Функция для обновления updated_at в webhook_endpoints
CREATE OR REPLACE FUNCTION update_webhook_endpoints_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Триггер для обновления updated_at в webhook_endpoints
CREATE TRIGGER webhook_endpoints_updated_at_trigger
    BEFORE UPDATE ON webhook_endpoints
    FOR EACH ROW
    EXECUTE FUNCTION update_webhook_endpoints_updated_at();

-- Функция для обновления updated_at в webhook_deliveries
CREATE OR REPLACE FUNCTION update_webhook_deliveries_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Триггер для обновления updated_at в webhook_deliveries
CREATE TRIGGER webhook_deliveries_updated_at_trigger
    BEFORE UPDATE ON webhook_deliveries
    FOR EACH ROW
    EXECUTE FUNCTION update_webhook_deliveries_updated_at();

-- Функция для обновления статистики endpoint-а
CREATE OR REPLACE FUNCTION update_webhook_endpoint_stats()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE webhook_endpoints 
        SET total_sent = total_sent + 1,
            last_sent_at = NOW()
        WHERE id = NEW.webhook_endpoint_id;
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.status != NEW.status THEN
            IF NEW.status = 'delivered' THEN
                UPDATE webhook_endpoints 
                SET total_delivered = total_delivered + 1
                WHERE id = NEW.webhook_endpoint_id;
            ELSIF NEW.status = 'failed' THEN
                UPDATE webhook_endpoints 
                SET total_failed = total_failed + 1,
                    last_failed_at = NOW(),
                    last_error = NEW.error
                WHERE id = NEW.webhook_endpoint_id;
            END IF;
        END IF;
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Триггер для автоматического обновления статистики
CREATE TRIGGER webhook_endpoint_stats_trigger
    AFTER INSERT OR UPDATE ON webhook_deliveries
    FOR EACH ROW
    EXECUTE FUNCTION update_webhook_endpoint_stats();

-- Представление для активных webhook endpoints
CREATE VIEW v_active_webhook_endpoints AS
SELECT 
    id,
    url,
    name,
    description,
    event_types,
    campaign_ids,
    max_retries,
    retry_delay,
    timeout,
    total_sent,
    total_delivered,
    total_failed,
    CASE 
        WHEN total_sent = 0 THEN 0
        ELSE ROUND((total_delivered::numeric / total_sent::numeric) * 100, 2)
    END as success_rate,
    last_sent_at,
    last_failed_at,
    created_at,
    updated_at
FROM webhook_endpoints
WHERE is_active = TRUE;

-- Представление для неудачных доставок требующих повтора
CREATE VIEW v_webhook_pending_retries AS
SELECT 
    wd.id,
    wd.webhook_endpoint_id,
    we.url,
    we.name as endpoint_name,
    wd.event_type,
    wd.attempt_number,
    wd.next_retry_at,
    wd.error,
    wd.created_at
FROM webhook_deliveries wd
JOIN webhook_endpoints we ON wd.webhook_endpoint_id = we.id
WHERE wd.status = 'failed' 
  AND wd.next_retry_at IS NOT NULL 
  AND wd.next_retry_at <= NOW()
  AND wd.attempt_number < we.max_retries
  AND we.is_active = TRUE;

-- Функция для очистки старых логов доставки
CREATE OR REPLACE FUNCTION cleanup_old_webhook_deliveries()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- Удаляем записи старше 30 дней
    DELETE FROM webhook_deliveries 
    WHERE created_at < NOW() - INTERVAL '30 days';
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Комментарии к таблицам
COMMENT ON TABLE webhook_endpoints IS 'Конечные точки для webhook уведомлений';
COMMENT ON TABLE webhook_deliveries IS 'Логи доставки webhook уведомлений';
COMMENT ON VIEW v_active_webhook_endpoints IS 'Активные webhook endpoints с статистикой';
COMMENT ON VIEW v_webhook_pending_retries IS 'Неудачные доставки ожидающие повтора';

-- Комментарии к основным колонкам
COMMENT ON COLUMN webhook_endpoints.event_types IS 'Типы событий для отправки (JSON array)';
COMMENT ON COLUMN webhook_endpoints.campaign_ids IS 'ID кампаний для фильтрации (NULL = все)';
COMMENT ON COLUMN webhook_endpoints.secret IS 'Секрет для подписи webhook-ов';
COMMENT ON COLUMN webhook_deliveries.event_id IS 'Уникальный идентификатор события';
COMMENT ON COLUMN webhook_deliveries.processing_time IS 'Время обработки запроса в миллисекундах'; 