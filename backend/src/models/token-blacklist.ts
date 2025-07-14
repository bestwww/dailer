import { BaseModel } from '@/config/database'

/**
 * Интерфейс заблокированного токена
 */
export interface TokenBlacklistData {
  id: number
  token: string
  userId: number
  reason: 'logout' | 'password_change' | 'security_breach' | 'admin_revoke'
  expiresAt: Date
  createdAt: Date
}

/**
 * Модель для заблокированных JWT токенов
 */
export class TokenBlacklistModel extends BaseModel {
  private static tableName = 'token_blacklist'

  /**
   * Добавление токена в blacklist
   */
  async addToBlacklist(token: string, userId: number, reason: TokenBlacklistData['reason'], expiresAt: Date): Promise<TokenBlacklistData> {
    const data = {
      token,
      userId,
      reason,
      expiresAt,
      createdAt: new Date()
    }

    return await this.create<TokenBlacklistData>(TokenBlacklistModel.tableName, data)
  }

  /**
   * Проверка находится ли токен в blacklist
   */
  async isTokenBlacklisted(token: string): Promise<boolean> {
    const result = await this.queryOne<TokenBlacklistData>(
      `SELECT id FROM ${TokenBlacklistModel.tableName} 
       WHERE token = $1 AND expires_at > NOW()`,
      [token]
    )
    return !!result
  }

  /**
   * Добавление всех токенов пользователя в blacklist
   */
  async blacklistAllUserTokens(userId: number, reason: TokenBlacklistData['reason']): Promise<void> {
    // Заглушка - в реальном приложении нужно хранить активные токены
    console.log(`Blacklisting all tokens for user ${userId} with reason: ${reason}`)
  }

  /**
   * Очистка просроченных токенов
   */
  async cleanupExpiredTokens(): Promise<void> {
    await this.query(
      `DELETE FROM ${TokenBlacklistModel.tableName} WHERE expires_at < NOW()`
    )
  }

  /**
   * Получение количества заблокированных токенов для пользователя
   */
  async getBlacklistedTokensCount(userId: number): Promise<number> {
    const result = await this.query<{ count: string }>(
      `SELECT COUNT(*) as count FROM ${TokenBlacklistModel.tableName} 
       WHERE user_id = $1 AND expires_at > NOW()`,
      [userId]
    )
    return parseInt(result.rows[0]?.count || '0')
  }

  /**
   * Создание SQL таблицы
   */
  async createTable(): Promise<void> {
    await this.query(`
      CREATE TABLE IF NOT EXISTS ${TokenBlacklistModel.tableName} (
        id SERIAL PRIMARY KEY,
        token VARCHAR(1000) NOT NULL,
        user_id INTEGER NOT NULL,
        reason VARCHAR(50) NOT NULL,
        expires_at TIMESTAMP NOT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT NOW(),
        
        CONSTRAINT fk_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        CONSTRAINT valid_reason CHECK (reason IN ('logout', 'password_change', 'security_breach', 'admin_revoke'))
      )
    `)

    // Создание индексов
    await this.query(`
      CREATE INDEX IF NOT EXISTS idx_token_blacklist_token ON ${TokenBlacklistModel.tableName} (token);
      CREATE INDEX IF NOT EXISTS idx_token_blacklist_user_id ON ${TokenBlacklistModel.tableName} (user_id);
      CREATE INDEX IF NOT EXISTS idx_token_blacklist_expires_at ON ${TokenBlacklistModel.tableName} (expires_at);
    `)
  }
}

// Экспорт экземпляра модели
export const tokenBlacklistModel = new TokenBlacklistModel()
export default tokenBlacklistModel 