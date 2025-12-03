import express from 'express';
import { body, validationResult } from 'express-validator';
import { prisma } from '../utils/prisma.js';

const router = express.Router();

/**
 * @swagger
 * components:
 *   schemas:
 *     Session:
 *       type: object
 *       required:
 *         - deviceId
 *         - sessionId
 *       properties:
 *         id:
 *           type: string
 *           description: Unique session ID
 *         deviceId:
 *           type: string
 *           description: Device ID
 *         sessionId:
 *           type: string
 *           description: Numeric session ID
 *         appVersion:
 *           type: string
 *         buildNumber:
 *           type: string
 *         createdAt:
 *           type: string
 *           format: date-time
 *         updatedAt:
 *           type: string
 *           format: date-time
 */

/**
 * @swagger
 * /api/sessions/device/{deviceKey}:
 *   get:
 *     summary: Get all sessions for a device
 *     tags: [Sessions]
 *     parameters:
 *       - in: path
 *         name: deviceKey
 *         required: true
 *         schema:
 *           type: string
 *         description: Device key identifier
 *     responses:
 *       200:
 *         description: List of sessions
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: '#/components/schemas/Session'
 */
router.get('/device/:deviceKey', async (req, res, next) => {
  try {
    const { deviceKey } = req.params;

    // First get the device
    const device = await prisma.device.findUnique({
      where: { deviceKey },
    });

    if (!device) {
      return res.status(404).json({ error: 'Device not found' });
    }

    const sessions = await prisma.session.findMany({
      where: { deviceId: device.id },
      include: {
        _count: {
          select: { logs: true },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    res.json(sessions);
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/sessions/{sessionId}:
 *   get:
 *     summary: Get session by ID
 *     tags: [Sessions]
 *     parameters:
 *       - in: path
 *         name: sessionId
 *         required: true
 *         schema:
 *           type: string
 *         description: Session UUID
 *     responses:
 *       200:
 *         description: Session details
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Session'
 *       404:
 *         description: Session not found
 */
router.get('/:sessionId', async (req, res, next) => {
  try {
    const { sessionId } = req.params;
    const session = await prisma.session.findUnique({
      where: { id: sessionId },
      include: {
        device: true,
        logs: {
          orderBy: {
            timestamp: 'asc',
          },
        },
      },
    });

    if (!session) {
      return res.status(404).json({ error: 'Session not found' });
    }

    res.json(session);
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/sessions:
 *   post:
 *     summary: Create a new session
 *     tags: [Sessions]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - deviceKey
 *               - sessionId
 *             properties:
 *               deviceKey:
 *                 type: string
 *               sessionId:
 *                 type: string
 *               appVersion:
 *                 type: string
 *               buildNumber:
 *                 type: string
 *     responses:
 *       201:
 *         description: Session created
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Session'
 */
router.post(
  '/',
  [
    body('deviceKey').notEmpty().withMessage('deviceKey is required'),
    body('sessionId').notEmpty().withMessage('sessionId is required'),
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
      }

      const { deviceKey, sessionId, appVersion, buildNumber } = req.body;

      // Get or create device
      const device = await prisma.device.upsert({
        where: { deviceKey },
        update: {},
        create: {
          deviceKey,
          platform: 'android', // Default, can be passed in request if needed
        },
      });

      // Create session
      const session = await prisma.session.create({
        data: {
          deviceId: device.id,
          sessionId,
          appVersion,
          buildNumber,
        },
        include: {
          device: true,
        },
      });

      res.status(201).json(session);
    } catch (error) {
      // Handle unique constraint violation
      if (error.code === 'P2002') {
        // Session already exists, return existing session
        const { deviceKey, sessionId } = req.body;
        const device = await prisma.device.findUnique({
          where: { deviceKey },
        });
        if (device) {
          const existingSession = await prisma.session.findUnique({
            where: {
              deviceId_sessionId: {
                deviceId: device.id,
                sessionId,
              },
            },
          });
          if (existingSession) {
            return res.json(existingSession);
          }
        }
      }
      next(error);
    }
  }
);

/**
 * @swagger
 * /api/sessions/{sessionId}:
 *   delete:
 *     summary: Delete a session and all its logs
 *     tags: [Sessions]
 *     parameters:
 *       - in: path
 *         name: sessionId
 *         required: true
 *         schema:
 *           type: string
 *         description: Session UUID
 *     responses:
 *       200:
 *         description: Session deleted successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                 deletedSession:
 *                   $ref: '#/components/schemas/Session'
 *       404:
 *         description: Session not found
 */
router.delete('/:sessionId', async (req, res, next) => {
  try {
    const { sessionId } = req.params;

    // Find the session first
    const session = await prisma.session.findUnique({
      where: { id: sessionId },
      include: {
        _count: {
          select: { logs: true },
        },
      },
    });

    if (!session) {
      return res.status(404).json({ error: 'Session not found' });
    }

    // Delete session (cascades to logs due to onDelete: Cascade in schema)
    await prisma.session.delete({
      where: { id: sessionId },
    });

    console.log(`Session ${sessionId} and all associated logs deleted successfully`);
    res.json({
      message: 'Session and all associated logs deleted successfully',
      deletedSession: session,
    });
  } catch (error) {
    console.error('Error deleting session:', error);
    next(error);
  }
});

export default router;


