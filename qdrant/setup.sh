#!/bin/bash
set -e

echo "🔍 Setting up Qdrant vector database..."

# Note: Brev already has Docker installed
echo "Using existing Docker installation..."

# Create data directory for persistence
mkdir -p "$HOME/qdrant_storage"

# Pull and run Qdrant container
echo "Starting Qdrant..."
docker run -d \
  --name qdrant \
  --restart unless-stopped \
  -p 6333:6333 \
  -p 6334:6334 \
  -v "$HOME/qdrant_storage:/qdrant/storage" \
  qdrant/qdrant:latest 2>/dev/null || echo "Qdrant container already running"

# Wait for service
echo "Waiting for Qdrant to start..."
sleep 3

# Create example Python script
cat > "$HOME/qdrant_example.py" << 'EOF'
#!/usr/bin/env python3
"""Example using Qdrant for vector search"""
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct

# Connect to Qdrant
client = QdrantClient(host="localhost", port=6333)

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
echo "Dashboard: http://localhost:6333/dashboard"
echo "API endpoint: http://localhost:6333"
echo "gRPC endpoint: localhost:6334"
echo ""
echo "⚠️  To access from outside Brev, open ports:"
echo "  - 6333/tcp (HTTP API & Dashboard)"
echo "  - 6334/tcp (gRPC - optional)"
echo ""
echo "Install Python client:"
echo "  pip install qdrant-client"
echo ""
echo "Test installation:"
echo "  python3 $HOME/qdrant_example.py"
echo ""
echo "See README for RAG examples"
echo ""
echo "Data stored in: $HOME/qdrant_storage"
echo ""
echo "Manage:"
echo "  docker logs qdrant        # View logs"
echo "  docker restart qdrant     # Restart"
echo "  docker stop qdrant        # Stop"

