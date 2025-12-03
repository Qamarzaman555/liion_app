# Quick Start Guide

## Prerequisites
- Node.js 18+ installed
- Docker installed (for PostgreSQL)

## Setup Steps

1. **Install dependencies:**
   ```bash
   cd backend
   npm install
   ```

2. **Set up environment:**
   ```bash
   cp env.example .env
   # Edit .env if needed (defaults should work for local development)
   ```

3. **Start PostgreSQL database:**
   ```bash
   npm run db:up
   ```

4. **Run database migrations:**
   ```bash
   npm run migration:run
   ```

5. **Start the development server:**
   ```bash
   npm run dev
   ```

The server will be available at `http://localhost:3000`

## Test the API

### 1. Initialize a session:
```bash
curl -X POST http://localhost:3000/api/v1/sessions/initialize \
  -H "Content-Type: application/json" \
  -d '{
    "deviceKey": "samsung_sm-s906b - SM-S906B",
    "appVersion": "1.0.0",
    "buildNumber": "123",
    "platform": "android"
  }'
```

Response will include a `sessionId` - save this for the next step.

### 2. Send batch logs:
```bash
curl -X POST http://localhost:3000/api/v1/logs/batch \
  -H "Content-Type: application/json" \
  -d '{
    "sessionId": 1,
    "logs": [
      {
        "level": "INFO",
        "message": "Logging session initialized"
      },
      {
        "level": "DEBUG",
        "message": "Debug message"
      }
    ]
  }'
```

### 3. View Swagger documentation:
Open `http://localhost:3000/api-docs` in your browser.

### 4. Check health:
```bash
curl http://localhost:3000/health
```

## Production Build

```bash
npm run build
npm start
```

## Troubleshooting

### Docker daemon not running
If you see "Cannot connect to the Docker daemon":
1. **Start Docker Desktop** on macOS/Windows
2. Wait for Docker to fully start (check system tray/status)
3. Verify Docker is running: `docker ps`
4. Then retry: `npm run db:up`

**Alternative: Use local PostgreSQL**
If you have PostgreSQL installed locally:
1. Create database: `createdb liion_logs`
2. Update `.env` with your local PostgreSQL credentials
3. Skip Docker setup and proceed to migrations

### Database connection errors
- Make sure PostgreSQL is running: `docker ps` (or check local PostgreSQL service)
- Check database credentials in `.env`
- Verify database exists: `docker exec -it liion_logs_db psql -U postgres -c "\l"` (Docker) or `psql -U postgres -c "\l"` (local)

### Port already in use
- Change `PORT` in `.env` file
- Or stop the process using port 3000
- For PostgreSQL port conflict, change `DB_PORT` in `.env` and update docker-compose.yml port mapping

### Migration errors
- Make sure database is running
- Check database connection in `.env`
- Try resetting database: `npm run db:reset` (WARNING: deletes all data)

