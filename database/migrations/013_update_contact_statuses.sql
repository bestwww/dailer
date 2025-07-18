-- Обновление check constraint для статусов контактов
-- Добавляем статусы, которые использует диалер

-- Удаляем старый constraint
ALTER TABLE contacts DROP CONSTRAINT IF EXISTS contacts_status_check;

-- Добавляем новый constraint с дополнительными статусами
ALTER TABLE contacts ADD CONSTRAINT contacts_status_check 
CHECK (status IN (
    'pending',       -- ожидает обработки (начальный статус)
    'new',          -- новый контакт, готов к звонку
    'calling',      -- в процессе звонка
    'retry',        -- требует повторного звонка
    'callback',     -- требует обратного звонка
    'completed',    -- звонок завершен успешно
    'interested',   -- клиент заинтересован (DTMF = 1)
    'not_interested', -- клиент не заинтересован (DTMF = 2)
    'failed',       -- звонок не удался
    'blacklisted',  -- номер в черном списке
    'do_not_call'   -- не звонить (по запросу клиента)
));

-- Обновляем существующие pending контакты на new
UPDATE contacts SET status = 'new' WHERE status = 'pending';

-- Обновляем значение по умолчанию
ALTER TABLE contacts ALTER COLUMN status SET DEFAULT 'new'; 