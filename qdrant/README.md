# Qdrant

High-performance vector database for AI applications.

## What it installs

- **Qdrant** - Vector similarity search engine
- **Docker container** - Runs as background service
- **Persistent storage** - Data saved to `~/qdrant_storage`
- **Web dashboard** - Visual interface for managing collections

## Features

- **Fast vector search** - Optimized for similarity queries
- **Multiple distance metrics** - Cosine, Euclidean, Dot product
- **Filtering** - Combine vector search with metadata filters
- **HNSW indexing** - Efficient approximate nearest neighbor search
- **RESTful API** - Easy HTTP interface
- **gRPC support** - High-performance option
- **Python SDK** - Simple client library

## ⚠️ Required Ports

To access from outside Brev, open:
- **6333/tcp** (HTTP API + Dashboard)
- **6334/tcp** (gRPC - optional)

## Usage

```bash
bash setup.sh
```

Takes ~1-2 minutes.

## What you get

- **Dashboard:** `http://localhost:6333/dashboard`
- **API endpoint:** `http://localhost:6333`
- **gRPC endpoint:** `localhost:6334`
- **Storage:** `~/qdrant_storage`
- **Examples:** `~/qdrant_example.py`, `~/qdrant_rag_example.py`

## Quick Start

**Install Python client:**
```bash
pip install qdrant-client
```

**Basic usage:**
```python
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct

# Connect
client = QdrantClient(host="localhost", port=6333)

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

# Setup
client = QdrantClient(host="localhost", port=6333)
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

client = QdrantClient(host="localhost", port=6333)
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

client = QdrantClient(host="localhost", port=6333)

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
curl -X PUT http://localhost:6333/collections/test_collection \
  -H 'Content-Type: application/json' \
  -d '{
    "vectors": {
      "size": 384,
      "distance": "Cosine"
    }
  }'
```

**Insert point:**
```bash
curl -X PUT http://localhost:6333/collections/test_collection/points \
  -H 'Content-Type: application/json' \
  -d '{
    "points": [
      {"id": 1, "vector": [0.1, 0.2, ...], "payload": {"text": "example"}}
    ]
  }'
```

**Search:**
```bash
curl -X POST http://localhost:6333/collections/test_collection/points/search \
  -H 'Content-Type: application/json' \
  -d '{
    "vector": [0.1, 0.2, ...],
    "limit": 5
  }'
```

## Web Dashboard

Access at `http://localhost:6333/dashboard`

Features:
- Browse collections
- View points and payloads
- Run searches visually
- Monitor performance

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
```bash
docker logs qdrant
docker restart qdrant
```

**Out of memory:**
- Use quantization
- Enable on-disk storage
- Reduce collection size

**Slow searches:**
- Check HNSW parameters
- Ensure proper indexing
- Monitor with dashboard

## Resources

- **Docs:** https://qdrant.tech/documentation/
- **GitHub:** https://github.com/qdrant/qdrant
- **Examples:** https://qdrant.tech/documentation/examples/
- **Discord:** https://discord.gg/qdrant

