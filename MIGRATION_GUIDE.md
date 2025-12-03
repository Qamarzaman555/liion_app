# Migration Guide: Firebase to Custom Backend Logging

This guide explains the migration from Firebase logging to a custom Node.js backend.

## Overview

The logging system has been migrated from Firebase Firestore to a custom Node.js backend with:
- PostgreSQL database
- Prisma ORM
- Swagger API documentation
- Real-time log ingestion (no batching)

## Backend Setup

### 1. Install Dependencies

```bash
cd backend
npm install
```

### 2. Configure Database

Edit `backend/.env` with your PostgreSQL credentials:

```env
DATABASE_URL="postgresql://user:password@localhost:5432/liion_logs?schema=public"
PORT=3000
HOST=0.0.0.0
NODE_ENV=development
```

### 3. Set Up Database

```bash
# Generate Prisma client
npm run prisma:generate

# Run migrations
npm run prisma:migrate
```

### 4. Start Backend Server

```bash
# Development mode (with auto-reload)
npm run dev

# Production mode
npm start
```

The server will start on `http://0.0.0.0:3000` (accessible from physical devices).

### 5. Access Swagger Documentation

Once the server is running, visit:
- Swagger UI: `http://localhost:3000/api-docs`
- Health check: `http://localhost:3000/health`

## Android App Configuration

### 1. Update Backend URL

Edit `android/app/src/main/kotlin/com/example/liion_app/BackendLoggingService.kt`:

```kotlin
// For Android emulator:
private val backendBaseUrl: String = "http://10.0.2.2:3000"

// For physical device (replace with your computer's IP):
private val backendBaseUrl: String = "http://192.168.1.100:3000"
```

**To find your computer's IP:**
- macOS/Linux: `ifconfig` or `ip addr`
- Windows: `ipconfig`

### 2. Network Security

The Android app is configured to allow HTTP connections for local development. The `network_security_config.xml` file allows cleartext traffic.

**Important**: For production, switch to HTTPS and update the network security config accordingly.

## Key Changes

### Removed Features
- ✅ Firebase Firestore dependency
- ✅ Batch logging (logs are now sent immediately)
- ✅ Local log buffering
- ✅ Retry mechanisms for Samsung devices

### New Features
- ✅ Direct HTTP API calls
- ✅ Immediate log writes (no batching)
- ✅ Swagger API documentation
- ✅ PostgreSQL database with proper relationships

## Database Schema

```
Device
  ├── id (UUID)
  ├── deviceKey (unique)
  ├── platform
  └── sessions[]
      └── Session
          ├── id (UUID)
          ├── deviceId
          ├── sessionId (numeric: 1, 2, 3...)
          ├── appVersion
          ├── buildNumber
          └── logs[]
              └── Log
                  ├── id (UUID)
                  ├── sessionId
                  ├── timestamp
                  ├── level
                  └── message
```

## API Endpoints

### Devices
- `GET /api/devices` - List all devices
- `GET /api/devices/:deviceKey` - Get device by key
- `POST /api/devices` - Create or get device

### Sessions
- `GET /api/sessions/device/:deviceKey` - Get sessions for device
- `GET /api/sessions/:sessionId` - Get session by UUID
- `POST /api/sessions` - Create session

### Logs
- `GET /api/logs/session/:sessionId` - Get logs for session
- `GET /api/logs/:logId` - Get log by UUID
- `POST /api/logs` - Create log entry (immediate write)

## Testing

1. Start the backend server
2. Build and run the Android app
3. Check logs in Swagger UI: `http://localhost:3000/api-docs`
4. Query logs via API or use Prisma Studio: `npm run prisma:studio`

## Troubleshooting

### Android app can't connect to backend
- Verify backend is running: `curl http://localhost:3000/health`
- Check firewall settings
- Ensure Android device and backend are on the same network
- Verify IP address in `BackendLoggingService.kt`

### Database connection errors
- Verify PostgreSQL is running
- Check `DATABASE_URL` in `.env`
- Ensure database exists: `CREATE DATABASE liion_logs;`

### Logs not appearing
- Check backend logs for errors
- Verify network connectivity on Android device
- Check Swagger UI for API errors
- Review Android logcat: `adb logcat | grep BackendLogging`

## Production Considerations

1. **HTTPS**: Switch backend to HTTPS and update Android network security config
2. **Authentication**: Add API authentication/authorization
3. **Rate Limiting**: Implement rate limiting for log endpoints
4. **Monitoring**: Add logging and monitoring for the backend
5. **Backup**: Set up database backups
6. **Environment Variables**: Use secure environment variable management


