#!/bin/bash
set -e

# Detect Brev user (handles ubuntu, nvidia, shadeform, etc.)
detect_brev_user() {
    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
        echo "$SUDO_USER"
        return
    fi
    # Check for Brev-specific markers
    for user_home in /home/*; do
        username=$(basename "$user_home")
        [ "$username" = "launchpad" ] && continue
        if ls "$user_home"/.lifecycle-script-ls-*.log 2>/dev/null | grep -q . || \
           [ -f "$user_home/.verb-setup.log" ] || \
           { [ -L "$user_home/.cache" ] && [ "$(readlink "$user_home/.cache")" = "/ephemeral/cache" ]; }; then
            echo "$username"
            return
        fi
    done
    # Fallback to common users
    [ -d "/home/nvidia" ] && echo "nvidia" && return
    [ -d "/home/ubuntu" ] && echo "ubuntu" && return
    echo "ubuntu"
}

# Set USER and HOME if running as root
if [ "$(id -u)" -eq 0 ] || [ "${USER:-}" = "root" ]; then
    DETECTED_USER=$(detect_brev_user)
    export USER="$DETECTED_USER"
    export HOME="/home/$DETECTED_USER"
fi

# Configuration (override with environment variables)
MODEL="${VLLM_MODEL:-Qwen/Qwen2.5-1.5B-Instruct}"
PORT="${VLLM_PORT:-8000}"

echo "⚡ Setting up vLLM inference server..."
echo "User: $USER | Home: $HOME"
echo "Model: $MODEL | Port: $PORT"

# Note: Brev already has Docker and NVIDIA Container Toolkit installed
echo "Using existing Docker installation..."

# Verify GPU is available
if command -v nvidia-smi &> /dev/null; then
    echo "GPU detected: $(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)"
else
    echo "❌ No GPU detected - This is a script meant to be run on an NVIDIA Brev GPU instance!"
    exit 1
fi

# Create cache directory for HuggingFace models
mkdir -p "$HOME/.cache/huggingface"

# Stop existing container if running
if docker ps -a --format '{{.Names}}' | grep -q '^vllm$'; then
    echo "Removing existing vLLM container..."
    docker stop vllm 2>/dev/null || true
    docker rm vllm 2>/dev/null || true
fi

# Run vLLM container
echo "Starting vLLM server with $MODEL..."
echo "This may take a few minutes on first run (downloading model)..."
docker run -d \
    --name vllm \
    --restart unless-stopped \
    --gpus all \
    -v "$HOME/.cache/huggingface:/root/.cache/huggingface" \
    -p "$PORT:8000" \
    -e "HF_TOKEN=${HF_TOKEN:-}" \
    -e "HUGGING_FACE_HUB_TOKEN=${HF_TOKEN:-}" \
    vllm/vllm-openai:latest \
    --model "$MODEL"

# Create examples directory
mkdir -p "$HOME/vllm-examples"

# Save config for example scripts
echo "$MODEL" > "$HOME/vllm-examples/.model"
echo "$PORT" > "$HOME/vllm-examples/.port"

# Create example Python script
cat > "$HOME/vllm-examples/chat.py" << 'EOF'
#!/usr/bin/env python3
"""Example: Chat with vLLM using OpenAI SDK"""
import os, pathlib

config_dir = pathlib.Path(__file__).parent
model = os.environ.get("VLLM_MODEL", (config_dir / ".model").read_text().strip())
port = os.environ.get("VLLM_PORT", (config_dir / ".port").read_text().strip())

from openai import OpenAI

client = OpenAI(base_url=f"http://localhost:{port}/v1", api_key="not-needed")

response = client.chat.completions.create(
    model=model,
    messages=[{"role": "user", "content": "Explain what vLLM is in two sentences."}]
)

print(response.choices[0].message.content)
EOF
chmod +x "$HOME/vllm-examples/chat.py"

# Create curl example script
cat > "$HOME/vllm-examples/test_api.sh" << 'EOF'
#!/bin/bash
# Test vLLM API with curl
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODEL="${VLLM_MODEL:-$(cat "$SCRIPT_DIR/.model")}"
PORT="${VLLM_PORT:-$(cat "$SCRIPT_DIR/.port")}"

curl -s "http://localhost:${PORT}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"${MODEL}\",
    \"messages\": [{\"role\": \"user\", \"content\": \"Hello!\"}],
    \"max_tokens\": 100
  }" | python3 -m json.tool
EOF
chmod +x "$HOME/vllm-examples/test_api.sh"

# Fix permissions if running as root
if [ "$(id -u)" -eq 0 ]; then
    chown -R $USER:$USER "$HOME/.cache/huggingface"
    chown -R $USER:$USER "$HOME/vllm-examples"
fi

# Wait for container to start
echo "Waiting for vLLM to initialize..."
echo "(Model download and loading may take several minutes)"
sleep 5

# Verify
echo ""
echo "Verifying installation..."
docker ps --filter "name=vllm" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "✅ vLLM container running!"
echo ""
echo "⏳ The model is still loading — this can take several minutes."
echo "   Run this to watch progress:"
echo "   docker logs -f vllm"
echo ""
echo "   The API is ready when you see: \"Uvicorn running on http://0.0.0.0:8000\""
echo ""
echo "Model: $MODEL"
echo "API Endpoint: http://localhost:$PORT"
echo "OpenAI-compatible: http://localhost:$PORT/v1"
echo ""
echo "⚠️  To access from outside Brev, open port: ${PORT}/tcp"
echo ""
echo "Quick start (after model finishes loading):"
echo "  pip install openai"
echo "  python3 $HOME/vllm-examples/chat.py"
echo "  bash $HOME/vllm-examples/test_api.sh"
echo ""
echo "Manage:"
echo "  docker logs -f vllm          # Watch startup progress"
echo "  docker restart vllm          # Restart server"
echo "  docker stop vllm             # Stop server"
echo ""
echo "Run with a different model:"
echo "  export HF_TOKEN={YOUR_HF_TOKEN}"
echo "  VLLM_MODEL=meta-llama/Llama-3.1-8B-Instruct bash setup.sh"