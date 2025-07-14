/**
 * Роутер для загрузки аудиофайлов
 */

import { Router } from 'express';
import { Request, Response } from 'express';
import { uploadAudioFile, handleUploadError, getFileInfo } from '@/middleware/upload';
import { log } from '@/utils/logger';

const router = Router();

/**
 * Загрузка аудиофайла
 * POST /api/audio/upload
 */
router.post('/upload', uploadAudioFile, (req: Request, res: Response) => {
  try {
    const file = req.file;
    
    if (!file) {
      return res.status(400).json({
        success: false,
        error: 'Аудиофайл не был загружен'
      });
    }

    const fileInfo = getFileInfo(file);
    
    // Исправляем кодировку оригинального имени файла для корректной работы с кириллицей
    const originalName = Buffer.from(fileInfo.originalName, 'latin1').toString('utf8');
    
    log.info(`Audio file uploaded: ${originalName} -> ${fileInfo.filename}`);

    return res.json({
      success: true,
      data: {
        filePath: file.path,
        fileName: fileInfo.filename,
        originalName: originalName,
        size: fileInfo.size,
        mimetype: fileInfo.mimetype
      },
      message: 'Аудиофайл успешно загружен'
    });
  } catch (error) {
    log.error('Error uploading audio file:', error);
    return res.status(500).json({
      success: false,
      error: 'Ошибка загрузки аудиофайла'
    });
  }
}, handleUploadError);

export default router; 