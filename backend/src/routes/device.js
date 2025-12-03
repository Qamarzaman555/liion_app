import express from 'express';
import { body, validationResult } from 'express-validator';
import { prisma } from '../utils/prisma.js';

const router = express.Router();

/**
 * @swagger
 * components:
 *   schemas:
 *     Device:
 *       type: object
 *       required:
 *         - deviceKey
 *         - platform
 *       properties:
 *         id:
 *           type: string
 *           description: Unique device ID
 *         deviceKey:
 *           type: string
 *           description: Device identifier (e.g., "device - model")
 *         platform:
 *           type: string
 *           description: Platform (e.g., "android")
 *         createdAt:
 *           type: string
 *           format: date-time
 *         updatedAt:
 *           type: string
 *           format: date-time
 */

/**
 * @swagger
 * /api/devices:
 *   get:
 *     summary: Get all devices
 *     tags: [Devices]
 *     responses:
 *       200:
 *         description: List of all devices
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: '#/components/schemas/Device'
 */
router.get('/', async (req, res, next) => {
  try {
    const devices = await prisma.device.findMany({
      include: {
        sessions: {
          include: {
            _count: {
              select: { logs: true },
            },
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });
    res.json(devices);
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/devices/{deviceKey}:
 *   get:
 *     summary: Get device by deviceKey
 *     tags: [Devices]
 *     parameters:
 *       - in: path
 *         name: deviceKey
 *         required: true
 *         schema:
 *           type: string
 *         description: Device key identifier
 *     responses:
 *       200:
 *         description: Device details
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Device'
 *       404:
 *         description: Device not found
 */
router.get('/:deviceKey', async (req, res, next) => {
  try {
    const { deviceKey } = req.params;
    const device = await prisma.device.findUnique({
      where: { deviceKey },
      include: {
        sessions: {
          include: {
            _count: {
              select: { logs: true },
            },
          },
          orderBy: {
            createdAt: 'desc',
          },
        },
      },
    });

    if (!device) {
      return res.status(404).json({ error: 'Device not found' });
    }

    res.json(device);
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/devices:
 *   post:
 *     summary: Create or get device
 *     tags: [Devices]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - deviceKey
 *               - platform
 *             properties:
 *               deviceKey:
 *                 type: string
 *               platform:
 *                 type: string
 *     responses:
 *       200:
 *         description: Device created or retrieved
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Device'
 */
router.post(
  '/',
  [
    body('deviceKey').notEmpty().withMessage('deviceKey is required'),
    body('platform').notEmpty().withMessage('platform is required'),
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        console.error('Device creation validation errors:', errors.array());
        return res.status(400).json({ errors: errors.array() });
      }

      const { deviceKey, platform } = req.body;
      console.log(`Creating/retrieving device: ${deviceKey}, platform: ${platform}`);

      // Upsert device (create if not exists, otherwise return existing)
      // This ensures device is always created if it doesn't exist
      const device = await prisma.device.upsert({
        where: { deviceKey },
        update: {}, // Don't update if exists
        create: {
          deviceKey,
          platform,
        },
      });

      console.log(`Device ${deviceKey} created/retrieved successfully`);
      // Return 200 for both create and update (upsert doesn't distinguish)
      res.status(200).json(device);
    } catch (error) {
      console.error('Error in device creation:', error);
      next(error);
    }
  }
);

/**
 * @swagger
 * /api/devices/{deviceKey}:
 *   delete:
 *     summary: Delete a device and all its sessions and logs
 *     tags: [Devices]
 *     parameters:
 *       - in: path
 *         name: deviceKey
 *         required: true
 *         schema:
 *           type: string
 *         description: Device key identifier
 *     responses:
 *       200:
 *         description: Device deleted successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                 deletedDevice:
 *                   $ref: '#/components/schemas/Device'
 *       404:
 *         description: Device not found
 */
router.delete('/:deviceKey', async (req, res, next) => {
  try {
    const { deviceKey } = req.params;

    // Find the device first
    const device = await prisma.device.findUnique({
      where: { deviceKey },
      include: {
        sessions: {
          include: {
            _count: {
              select: { logs: true },
            },
          },
        },
      },
    });

    if (!device) {
      return res.status(404).json({ error: 'Device not found' });
    }

    // Delete device (cascades to sessions and logs due to onDelete: Cascade in schema)
    await prisma.device.delete({
      where: { deviceKey },
    });

    console.log(`Device ${deviceKey} and all associated data deleted successfully`);
    res.json({
      message: 'Device and all associated sessions and logs deleted successfully',
      deletedDevice: device,
    });
  } catch (error) {
    console.error('Error deleting device:', error);
    next(error);
  }
});

export default router;


