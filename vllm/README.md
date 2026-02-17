# vLLM

High-performance LLM inference server with OpenAI-compatible API.

## What it installs

- **vLLM** - Fast LLM inference engine (Docker container)
- **Starter model** - Qwen2.5-1.5B-Instruct (downloaded on first run)
- **Example scripts** - `~/vllm-examples/chat.py` and `~/vllm-examples/test_api.sh`

## ⚠️ Required Port

To access from outside Brev, open:
- **8000/tcp** (vLLM API endpoint)

## Usage

```bash
bash setup.sh
```

Takes ~8-10 minutes (downloads model on first run).

**Options (environment variables):**
```bash
VLLM_MODEL=meta-llama/Llama-3.1-8B-Instruct bash setup.sh  # Different model
VLLM_PORT=9000 bash setup.sh                               # Different port
export HF_TOKEN={YOUR_HF_TOKEN}                            # Gated models (e.g., Llama)
```

## Quick Start

**1. Wait for model to load:**
```bash
docker logs -f vllm
# Wait until you see "Uvicorn running on http://0.0.0.0:8000"
```

**2. Test with curl:**
```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen2.5-1.5B-Instruct",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 100
  }' | jq
```

**3. Use with Python (OpenAI SDK):**
```python
from openai import OpenAI

client = OpenAI(base_url="http://localhost:8000/v1", api_key="not-needed")

response = client.chat.completions.create(
    model="Qwen/Qwen2.5-1.5B-Instruct",
    messages=[{"role": "user", "content": "Explain quantum computing simply."}]
)
print(response.choices[0].message.content)
```

## Health Check

```bash
curl http://localhost:8000/health | jq
curl http://localhost:8000/v1/models | jq
```

## Popular Models

| Model | VRAM |
|-------|------|
| `Qwen/Qwen2.5-1.5B-Instruct` (default) | ~4GB |
| `meta-llama/Llama-3.1-8B-Instruct` | ~16GB |
| `mistralai/Mistral-7B-Instruct-v0.3` | ~16GB |
| `Qwen/Qwen2.5-Coder-7B-Instruct` | ~16GB |
| `meta-llama/Llama-3.1-70B-Instruct` | ~140GB |

**Note:** Gated models (e.g., Llama) require `export HF_TOKEN={YOUR_HF_TOKEN}` before running.

## Manage Service

```bash
docker logs -f vllm          # Watch startup / logs
docker restart vllm          # Restart server
docker stop vllm             # Stop server
docker start vllm            # Start server
```

## Troubleshooting

**Container exits immediately:** `docker logs vllm` (usually out of GPU memory)

**Out of memory:** Try a smaller model or quantized variant (`TheBloke/Llama-2-7B-Chat-AWQ`)

**Connection refused:** Model may still be loading — check `docker logs -f vllm`

## Resources

- **Docs:** https://docs.vllm.ai/
- **GitHub:** https://github.com/vllm-project/vllm
- **Supported Models:** https://docs.vllm.ai/en/latest/models/supported_models.html