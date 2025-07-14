/**
 * Контроллер настроек системы
 * TODO: Будет реализован в Этапе 3
 */

import { Router } from 'express';

const router = Router();

// Временная заглушка
router.get('/', (_req, res) => {
  res.json({
    success: true,
    message: 'Settings controller - coming soon in Stage 3',
    timestamp: new Date().toISOString(),
  });
});

export default router; 