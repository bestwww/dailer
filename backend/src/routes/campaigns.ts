/**
 * Роутер для управления кампаниями
 */

import { Router } from 'express';
import {
  getCampaigns,
  createCampaign,
  getCampaignById,
  updateCampaign,
  deleteCampaign,
  startCampaign,
  stopCampaign,
  pauseCampaign,
  getCampaignsStats,
  uploadCampaignAudio,
  scheduleCampaign,
  unscheduleCampaign,
  getScheduledCampaigns,
  getSchedulerStatus,
  validateCronExpression
} from '@/controllers/campaigns';
import { uploadCampaignAudio as uploadMiddleware, handleUploadError } from '@/middleware/upload';

const router = Router();

// Основные CRUD операции
router.get('/', getCampaigns);
router.post('/', createCampaign);
router.get('/stats', getCampaignsStats);
router.get('/:id', getCampaignById);
router.put('/:id', updateCampaign);
router.delete('/:id', deleteCampaign);

// Управление кампаниями
router.post('/:id/start', startCampaign);
router.post('/:id/stop', stopCampaign);
router.post('/:id/pause', pauseCampaign);

// Планировщик кампаний
router.post('/:id/schedule', scheduleCampaign);
router.delete('/:id/schedule', unscheduleCampaign);
router.get('/scheduler/status', getSchedulerStatus);
router.get('/scheduler/campaigns', getScheduledCampaigns);
router.post('/scheduler/validate-cron', validateCronExpression);

// Загрузка аудио с multer middleware
router.post('/:id/audio', uploadMiddleware, uploadCampaignAudio, handleUploadError);

export default router; 