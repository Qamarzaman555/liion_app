import { createPrismaClient } from './prisma-timezone.js';

/**
 * Shared Prisma client instance with Pakistani timezone support
 * All routes should import this instead of creating new PrismaClient instances
 */
export const prisma = createPrismaClient();

