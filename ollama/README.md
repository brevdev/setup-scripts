# Ollama

Run large language models locally with GPU acceleration.

## What it installs

- **Ollama** - Local LLM inference engine
- **llama3.2** - Starter model (pre-downloaded)
- **Systemd service** - Auto-starts with system

## Features

- **GPU accelerated** - Uses NVIDIA GPU automatically
- **Simple CLI** - Easy to use chat interface
- **REST API** - HTTP API on port 11434
- **Model library** - Access to many popular models

## ⚠️ Required Port

To access Ollama API from outside Brev, open:
- **11434/tcp** (Ollama API port)

## Usage

```bash
bash setup.sh
```

Takes ~3-5 minutes (downloads llama3.2 model).

## What you get

```bash
ollama run llama3.2        # Start chatting
ollama list                # List models
ollama pull mistral        # Download new model
ollama serve               # Manual server start
```

## Examples

**Chat in terminal:**
```bash
ollama run llama3.2
>>> Why is the sky blue?
```

**Use the API:**
```bash
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2",
  "prompt": "Why is the sky blue?"
}'
```

**Python API example:**
```python
import requests

response = requests.post('http://localhost:11434/api/generate', 
    json={
        'model': 'llama3.2',
        'prompt': 'Explain quantum computing in simple terms',
        'stream': False
    }
)
print(response.json()['response'])
```

## Popular Models

```bash
# General purpose
ollama pull llama3.1          # Meta Llama 3.1 (8B)
ollama pull mistral           # Mistral 7B
ollama pull phi3              # Microsoft Phi-3

# Code generation
ollama pull codellama         # Meta Code Llama
ollama pull deepseek-coder    # DeepSeek Coder

# Vision models
ollama pull llama3.2-vision   # Llama 3.2 Vision
ollama pull llava             # LLaVA multimodal

# Specialized
ollama pull gemma2            # Google Gemma 2
ollama pull qwen2             # Alibaba Qwen 2
```

## Manage Service

```bash
sudo systemctl status ollama     # Check status
sudo systemctl restart ollama    # Restart service
sudo journalctl -u ollama -f     # View logs
```

## Model Storage

Models are stored in `/usr/share/ollama/.ollama/models`

To remove a model:
```bash
ollama rm llama3.2
```

## Using with Python

```bash
pip install ollama

# Then in Python:
import ollama
response = ollama.chat(model='llama3.2', messages=[
  {'role': 'user', 'content': 'Why is the sky blue?'}
])
print(response['message']['content'])
```

## GPU Memory

Different models need different amounts of GPU memory:
- 7B models (llama3.2, mistral): ~8GB VRAM
- 13B models: ~16GB VRAM
- 70B models: ~40GB VRAM (use quantized versions)

Check GPU usage:
```bash
nvidia-smi
```

## Troubleshooting

**Service won't start:**
```bash
sudo journalctl -u ollama -n 50
```

**Out of memory:**
- Try smaller models or quantized versions
- Use `ollama run model:7b-q4` for 4-bit quantization

**Slow inference:**
- Verify GPU is being used: `nvidia-smi`
- Check model is using GPU (should show in nvidia-smi)

