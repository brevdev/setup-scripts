#!/bin/bash
set -e

echo "🗄️  Setting up databases..."

# Note: Brev already has Docker installed, so we just use it

# Generate secure passwords
if [ ! -f "$HOME/.db_passwords.env" ]; then
    echo "Generating secure passwords..."
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    
    cat > "$HOME/.db_passwords.env" << EOF
# Database passwords - Keep this file secure!
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
REDIS_PASSWORD=$REDIS_PASSWORD
EOF
    chmod 600 "$HOME/.db_passwords.env"
    echo "✓ Passwords saved to $HOME/.db_passwords.env"
else
    echo "Loading existing passwords from $HOME/.db_passwords.env"
    source "$HOME/.db_passwords.env"
fi

# Create network for databases
docker network create dev-network 2>/dev/null || echo "Network already exists"

# PostgreSQL
echo "Starting PostgreSQL..."
docker run -d \
  --name postgres \
  --network dev-network \
  --restart unless-stopped \
  -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
  -p 127.0.0.1:5432:5432 \
  -v postgres-data:/var/lib/postgresql/data \
  postgres:16 2>/dev/null || echo "PostgreSQL already running"

# Redis
echo "Starting Redis..."
docker run -d \
  --name redis \
  --network dev-network \
  --restart unless-stopped \
  -p 127.0.0.1:6379:6379 \
  redis:7 redis-server --requirepass "$REDIS_PASSWORD" 2>/dev/null || echo "Redis already running"

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
echo "🔐 SECURITY: Services bound to localhost (127.0.0.1) only."
echo "   Passwords saved to: $HOME/.db_passwords.env"
echo ""
echo "PostgreSQL: localhost:5432"
echo "  User: postgres"
echo "  Password can be retrieved with: grep POSTGRES_PASSWORD $HOME/.db_passwords.env)"
echo ""
echo "Redis: localhost:6379"
echo "  Password can be retrieved with: grep REDIS_PASSWORD $HOME/.db_passwords.env"
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

