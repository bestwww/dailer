/**
 * Контроллер аутентификации
 * Обработка входа и управления токенами с улучшенной безопасностью
 */

const express = require('express');
const jwt = require('jsonwebtoken');
const rateLimit = require('express-rate-limit');
const helmet = require('helmet');
const slowDown = require('express-slow-down');

import { config } from '@/config';
import { log } from '@/utils/logger';
import { ApiResponse } from '@/types';
import { userModel, UserData } from '@/models/user';
import { tokenBlacklistModel } from '@/models/token-blacklist';
import type { Request } from 'express';

const router = express.Router();

// Настройка безопасности
router.use(helmet());

// Rate limiting для auth endpoints - строгий лимит
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 минут
  max: 5, // максимум 5 попыток на IP
  message: {
    success: false,
    error: 'Слишком много попыток авторизации. Попробуйте позже.',
  },
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req: Request) => `auth:${req.ip}:${req.headers['user-agent']}`, // Учитываем IP и User-Agent
});

// Дополнительное замедление для подозрительных запросов
const speedLimiter = slowDown({
  windowMs: 15 * 60 * 1000,
  delayAfter: 2,
  delayMs: 500,
  maxDelayMs: 20000,
});

// Константы безопасности
const MAX_LOGIN_ATTEMPTS = 5;
const LOCKOUT_DURATION = 30 * 60 * 1000; // 30 минут
const TOKEN_EXPIRY = 24 * 60 * 60 * 1000; // 24 часа

/**
 * Генерация JWT токена
 */
function generateToken(user: UserData): string {
  const payload = {
    id: user.id,
    username: user.username,
    email: user.email,
    role: user.role,
    permissions: user.permissions,
  };

  return jwt.sign(payload, config.jwtSecret, {
    expiresIn: config.jwtExpiresIn,
    issuer: 'dialer-system',
    audience: 'dialer-client',
  });
}

/**
 * Валидация JWT токена
 */
async function verifyToken(token: string): Promise<any> {
  try {
    // Проверяем токен в blacklist
    const isBlacklisted = await tokenBlacklistModel.isTokenBlacklisted(token);
    if (isBlacklisted) {
      return null;
    }

    return jwt.verify(token, config.jwtSecret);
  } catch (error) {
    return null;
  }
}

/**
 * Безопасная проверка состояния пользователя
 */
async function validateUserSecurity(user: UserData): Promise<{ valid: boolean; message?: string }> {
  // Проверка активности
  if (!user.isActive) {
    return { valid: false, message: 'Аккаунт деактивирован' };
  }

  // Проверка блокировки
  const isLocked = await userModel.isUserLocked(user);
  if (isLocked) {
    return { valid: false, message: 'Аккаунт временно заблокирован' };
  }

  // Проверка превышения попыток входа
  if (user.loginAttempts >= MAX_LOGIN_ATTEMPTS) {
    await userModel.lockUser(user.id, LOCKOUT_DURATION);
    return { valid: false, message: 'Слишком много неуспешных попыток входа' };
  }

  return { valid: true };
}

/**
 * @swagger
 * /api/auth/login:
 *   post:
 *     summary: Вход пользователя в систему
 *     description: Аутентификация пользователя по username/email и паролю
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - identifier
 *               - password
 *             properties:
 *               identifier:
 *                 type: string
 *                 description: Username или email
 *                 example: admin
 *               password:
 *                 type: string
 *                 description: Пароль пользователя
 *                 example: admin123
 *     responses:
 *       200:
 *         description: Успешная аутентификация
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   type: object
 *                   properties:
 *                     token:
 *                       type: string
 *                       description: JWT токен
 *                     user:
 *                       $ref: '#/components/schemas/User'
 *       400:
 *         description: Неверные данные запроса
 *       401:
 *         description: Неверные учетные данные
 *       429:
 *         description: Слишком много попыток входа
 */
router.post('/login', authLimiter, speedLimiter, async (req: any, res: any) => {
  try {
    const { identifier, password } = req.body;

    // Валидация входных данных
    if (!identifier || !password) {
      log.warn('Login attempt with missing credentials', { ip: req.ip });
      return res.status(400).json({
        success: false,
        error: 'Необходимо указать логин и пароль',
      } as ApiResponse);
    }

    // Поиск пользователя
    const user = await userModel.findByIdentifier(identifier);
    if (!user) {
      log.warn('Login attempt with invalid user', { identifier, ip: req.ip });
      return res.status(401).json({
        success: false,
        error: 'Неверные учетные данные',
      } as ApiResponse);
    }

    // Проверка безопасности пользователя
    const securityCheck = await validateUserSecurity(user);
    if (!securityCheck.valid) {
      log.warn('Login blocked for security reasons', { 
        userId: user.id, 
        reason: securityCheck.message,
        ip: req.ip 
      });
      return res.status(401).json({
        success: false,
        error: securityCheck.message,
      } as ApiResponse);
    }

    // Проверка пароля
    const isPasswordValid = await userModel.validatePassword(user, password);
    if (!isPasswordValid) {
      // Увеличиваем счетчик попыток
      await userModel.incrementLoginAttempts(user.id);
      
      log.warn('Invalid password attempt', { 
        userId: user.id, 
        attempts: user.loginAttempts + 1,
        ip: req.ip 
      });
      
      return res.status(401).json({
        success: false,
        error: 'Неверные учетные данные',
      } as ApiResponse);
    }

    // Сброс попыток входа при успешном входе
    await userModel.resetLoginAttempts(user.id);

    // Генерация токена
    const token = generateToken(user);

    // Обновление времени последнего входа
    await userModel.updateLastLogin(user.id);

    // Сохранение токена сессии (для возможности отзыва)
    await userModel.updateSessionToken(user.id, token);

    // Логирование успешного входа
    log.info('Successful login', { 
      userId: user.id, 
      username: user.username, 
      ip: req.ip 
    });

    // Удаление пароля из ответа
    const { passwordHash, sessionToken, ...userResponse } = user;

    res.json({
      success: true,
      data: {
        token,
        user: userResponse,
      },
      message: 'Успешный вход в систему',
      timestamp: new Date().toISOString(),
    } as ApiResponse);

  } catch (error) {
    log.error('Login error:', error);
    res.status(500).json({
      success: false,
      error: 'Внутренняя ошибка сервера',
      timestamp: new Date().toISOString(),
    } as ApiResponse);
  }
});

/**
 * @swagger
 * /api/auth/me:
 *   get:
 *     summary: Получение информации о текущем пользователе
 *     description: Возвращает данные аутентифицированного пользователя
 *     tags: [Auth]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Информация о пользователе
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   $ref: '#/components/schemas/User'
 *       401:
 *         description: Не авторизован
 */
router.get('/me', async (req: any, res: any) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        error: 'Отсутствует заголовок авторизации',
      } as ApiResponse);
    }

    const token = authHeader.substring(7);
    const decoded = await verifyToken(token);

    if (!decoded) {
      return res.status(401).json({
        success: false,
        error: 'Недействительный или истекший токен',
      } as ApiResponse);
    }

    // Поиск пользователя по ID из токена
    const user = await userModel.findUserById(decoded.id);
    if (!user || !user.isActive) {
      return res.status(401).json({
        success: false,
        error: 'Пользователь не найден или неактивен',
      } as ApiResponse);
    }

    // Удаление пароля из ответа
    const { passwordHash, sessionToken, ...userResponse } = user;

    res.json({
      success: true,
      data: userResponse,
      timestamp: new Date().toISOString(),
    } as ApiResponse);

  } catch (error) {
    log.error('Get user info error:', error);
    res.status(500).json({
      success: false,
      error: 'Внутренняя ошибка сервера',
      timestamp: new Date().toISOString(),
    } as ApiResponse);
  }
});

/**
 * @swagger
 * /api/auth/refresh:
 *   post:
 *     summary: Обновление токена
 *     description: Генерация нового JWT токена для аутентифицированного пользователя
 *     tags: [Auth]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Новый токен
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: object
 *                   properties:
 *                     token:
 *                       type: string
 *       401:
 *         description: Не авторизован
 */
router.post('/refresh', async (req: any, res: any) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        error: 'Отсутствует заголовок авторизации',
      } as ApiResponse);
    }

    const token = authHeader.substring(7);
    const decoded = await verifyToken(token);

    if (!decoded) {
      return res.status(401).json({
        success: false,
        error: 'Недействительный или истекший токен',
      } as ApiResponse);
    }

    // Поиск пользователя
    const user = await userModel.findUserById(decoded.id);
    if (!user || !user.isActive) {
      return res.status(401).json({
        success: false,
        error: 'Пользователь не найден или неактивен',
      } as ApiResponse);
    }

    // Добавляем старый токен в blacklist
    const expiresAt = new Date(Date.now() + TOKEN_EXPIRY);
    await tokenBlacklistModel.addToBlacklist(token, user.id, 'logout', expiresAt);

    // Генерация нового токена
    const newToken = generateToken(user);

    // Обновляем токен сессии
    await userModel.updateSessionToken(user.id, newToken);

    res.json({
      success: true,
      data: {
        token: newToken,
      },
      message: 'Токен успешно обновлен',
      timestamp: new Date().toISOString(),
    } as ApiResponse);

  } catch (error) {
    log.error('Refresh token error:', error);
    res.status(500).json({
      success: false,
      error: 'Внутренняя ошибка сервера',
      timestamp: new Date().toISOString(),
    } as ApiResponse);
  }
});

/**
 * @swagger
 * /api/auth/logout:
 *   post:
 *     summary: Выход из системы
 *     description: Деактивация токена (в реальном приложении добавить в blacklist)
 *     tags: [Auth]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Успешный выход
 */
router.post('/logout', async (req: any, res: any) => {
  try {
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.substring(7);
      const decoded = await verifyToken(token);

      if (decoded) {
        // Добавляем токен в blacklist
        const expiresAt = new Date(Date.now() + TOKEN_EXPIRY);
        await tokenBlacklistModel.addToBlacklist(token, decoded.id, 'logout', expiresAt);
        
        // Очищаем токен сессии
        await userModel.updateSessionToken(decoded.id, null);
        
        log.info('User logged out', { userId: decoded.id, ip: req.ip });
      }
    }

    res.json({
      success: true,
      message: 'Успешный выход из системы',
      timestamp: new Date().toISOString(),
    } as ApiResponse);

  } catch (error) {
    log.error('Logout error:', error);
    res.status(500).json({
      success: false,
      error: 'Внутренняя ошибка сервера',
      timestamp: new Date().toISOString(),
    } as ApiResponse);
  }
});

/**
 * Middleware для проверки аутентификации
 */
export function authenticateToken(req: any, res: any, next: any): void {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      success: false,
      error: 'Отсутствует заголовок авторизации',
    } as ApiResponse);
  }

  const token = authHeader.substring(7);
  
  // Асинхронная проверка токена
  verifyToken(token)
    .then(async (decoded) => {
      if (!decoded) {
        return res.status(401).json({
          success: false,
          error: 'Недействительный или истекший токен',
        } as ApiResponse);
      }

      // Поиск пользователя
      const user = await userModel.findUserById(decoded.id);
      if (!user || !user.isActive) {
        return res.status(401).json({
          success: false,
          error: 'Пользователь не найден или неактивен',
        } as ApiResponse);
      }

      // Добавление пользователя в запрос
      req.user = user;
      next();
    })
    .catch((error) => {
      log.error('Token verification error:', error);
      return res.status(500).json({
        success: false,
        error: 'Внутренняя ошибка сервера',
      } as ApiResponse);
    });
}

/**
 * Middleware для проверки ролей
 */
export function requireRole(roles: string[]) {
  return (req: any, res: any, next: any) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        error: 'Требуется аутентификация',
      } as ApiResponse);
    }

    if (!roles.includes(req.user.role)) {
      log.warn('Access denied for user', { 
        userId: req.user.id, 
        role: req.user.role, 
        requiredRoles: roles 
      });
      return res.status(403).json({
        success: false,
        error: 'Недостаточно прав доступа',
      } as ApiResponse);
    }

    next();
  };
}

/**
 * Middleware для проверки конкретных разрешений
 */
export function requirePermission(permission: string) {
  return (req: any, res: any, next: any) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        error: 'Требуется аутентификация',
      } as ApiResponse);
    }

    if (!req.user.permissions || !req.user.permissions[permission]) {
      log.warn('Permission denied for user', { 
        userId: req.user.id, 
        permission, 
        userPermissions: req.user.permissions 
      });
      return res.status(403).json({
        success: false,
        error: 'Недостаточно прав доступа',
      } as ApiResponse);
    }

    next();
  };
}

/**
 * Маршрут для смены пароля
 */
router.post('/change-password', authenticateToken, async (req: any, res: any) => {
  try {
    const { currentPassword, newPassword } = req.body;
    const user = req.user;

    // Валидация входных данных
    if (!currentPassword || !newPassword) {
      return res.status(400).json({
        success: false,
        error: 'Необходимо указать текущий и новый пароль',
      } as ApiResponse);
    }

    // Проверка длины пароля
    if (newPassword.length < 6) {
      return res.status(400).json({
        success: false,
        error: 'Пароль должен содержать минимум 6 символов',
      } as ApiResponse);
    }

    // Проверка текущего пароля
    const isCurrentPasswordValid = await userModel.validatePassword(user, currentPassword);
    if (!isCurrentPasswordValid) {
      return res.status(400).json({
        success: false,
        error: 'Неверный текущий пароль',
      } as ApiResponse);
    }

    // Хеширование нового пароля
    const hashedNewPassword = await userModel.hashPassword(newPassword);

    // Обновление пароля
    await userModel.updateUser(user.id, { 
      passwordHash: hashedNewPassword,
      passwordChangedAt: new Date()
    });

    // Аннулирование всех токенов пользователя
    await tokenBlacklistModel.blacklistAllUserTokens(user.id, 'password_change');

    log.info('Password changed successfully', { userId: user.id });

    res.json({
      success: true,
      message: 'Пароль успешно изменен',
      timestamp: new Date().toISOString(),
    } as ApiResponse);

  } catch (error) {
    log.error('Change password error:', error);
    res.status(500).json({
      success: false,
      error: 'Внутренняя ошибка сервера',
      timestamp: new Date().toISOString(),
    } as ApiResponse);
  }
});

export default router; 