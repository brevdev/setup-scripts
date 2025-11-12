#!/bin/bash
set -e

# Create data directory for persistence
mkdir -p "$HOME/database_storage"

# 🔐 Generate self-signed TLS certificates for PostgreSQL and Redis
BASE_CERT_DIR="$HOME/database_certs"

generate_cert() {
    local SERVICE_NAME=$1
    local CERT_DIR="$BASE_CERT_DIR/$SERVICE_NAME"
    
    # Use service-specific filenames
	local CERT_FILE="$CERT_DIR/server.crt"
	local KEY_FILE="$CERT_DIR/server.key"
    
    local OPENSSL_CONF="$CERT_DIR/openssl.cnf"

    if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
        echo "Generating self-signed TLS certificate for $SERVICE_NAME..."
        mkdir -p "$CERT_DIR"

        cat > "$OPENSSL_CONF" <<EOF
[ req ]
default_bits       = 2048
prompt             = no
default_md         = sha256
distinguished_name = dn
x509_extensions    = v3_req

[ dn ]
C  = US
ST = State
L  = City
O  = Organization
CN = localhost

[ v3_req ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = localhost
IP.1  = 127.0.0.1
EOF

        # Generate certificate and private key
        openssl req -x509 -nodes -days 365 \
          -newkey rsa:2048 \
          -keyout "$KEY_FILE" \
          -out "$CERT_FILE" \
          -config "$OPENSSL_CONF" \
          -extensions v3_req

        chmod 600 "$KEY_FILE"
        chmod 644 "$CERT_FILE"
        
        # Generate CA certificate for Redis (required)
        if [ "$SERVICE_NAME" = "redis" ]; then
            openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
              -keyout "$CERT_DIR/ca.key" \
              -out "$CERT_DIR/ca.crt" \
              -subj "/C=US/ST=State/L=City/O=Organization/CN=RedisCA"
            chmod 644 "$CERT_DIR/ca.crt"
            chmod 600 "$CERT_DIR/ca.key"
        fi
        
        echo "✓ Certificate for $SERVICE_NAME created at $CERT_DIR"
    else
        echo "Using existing TLS certificate for $SERVICE_NAME from $CERT_DIR"
    fi

        echo "Setting correct permissions for $SERVICE_NAME certificates..."
    
    if command -v sudo &> /dev/null && [ "$(id -u)" -ne 0 ]; then
        # If sudo is available and not root
        sudo chown -R 999:999 "$CERT_DIR"
        sudo chmod 755 "$CERT_DIR"
        sudo chmod 600 "$CERT_DIR"/*.key 2>/dev/null || true
        sudo chmod 644 "$CERT_DIR"/*.crt 2>/dev/null || true
    else
        # If running as root or sudo not available
        chown -R 999:999 "$CERT_DIR" 2>/dev/null || true
        chmod 755 "$CERT_DIR"
        chmod 600 "$CERT_DIR"/*.key 2>/dev/null || true
        chmod 644 "$CERT_DIR"/*.crt 2>/dev/null || true
    fi
    
    echo "✓ Permissions set for $SERVICE_NAME"
}
# Generate for both services
generate_cert "postgres"
generate_cert "redis"

echo "✓ Both PostgreSQL and Redis certificates are ready."



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

echo "Stopping existing containers..."
docker stop postgres redis 2>/dev/null || true
docker rm postgres redis 2>/dev/null || true

# Clean up old data if exists and causing issues
if [ -d "$HOME/database_storage/postgres" ]; then
    echo "⚠️  Existing PostgreSQL data found. Cleaning up for fresh start..."
    sudo rm -rf "$HOME/database_storage/postgres" 2>/dev/null || rm -rf "$HOME/database_storage/postgres"
fi
# PostgreSQL
echo "Starting PostgreSQL..."
docker run -d \
  --name postgres \
  --network dev-network \
  --restart unless-stopped \
  -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
  -p 127.0.0.1:5432:5432 \
  -v "$HOME/database_storage/postgres:/var/lib/postgresql/data" \
  -v "$HOME/database_certs/postgres/server.crt:/var/lib/postgresql/server.crt:ro" \
  -v "$HOME/database_certs/postgres/server.key:/var/lib/postgresql/server.key:ro" \
  postgres:16 \
  -c ssl=on \
  -c ssl_cert_file=/var/lib/postgresql/server.crt \
  -c ssl_key_file=/var/lib/postgresql/server.key

# Redis
echo "Starting Redis..."
# Redis with TLS
echo "Starting Redis with TLS..."
docker run -d \
  --name redis \
  --network dev-network \
  --restart unless-stopped \
  -p 127.0.0.1:6379:6379 \
  -v "$HOME/database_storage/redis:/data" \
  -v "$HOME/database_certs/redis:/tls:ro" \
  redis:7 redis-server \
    --requirepass "$REDIS_PASSWORD" \
    --tls-port 6379 \
    --port 0 \
    --tls-cert-file /tls/server.crt \
    --tls-key-file /tls/server.key \
    --tls-ca-cert-file /tls/ca.crt \
    --tls-auth-clients no

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
echo "Manage:"
echo "  docker ps"
echo "  docker stop postgres redis"
echo "  docker start postgres redis"
echo "  docker logs postgres"
