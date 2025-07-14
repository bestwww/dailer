/**
 * Модель CallResult - результаты звонков и статистика
 */

import { BaseModel } from '@/config/database';
import { CallResult, CallStatus } from '@/types';
import { log } from '@/utils/logger';

export class CallResultModel extends BaseModel {
  private tableName = 'call_results';

  /**
   * Создание записи результата звонка
   */
  async createCallResult(data: {
    contactId: number;
    campaignId: number;
    callUuid?: string;
    phoneNumber: string;
    callStatus: CallStatus;
    callDuration: number;
    ringDuration: number;
    dtmfResponse?: string;
    dtmfTimestamp?: Date;
    isAnsweringMachine: boolean;
    amdConfidence?: number;
    amdDetectionTime?: number;
    bitrixLeadId?: number;
    bitrixLeadCreated?: boolean;
    bitrixError?: string;
    recordingFilePath?: string;
    recordingDuration?: number;
    callerIdName?: string;
    callerIdNumber?: string;
    hangupCause?: string;
    audioQualityScore?: number;
    networkQuality?: string;
    additionalData?: Record<string, any>;
    callStartedAt?: Date;
    callAnsweredAt?: Date;
    callEndedAt?: Date;
  }): Promise<CallResult> {
    try {
      const callResultData = {
        contact_id: data.contactId,
        campaign_id: data.campaignId,
        call_uuid: data.callUuid || null,
        phone_number: data.phoneNumber,
        
        // Результаты звонка
        call_status: data.callStatus,
        call_duration: data.callDuration,
        ring_duration: data.ringDuration,
        
        // DTMF ответ
        dtmf_response: data.dtmfResponse || null,
        dtmf_timestamp: data.dtmfTimestamp || null,
        
        // AMD результаты
        is_answering_machine: data.isAnsweringMachine,
        amd_confidence: data.amdConfidence || null,
        amd_detection_time: data.amdDetectionTime || null,
        
        // Битрикс24 интеграция
        bitrix_lead_id: data.bitrixLeadId || null,
        bitrix_lead_created: data.bitrixLeadCreated || false,
        bitrix_error: data.bitrixError || null,
        
        // Аудио записи
        recording_file_path: data.recordingFilePath || null,
        recording_duration: data.recordingDuration || null,
        
        // Технические данные
        caller_id_name: data.callerIdName || null,
        caller_id_number: data.callerIdNumber || null,
        hangup_cause: data.hangupCause || null,
        
        // Качество звонка
        audio_quality_score: data.audioQualityScore || null,
        network_quality: data.networkQuality || null,
        
        // Дополнительные данные
        additional_data: data.additionalData || {},
        
        // Времена звонка
        call_started_at: data.callStartedAt || null,
        call_answered_at: data.callAnsweredAt || null,
        call_ended_at: data.callEndedAt || null,
      };

      const callResult = await this.create<CallResult>(this.tableName, callResultData);

      log.call.answered(data.phoneNumber, data.callDuration, {
        callUuid: data.callUuid,
        status: data.callStatus,
        dtmfResponse: data.dtmfResponse,
      });

      return this.formatCallResult(callResult);

    } catch (error) {
      log.error('Failed to create call result:', error);
      throw error;
    }
  }

  /**
   * Получение результата звонка по ID
   */
  async getCallResultById(id: number): Promise<CallResult | null> {
    try {
      const callResult = await this.findById<any>(this.tableName, id);
      return callResult ? this.formatCallResult(callResult) : null;
    } catch (error) {
      log.error(`Failed to get call result ${id}:`, error);
      throw error;
    }
  }

  /**
   * Получение результатов звонков по кампании
   */
  async getCallResultsByCampaign(
    campaignId: number,
    page: number = 1,
    limit: number = 10,
    status?: CallStatus,
    phoneNumber?: string
  ): Promise<{
    callResults: CallResult[];
    total: number;
    page: number;
    totalPages: number;
  }> {
    try {
      let whereClause = 'campaign_id = $1';
      const params: any[] = [campaignId];

      if (status) {
        whereClause += ` AND call_status = $${params.length + 1}`;
        params.push(status);
      }

      if (phoneNumber) {
        whereClause += ` AND phone_number ILIKE $${params.length + 1}`;
        params.push(`%${phoneNumber}%`);
      }

      const result = await this.paginate<any>(
        this.tableName,
        page,
        limit,
        whereClause,
        'created_at DESC',
        params
      );

      return {
        callResults: result.items.map(item => this.formatCallResult(item)),
        total: result.total,
        page: result.page,
        totalPages: result.totalPages,
      };

    } catch (error) {
      log.error(`Failed to get call results for campaign ${campaignId}:`, error);
      throw error;
    }
  }

  /**
   * Получение результатов звонков по контакту
   */
  async getCallResultsByContact(contactId: number): Promise<CallResult[]> {
    try {
      const result = await this.query<any>(
        'SELECT * FROM call_results WHERE contact_id = $1 ORDER BY created_at DESC',
        [contactId]
      );

      return result.rows.map(row => this.formatCallResult(row));

    } catch (error) {
      log.error(`Failed to get call results for contact ${contactId}:`, error);
      throw error;
    }
  }

  /**
   * Получение статистики звонков по кампании
   */
  async getCallStatsByCampaign(campaignId: number): Promise<{
    totalCalls: number;
    answeredCalls: number;
    busyCalls: number;
    noAnswerCalls: number;
    failedCalls: number;
    averageCallDuration: number;
    averageRingDuration: number;
    interestedResponses: number;
    notInterestedResponses: number;
    humanAnswers: number;
    machineAnswers: number;
    answerRate: number;
    conversionRate: number;
  }> {
    try {
      const result = await this.query<any>(`
        SELECT 
          COUNT(*) as total_calls,
          COUNT(CASE WHEN call_status = 'answered' THEN 1 END) as answered_calls,
          COUNT(CASE WHEN call_status = 'busy' THEN 1 END) as busy_calls,
          COUNT(CASE WHEN call_status = 'no_answer' THEN 1 END) as no_answer_calls,
          COUNT(CASE WHEN call_status = 'failed' THEN 1 END) as failed_calls,
          AVG(call_duration) as avg_call_duration,
          AVG(ring_duration) as avg_ring_duration,
          COUNT(CASE WHEN dtmf_response = '1' THEN 1 END) as interested_responses,
          COUNT(CASE WHEN dtmf_response = '2' THEN 1 END) as not_interested_responses,
          COUNT(CASE WHEN is_answering_machine = false AND call_status = 'answered' THEN 1 END) as human_answers,
          COUNT(CASE WHEN is_answering_machine = true THEN 1 END) as machine_answers
        FROM call_results 
        WHERE campaign_id = $1
      `, [campaignId]);

      const row = result.rows[0];
      
      const totalCalls = parseInt(row.total_calls || '0', 10);
      const answeredCalls = parseInt(row.answered_calls || '0', 10);
      const interestedResponses = parseInt(row.interested_responses || '0', 10);

      const answerRate = totalCalls > 0 ? (answeredCalls / totalCalls) * 100 : 0;
      const conversionRate = answeredCalls > 0 ? (interestedResponses / answeredCalls) * 100 : 0;

      return {
        totalCalls,
        answeredCalls,
        busyCalls: parseInt(row.busy_calls || '0', 10),
        noAnswerCalls: parseInt(row.no_answer_calls || '0', 10),
        failedCalls: parseInt(row.failed_calls || '0', 10),
        averageCallDuration: parseFloat(row.avg_call_duration || '0'),
        averageRingDuration: parseFloat(row.avg_ring_duration || '0'),
        interestedResponses,
        notInterestedResponses: parseInt(row.not_interested_responses || '0', 10),
        humanAnswers: parseInt(row.human_answers || '0', 10),
        machineAnswers: parseInt(row.machine_answers || '0', 10),
        answerRate: Math.round(answerRate * 100) / 100,
        conversionRate: Math.round(conversionRate * 100) / 100,
      };

    } catch (error) {
      log.error(`Failed to get call stats for campaign ${campaignId}:`, error);
      throw error;
    }
  }

  /**
   * Получение статистики по временным интервалам
   */
  async getCallStatsTimeseries(
    campaignId: number,
    intervalHours: number = 1,
    startDate?: Date,
    endDate?: Date
  ): Promise<Array<{
    timestamp: Date;
    totalCalls: number;
    answeredCalls: number;
    failedCalls: number;
    averageDuration: number;
  }>> {
    try {
      const now = new Date();
      const start = startDate || new Date(now.getTime() - 24 * 60 * 60 * 1000); // последние 24 часа
      const end = endDate || now;

      const result = await this.query<any>(`
        SELECT 
          date_trunc('hour', created_at) + 
          INTERVAL '${intervalHours} hour' * 
          FLOOR(EXTRACT(HOUR FROM created_at) / ${intervalHours}) as timestamp,
          COUNT(*) as total_calls,
          COUNT(CASE WHEN call_status = 'answered' THEN 1 END) as answered_calls,
          COUNT(CASE WHEN call_status IN ('failed', 'busy', 'no_answer') THEN 1 END) as failed_calls,
          AVG(call_duration) as avg_duration
        FROM call_results 
        WHERE campaign_id = $1 
        AND created_at BETWEEN $2 AND $3
        GROUP BY timestamp
        ORDER BY timestamp
      `, [campaignId, start, end]);

      return result.rows.map(row => ({
        timestamp: new Date(row.timestamp),
        totalCalls: parseInt(row.total_calls || '0', 10),
        answeredCalls: parseInt(row.answered_calls || '0', 10),
        failedCalls: parseInt(row.failed_calls || '0', 10),
        averageDuration: parseFloat(row.avg_duration || '0'),
      }));

    } catch (error) {
      log.error(`Failed to get call stats timeseries for campaign ${campaignId}:`, error);
      throw error;
    }
  }

  /**
   * Получение топ номеров по количеству звонков
   */
  async getTopCallNumbers(
    campaignId: number,
    limit: number = 10
  ): Promise<Array<{
    phoneNumber: string;
    totalCalls: number;
    answeredCalls: number;
    lastCallAt: Date;
    lastCallStatus: CallStatus;
  }>> {
    try {
      const result = await this.query<any>(`
        SELECT 
          phone_number,
          COUNT(*) as total_calls,
          COUNT(CASE WHEN call_status = 'answered' THEN 1 END) as answered_calls,
          MAX(created_at) as last_call_at,
          (array_agg(call_status ORDER BY created_at DESC))[1] as last_call_status
        FROM call_results 
        WHERE campaign_id = $1
        GROUP BY phone_number
        ORDER BY total_calls DESC, last_call_at DESC
        LIMIT $2
      `, [campaignId, limit]);

      return result.rows.map(row => ({
        phoneNumber: row.phone_number,
        totalCalls: parseInt(row.total_calls || '0', 10),
        answeredCalls: parseInt(row.answered_calls || '0', 10),
        lastCallAt: new Date(row.last_call_at),
        lastCallStatus: row.last_call_status,
      }));

    } catch (error) {
      log.error(`Failed to get top call numbers for campaign ${campaignId}:`, error);
      throw error;
    }
  }

  /**
   * Удаление результатов звонков старше указанного периода
   */
  async cleanupOldCallResults(daysOld: number = 90): Promise<number> {
    try {
      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - daysOld);

      const result = await this.query<any>(
        'DELETE FROM call_results WHERE created_at < $1',
        [cutoffDate]
      );

      const deletedCount = result.rowCount || 0;
      
      if (deletedCount > 0) {
        log.info(`Cleaned up ${deletedCount} old call results older than ${daysOld} days`);
      }

      return deletedCount;

    } catch (error) {
      log.error(`Failed to cleanup old call results:`, error);
      throw error;
    }
  }

  /**
   * Форматирование данных результата звонка для API
   */
  private formatCallResult(row: any): CallResult {
    return {
      id: row.id,
      contactId: row.contact_id,
      campaignId: row.campaign_id,
      
      // Информация о звонке
      callUuid: row.call_uuid,
      phoneNumber: row.phone_number,
      
      // Результаты звонка
      callStatus: row.call_status,
      callDuration: row.call_duration,
      ringDuration: row.ring_duration,
      
      // DTMF ответ пользователя
      dtmfResponse: row.dtmf_response,
      ...(row.dtmf_timestamp && { dtmfTimestamp: new Date(row.dtmf_timestamp) }),
      
      // AMD результаты
      isAnsweringMachine: row.is_answering_machine,
      amdConfidence: row.amd_confidence,
      amdDetectionTime: row.amd_detection_time,
      
      // Битрикс24 интеграция
      bitrixLeadId: row.bitrix_lead_id,
      bitrixLeadCreated: row.bitrix_lead_created,
      bitrixError: row.bitrix_error,
      
      // Аудио записи
      recordingFilePath: row.recording_file_path,
      recordingDuration: row.recording_duration,
      
      // Технические данные
      callerIdName: row.caller_id_name,
      callerIdNumber: row.caller_id_number,
      hangupCause: row.hangup_cause,
      
      // Качество звонка
      audioQualityScore: row.audio_quality_score,
      networkQuality: row.network_quality,
      
      // Дополнительные данные
      additionalData: row.additional_data || {},
      
      // Времена звонка
      ...(row.call_started_at && { callStartedAt: new Date(row.call_started_at) }),
      ...(row.call_answered_at && { callAnsweredAt: new Date(row.call_answered_at) }),
      ...(row.call_ended_at && { callEndedAt: new Date(row.call_ended_at) }),
      
      // Временные метки
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at),
    };
  }
}

/**
 * Singleton экземпляр модели результата звонка
 */
export const callResultModel = new CallResultModel(); 