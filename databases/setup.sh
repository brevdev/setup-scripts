#!/bin/bash
set -e

echo "🗄️  Setting up databases..."

# Note: Brev already has Docker installed, so we just use it

# Create network for databases
docker network create dev-network 2>/dev/null || echo "Network already exists"

# PostgreSQL
echo "Starting PostgreSQL..."
docker run -d \
  --name postgres \
  --network dev-network \
  --restart unless-stopped \
  -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 \
  -v postgres-data:/var/lib/postgresql/data \
  postgres:16 2>/dev/null || echo "PostgreSQL already running"

# Redis
echo "Starting Redis..."
docker run -d \
  --name redis \
  --network dev-network \
  --restart unless-stopped \
  -p 6379:6379 \
  redis:7 2>/dev/null || echo "Redis already running"

# Wait for services to be ready
echo "Waiting for services..."
sleep 5

# Verify
echo ""
echo "Verifying..."
docker ps --filter "name=postgres" --filter "name=redis" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "✅ Databases ready!"
echo ""
echo "PostgreSQL: localhost:5432"
echo "  User: postgres"
echo "  Pass: postgres"
echo ""
echo "Redis: localhost:6379"
echo ""
echo "⚠️  OPEN THESE PORTS ON BREV:"
echo "  - 5432/tcp (PostgreSQL)"
echo "  - 6379/tcp (Redis)"
echo ""
echo "Manage:"
echo "  docker ps"
echo "  docker stop postgres redis"
echo "  docker start postgres redis"
echo "  docker logs postgres"

