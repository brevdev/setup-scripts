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
MODEL="${TRTLLM_MODEL:-TinyLlama/TinyLlama-1.1B-Chat-v1.0}"
PORT="${TRTLLM_PORT:-8000}"
IMAGE="${TRTLLM_IMAGE:-nvcr.io/nvidia/tensorrt-llm/release:latest}"

echo "⚡ Setting up TensorRT-LLM inference server..."
echo "User: $USER | Home: $HOME"
echo "Model: $MODEL | Port: $PORT"
echo "Image: $IMAGE"

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
if docker ps -a --format '{{.Names}}' | grep -q '^trtllm$'; then
    echo "Removing existing TensorRT-LLM container..."
    docker stop trtllm 2>/dev/null || true
    docker rm trtllm 2>/dev/null || true
fi

# Run TensorRT-LLM container
echo "Starting TensorRT-LLM server with $MODEL..."
echo "This may take 8-10 minutes on first run (engine building + model download)..."
docker run -d \
    --name trtllm \
    --restart unless-stopped \
    --gpus all \
    --ipc host \
    --ulimit memlock=-1 \
    --ulimit stack=67108864 \
    -v "$HOME/.cache/huggingface:/root/.cache/huggingface" \
    -p "$PORT:8000" \
    -e "HF_TOKEN=${HF_TOKEN:-}" \
    -e "HUGGING_FACE_HUB_TOKEN=${HF_TOKEN:-}" \
    "$IMAGE" \
    trtllm-serve serve "$MODEL" --host 0.0.0.0 --port 8000

# Create examples directory
mkdir -p "$HOME/trtllm-examples"

# Save config for example scripts
echo "$MODEL" > "$HOME/trtllm-examples/.model"
echo "$PORT" > "$HOME/trtllm-examples/.port"

# Create example Python script
cat > "$HOME/trtllm-examples/chat.py" << 'EOF'
#!/usr/bin/env python3
"""Example: Chat with TensorRT-LLM using OpenAI SDK"""
import os, pathlib

config_dir = pathlib.Path(__file__).parent
model = os.environ.get("TRTLLM_MODEL", (config_dir / ".model").read_text().strip())
port = os.environ.get("TRTLLM_PORT", (config_dir / ".port").read_text().strip())

from openai import OpenAI

client = OpenAI(base_url=f"http://localhost:{port}/v1", api_key="tensorrt_llm")

response = client.chat.completions.create(
    model=model,
    messages=[{"role": "user", "content": "Explain what TensorRT-LLM is in two sentences."}]
)

print(response.choices[0].message.content)
EOF
chmod +x "$HOME/trtllm-examples/chat.py"

# Create curl example script
cat > "$HOME/trtllm-examples/test_api.sh" << 'EOF'
#!/bin/bash
# Test TensorRT-LLM API with curl
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODEL="${TRTLLM_MODEL:-$(cat "$SCRIPT_DIR/.model")}"
PORT="${TRTLLM_PORT:-$(cat "$SCRIPT_DIR/.port")}"

curl -s "http://localhost:${PORT}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"${MODEL}\",
    \"messages\": [{\"role\": \"user\", \"content\": \"Hello!\"}],
    \"max_tokens\": 100
  }" | python3 -m json.tool
EOF
chmod +x "$HOME/trtllm-examples/test_api.sh"

# Fix permissions if running as root
if [ "$(id -u)" -eq 0 ]; then
    chown -R $USER:$USER "$HOME/.cache/huggingface"
    chown -R $USER:$USER "$HOME/trtllm-examples"
fi

# Wait for container to start
echo "Waiting for TensorRT-LLM to initialize..."
echo "(Engine building and model loading may take 8-10 minutes on first run)"
sleep 5

# Verify
echo ""
echo "Verifying installation..."
docker ps --filter "name=trtllm" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "✅ TensorRT-LLM container running!"
echo ""
echo "⏳ The engine is still building — first run takes 8-10 minutes."
echo "   Subsequent starts are much faster (engine is cached)."
echo "   Run this to watch progress:"
echo "   docker logs -f trtllm"
echo ""
echo "   The API is ready when you see: \"Started server process\""
echo ""
echo "Model: $MODEL"
echo "API Endpoint: http://localhost:$PORT"
echo "OpenAI-compatible: http://localhost:$PORT/v1"
echo ""
echo "⚠️  To access from outside Brev, open port: ${PORT}/tcp"
echo ""
echo "Quick start (after engine finishes building):"
echo "  pip install openai"
echo "  python3 $HOME/trtllm-examples/chat.py"
echo "  bash $HOME/trtllm-examples/test_api.sh"
echo ""
echo "Manage:"
echo "  docker logs -f trtllm          # Watch startup progress"
echo "  docker restart trtllm          # Restart server"
echo "  docker stop trtllm             # Stop server"
echo ""
echo "Run with a different model:"
echo "  export HF_TOKEN={YOUR_HF_TOKEN}"
echo "  TRTLLM_MODEL=nvidia/Llama-3.1-8B-Instruct-FP8 bash setup.sh"