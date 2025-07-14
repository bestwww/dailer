"use strict";
/**
 * Настройка Jest тестов
 */
Object.defineProperty(exports, "__esModule", { value: true });
// Переопределение переменных окружения для тестов
process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://test_user:test_password@localhost:5432/test_db';
process.env.REDIS_URL = 'redis://localhost:6379/1';
process.env.JWT_SECRET = 'test-jwt-secret-for-testing-purposes-only';
process.env.LOG_LEVEL = 'error'; // Минимальное логирование в тестах
// Глобальные настройки для тестов
global.console = {
    ...console,
    // Подавление логов в тестах (кроме ошибок)
    log: jest.fn(),
    info: jest.fn(),
    warn: jest.fn(),
    error: console.error,
};
// Настройка таймаутов
jest.setTimeout(30000);
// Мокирование внешних сервисов
jest.mock('../src/config/database', () => ({
    query: jest.fn(),
    getPool: jest.fn(),
    checkConnection: jest.fn().mockResolvedValue(true),
}));
jest.mock('../src/utils/logger', () => ({
    logger: {
        info: jest.fn(),
        error: jest.fn(),
        warn: jest.fn(),
        debug: jest.fn(),
    },
    log: {
        info: jest.fn(),
        error: jest.fn(),
        warn: jest.fn(),
        debug: jest.fn(),
        auth: jest.fn(),
        database: jest.fn(),
        freeswitch: jest.fn(),
        dialer: jest.fn(),
        bitrix: jest.fn(),
        api: jest.fn(),
        call: {
            started: jest.fn(),
            answered: jest.fn(),
            failed: jest.fn(),
            dtmf: jest.fn(),
            amd: jest.fn(),
        },
        performance: jest.fn(),
        security: {
            loginAttempt: jest.fn(),
            rateLimitHit: jest.fn(),
            suspiciousActivity: jest.fn(),
        },
    },
}));
// Очистка моков после каждого теста
afterEach(() => {
    jest.clearAllMocks();
});
// Очистка всех моков после всех тестов
afterAll(() => {
    jest.restoreAllMocks();
});
//# sourceMappingURL=setup.js.map