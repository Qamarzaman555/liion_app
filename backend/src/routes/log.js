import express from 'express';
import { body, validationResult, query } from 'express-validator';
import { getKarachiTime, parseToKarachiTime, formatKarachiTime } from '../utils/timezone.js';
import { prisma } from '../utils/prisma.js';

const router = express.Router();

/**
 * @swagger
 * components:
 *   schemas:
 *     Log:
 *       type: object
 *       required:
 *         - sessionId
 *         - level
 *         - message
 *       properties:
 *         id:
 *           type: string
 *           description: Unique log ID
 *         sessionId:
 *           type: string
 *           description: Session UUID
 *         timestamp:
 *           type: string
 *           format: date-time
 *         level:
 *           type: string
 *           description: Log level (INFO, DEBUG, WARNING, ERROR, etc.)
 *         message:
 *           type: string
 *           description: Log message
 */

/**
 * @swagger
 * /api/logs/session/{sessionId}:
 *   get:
 *     summary: Get all logs for a session
 *     tags: [Logs]
 *     parameters:
 *       - in: path
 *         name: sessionId
 *         required: true
 *         schema:
 *           type: string
 *         description: Session UUID
 *       - in: query
 *         name: level
 *         schema:
 *           type: string
 *         description: Filter by log level
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 100
 *         description: Limit number of results
 *       - in: query
 *         name: offset
 *         schema:
 *           type: integer
 *           default: 0
 *         description: Offset for pagination
 *     responses:
 *       200:
 *         description: List of logs
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: '#/components/schemas/Log'
 */
router.get('/session/:sessionId', async (req, res, next) => {
  try {
    const { sessionId } = req.params;
    const { level, limit = 100, offset = 0 } = req.query;

    const where = {
      sessionId,
      ...(level && { level }),
    };

    const logs = await prisma.log.findMany({
      where,
      take: parseInt(limit),
      skip: parseInt(offset),
      orderBy: {
        timestamp: 'asc',
      },
    });

    // Format timestamps to Pakistani time (UTC+5) for display
    const formattedLogs = logs.map(log => ({
      ...log,
      timestamp: formatKarachiTime(log.timestamp),
    }));

    const total = await prisma.log.count({ where });

    res.json({
      logs: formattedLogs,
      total,
      limit: parseInt(limit),
      offset: parseInt(offset),
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/logs:
 *   post:
 *     summary: Create a new log entry
 *     tags: [Logs]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - deviceKey
 *               - sessionId
 *               - level
 *               - message
 *             properties:
 *               deviceKey:
 *                 type: string
 *                 description: Device key identifier
 *               sessionId:
 *                 type: string
 *                 description: Numeric session ID
 *               level:
 *                 type: string
 *                 description: Log level
 *               message:
 *                 type: string
 *                 description: Log message
 *               timestamp:
 *                 type: string
 *                 format: date-time
 *                 description: Optional timestamp (defaults to now)
 *     responses:
 *       201:
 *         description: Log created
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Log'
 */
router.post(
  '/',
  [
    body('deviceKey').notEmpty().withMessage('deviceKey is required'),
    body('sessionId').notEmpty().withMessage('sessionId is required'),
    body('level').notEmpty().withMessage('level is required'),
    body('message').notEmpty().withMessage('message is required'),
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
      }

      const { deviceKey, sessionId, level, message, timestamp } = req.body;

      // Get or create device
      const device = await prisma.device.upsert({
        where: { deviceKey },
        update: {},
        create: {
          deviceKey,
          platform: 'android',
        },
      });

      // Get or create session
      let dbSession = await prisma.session.findUnique({
        where: {
          deviceId_sessionId: {
            deviceId: device.id,
            sessionId,
          },
        },
      });

      if (!dbSession) {
        dbSession = await prisma.session.create({
          data: {
            deviceId: device.id,
            sessionId,
          },
        });
      }

      // Create log entry - always use Pakistani time
      // If Android provided timestamp, parse it; otherwise use current Pakistani time
      const logTimestamp = timestamp ? parseToKarachiTime(timestamp) : getKarachiTime();
      
      // Explicitly set timestamp to Pakistani time (middleware will also ensure this)
      const log = await prisma.log.create({
        data: {
          sessionId: dbSession.id,
          level,
          message,
          timestamp: logTimestamp, // Pakistani time
        },
      });

      // Format timestamp to Pakistani time for response
      const formattedLog = {
        ...log,
        timestamp: formatKarachiTime(log.timestamp),
      };

      res.status(201).json(formattedLog);
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @swagger
 * /api/logs/{logId}:
 *   get:
 *     summary: Get log by ID
 *     tags: [Logs]
 *     parameters:
 *       - in: path
 *         name: logId
 *         required: true
 *         schema:
 *           type: string
 *         description: Log UUID
 *     responses:
 *       200:
 *         description: Log details
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Log'
 *       404:
 *         description: Log not found
 */
router.get('/:logId', async (req, res, next) => {
  try {
    const { logId } = req.params;
    const log = await prisma.log.findUnique({
      where: { id: logId },
      include: {
        session: {
          include: {
            device: true,
          },
        },
      },
    });

    if (!log) {
      return res.status(404).json({ error: 'Log not found' });
    }

    // Format timestamp to Pakistani time for response
    const formattedLog = {
      ...log,
      timestamp: formatKarachiTime(log.timestamp),
    };

    res.json(formattedLog);
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/logs/session/{sessionId}:
 *   delete:
 *     summary: Delete all logs for a session
 *     tags: [Logs]
 *     parameters:
 *       - in: path
 *         name: sessionId
 *         required: true
 *         schema:
 *           type: string
 *         description: Session UUID
 *     responses:
 *       200:
 *         description: Logs deleted successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                 deletedCount:
 *                   type: integer
 */
router.delete('/session/:sessionId', async (req, res, next) => {
  try {
    const { sessionId } = req.params;

    // Check if session exists
    const session = await prisma.session.findUnique({
      where: { id: sessionId },
    });

    if (!session) {
      return res.status(404).json({ error: 'Session not found' });
    }

    // Delete all logs for this session
    const result = await prisma.log.deleteMany({
      where: { sessionId },
    });

    console.log(`Deleted ${result.count} logs for session ${sessionId}`);
    res.json({
      message: `Deleted ${result.count} log(s) for session`,
      deletedCount: result.count,
    });
  } catch (error) {
    console.error('Error deleting logs for session:', error);
    next(error);
  }
});

/**
 * @swagger
 * /api/logs/{logId}:
 *   delete:
 *     summary: Delete a log entry
 *     tags: [Logs]
 *     parameters:
 *       - in: path
 *         name: logId
 *         required: true
 *         schema:
 *           type: string
 *         description: Log UUID
 *     responses:
 *       200:
 *         description: Log deleted successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                 deletedLog:
 *                   $ref: '#/components/schemas/Log'
 *       404:
 *         description: Log not found
 */
router.delete('/:logId', async (req, res, next) => {
  try {
    const { logId } = req.params;

    // Find the log first
    const log = await prisma.log.findUnique({
      where: { id: logId },
    });

    if (!log) {
      return res.status(404).json({ error: 'Log not found' });
    }

    // Delete log
    await prisma.log.delete({
      where: { id: logId },
    });

    console.log(`Log ${logId} deleted successfully`);
    res.json({
      message: 'Log deleted successfully',
      deletedLog: {
        ...log,
        timestamp: formatKarachiTime(log.timestamp),
      },
    });
  } catch (error) {
    console.error('Error deleting log:', error);
    next(error);
  }
});

export default router;


