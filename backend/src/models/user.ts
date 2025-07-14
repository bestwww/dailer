import { BaseModel } from '@/config/database'
import bcrypt from 'bcryptjs'

/**
 * Интерфейс пользователя системы
 */
export interface UserData {
  id: number
  username: string
  email: string
  passwordHash: string
  role: 'admin' | 'manager' | 'user' | 'viewer'
  permissions: Record<string, boolean>
  firstName?: string
  lastName?: string
  phone?: string
  isActive: boolean
  isVerified: boolean
  lastLoginAt?: Date
  loginAttempts: number
  lockoutUntil?: Date
  twoFactorSecret?: string
  twoFactorEnabled: boolean
  passwordChangedAt?: Date
  timezone: string
  language: string
  sessionToken?: string
  createdAt: Date
  updatedAt: Date
}

/**
 * Модель пользователя системы
 */
export class UserModel extends BaseModel {
  private static tableName = 'users'

  /**
   * Преобразование данных из базы в формат интерфейса
   */
  private mapFromDb(dbRow: any): UserData {
    return {
      id: dbRow.id,
      username: dbRow.username,
      email: dbRow.email,
      passwordHash: dbRow.password_hash,
      role: dbRow.role,
      permissions: dbRow.permissions || {},
      firstName: dbRow.first_name,
      lastName: dbRow.last_name,
      phone: dbRow.phone,
      isActive: dbRow.is_active,
      isVerified: dbRow.is_verified,
      lastLoginAt: dbRow.last_login_at,
      loginAttempts: dbRow.login_attempts,
      lockoutUntil: dbRow.lockout_until,
      twoFactorSecret: dbRow.two_factor_secret,
      twoFactorEnabled: dbRow.two_factor_enabled,
      passwordChangedAt: dbRow.password_changed_at,
      timezone: dbRow.timezone,
      language: dbRow.language,
      sessionToken: dbRow.session_token,
      createdAt: dbRow.created_at,
      updatedAt: dbRow.updated_at
    }
  }

  /**
   * Создание пользователя
   */
  async createUser(userData: Partial<UserData>): Promise<UserData> {
    const data = {
      username: userData.username || '',
      email: userData.email || '',
      password_hash: userData.passwordHash || '',
      role: userData.role || 'user' as const,
      permissions: userData.permissions || {},
      first_name: userData.firstName,
      last_name: userData.lastName,
      phone: userData.phone,
      is_active: userData.isActive !== undefined ? userData.isActive : true,
      is_verified: userData.isVerified !== undefined ? userData.isVerified : true,
      login_attempts: userData.loginAttempts || 0,
      two_factor_enabled: userData.twoFactorEnabled || false,
      timezone: userData.timezone || 'UTC',
      language: userData.language || 'ru',
      created_at: new Date(),
      updated_at: new Date()
    }

    const result = await super.create<any>(UserModel.tableName, data)
    return this.mapFromDb(result)
  }

  /**
   * Поиск пользователя по ID
   */
  async findUserById(id: number): Promise<UserData | null> {
    const result = await super.findById<any>(UserModel.tableName, id)
    return result ? this.mapFromDb(result) : null
  }

  /**
   * Поиск пользователя по username
   */
  async findByUsername(username: string): Promise<UserData | null> {
    const result = await this.queryOne<any>(
      `SELECT * FROM ${UserModel.tableName} WHERE username = $1`,
      [username]
    )
    return result ? this.mapFromDb(result) : null
  }

  /**
   * Поиск пользователя по email
   */
  async findByEmail(email: string): Promise<UserData | null> {
    const result = await this.queryOne<any>(
      `SELECT * FROM ${UserModel.tableName} WHERE email = $1`,
      [email]
    )
    return result ? this.mapFromDb(result) : null
  }

  /**
   * Поиск пользователя по username или email
   */
  async findByIdentifier(identifier: string): Promise<UserData | null> {
    const result = await this.queryOne<any>(
      `SELECT * FROM ${UserModel.tableName} WHERE username = $1 OR email = $1`,
      [identifier]
    )
    return result ? this.mapFromDb(result) : null
  }

  /**
   * Проверка пароля
   */
  async validatePassword(user: UserData, password: string): Promise<boolean> {
    return await bcrypt.compare(password, user.passwordHash)
  }

  /**
   * Хеширование пароля
   */
  async hashPassword(password: string): Promise<string> {
    return await bcrypt.hash(password, 12)
  }

  /**
   * Обновление данных пользователя
   */
  async updateUser(id: number, userData: Partial<UserData>): Promise<UserData | null> {
    const data = {
      password_hash: userData.passwordHash,
      first_name: userData.firstName,
      last_name: userData.lastName,
      phone: userData.phone,
      is_active: userData.isActive,
      is_verified: userData.isVerified,
      password_changed_at: userData.passwordChangedAt,
      updated_at: new Date()
    }
    
    // Удаляем undefined значения
    Object.keys(data).forEach(key => {
      if (data[key as keyof typeof data] === undefined) {
        delete data[key as keyof typeof data]
      }
    })
    
    const result = await super.update<any>(UserModel.tableName, id, data)
    return result ? this.mapFromDb(result) : null
  }

  /**
   * Обновление разрешений пользователя
   */
  async updateUserPermissions(id: number, permissions: Record<string, boolean>): Promise<UserData | null> {
    const result = await this.query(
      `UPDATE ${UserModel.tableName} 
       SET permissions = $1, 
           updated_at = NOW() 
       WHERE id = $2 
       RETURNING *`,
      [JSON.stringify(permissions), id]
    )
    
    return result.rows.length > 0 ? this.mapFromDb(result.rows[0]) : null
  }

  /**
   * Обновление разрешений пользователя по роли
   */
  async updateUserPermissionsByRole(id: number, role: string): Promise<UserData | null> {
    const permissions = this.getDefaultPermissions(role)
    return await this.updateUserPermissions(id, permissions)
  }

  /**
   * Получение разрешений по умолчанию для роли
   */
  public getDefaultPermissions(role: string): Record<string, boolean> {
    const permissions: Record<string, Record<string, boolean>> = {
      admin: {
        // Кампании
        campaigns_view: true,
        campaigns_create: true,
        campaigns_edit: true,
        campaigns_delete: true,
        
        // Контакты
        contacts_view: true,
        contacts_import: true,
        
        // Настройки и управление
        settings_manage: true,
        users_manage: true,
        
        // Статистика и мониторинг
        stats_view: true,
        monitoring_view: true
      },
      manager: {
        // Кампании
        campaigns_view: true,
        campaigns_create: true,
        campaigns_edit: true,
        campaigns_delete: false,
        
        // Контакты
        contacts_view: true,
        contacts_import: true,
        
        // Настройки и управление
        settings_manage: false,
        users_manage: false,
        
        // Статистика и мониторинг
        stats_view: true,
        monitoring_view: true
      },
      user: {
        // Кампании
        campaigns_view: true,
        campaigns_create: false,
        campaigns_edit: false,
        campaigns_delete: false,
        
        // Контакты
        contacts_view: true,
        contacts_import: false,
        
        // Настройки и управление
        settings_manage: false,
        users_manage: false,
        
        // Статистика и мониторинг
        stats_view: true,
        monitoring_view: false
      },
      viewer: {
        // Кампании
        campaigns_view: true,
        campaigns_create: false,
        campaigns_edit: false,
        campaigns_delete: false,
        
        // Контакты
        contacts_view: true,
        contacts_import: false,
        
        // Настройки и управление
        settings_manage: false,
        users_manage: false,
        
        // Статистика и мониторинг
        stats_view: true,
        monitoring_view: false
      }
    };
    
    return permissions[role] ?? permissions['viewer']!;
  }

  /**
   * Увеличение количества попыток входа
   */
  async incrementLoginAttempts(id: number): Promise<void> {
    await this.query(
      `UPDATE ${UserModel.tableName} 
       SET login_attempts = login_attempts + 1, 
           updated_at = NOW() 
       WHERE id = $1`,
      [id]
    )
  }

  /**
   * Сброс попыток входа
   */
  async resetLoginAttempts(id: number): Promise<void> {
    await this.query(
      `UPDATE ${UserModel.tableName} 
       SET login_attempts = 0, 
           lockout_until = NULL, 
           updated_at = NOW() 
       WHERE id = $1`,
      [id]
    )
  }

  /**
   * Блокировка пользователя
   */
  async lockUser(id: number, lockoutDuration: number): Promise<void> {
    const lockoutUntil = new Date(Date.now() + lockoutDuration)
    await this.query(
      `UPDATE ${UserModel.tableName} 
       SET lockout_until = $1, 
           updated_at = NOW() 
       WHERE id = $2`,
      [lockoutUntil, id]
    )
  }

  /**
   * Проверка заблокирован ли пользователь
   */
  async isUserLocked(user: UserData): Promise<boolean> {
    if (!user.lockoutUntil) return false
    return new Date() < new Date(user.lockoutUntil)
  }

  /**
   * Обновление времени последнего входа
   */
  async updateLastLogin(id: number): Promise<void> {
    await this.query(
      `UPDATE ${UserModel.tableName} 
       SET last_login_at = NOW(), 
           updated_at = NOW() 
       WHERE id = $1`,
      [id]
    )
  }

  /**
   * Обновление токена сессии
   */
  async updateSessionToken(id: number, token: string | null): Promise<void> {
    await this.query(
      `UPDATE ${UserModel.tableName} 
       SET session_token = $1, 
           updated_at = NOW() 
       WHERE id = $2`,
      [token, id]
    )
  }

  /**
   * Получение активных пользователей
   */
  async getActiveUsers(): Promise<UserData[]> {
    const result = await this.query<any>(
      `SELECT * FROM ${UserModel.tableName} WHERE is_active = true ORDER BY created_at DESC`
    )
    return result.rows.map(row => this.mapFromDb(row))
  }

  /**
   * Создание SQL таблицы
   */
  async createTable(): Promise<void> {
    await this.query(`
      CREATE TABLE IF NOT EXISTS ${UserModel.tableName} (
        id SERIAL PRIMARY KEY,
        username VARCHAR(50) UNIQUE NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        role VARCHAR(20) NOT NULL DEFAULT 'user',
        permissions JSONB NOT NULL DEFAULT '{}',
        first_name VARCHAR(100),
        last_name VARCHAR(100),
        phone VARCHAR(20),
        is_active BOOLEAN NOT NULL DEFAULT true,
        is_verified BOOLEAN NOT NULL DEFAULT true,
        last_login_at TIMESTAMP,
        login_attempts INTEGER NOT NULL DEFAULT 0,
        lockout_until TIMESTAMP,
        two_factor_secret VARCHAR(255),
        two_factor_enabled BOOLEAN NOT NULL DEFAULT false,
        password_changed_at TIMESTAMP,
        timezone VARCHAR(50) NOT NULL DEFAULT 'UTC',
        language VARCHAR(10) NOT NULL DEFAULT 'ru',
        session_token VARCHAR(255),
        created_at TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
        
        CONSTRAINT valid_role CHECK (role IN ('admin', 'manager', 'user', 'viewer')),
        CONSTRAINT valid_timezone CHECK (timezone ~ '^[A-Za-z0-9/_-]+$'),
        CONSTRAINT valid_language CHECK (language ~ '^[a-z]{2}$')
      )
    `)

    // Создание индексов
    await this.query(`
      CREATE INDEX IF NOT EXISTS idx_users_username ON ${UserModel.tableName} (username);
      CREATE INDEX IF NOT EXISTS idx_users_email ON ${UserModel.tableName} (email);
      CREATE INDEX IF NOT EXISTS idx_users_active ON ${UserModel.tableName} (is_active);
      CREATE INDEX IF NOT EXISTS idx_users_role ON ${UserModel.tableName} (role);
    `)
    
    // Создание индекса для session_token если столбец существует
    try {
      await this.query(`
        CREATE INDEX IF NOT EXISTS idx_users_session_token ON ${UserModel.tableName} (session_token);
      `)
    } catch (error) {
      console.log('Индекс session_token не создан - столбец не существует')
    }
  }

  /**
   * Создание администратора по умолчанию
   */
  async createDefaultAdmin(): Promise<UserData> {
    const existingAdmin = await this.findByUsername('admin')
    
    if (existingAdmin) {
      // Обновляем разрешения для существующего администратора
      const updatedAdmin = await this.updateUserPermissionsByRole(existingAdmin.id, 'admin')
      console.log('✅ Администратор обновлен с новыми разрешениями')
      return updatedAdmin || existingAdmin
    }

    const hashedPassword = await this.hashPassword('admin123')
    
    const adminData = {
      username: 'admin',
      email: 'admin@dialer.local',
      passwordHash: hashedPassword,
      role: 'admin' as const,
      permissions: this.getDefaultPermissions('admin'),
      firstName: 'System',
      lastName: 'Administrator',
      isActive: true,
      isVerified: true,
      timezone: 'UTC',
      language: 'ru'
    }

    const newAdmin = await this.createUser(adminData)
    console.log('✅ Новый администратор создан')
    return newAdmin
  }
}

// Экспорт экземпляра модели
export const userModel = new UserModel()
export default userModel 