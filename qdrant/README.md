# Qdrant

High-performance vector database for AI applications.

## What it installs

- **Qdrant** - Vector similarity search engine
- **Docker container** - Runs as background service
- **Persistent storage** - Data saved to `~/qdrant_storage`
- **Web dashboard** - Visual interface for managing collections
- **API key authentication** - Secure access with auto-generated API key
- **SSL/TLS certificates** - Self-signed certificates for HTTPS access
- **Localhost binding** - Service bound to 127.0.0.1 for security

## Features

- **Fast vector search** - Optimized for similarity queries
- **Multiple distance metrics** - Cosine, Euclidean, Dot product
- **Filtering** - Combine vector search with metadata filters
- **HNSW indexing** - Efficient approximate nearest neighbor search
- **RESTful API** - Easy HTTP interface
- **gRPC support** - High-performance option
- **Python SDK** - Simple client library

## 🔒 Security

- **HTTPS/SSL encryption** - All traffic encrypted with TLS/SSL
- **Localhost binding** - Service is bound to `127.0.0.1` only (not exposed to network)
- **API key authentication** - Cryptographically secure API key required for all operations
- **API key storage** - Key saved to `~/.qdrant_api_key.env` with restricted permissions (600)
- **Self-signed certificates** - Automatically generated SSL certificates (valid for 1 year)
- **Secure remote access** - Use SSH port forwarding for remote access

## Usage

```bash
bash setup.sh
```

Takes ~1-2 minutes.

## What you get

- **Dashboard:** `https://localhost:6333/dashboard`
- **API endpoint:** `https://localhost:6333`
- **gRPC endpoint:** `localhost:6334`
- **Storage:** `~/qdrant_storage`
- **SSL certificates:** `~/qdrant_certs/`
- **Examples:** `~/qdrant_example.py`, `~/qdrant_rag_example.py`

## Retrieve API Key

The API key is stored securely in `~/.qdrant_api_key.env`:

```bash
# View API key
grep QDRANT_API_KEY ~/.qdrant_api_key.env

# Or view the entire file
cat ~/.qdrant_api_key.env

# Use in your code
source ~/.qdrant_api_key.env
echo $QDRANT_API_KEY
```

**Note:** Keep this file secure! It has restricted permissions (600) by default.

## Access & Remote Access

### Local Access

The service is bound to `localhost` (127.0.0.1) for security. Access it locally via HTTPS:

```bash
# Dashboard (requires API key)
https://localhost:6333/dashboard

# API endpoint
https://localhost:6333
```

### Remote Access via SSH Port Forwarding

For secure remote access, use SSH port forwarding:

```bash
# From your local machine - HTTP API + Dashboard
ssh -L 6333:localhost:6333 user@your-server

# From your local machine - gRPC (optional)
ssh -L 6334:localhost:6334 user@your-server

# Then access in your local browser
https://localhost:6333/dashboard
```

The API key is still required for authentication.

## Quick Start

**Install Python client:**
```bash
pip install qdrant-client
```

**Basic usage:**
```python
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct
import os

# Load API key
with open(os.path.expanduser("~/.qdrant_api_key.env")) as f:
    for line in f:
        if "=" in line and not line.startswith("#"):
            key, value = line.strip().split("=", 1)
            os.environ[key] = value

api_key = os.environ["QDRANT_API_KEY"]

# Connect with API key
client = QdrantClient(host="localhost", port=6333, api_key=api_key)

# Create collection
client.create_collection(
    collection_name="my_collection",
    vectors_config=VectorParams(size=384, distance=Distance.COSINE),
)

# Insert vectors
client.upsert(
    collection_name="my_collection",
    points=[
        PointStruct(id=1, vector=[0.1, 0.2, ...], payload={"text": "example"})
    ]
)

# Search
results = client.search(
    collection_name="my_collection",
    query_vector=[0.1, 0.2, ...],
    limit=5
)
```

## RAG Example

Complete RAG (Retrieval Augmented Generation) pipeline:

```python
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct
import openai
import os

# Load API key
with open(os.path.expanduser("~/.qdrant_api_key.env")) as f:
    for line in f:
        if "=" in line and not line.startswith("#"):
            key, value = line.strip().split("=", 1)
            os.environ[key] = value

api_key = os.environ["QDRANT_API_KEY"]

# Setup
client = QdrantClient(host="localhost", port=6333, api_key=api_key)
openai.api_key = "your-key"

# 1. Create collection
client.recreate_collection(
    collection_name="knowledge_base",
    vectors_config=VectorParams(size=1536, distance=Distance.COSINE)
)

# 2. Add documents
documents = ["Paris is the capital of France", "Berlin is in Germany"]

for i, doc in enumerate(documents):
    # Get embedding
    embedding = openai.Embedding.create(
        input=doc,
        model="text-embedding-ada-002"
    )["data"][0]["embedding"]
    
    # Store in Qdrant
    client.upsert(
        collection_name="knowledge_base",
        points=[PointStruct(id=i, vector=embedding, payload={"text": doc})]
    )

# 3. Query with RAG
query = "What is the capital of France?"

# Get query embedding
query_embedding = openai.Embedding.create(
    input=query,
    model="text-embedding-ada-002"
)["data"][0]["embedding"]

# Search for context
results = client.search(
    collection_name="knowledge_base",
    query_vector=query_embedding,
    limit=3
)

# Use context with LLM
context = "\n".join([r.payload["text"] for r in results])
response = openai.ChatCompletion.create(
    model="gpt-3.5-turbo",
    messages=[
        {"role": "system", "content": f"Context: {context}"},
        {"role": "user", "content": query}
    ]
)

print(response.choices[0].message.content)
```

## With LangChain

```python
from langchain_community.vectorstores import Qdrant
from langchain_openai import OpenAIEmbeddings
from qdrant_client import QdrantClient
import os

# Load API key
with open(os.path.expanduser("~/.qdrant_api_key.env")) as f:
    for line in f:
        if "=" in line and not line.startswith("#"):
            key, value = line.strip().split("=", 1)
            os.environ[key] = value

api_key = os.environ["QDRANT_API_KEY"]

client = QdrantClient(host="localhost", port=6333, api_key=api_key)
embeddings = OpenAIEmbeddings()

# Create vector store
vectorstore = Qdrant(
    client=client,
    collection_name="langchain_collection",
    embeddings=embeddings
)

# Add documents
vectorstore.add_texts(
    texts=["Document 1", "Document 2"],
    metadatas=[{"source": "doc1"}, {"source": "doc2"}]
)

# Search
docs = vectorstore.similarity_search("query", k=3)
```

## With LlamaIndex

```python
from llama_index.vector_stores.qdrant import QdrantVectorStore
from llama_index.core import VectorStoreIndex, StorageContext
from qdrant_client import QdrantClient
import os

# Load API key
with open(os.path.expanduser("~/.qdrant_api_key.env")) as f:
    for line in f:
        if "=" in line and not line.startswith("#"):
            key, value = line.strip().split("=", 1)
            os.environ[key] = value

api_key = os.environ["QDRANT_API_KEY"]

client = QdrantClient(host="localhost", port=6333, api_key=api_key)

# Create vector store
vector_store = QdrantVectorStore(
    client=client,
    collection_name="llamaindex_collection"
)

storage_context = StorageContext.from_defaults(vector_store=vector_store)

# Create index
index = VectorStoreIndex.from_documents(
    documents,
    storage_context=storage_context
)

# Query
query_engine = index.as_query_engine()
response = query_engine.query("What is...?")
```

## Filtering

Combine vector search with metadata filters:

```python
from qdrant_client.models import Filter, FieldCondition, MatchValue

results = client.search(
    collection_name="my_collection",
    query_vector=[0.1, 0.2, ...],
    query_filter=Filter(
        must=[
            FieldCondition(
                key="category",
                match=MatchValue(value="technology")
            )
        ]
    ),
    limit=5
)
```

## Distance Metrics

Choose the right metric for your use case:

```python
from qdrant_client.models import Distance

# Cosine similarity (most common for text)
Distance.COSINE

# Euclidean distance
Distance.EUCLID

# Dot product (for pre-normalized vectors)
Distance.DOT
```

## Collections Management

```python
# List collections
collections = client.get_collections()

# Get collection info
info = client.get_collection("my_collection")

# Delete collection
client.delete_collection("my_collection")

# Count points
count = client.count("my_collection")
```

## Snapshots & Backups

```python
# Create snapshot
snapshot_info = client.create_snapshot("my_collection")

# List snapshots
snapshots = client.list_snapshots("my_collection")

# Download snapshot
client.download_snapshot("my_collection", snapshot_info.name)
```

## Performance Tips

1. **Batch inserts** - Upsert multiple points at once
2. **Use HNSW index** - Enabled by default, tune `ef_construct` and `m`
3. **Quantization** - Reduce memory with scalar or product quantization
4. **Disk storage** - For large collections, use on-disk storage

## REST API

**Create collection:**
```bash
# Load API key
source ~/.qdrant_api_key.env

curl -X PUT https://localhost:6333/collections/test_collection \
  -H 'Content-Type: application/json' \
  -H "api-key: $QDRANT_API_KEY" \
  -d '{
    "vectors": {
      "size": 384,
      "distance": "Cosine"
    }
  }'
```

**Insert point:**
```bash
source ~/.qdrant_api_key.env

curl -X PUT https://localhost:6333/collections/test_collection/points \
  -H 'Content-Type: application/json' \
  -H "api-key: $QDRANT_API_KEY" \
  -d '{
    "points": [
      {"id": 1, "vector": [0.1, 0.2, ...], "payload": {"text": "example"}}
    ]
  }'
```

**Search:**
```bash
source ~/.qdrant_api_key.env

curl -X POST https://localhost:6333/collections/test_collection/points/search \
  -H 'Content-Type: application/json' \
  -H "api-key: $QDRANT_API_KEY" \
  -d '{
    "vector": [0.1, 0.2, ...],
    "limit": 5
  }'
```

## Web Dashboard

Access at `https://localhost:6333/dashboard` (requires API key)

Features:
- Browse collections
- View points and payloads
- Run searches visually
- Monitor performance

**Note:** You'll need to enter the API key when accessing the dashboard. Retrieve it with:
```bash
grep QDRANT_API_KEY ~/.qdrant_api_key.env
```

## Manage Service

```bash
docker ps                    # Check status
docker logs qdrant           # View logs
docker logs -f qdrant        # Follow logs
docker restart qdrant        # Restart
docker stop qdrant           # Stop
docker start qdrant          # Start
```

## Storage Location

Data persisted in: `~/qdrant_storage`

To backup:
```bash
tar -czf qdrant_backup.tar.gz ~/qdrant_storage
```

## Troubleshooting

**Connection refused:**
- Verify service is running: `docker ps | grep qdrant`
- For remote access, use SSH port forwarding (see above)
- View logs: `docker logs qdrant`

**API key not working:**
- Verify API key file exists: `ls -la ~/.qdrant_api_key.env`
- Check API key permissions: `chmod 600 ~/.qdrant_api_key.env`
- View API key: `grep QDRANT_API_KEY ~/.qdrant_api_key.env`
- Ensure API key is passed in requests (header: `api-key: <your-key>`)

**Out of memory:**
- Use quantization
- Enable on-disk storage
- Reduce collection size

**Slow searches:**
- Check HNSW parameters
- Ensure proper indexing
- Monitor with dashboard

**Can't access dashboard:**
- Verify service is running: `docker ps | grep qdrant`
- For remote access, use SSH port forwarding (see above)
- Ensure you have the API key (required for dashboard access)

## Reset API Key

If you need to reset the API key:

```bash
# Stop container
docker stop qdrant

# Remove API key file
rm ~/.qdrant_api_key.env

# Remove container (optional - this will delete data!)
docker rm qdrant

# Run setup script again
bash setup.sh
```

**Warning:** Removing the container will delete all data unless you preserve the storage volume.

## Resources

- **Docs:** https://qdrant.tech/documentation/
- **GitHub:** https://github.com/qdrant/qdrant
- **Examples:** https://qdrant.tech/documentation/examples/
- **Discord:** https://discord.gg/qdrant

