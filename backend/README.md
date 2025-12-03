# Liion Logging Backend

Backend service for managing device logs, sessions, and log entries.

## Features

- RESTful API for device, session, and log management
- PostgreSQL database with Prisma ORM
- Swagger API documentation
- Real-time log ingestion (no batching)

## Prerequisites

- Node.js 18+ 
- PostgreSQL database
- npm or yarn

## Setup

1. Install dependencies:
```bash
npm install
```

2. Set up environment variables:
```bash
cp .env.example .env
# Edit .env with your database credentials
```

3. Set up the database:
```bash
# Generate Prisma client
npm run prisma:generate

# Run migrations
npm run prisma:migrate
```

4. Start the server:
```bash
# Development mode (with auto-reload)
npm run dev

# Production mode
npm start
```

The server will start on `http://0.0.0.0:3000` (accessible from physical devices on the same network).

**Important**: Update the `backendBaseUrl` in `BackendLoggingService.kt` to match your backend server IP address.

## API Documentation

Once the server is running, visit:
- Swagger UI: `http://localhost:3000/api-docs`
- Health check: `http://localhost:3000/health`

## API Endpoints

### Devices
- `GET /api/devices` - Get all devices
- `GET /api/devices/:deviceKey` - Get device by key
- `POST /api/devices` - Create or get device

### Sessions
- `GET /api/sessions/device/:deviceKey` - Get all sessions for a device
- `GET /api/sessions/:sessionId` - Get session by ID
- `POST /api/sessions` - Create a new session

### Logs
- `GET /api/logs/session/:sessionId` - Get logs for a session
- `GET /api/logs/:logId` - Get log by ID
- `POST /api/logs` - Create a new log entry (immediate write, no batching)

## Database Schema

- **Device**: Stores device information (deviceKey, platform)
- **Session**: Stores session information (deviceId, sessionId, appVersion, buildNumber)
- **Log**: Stores individual log entries (sessionId, timestamp, level, message)

## Environment Variables

- `DATABASE_URL`: PostgreSQL connection string
- `PORT`: Server port (default: 3000)
- `HOST`: Server host (default: 0.0.0.0)
- `NODE_ENV`: Environment (development/production)

## Timezone Configuration

**Important**: All timestamps are stored in **Pakistani Standard Time (UTC+5)** regardless of where the server is hosted. The backend automatically converts all timestamps to Pakistani time before storing them in the database.

- Device `createdAt` and `updatedAt`: Stored in Pakistani time
- Session `createdAt` and `updatedAt`: Stored in Pakistani time  
- Log `timestamp`: Stored in Pakistani time

This ensures consistent time representation across all data, matching the Android app's timezone.

