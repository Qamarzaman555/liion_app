#!/bin/bash

# Setup script for Liion Logging Backend

echo "Setting up Liion Logging Backend..."

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "Error: Node.js is not installed. Please install Node.js 18+ first."
    exit 1
fi

# Check Node.js version
NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo "Error: Node.js version 18+ is required. Current version: $(node -v)"
    exit 1
fi

# Check if PostgreSQL is installed
if ! command -v psql &> /dev/null; then
    echo "Warning: PostgreSQL is not installed or not in PATH."
    echo "Please ensure PostgreSQL is installed and running."
fi

# Install dependencies
echo "Installing dependencies..."
npm install

# Generate Prisma client
echo "Generating Prisma client..."
npm run prisma:generate

# Check if .env exists
if [ ! -f .env ]; then
    echo "Creating .env file from .env.example..."
    cp .env.example .env
    echo ""
    echo "Please edit .env file with your database credentials:"
    echo "  DATABASE_URL=\"postgresql://user:password@localhost:5432/liion_logs?schema=public\""
    echo ""
    read -p "Press Enter after you've updated the .env file..."
fi

# Run migrations
echo "Running database migrations..."
npm run prisma:migrate

echo ""
echo "Setup complete!"
echo ""
echo "To start the server:"
echo "  npm run dev    # Development mode with auto-reload"
echo "  npm start      # Production mode"
echo ""
echo "Swagger documentation will be available at:"
echo "  http://localhost:3000/api-docs"
echo ""


