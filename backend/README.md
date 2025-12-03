# Liion Logging Backend

A Node.js backend service for logging application events and sessions, replacing Firebase Firestore with a custom PostgreSQL database.

## Features

- **RESTful API** for session management and log batching
- **TypeORM** for database operations with PostgreSQL
- **Swagger/OpenAPI** documentation
- **Batch logging** support (recommended batch size: 10)
- **Rate limiting** and security middleware
- **Database migrations** support
- **Error handling** and validation

## Prerequisites

- Node.js (v18 or higher)
- PostgreSQL (v12 or higher)
- npm or yarn

## Installation

1. Install dependencies:
```bash
npm install
```

2. Set up environment variables:
```bash
cp .env.example .env
```

Edit `.env` with your database credentials:
```
DB_HOST=localhost
DB_PORT=5432
DB_USERNAME=postgres
DB_PASSWORD=postgres
DB_NAME=liion_logs
```

3. Start PostgreSQL database (using Docker):
```bash
docker-compose up -d
```

Or use your own PostgreSQL instance.

4. Run database migrations:
```bash
npm run migration:run
```

## Running the Server

### Development Mode
```bash
npm run dev
```

### Production Mode
```bash
npm run build
npm start
```

The server will start on `http://localhost:3000` (or the port specified in `.env`).

## API Documentation

Once the server is running, access Swagger documentation at:
- http://localhost:3000/api-docs

## API Endpoints

### Sessions

#### Initialize Session
```
POST /api/v1/sessions/initialize
```

Request body:
```json
{
  "deviceKey": "samsung_sm-s906b - SM-S906B",
  "appVersion": "1.0.0",
  "buildNumber": "123",
  "platform": "android"
}
```

Response:
```json
{
  "success": true,
  "sessionId": 1,
  "deviceKey": "samsung_sm-s906b - SM-S906B",
  "message": "Session initialized successfully"
}
```

#### Get Session
```
GET /api/v1/sessions/:sessionId
```

### Logs

#### Batch Log Entries
```
POST /api/v1/logs/batch
```

Request body:
```json
{
  "sessionId": 1,
  "logs": [
    {
      "ts": "2024-01-01T12:00:00Z",
      "level": "INFO",
      "message": "Logging session initialized"
    },
    {
      "level": "DEBUG",
      "message": "Debug message"
    }
  ]
}
```

Response:
```json
{
  "success": true,
  "inserted": 2,
  "message": "Successfully inserted 2 log entries"
}
```

#### Get Session Logs
```
GET /api/v1/logs/session/:sessionId?level=INFO&limit=100&offset=0
```

## Database Schema

### Sessions Table
- `id` (int, primary key, auto-increment)
- `deviceKey` (varchar 255)
- `platform` (varchar 50, default: 'android')
- `appVersion` (varchar 50)
- `buildNumber` (varchar 50)
- `createdAt` (timestamp)
- `updatedAt` (timestamp)

### Log Entries Table
- `id` (int, primary key, auto-increment)
- `sessionId` (int, foreign key to sessions.id)
- `ts` (timestamp)
- `level` (varchar 50)
- `message` (text)
- `createdAt` (timestamp)

## Migration Commands

```bash
# Generate a new migration
npm run migration:generate -- src/migrations/MigrationName

# Run migrations
npm run migration:run

# Revert last migration
npm run migration:revert
```

## Health Check

```
GET /health
```

Returns server and database status.

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | Server port | 3000 |
| `NODE_ENV` | Environment (development/production) | development |
| `DB_HOST` | Database host | localhost |
| `DB_PORT` | Database port | 5432 |
| `DB_USERNAME` | Database username | postgres |
| `DB_PASSWORD` | Database password | postgres |
| `DB_NAME` | Database name | liion_logs |
| `DB_SSL` | Enable SSL for database | false |
| `API_PREFIX` | API route prefix | /api/v1 |
| `RATE_LIMIT_WINDOW_MS` | Rate limit window (ms) | 900000 |
| `RATE_LIMIT_MAX_REQUESTS` | Max requests per window | 100 |

## Project Structure

```
backend/
├── src/
│   ├── config/
│   │   ├── data-source.ts      # TypeORM configuration
│   │   └── swagger.ts           # Swagger configuration
│   ├── controllers/
│   │   ├── LogController.ts    # Log endpoints
│   │   └── SessionController.ts # Session endpoints
│   ├── dto/
│   │   ├── BatchLogDto.ts      # Batch log DTO
│   │   ├── InitializeSessionDto.ts # Session init DTO
│   │   └── LogEntryDto.ts      # Log entry DTO
│   ├── entities/
│   │   ├── LogEntry.ts         # Log entry entity
│   │   └── Session.ts          # Session entity
│   ├── middleware/
│   │   └── errorHandler.ts     # Error handling middleware
│   ├── migrations/
│   │   └── 1700000000000-InitialMigration.ts
│   ├── routes/
│   │   ├── logRoutes.ts        # Log routes
│   │   └── sessionRoutes.ts    # Session routes
│   └── server.ts               # Main server file
├── docker-compose.yml           # PostgreSQL Docker setup
├── package.json
├── tsconfig.json
└── README.md
```

## Security Features

- **Helmet.js** for security headers
- **CORS** enabled
- **Rate limiting** to prevent abuse
- **Input validation** using class-validator
- **SQL injection protection** via TypeORM parameterized queries

## Error Handling

All errors are handled consistently with the following format:
```json
{
  "success": false,
  "error": "Error type",
  "message": "Detailed error message"
}
```

## Logging Levels

Supported log levels (matching Firebase implementation):
- INFO
- DEBUG
- WARNING
- ERROR
- SCAN
- CONNECT
- CONNECTED
- AUTO_CONNECT
- DISCONNECT
- COMMAND_SENT
- COMMAND_RESPONSE
- RECONNECT
- BLE_STATE
- SERVICE
- CHARGE_LIMIT
- BATTERY
- NETWORK_OUTAGE
- NETWORK_OUTAGE_END

## Integration with Android App

To integrate this backend with your Android app, you'll need to:

1. Update `FirebaseLoggingService.kt` to use HTTP requests instead of Firebase
2. Replace Firebase calls with REST API calls to this backend
3. Use a library like Retrofit or OkHttp for HTTP requests
4. Update the base URL to point to your backend server

## License

ISC

