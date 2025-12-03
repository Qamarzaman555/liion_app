import swaggerJsdoc from 'swagger-jsdoc';

const options: swaggerJsdoc.Options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'Liion Logging API',
      version: '1.0.0',
      description: 'API for logging application events and sessions',
      contact: {
        name: 'API Support',
      },
    },
    servers: [
      {
        url: `http://localhost:${process.env.PORT || 3000}`,
        description: 'Development server',
      },
    ],
    components: {
      schemas: {
        InitializeSessionRequest: {
          type: 'object',
          required: ['deviceKey', 'appVersion', 'buildNumber'],
          properties: {
            deviceKey: {
              type: 'string',
              description: 'Device identifier (e.g., "device - model")',
              example: 'samsung_sm-s906b - SM-S906B',
            },
            appVersion: {
              type: 'string',
              description: 'Application version',
              example: '1.0.0',
            },
            buildNumber: {
              type: 'string',
              description: 'Build number',
              example: '123',
            },
            platform: {
              type: 'string',
              description: 'Platform (default: android)',
              example: 'android',
              default: 'android',
            },
          },
        },
        InitializeSessionResponse: {
          type: 'object',
          properties: {
            success: {
              type: 'boolean',
            },
            sessionId: {
              type: 'number',
              description: 'Session ID',
            },
            deviceKey: {
              type: 'string',
            },
            message: {
              type: 'string',
            },
          },
        },
        LogEntry: {
          type: 'object',
          required: ['level', 'message'],
          properties: {
            ts: {
              type: 'string',
              format: 'date-time',
              description: 'Timestamp (ISO 8601). If not provided, server timestamp will be used.',
            },
            level: {
              type: 'string',
              description: 'Log level',
              enum: [
                'INFO',
                'DEBUG',
                'WARNING',
                'ERROR',
                'SCAN',
                'CONNECT',
                'CONNECTED',
                'AUTO_CONNECT',
                'DISCONNECT',
                'COMMAND_SENT',
                'COMMAND_RESPONSE',
                'RECONNECT',
                'BLE_STATE',
                'SERVICE',
                'CHARGE_LIMIT',
                'BATTERY',
                'NETWORK_OUTAGE',
                'NETWORK_OUTAGE_END',
              ],
            },
            message: {
              type: 'string',
              description: 'Log message',
            },
          },
        },
        BatchLogRequest: {
          type: 'object',
          required: ['logs'],
          properties: {
            sessionId: {
              type: 'number',
              description: 'Session ID (optional if device info provided)',
            },
            deviceKey: {
              type: 'string',
              description: 'Device identifier (required if sessionId not provided)',
              example: 'samsung_sm-s906b - SM-S906B',
            },
            appVersion: {
              type: 'string',
              description: 'App version (required if deviceKey provided)',
              example: '1.0.0',
            },
            buildNumber: {
              type: 'string',
              description: 'Build number (required if deviceKey provided)',
              example: '123',
            },
            platform: {
              type: 'string',
              description: 'Platform (optional, default: android)',
              example: 'android',
              default: 'android',
            },
            logs: {
              type: 'array',
              items: {
                $ref: '#/components/schemas/LogEntry',
              },
              description: 'Array of log entries (batch size recommended: 10)',
            },
          },
        },
        BatchLogResponse: {
          type: 'object',
          properties: {
            success: {
              type: 'boolean',
            },
            sessionId: {
              type: 'number',
              description: 'Session ID (returned if session was auto-created)',
            },
            inserted: {
              type: 'number',
              description: 'Number of logs inserted',
            },
            message: {
              type: 'string',
            },
          },
        },
        ErrorResponse: {
          type: 'object',
          properties: {
            success: {
              type: 'boolean',
              example: false,
            },
            error: {
              type: 'string',
            },
            message: {
              type: 'string',
            },
          },
        },
      },
    },
  },
  apis: ['./src/routes/*.ts', './src/controllers/*.ts'],
};

export const swaggerSpec = swaggerJsdoc(options);

