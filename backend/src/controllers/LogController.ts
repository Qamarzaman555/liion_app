import { Request, Response } from 'express';
import { AppDataSource } from '../config/data-source';
import { LogEntry } from '../entities/LogEntry';
import { Session } from '../entities/Session';
import { BatchLogDto } from '../dto/BatchLogDto';
import { validate } from 'class-validator';

/**
 * @swagger
 * /api/v1/logs/batch:
 *   post:
 *     summary: Add a batch of log entries (auto-creates session if device info provided)
 *     tags: [Logs]
 *     description: |
 *       Send logs with either:
 *       - sessionId: Use existing session
 *       - deviceKey + appVersion + buildNumber: Auto-create new session
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/BatchLogRequest'
 *     responses:
 *       200:
 *         description: Logs added successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/BatchLogResponse'
 *       400:
 *         description: Invalid request data
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       404:
 *         description: Session not found (only if sessionId provided)
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
export class LogController {
  async batchLog(req: Request, res: Response): Promise<void> {
    try {
      const dto = new BatchLogDto();
      Object.assign(dto, req.body);

      const errors = await validate(dto);
      if (errors.length > 0) {
        res.status(400).json({
          success: false,
          error: 'Validation failed',
          message: errors.map((e: any) => Object.values(e.constraints || {})).flat().join(', '),
        });
        return;
      }

      const sessionRepository = AppDataSource.getRepository(Session);
      let sessionId: number;

      // Auto-create session if device info is provided
      if (dto.deviceKey) {
        if (!dto.appVersion || !dto.buildNumber) {
          res.status(400).json({
            success: false,
            error: 'Validation failed',
            message: 'deviceKey requires appVersion and buildNumber',
          });
          return;
        }

        // Create new session
        const session = new Session();
        session.deviceKey = dto.deviceKey;
        session.platform = dto.platform || 'android';
        session.appVersion = dto.appVersion;
        session.buildNumber = dto.buildNumber;

        const savedSession = await sessionRepository.save(session);
        sessionId = savedSession.id;
      } else if (dto.sessionId) {
        // Use existing session
        const session = await sessionRepository.findOne({
          where: { id: dto.sessionId },
        });

        if (!session) {
          res.status(404).json({
            success: false,
            error: 'Session not found',
            message: `Session with ID ${dto.sessionId} does not exist`,
          });
          return;
        }
        sessionId = dto.sessionId;
      } else {
        res.status(400).json({
          success: false,
          error: 'Validation failed',
          message: 'Either sessionId or deviceKey (with appVersion and buildNumber) is required',
        });
        return;
      }

      // Create log entries
      const logRepository = AppDataSource.getRepository(LogEntry);
      const logEntries = dto.logs.map((logDto) => {
        const logEntry = new LogEntry();
        logEntry.sessionId = sessionId;
        logEntry.level = logDto.level;
        logEntry.message = logDto.message;
        logEntry.ts = logDto.ts ? new Date(logDto.ts) : new Date();
        return logEntry;
      });

      // Batch insert
      const savedLogs = await logRepository.save(logEntries);

      res.status(200).json({
        success: true,
        sessionId: sessionId,
        inserted: savedLogs.length,
        message: `Successfully inserted ${savedLogs.length} log entries`,
      });
    } catch (error) {
      console.error('Error batch logging:', error);
      res.status(500).json({
        success: false,
        error: 'Internal server error',
        message: error instanceof Error ? error.message : 'Unknown error',
      });
    }
  }

  /**
   * @swagger
   * /api/v1/logs/session/{sessionId}:
   *   get:
   *     summary: Get logs for a session
   *     tags: [Logs]
   *     parameters:
   *       - in: path
   *         name: sessionId
   *         required: true
   *         schema:
   *           type: number
   *         description: Session ID
   *       - in: query
   *         name: level
   *         schema:
   *           type: string
   *         description: Filter by log level
   *       - in: query
   *         name: limit
   *         schema:
   *           type: number
   *           default: 100
   *         description: Maximum number of logs to return
   *       - in: query
   *         name: offset
   *         schema:
   *           type: number
   *           default: 0
   *         description: Number of logs to skip
   *     responses:
   *       200:
   *         description: List of logs
   *       404:
   *         description: Session not found
   */
  async getSessionLogs(req: Request, res: Response): Promise<void> {
    try {
      const sessionId = parseInt(req.params.sessionId, 10);
      if (isNaN(sessionId)) {
        res.status(400).json({
          success: false,
          error: 'Invalid session ID',
        });
        return;
      }

      const level = req.query.level as string | undefined;
      const limit = parseInt(req.query.limit as string, 10) || 100;
      const offset = parseInt(req.query.offset as string, 10) || 0;

      // Verify session exists
      const sessionRepository = AppDataSource.getRepository(Session);
      const session = await sessionRepository.findOne({
        where: { id: sessionId },
      });

      if (!session) {
        res.status(404).json({
          success: false,
          error: 'Session not found',
        });
        return;
      }

      const logRepository = AppDataSource.getRepository(LogEntry);
      const queryBuilder = logRepository
        .createQueryBuilder('log')
        .where('log.sessionId = :sessionId', { sessionId })
        .orderBy('log.ts', 'ASC')
        .skip(offset)
        .take(limit);

      if (level) {
        queryBuilder.andWhere('log.level = :level', { level });
      }

      const [logs, total] = await queryBuilder.getManyAndCount();

      res.status(200).json({
        success: true,
        logs: logs.map((log) => ({
          id: log.id,
          ts: log.ts,
          level: log.level,
          message: log.message,
        })),
        pagination: {
          total,
          limit,
          offset,
          hasMore: offset + logs.length < total,
        },
      });
    } catch (error) {
      console.error('Error getting session logs:', error);
      res.status(500).json({
        success: false,
        error: 'Internal server error',
        message: error instanceof Error ? error.message : 'Unknown error',
      });
    }
  }
}

