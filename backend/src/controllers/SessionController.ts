import { Request, Response } from 'express';
import { AppDataSource } from '../config/data-source';
import { Session } from '../entities/Session';
import { InitializeSessionDto } from '../dto/InitializeSessionDto';
import { validate } from 'class-validator';

/**
 * @swagger
 * /api/v1/sessions:
 *   post:
 *     summary: Create a new session/device
 *     tags: [Sessions]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/InitializeSessionRequest'
 *     responses:
 *       200:
 *         description: Session created successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/InitializeSessionResponse'
 *       400:
 *         description: Invalid request data
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
export class SessionController {
    async createSession(req: Request, res: Response): Promise<void> {
        try {
            const dto = new InitializeSessionDto();
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

            // Create new session
            const session = new Session();
            session.deviceKey = dto.deviceKey;
            session.platform = dto.platform || 'android';
            session.appVersion = dto.appVersion;
            session.buildNumber = dto.buildNumber;

            const savedSession = await sessionRepository.save(session);

            res.status(200).json({
                success: true,
                sessionId: savedSession.id,
                deviceKey: savedSession.deviceKey,
                message: 'Session created successfully',
            });
        } catch (error) {
            console.error('Error initializing session:', error);
            res.status(500).json({
                success: false,
                error: 'Internal server error',
                message: error instanceof Error ? error.message : 'Unknown error',
            });
        }
    }

    /**
     * @swagger
     * /api/v1/sessions/{sessionId}:
     *   get:
     *     summary: Get session information
     *     tags: [Sessions]
     *     parameters:
     *       - in: path
     *         name: sessionId
     *         required: true
     *         schema:
     *           type: number
     *         description: Session ID
     *     responses:
     *       200:
     *         description: Session information
     *       404:
     *         description: Session not found
     */
    async getSession(req: Request, res: Response): Promise<void> {
        try {
            const sessionId = parseInt(req.params.sessionId, 10);
            if (isNaN(sessionId)) {
                res.status(400).json({
                    success: false,
                    error: 'Invalid session ID',
                });
                return;
            }

            const sessionRepository = AppDataSource.getRepository(Session);
            const session = await sessionRepository.findOne({
                where: { id: sessionId },
                relations: ['logs'],
            });

            if (!session) {
                res.status(404).json({
                    success: false,
                    error: 'Session not found',
                });
                return;
            }

            res.status(200).json({
                success: true,
                session: {
                    id: session.id,
                    deviceKey: session.deviceKey,
                    platform: session.platform,
                    appVersion: session.appVersion,
                    buildNumber: session.buildNumber,
                    createdAt: session.createdAt,
                    logCount: session.logs?.length || 0,
                },
            });
        } catch (error) {
            console.error('Error getting session:', error);
            res.status(500).json({
                success: false,
                error: 'Internal server error',
                message: error instanceof Error ? error.message : 'Unknown error',
            });
        }
    }
}

