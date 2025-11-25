# vLLM

High-performance LLM inference with OpenAI-compatible API.

## What it installs

- **vLLM** - Fast LLM inference engine with PagedAttention
- **Python virtual environment** - Isolated Python environment
- **OpenAI-compatible API** - Drop-in replacement for OpenAI API
- **Systemd service** - Auto-restart and logging
- **Example scripts** - Python and curl examples

## Features

- **⚡ Fast** - 24x throughput vs HuggingFace, 2-4x faster than Ollama
- **🎯 Production-ready** - Used by major companies (Cloudflare, NVIDIA, etc.)
- **🔌 OpenAI-compatible** - Works with OpenAI SDK/clients
- **🔥 Multi-GPU support** - Tensor parallelism across GPUs
- **📦 Any model** - Support for Llama, Mistral, Qwen, Phi, etc.
- **💾 Efficient memory** - PagedAttention for 2x memory efficiency
- **🔄 Continuous batching** - High throughput under load

## Requirements

- **NVIDIA GPU** - Required (A10, L4, V100, A100, H100, etc.)
- **8GB+ VRAM** - For 7B models (3B models work with 6GB)
- **CUDA** - Already provided by Brev

## ⚠️ Required Port

To access from outside Brev, open:
- **8000/tcp** (vLLM API endpoint)

## Usage

```bash
bash setup.sh
```

Takes ~3-5 minutes.

## What you get

- **API Endpoint:** `http://localhost:8000`
- **Configuration:** `~/vllm-server/config.env`
- **Examples:** `~/vllm-examples/`
- **Service:** Auto-starts on boot (after first manual start)

## Quick Start

### 1. Configure the model

Edit `~/vllm-server/config.env`:

```bash
nano ~/vllm-server/config.env
```

**For open models (Mistral, Qwen, Phi):**
```bash
MODEL_NAME="mistralai/Mistral-7B-Instruct-v0.3"
```

**For gated models (Llama):**
1. Get HuggingFace token: https://huggingface.co/settings/tokens
2. Accept model license on HuggingFace (e.g., https://huggingface.co/meta-llama/Llama-3.2-3B-Instruct)
3. Add token to config:
```bash
HF_TOKEN="hf_your_token_here"
```

### 2. Start the service

```bash
sudo systemctl start vllm
```

**Monitor the first start (downloads model):**
```bash
sudo journalctl -u vllm -f
```

The first start takes 3-10 minutes to download the model. Look for:
```
INFO: Waiting for application startup.
INFO: Application startup complete.
```

### 3. Test it works

```bash
# Check service is running
sudo systemctl status vllm

# Test API
curl http://localhost:8000/v1/models

# Run Python example
python3 ~/vllm-examples/test_api.py
```

## Model Selection Guide

### Small & Fast (6-8GB VRAM)

```bash
# Llama 3.2 3B - Great quality for size
MODEL_NAME="meta-llama/Llama-3.2-3B-Instruct"

# Phi-3 Mini - Microsoft's efficient model
MODEL_NAME="microsoft/Phi-3-mini-4k-instruct"

# Gemma 2B - Google's small model
MODEL_NAME="google/gemma-2b-it"
```

### Medium (12-16GB VRAM)

```bash
# Llama 3.1 8B - Excellent all-around
MODEL_NAME="meta-llama/Llama-3.1-8B-Instruct"

# Mistral 7B - Fast and capable
MODEL_NAME="mistralai/Mistral-7B-Instruct-v0.3"

# Qwen 2.5 7B - Best for coding
MODEL_NAME="Qwen/Qwen2.5-7B-Instruct"

# Nous Hermes 2 - Creative writing
MODEL_NAME="NousResearch/Hermes-2-Pro-Llama-3-8B"
```

### Large (24GB+ VRAM)

```bash
# Llama 3.1 70B (requires 40GB+ VRAM or multi-GPU)
MODEL_NAME="meta-llama/Llama-3.1-70B-Instruct"

# Qwen 2.5 32B
MODEL_NAME="Qwen/Qwen2.5-32B-Instruct"

# DeepSeek Coder 33B
MODEL_NAME="deepseek-ai/deepseek-coder-33b-instruct"
```

### Quantized (Lower memory)

```bash
# AWQ quantized models (half the memory)
MODEL_NAME="TheBloke/Llama-2-13B-chat-AWQ"
MODEL_NAME="TheBloke/Mistral-7B-Instruct-v0.2-AWQ"
```

## Multi-GPU Configuration

If you have multiple GPUs:

```bash
# Edit config
nano ~/vllm-server/config.env

# Set tensor parallelism to GPU count
TENSOR_PARALLEL_SIZE="2"  # For 2 GPUs
TENSOR_PARALLEL_SIZE="4"  # For 4 GPUs
TENSOR_PARALLEL_SIZE="8"  # For 8 GPUs

# Restart service
sudo systemctl restart vllm
```

**Example:** Serve Llama 70B on 2x A100 (40GB each):
```bash
MODEL_NAME="meta-llama/Llama-3.1-70B-Instruct"
TENSOR_PARALLEL_SIZE="2"
```

## API Usage

### Python (OpenAI SDK)

```python
from openai import OpenAI

# Point to vLLM server
client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="EMPTY"
)

# Chat completion
response = client.chat.completions.create(
    model="meta-llama/Llama-3.2-3B-Instruct",
    messages=[
        {"role": "system", "content": "You are a helpful coding assistant."},
        {"role": "user", "content": "Write a Python function to sort a list."}
    ],
    temperature=0.7,
    max_tokens=500
)

print(response.choices[0].message.content)
```

### Python (Streaming)

```python
stream = client.chat.completions.create(
    model="meta-llama/Llama-3.2-3B-Instruct",
    messages=[{"role": "user", "content": "Tell me a story."}],
    stream=True,
    max_tokens=500
)

for chunk in stream:
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="", flush=True)
```

### cURL

```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Llama-3.2-3B-Instruct",
    "messages": [
      {"role": "user", "content": "Hello!"}
    ],
    "temperature": 0.7,
    "max_tokens": 100
  }'
```

### JavaScript/TypeScript

```typescript
import OpenAI from 'openai';

const client = new OpenAI({
  baseURL: 'http://localhost:8000/v1',
  apiKey: 'EMPTY'
});

const response = await client.chat.completions.create({
  model: 'meta-llama/Llama-3.2-3B-Instruct',
  messages: [{ role: 'user', content: 'Hello!' }]
});

console.log(response.choices[0].message.content);
```

## Advanced Configuration

### Optimize for throughput

```bash
nano ~/vllm-server/config.env

# Increase batch size
MAX_NUM_SEQS="512"

# Use more GPU memory
GPU_MEMORY_UTILIZATION="0.95"

# Restart
sudo systemctl restart vllm
```

### Optimize for latency

```bash
# Smaller batch size
MAX_NUM_SEQS="64"

# Lower memory usage (more free for KV cache)
GPU_MEMORY_UTILIZATION="0.85"
```

### Longer context windows

```bash
# Extend max length (uses more memory)
MAX_MODEL_LEN="8192"  # or 16384, 32768
```

### Add API authentication

Edit service file:

```bash
sudo nano /etc/systemd/system/vllm.service
```

Add to ExecStart line:
```bash
--api-key "your-secret-key"
```

Reload and restart:
```bash
sudo systemctl daemon-reload
sudo systemctl restart vllm
```

Now use with:
```python
client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="your-secret-key"
)
```

## Manage Service

```bash
# Start service
sudo systemctl start vllm

# Stop service
sudo systemctl stop vllm

# Restart service
sudo systemctl restart vllm

# Check status
sudo systemctl status vllm

# View logs (live)
sudo journalctl -u vllm -f

# View recent logs
sudo journalctl -u vllm -n 100
```

## Performance Monitoring

### Check GPU usage

```bash
watch -n 1 nvidia-smi
```

### API health check

```bash
curl http://localhost:8000/health
curl http://localhost:8000/v1/models
```

### Request metrics

vLLM logs show:
- Requests per second
- Token throughput
- KV cache usage
- GPU memory usage

```bash
sudo journalctl -u vllm -f | grep "Avg prompt throughput"
```

## Troubleshooting

### Service won't start

**Check logs:**
```bash
sudo journalctl -u vllm -n 50 --no-pager
```

**Common issues:**

1. **Out of memory:**
   - Use smaller model
   - Lower `GPU_MEMORY_UTILIZATION` to 0.8
   - Reduce `MAX_MODEL_LEN`

2. **HuggingFace token invalid:**
   - Verify token at https://huggingface.co/settings/tokens
   - Accept model license on HuggingFace
   - Check `HF_TOKEN` in `~/vllm-server/config.env`

3. **Model not found:**
   - Verify model name on HuggingFace
   - Check internet connection
   - Try: `huggingface-cli login` with your token

### Slow first request

This is normal! vLLM:
1. Downloads model on first start (3-10 minutes)
2. Loads model into GPU (30-60 seconds)
3. Warms up inference engine

Subsequent requests are fast.

### Out of GPU memory

```bash
# Check current memory
nvidia-smi

# Solutions:
# 1. Use smaller model
# 2. Lower GPU memory usage
nano ~/vllm-server/config.env
GPU_MEMORY_UTILIZATION="0.8"  # Was 0.9

# 3. Reduce max length
MAX_MODEL_LEN="2048"  # Was 4096

# 4. Use quantized model (AWQ/GPTQ)
MODEL_NAME="TheBloke/Mistral-7B-Instruct-v0.2-AWQ"

# Restart
sudo systemctl restart vllm
```

### Model download fails

```bash
# Manual download
cd ~/.cache/huggingface
export HF_TOKEN="hf_your_token"

# Install huggingface-cli
pip install huggingface-hub

# Login
huggingface-cli login

# Download model
huggingface-cli download meta-llama/Llama-3.2-3B-Instruct
```

### API returns errors

```bash
# Check service is running
sudo systemctl status vllm

# Check logs for errors
sudo journalctl -u vllm -n 50

# Test health endpoint
curl http://localhost:8000/health

# Verify model loaded
curl http://localhost:8000/v1/models
```

### Change model

```bash
# 1. Stop service
sudo systemctl stop vllm

# 2. Edit config
nano ~/vllm-server/config.env
# Change MODEL_NAME

# 3. Clear cache (optional, saves disk space)
rm -rf ~/.cache/huggingface/hub/*

# 4. Start service
sudo systemctl start vllm

# 5. Monitor download
sudo journalctl -u vllm -f
```

## Benchmarks vs Alternatives

**Throughput (requests/sec):**
- vLLM: ~2000
- Ollama: ~500-1000  
- HuggingFace Transformers: ~80

**Latency (first token):**
- vLLM: ~20ms
- Ollama: ~50ms
- HuggingFace Transformers: ~100ms

**Memory efficiency:**
- vLLM: 2x better than alternatives (PagedAttention)
- Can serve 2x more requests with same GPU

## When to use vLLM vs Ollama

**Use vLLM for:**
- ✅ Production workloads
- ✅ High throughput needs
- ✅ Multi-GPU setups
- ✅ Custom model configurations
- ✅ Maximum performance

**Use Ollama for:**
- ✅ Quick prototyping
- ✅ Simpler setup
- ✅ Model management UI
- ✅ Desktop/laptop use
- ✅ Non-technical users

## Integration Examples

### With LiteLLM

Point LiteLLM to vLLM:

```yaml
# ~/.litellm/config.yaml
model_list:
  - model_name: llama-3-8b
    litellm_params:
      model: openai/meta-llama/Llama-3.1-8B-Instruct
      api_base: http://localhost:8000/v1
      api_key: EMPTY
```

### With LangChain

```python
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(
    base_url="http://localhost:8000/v1",
    api_key="EMPTY",
    model="meta-llama/Llama-3.2-3B-Instruct"
)

response = llm.invoke("Hello!")
print(response.content)
```

### With LlamaIndex

```python
from llama_index.llms.openai import OpenAI

llm = OpenAI(
    api_base="http://localhost:8000/v1",
    api_key="EMPTY",
    model="meta-llama/Llama-3.2-3B-Instruct"
)

response = llm.complete("Hello!")
print(response)
```

## Update vLLM

```bash
source ~/vllm-server/venv/bin/activate
pip install --upgrade vllm
sudo systemctl restart vllm
```

## Uninstall

```bash
sudo systemctl stop vllm
sudo systemctl disable vllm
sudo rm /etc/systemd/system/vllm.service
sudo systemctl daemon-reload
rm -rf ~/vllm-server
rm -rf ~/vllm-examples
rm -rf ~/.cache/huggingface  # Optional: removes downloaded models
```

## Resources

- **GitHub:** https://github.com/vllm-project/vllm
- **Docs:** https://docs.vllm.ai/
- **Paper:** https://arxiv.org/abs/2309.06180 (PagedAttention)
- **Models:** https://huggingface.co/models
- **Discord:** https://discord.gg/vllm

## Popular Use Cases

1. **Production API** - High-throughput LLM serving
2. **RAG systems** - Fast embedding + generation
3. **Code assistants** - Low-latency code completion
4. **Chatbots** - Concurrent user conversations
5. **Batch processing** - Large-scale text generation
6. **Research** - Experiment with different models quickly

## Tips & Best Practices

1. **Start small** - Test with 3B/7B models first
2. **Monitor GPU** - Use `nvidia-smi` to watch memory
3. **Tune batch size** - Balance throughput vs latency
4. **Use quantization** - AWQ models for 2x memory savings
5. **Enable tensor parallelism** - Utilize all GPUs
6. **Cache models** - First start is slow (downloads model)
7. **Set max tokens** - Prevent runaway generations
8. **Use streaming** - Better UX for long responses

## Example: Production Setup

```bash
# 1. Use a production-grade model
MODEL_NAME="meta-llama/Llama-3.1-8B-Instruct"

# 2. Optimize for throughput
MAX_NUM_SEQS="512"
GPU_MEMORY_UTILIZATION="0.95"

# 3. Enable multi-GPU (if available)
TENSOR_PARALLEL_SIZE="2"

# 4. Set reasonable limits
MAX_MODEL_LEN="4096"

# 5. Add authentication (edit service file)
# --api-key "production-secret-key"

# 6. Monitor with Prometheus (optional)
# Add: --enable-metrics
```

## Community Models to Try

**Coding:**
- Qwen/Qwen2.5-Coder-7B-Instruct
- deepseek-ai/deepseek-coder-6.7b-instruct
- codellama/CodeLlama-13b-Instruct-hf

**Creative Writing:**
- NousResearch/Hermes-2-Pro-Llama-3-8B
- SynthIA-7B-v2.0

**Multilingual:**
- Qwen/Qwen2.5-7B-Instruct (29+ languages)
- aya-23-8B (23 languages)

**Fast & Small:**
- microsoft/Phi-3-mini-4k-instruct
- google/gemma-2-2b-it
- stabilityai/stablelm-2-1_6b

Happy serving! 🚀

