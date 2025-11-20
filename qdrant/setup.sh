#!/bin/bash
set -e

echo "🔍 Setting up Qdrant vector database..."

# Note: Brev already has Docker installed
echo "Using existing Docker installation..."

# Generate secure API key
if [ ! -f "$HOME/.qdrant_api_key.env" ]; then
    echo "Generating secure API key..."
    QDRANT_API_KEY=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    
    cat > "$HOME/.qdrant_api_key.env" << EOF
# Qdrant API key - Keep this file secure!
QDRANT_API_KEY=$QDRANT_API_KEY
EOF
    chmod 600 "$HOME/.qdrant_api_key.env"
    echo "✓ API key saved to $HOME/.qdrant_api_key.env"
else
    echo "Loading existing API key from $HOME/.qdrant_api_key.env"
    source "$HOME/.qdrant_api_key.env"
fi

# Create data directory for persistence
mkdir -p "$HOME/qdrant_storage"

# 🔐 Generate self-signed TLS certificate
CERT_DIR="$HOME/qdrant_certs"
CERT_FILE="$CERT_DIR/cert.pem"
KEY_FILE="$CERT_DIR/key.pem"
OPENSSL_CONF="$CERT_DIR/openssl.cnf"

if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
    echo "🔐 Generating self-signed TLS certificate..."
    mkdir -p "$CERT_DIR"

    # Create a minimal OpenSSL config with SAN (Subject Alternative Name)
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
O  = Qdrant
CN = localhost

[ v3_req ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = localhost
IP.1  = 127.0.0.1
EOF

    # Generate the key and certificate
    openssl req -x509 -nodes -days 365 \
        -newkey rsa:2048 \
        -keyout "$KEY_FILE" \
        -out "$CERT_FILE" \
        -config "$OPENSSL_CONF" \
        -extensions v3_req

    chmod 600 "$KEY_FILE"
    chmod 644 "$CERT_FILE"

    echo "✅ Self-signed certificate created at $CERT_DIR"
    echo "Certificate details:"
    openssl x509 -in "$CERT_FILE" -noout -subject -dates
else
    echo "Using existing TLS certificate from $CERT_DIR"
fi

# Stop and remove existing container if present
echo "Stopping existing Qdrant container..."
docker stop qdrant 2>/dev/null || true
docker rm qdrant 2>/dev/null || true

# Pull and run Qdrant container with TLS enabled via environment variables
echo "Starting Qdrant with TLS/HTTPS enabled..."
# Security: Bind to 127.0.0.1 only (localhost). API key required for all operations.
docker run -d \
  --name qdrant \
  --restart unless-stopped \
  -p 127.0.0.1:6333:6333 \
  -p 127.0.0.1:6334:6334 \
  -e QDRANT__SERVICE__API_KEY="$QDRANT_API_KEY" \
  -e QDRANT__SERVICE__ENABLE_TLS=true \
  -e QDRANT__TLS__CERT=/qdrant/certs/cert.pem \
  -e QDRANT__TLS__KEY=/qdrant/certs/key.pem \
  -v "$HOME/qdrant_storage:/qdrant/storage" \
  -v "$CERT_DIR:/qdrant/certs:ro" \
  qdrant/qdrant:latest

# Wait for service
echo "Waiting for Qdrant to start..."
sleep 3

# Create example Python script
cat > "$HOME/qdrant_example.py" << 'EOF'
#!/usr/bin/env python3
"""Example using Qdrant for vector search"""
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct
import os

# Load API key from environment file
api_key = os.environ.get("QDRANT_API_KEY") or "$QDRANT_API_KEY"

# Connect to Qdrant with API key
client = QdrantClient(host="localhost", port=6333, api_key=api_key)

# Create a collection
collection_name = "test_collection"
client.recreate_collection(
    collection_name=collection_name,
    vectors_config=VectorParams(size=4, distance=Distance.COSINE),
)

# Insert vectors
points = [
    PointStruct(id=1, vector=[0.05, 0.61, 0.76, 0.74], payload={"city": "Berlin"}),
    PointStruct(id=2, vector=[0.19, 0.81, 0.75, 0.11], payload={"city": "London"}),
    PointStruct(id=3, vector=[0.36, 0.55, 0.47, 0.94], payload={"city": "Paris"}),
]

client.upsert(collection_name=collection_name, points=points)

# Search
results = client.search(
    collection_name=collection_name,
    query_vector=[0.2, 0.1, 0.9, 0.7],
    limit=3
)

print("Search results:")
for result in results:
    print(f"  - {result.payload['city']}: score={result.score:.3f}")

print("\n✅ Qdrant is working!")
EOF
chmod +x "$HOME/qdrant_example.py"

# Fix all permissions if running as root
if [ "$(id -u)" -eq 0 ]; then
    chown -R $USER:$USER "$HOME/qdrant_storage"
    chown $USER:$USER "$HOME/qdrant_example.py"
fi

# Verify
echo ""
echo "Verifying installation..."
docker ps --filter "name=qdrant" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "✅ Qdrant vector database ready!"
echo ""
echo "🔐 SECURITY: Qdrant bound to localhost (127.0.0.1) only."
echo "   API key saved to: $HOME/.qdrant_api_key.env"
echo ""
echo "Dashboard: https://localhost:6333/dashboard"
echo "API endpoint: https://localhost:6333"
echo "gRPC endpoint: localhost:6334"
echo ""
echo "⚠️  SECURITY NOTE:"
echo "   Qdrant is bound to localhost only for security."
echo "   For remote access, use SSH port forwarding:"
echo "     ssh -L 6333:localhost:6333 user@server  # HTTPS API"
echo "     ssh -L 6334:localhost:6334 user@server  # gRPC (optional)"
echo ""
echo ""
echo "Install Python client:"
echo "  pip install qdrant-client"
echo ""
echo "Test installation:"
echo "  export QDRANT_API_KEY=<your_qdrant_api_key>"
echo "  python3 $HOME/qdrant_example.py"
echo "  # Or: QDRANT_API_KEY=<your_qdrant_api_key> python3 $HOME/qdrant_example.py"
echo ""
echo "See README for RAG examples"
echo ""
echo "Data stored in: $HOME/qdrant_storage"
echo ""
echo "Manage:"
echo "  docker logs qdrant        # View logs"
echo "  docker restart qdrant     # Restart"
echo "  docker stop qdrant        # Stop"
