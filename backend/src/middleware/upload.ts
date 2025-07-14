/**
 * Middleware для загрузки файлов с использованием multer
 */

import multer from 'multer';
import path from 'path';
import fs from 'fs';
import { Request } from 'express';
import { config } from '@/config';
import { log } from '@/utils/logger';

/**
 * Настройка хранилища для аудиофайлов
 */
const audioStorage = multer.diskStorage({
  destination: (_req: Request, _file: Express.Multer.File, cb: (error: Error | null, destination: string) => void) => {
    // Создаем папку для аудиофайлов если не существует
    const uploadPath = config.audioUploadPath;
    if (!fs.existsSync(uploadPath)) {
      fs.mkdirSync(uploadPath, { recursive: true });
    }
    cb(null, uploadPath);
  },
  filename: (_req: Request, file: Express.Multer.File, cb: (error: Error | null, filename: string) => void) => {
    // Генерируем уникальное имя файла
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    const ext = path.extname(file.originalname);
    const filename = `campaign-audio-${uniqueSuffix}${ext}`;
    cb(null, filename);
  }
});

/**
 * Фильтр для проверки типа файла
 */
const audioFileFilter = (_req: Request, file: Express.Multer.File, cb: multer.FileFilterCallback) => {
  // Проверяем MIME-тип
  const allowedMimeTypes = [
    'audio/mpeg',     // MP3
    'audio/wav',      // WAV
    'audio/wave',     // WAV альтернативный
    'audio/x-wav',    // WAV альтернативный
    'audio/aiff',     // AIFF
    'audio/x-aiff',   // AIFF альтернативный
    'audio/mp4',      // M4A
    'audio/x-m4a'     // M4A альтернативный
  ];

  // Проверяем расширение файла
  const ext = path.extname(file.originalname).toLowerCase();
  const allowedExtensions = config.supportedAudioFormats.map(format => `.${format}`);

  if (allowedMimeTypes.includes(file.mimetype) || allowedExtensions.includes(ext)) {
    cb(null, true);
  } else {
    log.warn(`Rejected file upload: ${file.originalname} (${file.mimetype})`);
    cb(new Error(`Неподдерживаемый формат файла. Поддерживаются: ${config.supportedAudioFormats.join(', ')}`));
  }
};

/**
 * Middleware для загрузки одного аудиофайла
 */
export const uploadAudioFile = multer({
  storage: audioStorage,
  fileFilter: audioFileFilter,
  limits: {
    fileSize: config.audioMaxSize, // Максимальный размер файла (по умолчанию 10MB)
    files: 1 // Только один файл
  }
}).single('audio');

/**
 * Middleware для загрузки аудиофайла кампании
 */
export const uploadCampaignAudio = multer({
  storage: audioStorage,
  fileFilter: audioFileFilter,
  limits: {
    fileSize: config.audioMaxSize,
    files: 1
  }
}).single('audio');

/**
 * Middleware для обработки ошибок загрузки
 */
export const handleUploadError = (error: any, _req: Request, res: any, _next: any) => {
  if (error instanceof multer.MulterError) {
    if (error.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({
        success: false,
        error: `Размер файла слишком большой. Максимальный размер: ${config.audioMaxSize / 1024 / 1024}MB`
      });
    }
    if (error.code === 'LIMIT_FILE_COUNT') {
      return res.status(400).json({
        success: false,
        error: 'Можно загружать только один файл'
      });
    }
    if (error.code === 'LIMIT_UNEXPECTED_FILE') {
      return res.status(400).json({
        success: false,
        error: 'Неожиданное поле файла'
      });
    }
  }
  
  if (error.message) {
    return res.status(400).json({
      success: false,
      error: error.message
    });
  }
  
  log.error('Upload error:', error);
  return res.status(500).json({
    success: false,
    error: 'Ошибка загрузки файла'
  });
};

/**
 * Функция для получения информации о загруженном файле
 */
export const getFileInfo = (file: Express.Multer.File) => {
  return {
    originalName: file.originalname,
    filename: file.filename,
    path: file.path,
    size: file.size,
    mimetype: file.mimetype
  };
};

/**
 * Функция для удаления файла
 */
export const deleteFile = (filePath: string): Promise<void> => {
  return new Promise((resolve, reject) => {
    fs.unlink(filePath, (error) => {
      if (error) {
        log.error(`Error deleting file ${filePath}:`, error);
        reject(error);
      } else {
        log.info(`File deleted: ${filePath}`);
        resolve();
      }
    });
  });
}; 