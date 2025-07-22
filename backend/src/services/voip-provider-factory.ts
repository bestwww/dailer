/**
 * Фабрика для создания VoIP провайдеров
 * Позволяет легко переключаться между FreeSWITCH и Asterisk
 */

import { VoIPProvider, VoIPConfig, VoIPProviderType } from './voip-provider';
import { FreeSwitchAdapter } from './adapters/freeswitch-adapter';
import { AsteriskAdapter } from './adapters/asterisk-adapter';
import { config } from '@/config';
import { log } from '@/utils/logger';

export class VoIPProviderFactory {
  private static instance: VoIPProvider | null = null;

  /**
   * Создание VoIP провайдера на основе конфигурации
   */
  static create(voipConfig: VoIPConfig): VoIPProvider {
    log.info(`🏭 VoIPProviderFactory: Creating ${voipConfig.provider} provider`);

    switch (voipConfig.provider) {
      case 'freeswitch':
        if (!voipConfig.freeswitch) {
          throw new Error('FreeSWITCH configuration is required when provider is "freeswitch"');
        }
        
        log.info('🔥 VoIPProviderFactory: Creating FreeSWITCH adapter');
        return new FreeSwitchAdapter(voipConfig.freeswitch);

      case 'asterisk':
        if (!voipConfig.asterisk) {
          throw new Error('Asterisk configuration is required when provider is "asterisk"');
        }
        
        log.info('🆕 VoIPProviderFactory: Creating Asterisk adapter');
        return new AsteriskAdapter(voipConfig.asterisk);

      default:
        throw new Error(`Unsupported VoIP provider: ${voipConfig.provider}`);
    }
  }

  /**
   * Создание VoIP провайдера из переменных окружения (singleton)
   */
  static createFromConfig(): VoIPProvider {
    if (VoIPProviderFactory.instance) {
      return VoIPProviderFactory.instance;
    }

    const voipConfig = VoIPProviderFactory.buildConfigFromEnv();
    VoIPProviderFactory.instance = VoIPProviderFactory.create(voipConfig);
    
    log.info(`✅ VoIPProviderFactory: Created ${voipConfig.provider} provider instance`);
    return VoIPProviderFactory.instance;
  }

  /**
   * Построение конфигурации из переменных окружения
   */
  private static buildConfigFromEnv(): VoIPConfig {
    // Определяем провайдера из переменной окружения или используем FreeSWITCH по умолчанию
    const provider = (process.env.VOIP_PROVIDER as VoIPProviderType) || 'freeswitch';
    
    log.info(`🔧 VoIPProviderFactory: Building config for provider: ${provider}`);

    const voipConfig: VoIPConfig = {
      provider,
      freeswitch: {
        host: config.freeswitchHost,
        port: config.freeswitchPort,
        password: config.freeswitchPassword,
      },
      asterisk: {
        host: process.env.ASTERISK_HOST || 'asterisk',
        port: parseInt(process.env.ASTERISK_PORT || '5038'),
        username: process.env.ASTERISK_USERNAME || 'admin',
        password: process.env.ASTERISK_PASSWORD || 'admin',
      },
    };

    // Логируем конфигурацию (без паролей)
    log.info('📋 VoIPProviderFactory: Configuration:', {
      provider: voipConfig.provider,
      freeswitch: voipConfig.freeswitch ? {
        host: voipConfig.freeswitch.host,
        port: voipConfig.freeswitch.port,
        password: '[HIDDEN]'
      } : undefined,
      asterisk: voipConfig.asterisk ? {
        host: voipConfig.asterisk.host,
        port: voipConfig.asterisk.port,
        username: voipConfig.asterisk.username,
        password: '[HIDDEN]'
      } : undefined,
    });

    return voipConfig;
  }

  /**
   * Получение текущего провайдера (если создан)
   */
  static getCurrentProvider(): VoIPProvider | null {
    return VoIPProviderFactory.instance;
  }

  /**
   * Сброс singleton (для тестирования)
   */
  static reset(): void {
    if (VoIPProviderFactory.instance) {
      VoIPProviderFactory.instance.disconnect();
      VoIPProviderFactory.instance = null;
    }
    log.info('🔄 VoIPProviderFactory: Instance reset');
  }

  /**
   * Проверка доступности провайдера
   */
  static async testProvider(providerType: VoIPProviderType): Promise<boolean> {
    try {
      log.info(`🧪 VoIPProviderFactory: Testing ${providerType} provider`);
      
      const testConfig: VoIPConfig = {
        provider: providerType,
        ...VoIPProviderFactory.buildConfigFromEnv()
      };
      
      const provider = VoIPProviderFactory.create(testConfig);
      
      // Пытаемся подключиться
      await provider.connect();
      const isConnected = provider.isConnected();
      
      // Отключаемся после теста
      provider.disconnect();
      
      log.info(`✅ VoIPProviderFactory: ${providerType} test result: ${isConnected}`);
      return isConnected;
      
    } catch (error) {
      log.error(`❌ VoIPProviderFactory: ${providerType} test failed:`, error);
      return false;
    }
  }
}

/**
 * Глобальная функция для получения текущего VoIP провайдера
 */
export function getVoIPProvider(): VoIPProvider {
  return VoIPProviderFactory.createFromConfig();
}

/**
 * Функция для переключения провайдера во время выполнения
 */
export async function switchVoIPProvider(newProvider: VoIPProviderType): Promise<VoIPProvider> {
  log.info(`🔄 Switching VoIP provider to: ${newProvider}`);
  
  // Отключаем текущий провайдер
  const currentProvider = VoIPProviderFactory.getCurrentProvider();
  if (currentProvider) {
    currentProvider.disconnect();
  }
  
  // Сбрасываем singleton
  VoIPProviderFactory.reset();
  
  // Устанавливаем новый провайдер в переменную окружения
  process.env.VOIP_PROVIDER = newProvider;
  
  // Создаем новый провайдер
  const newProviderInstance = VoIPProviderFactory.createFromConfig();
  await newProviderInstance.connect();
  
  log.info(`✅ Successfully switched to ${newProvider} provider`);
  return newProviderInstance;
} 