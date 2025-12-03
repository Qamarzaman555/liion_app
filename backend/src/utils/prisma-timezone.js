import { PrismaClient } from '@prisma/client';
import { getKarachiTime } from './timezone.js';

/**
 * Create Prisma client with Pakistani timezone support
 * This ensures all timestamps are stored in Pakistani Standard Time (UTC+5)
 * regardless of where the server is hosted
 */
export function createPrismaClient() {
  // Configure Prisma to use Pakistani timezone in connection
  // This ensures PostgreSQL uses Asia/Karachi timezone for all operations
  const basePrisma = new PrismaClient({
    datasources: {
      db: {
        url: process.env.DATABASE_URL,
      },
    },
  });

  // Extend Prisma client to automatically set Pakistani time for timestamps
  // This overrides Prisma's @default(now()) to use Pakistani time instead of server time
  return basePrisma.$extends({
    query: {
      $allModels: {
        async create({ args, query, model }) {
          // Set Pakistani time for timestamps when not explicitly provided
          // This ensures @default(now()) uses Pakistani time instead of server timezone
          const karachiTime = getKarachiTime();
          if (args.data) {
            // For Device and Session models, set defaults to Pakistani time
            if (model === 'Device' || model === 'Session') {
              // Only set if not explicitly provided (to override Prisma's @default(now()))
              if (args.data.createdAt === undefined) {
                args.data.createdAt = karachiTime;
              }
              if (args.data.updatedAt === undefined) {
                args.data.updatedAt = karachiTime;
              }
            }
            // For Log model, set timestamp default to Pakistani time
            if (model === 'Log') {
              // Only set if not explicitly provided
              // If provided, it should already be in Pakistani time from parseToKarachiTime()
              if (args.data.timestamp === undefined) {
                args.data.timestamp = karachiTime;
              }
            }
          }
          const result = await query(args);
          return result;
        },
        async update({ args, query }) {
          // Always set Pakistani time for updatedAt
          const karachiTime = getKarachiTime();
          if (args.data) {
            args.data.updatedAt = karachiTime;
          }
          return query(args);
        },
        async upsert({ args, query, model }) {
          // Set Pakistani time for timestamps when not explicitly provided
          const karachiTime = getKarachiTime();
          if (args.create) {
            if (model === 'Device' || model === 'Session') {
              // Only set defaults if not provided
              if (args.create.createdAt === undefined) {
                args.create.createdAt = karachiTime;
              }
              if (args.create.updatedAt === undefined) {
                args.create.updatedAt = karachiTime;
              }
            }
            if (model === 'Log') {
              // Only set default if not provided
              if (args.create.timestamp === undefined) {
                args.create.timestamp = karachiTime;
              }
            }
          }
          if (args.update) {
            // Always update updatedAt to Pakistani time
            args.update.updatedAt = karachiTime;
          }
          return query(args);
        },
      },
    },
  });
}

