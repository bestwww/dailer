module.exports = {
  // Основные настройки
  preset: 'ts-jest',
  testEnvironment: 'node',
  
  // Директории и файлы
  testMatch: [
    '**/tests/**/*.test.ts',
    '**/tests/**/*.spec.ts',
    '**/__tests__/**/*.ts',
  ],
  testPathIgnorePatterns: [
    '/node_modules/',
    '/dist/',
  ],
  
  // Покрытие кода
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    '!src/**/index.ts',
    '!src/types/**',
  ],
  coverageDirectory: 'coverage',
  coverageReporters: [
    'text',
    'lcov',
    'html',
  ],
  coverageThreshold: {
    global: {
      branches: 70,
      functions: 70,
      lines: 70,
      statements: 70,
    },
  },
  
  // Настройка модулей
  moduleNameMapping: {
    '^@/(.*)$': '<rootDir>/src/$1',
  },
  
  // Настройка окружения
  setupFilesAfterEnv: ['<rootDir>/tests/setup.ts'],
  
  // Таймауты
  testTimeout: 10000,
  
  // Verbose output для отладки
  verbose: true,
  
  // Очистка моков между тестами
  clearMocks: true,
  restoreMocks: true,
  
  // Глобальные переменные для тестов
  globals: {
    'ts-jest': {
      tsconfig: 'tsconfig.json',
    },
  },
}; 