# Alternative Database Setup Options

If Docker is not available or you prefer a different setup, here are alternatives:

## Option 1: Local PostgreSQL Installation

### macOS (using Homebrew)
```bash
# Install PostgreSQL
brew install postgresql@15

# Start PostgreSQL service
brew services start postgresql@15

# Create database
createdb liion_logs

# Create user (optional, can use default postgres user)
createuser -s postgres
```

### Update .env
```env
DB_HOST=localhost
DB_PORT=5432
DB_USERNAME=postgres
DB_PASSWORD=your_password  # or leave empty if no password
DB_NAME=liion_logs
```

## Option 2: PostgreSQL via Homebrew (macOS)

```bash
# Install
brew install postgresql

# Start service
brew services start postgresql

# Create database
psql postgres -c "CREATE DATABASE liion_logs;"
```

## Option 3: Use SQLite (Development Only)

For quick testing, you can modify the data source to use SQLite:

### Update `src/config/data-source.ts`:
```typescript
import { DataSource } from 'typeorm';
import { Session } from '../entities/Session';
import { LogEntry } from '../entities/LogEntry';

export const AppDataSource = new DataSource({
  type: 'sqlite',
  database: 'liion_logs.db',
  synchronize: true, // Auto-create tables (development only)
  logging: true,
  entities: [Session, LogEntry],
});
```

**Note:** SQLite is not recommended for production. Use PostgreSQL for production deployments.

## Option 4: Cloud PostgreSQL (Production)

### Heroku Postgres
1. Create a Heroku app
2. Add Postgres addon: `heroku addons:create heroku-postgresql:mini`
3. Get connection string: `heroku config:get DATABASE_URL`
4. Update `.env` with connection details

### AWS RDS, Google Cloud SQL, etc.
Use your cloud provider's PostgreSQL service and update `.env` with the connection details.

## Option 5: Docker Alternative - Podman

If you prefer Podman over Docker:
```bash
# Use podman-compose instead
podman-compose up -d
```

## Verifying Your Setup

After setting up PostgreSQL (any method), verify connection:

```bash
# Test connection
psql -h localhost -U postgres -d liion_logs -c "SELECT version();"
```

Or update the connection test in your `.env` and run:
```bash
npm run migration:run
```

If migrations run successfully, your database is properly configured!

