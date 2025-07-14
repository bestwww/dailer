/**
 * Сервис для работы с PostgreSQL базой данных
 */

import { Pool, PoolClient, QueryResult, QueryResultRow } from 'pg';
import { config, isDevelopment } from './index';

/**
 * Пул соединений PostgreSQL
 */
let pool: Pool | null = null;

/**
 * Конфигурация пула соединений
 */
const poolConfig = {
  connectionString: config.databaseUrl,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
  max: 20, // максимальное количество соединений в пуле
  idleTimeoutMillis: 30000, // время ожидания неактивного соединения
  connectionTimeoutMillis: 10000, // время ожидания подключения
  // Убеждаемся, что используется UTF-8 кодировка
  client_encoding: 'UTF8',
};

/**
 * Создание пула соединений
 */
export function createPool(): Pool {
  if (!pool) {
    pool = new Pool(poolConfig);
    
    // Обработка ошибок пула
    pool.on('error', (err) => {
      console.error('Unexpected error on idle client:', err);
      process.exit(-1);
    });

    // Логирование подключений в development режиме
    if (isDevelopment) {
      pool.on('connect', () => {
        console.log('📊 New PostgreSQL client connected');
      });

      pool.on('remove', () => {
        console.log('📊 PostgreSQL client removed');
      });
    }

    console.log('✅ PostgreSQL pool created successfully');
  }
  
  return pool;
}

/**
 * Получение пула соединений
 */
export function getPool(): Pool {
  if (!pool) {
    return createPool();
  }
  return pool;
}

/**
 * Выполняет SQL запрос к базе данных
 * @param text - SQL запрос
 * @param params - Параметры для запроса
 * @returns Результат выполнения запроса
 */
export async function query<T extends QueryResultRow = any>(
  text: string,
  params?: any[]
): Promise<QueryResult<T>> {
  const poolInstance = getPool();
  const client = await poolInstance.connect();
  try {
    const result = await client.query<T>(text, params);
    return result;
  } finally {
    client.release();
  }
}

/**
 * Выполняет SQL запрос с использованием переданного клиента
 * @param client - Клиент базы данных
 * @param text - SQL запрос
 * @param params - Параметры для запроса
 * @returns Результат выполнения запроса
 */
export async function queryWithClient<T extends QueryResultRow = any>(
  client: PoolClient,
  text: string,
  params?: any[]
): Promise<QueryResult<T>> {
  const result = await client.query<T>(text, params);
  return result;
}

/**
 * Получение клиента для транзакций
 */
export async function getClient(): Promise<PoolClient> {
  return await getPool().connect();
}

/**
 * Выполнение в транзакции
 */
export async function transaction<T>(
  callback: (client: PoolClient) => Promise<T>
): Promise<T> {
  const client = await getClient();
  
  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

/**
 * Проверка подключения к базе данных
 */
export async function checkConnection(): Promise<boolean> {
  try {
    const result = await query('SELECT NOW() as current_time');
    console.log('✅ Database connection successful:', result.rows[0]?.current_time);
    return true;
  } catch (error) {
    console.error('❌ Database connection failed:', error);
    return false;
  }
}

/**
 * Получение информации о базе данных
 */
export async function getDatabaseInfo(): Promise<{
  version: string;
  totalConnections: number;
  activeConnections: number;
}> {
  try {
    const versionResult = await query('SELECT version()');
    const connectionsResult = await query(`
      SELECT 
        max_conn,
        used,
        (max_conn - used) as available
      FROM (
        SELECT 
          setting::int as max_conn,
          count(*) as used
        FROM pg_settings s
        CROSS JOIN pg_stat_activity
        WHERE s.name = 'max_connections'
        GROUP BY s.setting
      ) t
    `);

    return {
      version: versionResult.rows[0]?.version || 'Unknown',
      totalConnections: connectionsResult.rows[0]?.max_conn || 0,
      activeConnections: connectionsResult.rows[0]?.used || 0,
    };
  } catch (error) {
    console.error('❌ Failed to get database info:', error);
    throw error;
  }
}

/**
 * Закрытие пула соединений
 */
export async function closePool(): Promise<void> {
  if (pool) {
    await pool.end();
    pool = null;
    console.log('📊 PostgreSQL pool closed');
  }
}

/**
 * Базовый класс для моделей данных
 */
export abstract class BaseModel {
  /**
   * Выполняет SQL запрос
   * @param text - SQL запрос
   * @param params - Параметры для запроса
   * @returns Результат выполнения запроса
   */
  protected async query<T extends QueryResultRow = any>(text: string, params?: any[]): Promise<QueryResult<T>> {
    const poolInstance = getPool();
    const client = await poolInstance.connect();
    try {
      const result = await client.query<T>(text, params);
      return result;
    } finally {
      client.release();
    }
  }

  /**
   * Выполняет SQL запрос и возвращает первую строку результата
   * @param text - SQL запрос
   * @param params - Параметры для запроса
   * @returns Первая строка результата или undefined
   */
  protected async queryOne<T extends QueryResultRow = any>(text: string, params?: any[]): Promise<T | undefined> {
    const result = await this.query<T>(text, params);
    return result.rows[0];
  }

  /**
   * Поиск записи по ID
   */
  protected async findById<T extends QueryResultRow = any>(tableName: string, id: number): Promise<T | null> {
    const result = await this.query<T>(
      `SELECT * FROM ${tableName} WHERE id = $1`,
      [id]
    );
    return result.rows[0] || null;
  }

  /**
   * Создание записи
   */
  protected async create<T extends QueryResultRow = any>(
    tableName: string, 
    data: Record<string, any>
  ): Promise<T> {
    const keys = Object.keys(data);
    const values = Object.values(data);
    const placeholders = keys.map((_, index) => `$${index + 1}`).join(', ');
    const columns = keys.join(', ');

    const result = await this.query<T>(
      `INSERT INTO ${tableName} (${columns}) VALUES (${placeholders}) RETURNING *`,
      values
    );

    if (!result.rows[0]) {
      throw new Error(`Failed to create record in ${tableName}`);
    }

    return result.rows[0];
  }

  /**
   * Обновление записи
   */
  protected async update<T extends QueryResultRow = any>(
    tableName: string,
    id: number,
    data: Record<string, any>
  ): Promise<T | null> {
    const keys = Object.keys(data);
    const values = Object.values(data);
    const setClause = keys.map((key, index) => `${key} = $${index + 2}`).join(', ');

    const result = await this.query<T>(
      `UPDATE ${tableName} SET ${setClause}, updated_at = NOW() WHERE id = $1 RETURNING *`,
      [id, ...values]
    );

    return result.rows[0] || null;
  }

  /**
   * Удаление записи
   */
  protected async delete(tableName: string, id: number): Promise<boolean> {
    const result = await this.query(
      `DELETE FROM ${tableName} WHERE id = $1`,
      [id]
    );

    return (result.rowCount || 0) > 0;
  }

  /**
   * Подсчет записей
   */
  protected async count(tableName: string, whereClause?: string, params?: any[]): Promise<number> {
    const sql = whereClause 
      ? `SELECT COUNT(*) as count FROM ${tableName} WHERE ${whereClause}`
      : `SELECT COUNT(*) as count FROM ${tableName}`;

    const result = await this.query<{ count: string }>(sql, params);
    return parseInt(result.rows[0]?.count || '0', 10);
  }

  /**
   * Пагинация
   */
  protected async paginate<T extends QueryResultRow = any>(
    tableName: string,
    page: number = 1,
    limit: number = 10,
    whereClause?: string,
    orderBy?: string,
    params?: any[]
  ): Promise<{ items: T[]; total: number; page: number; totalPages: number }> {
    const offset = (page - 1) * limit;
    const orderClause = orderBy || 'created_at DESC';
    
    // Строим запрос
    let baseQuery = `FROM ${tableName}`;
    if (whereClause) {
      baseQuery += ` WHERE ${whereClause}`;
    }

    // Получаем общее количество
    const countResult = await this.query<{ count: string }>(
      `SELECT COUNT(*) as count ${baseQuery}`,
      params
    );
    const total = parseInt(countResult.rows[0]?.count || '0', 10);

    // Получаем данные
    const dataResult = await this.query<T>(
      `SELECT * ${baseQuery} ORDER BY ${orderClause} LIMIT $${(params?.length || 0) + 1} OFFSET $${(params?.length || 0) + 2}`,
      [...(params || []), limit, offset]
    );

    return {
      items: dataResult.rows,
      total,
      page,
      totalPages: Math.ceil(total / limit),
    };
  }
}

// Обработка завершения процесса
process.on('SIGINT', async () => {
  console.log('📊 Closing database pool...');
  await closePool();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  console.log('📊 Closing database pool...');
  await closePool();
  process.exit(0);
}); 