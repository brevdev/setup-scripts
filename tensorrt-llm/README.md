# TensorRT-LLM

NVIDIA's optimized LLM inference engine with OpenAI-compatible API.

TensorRT-LLM compiles models into highly optimized TensorRT engines that squeeze maximum throughput out of NVIDIA GPUs. It builds a GPU-specific execution plan on first run (which takes a while), but once built, inference is extremely fast — especially with NVIDIA's pre-quantized FP8 checkpoints on Ada/Hopper GPUs. Think of it as the "compiled binary" approach to LLM serving vs. vLLM's "interpreter" approach.

## What it installs

- **TensorRT-LLM** - GPU-optimized inference with automatic engine building (Docker container)
- **Starter model** - TinyLlama-1.1B-Chat (downloaded on first run)
- **Example scripts** - `~/trtllm-examples/chat.py` and `~/trtllm-examples/test_api.sh`

## ⚠️ Required Port

To access from outside Brev, open:
- **8000/tcp** (TensorRT-LLM API endpoint)

## Usage

```bash
bash setup.sh
```

Takes ~8-10 minutes on first run (downloads model + builds TensorRT engine). Subsequent starts are much faster.

**Options (environment variables):**
```bash
TRTLLM_MODEL=nvidia/Llama-3.1-8B-Instruct-FP8 bash setup.sh  # Different model
TRTLLM_PORT=9000 bash setup.sh                                # Different port
export HF_TOKEN={YOUR_HF_TOKEN}                               # Gated models (e.g., Llama)
```

## Quick Start

**1. Wait for engine to build:**
```bash
docker logs -f trtllm
# Wait until you see "Started server process"
```

**2. Test with curl:**
```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "TinyLlama/TinyLlama-1.1B-Chat-v1.0",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 100
  }' | jq
```

**3. Use with Python (OpenAI SDK):**
```python
from openai import OpenAI

client = OpenAI(base_url="http://localhost:8000/v1", api_key="tensorrt_llm")

response = client.chat.completions.create(
    model="TinyLlama/TinyLlama-1.1B-Chat-v1.0",
    messages=[{"role": "user", "content": "Explain quantum computing simply."}]
)
print(response.choices[0].message.content)
```

## Health Check

```bash
curl http://localhost:8000/health | jq
curl http://localhost:8000/v1/models | jq
curl http://localhost:8000/metrics | jq    # GPU memory + batching stats
```

## Popular Models

| Model | VRAM | Notes |
|-------|------|-------|
| `TinyLlama/TinyLlama-1.1B-Chat-v1.0` (default) | ~4GB | Fast to build, good for testing |
| `nvidia/Llama-3.1-8B-Instruct-FP8` | ~10GB | Pre-quantized FP8, great perf |
| `nvidia/Qwen3-8B-FP8` | ~10GB | Pre-quantized FP8 |
| `meta-llama/Llama-3.1-8B-Instruct` | ~16GB | Requires HF_TOKEN |
| `mistralai/Mistral-7B-Instruct-v0.3` | ~16GB | |
| `meta-llama/Llama-3.1-70B-Instruct` | ~140GB | Multi-GPU with `--tp_size` |

**Tip:** NVIDIA's [pre-quantized FP8 models](https://huggingface.co/collections/nvidia/inference-optimized-checkpoints-with-model-optimizer) offer the best performance on FP8-capable GPUs (Ada/Hopper).

**Note:** Gated models (e.g., Llama) require `export HF_TOKEN={YOUR_HF_TOKEN}` before running.

## Advanced Options

**Tensor parallelism (multi-GPU):**
```bash
# Serve on the container, then exec in to set tp_size
docker run -d --name trtllm --gpus all --ipc host \
  -p 8000:8000 nvcr.io/nvidia/tensorrt-llm/release:latest \
  trtllm-serve serve meta-llama/Llama-3.1-70B-Instruct \
  --host 0.0.0.0 --port 8000 --tp_size 4
```

**Custom image tag:**
```bash
TRTLLM_IMAGE=nvcr.io/nvidia/tensorrt-llm/release:1.3.0rc2 bash setup.sh
```

## Manage Service

```bash
docker logs -f trtllm          # Watch startup / logs
docker restart trtllm          # Restart server
docker stop trtllm             # Stop server
docker start trtllm            # Start server
```

## Troubleshooting

**Container exits immediately:** `docker logs trtllm` (usually out of GPU memory)

**Out of memory:** Try a smaller model or NVIDIA's FP8 quantized variants

**Engine build fails:** Ensure sufficient GPU memory — engine building needs more VRAM than inference

**Connection refused:** Engine may still be building — check `docker logs -f trtllm`

**Slow first start:** Normal — TensorRT compiles an optimized engine on first run. Subsequent starts reuse the cached engine

## Resources

- **Docs:** https://nvidia.github.io/TensorRT-LLM/
- **GitHub:** https://github.com/NVIDIA/TensorRT-LLM
- **Quick Start:** https://nvidia.github.io/TensorRT-LLM/quick-start-guide.html
- **Supported Models:** https://nvidia.github.io/TensorRT-LLM/models/supported-models.html
- **Pre-quantized Models:** https://huggingface.co/collections/nvidia/inference-optimized-checkpoints-with-model-optimizer