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

echo "🚀 Setting up vLLM..."
echo "User: $USER | Home: $HOME"

# Verify GPU is available
if command -v nvidia-smi &> /dev/null; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)
    GPU_COUNT=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)
    GPU_MEMORY=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader | head -1 | awk '{print $1}')
    echo "✓ GPU detected: $GPU_NAME (Count: $GPU_COUNT)"
    echo "✓ GPU memory: ${GPU_MEMORY}MB"
    
    # Warn if memory might be tight
    if [ "$GPU_MEMORY" -lt 12000 ]; then
        echo "⚠️  WARNING: GPU has <12GB memory. Default model (Mistral 7B) may not fit."
        echo "   Consider using a smaller model like: microsoft/Phi-3-mini-4k-instruct"
    fi
else
    echo "❌ ERROR: NVIDIA GPU required for vLLM"
    exit 1
fi

# Install system dependencies
echo "Installing system dependencies..."
sudo apt-get update -qq
sudo apt-get install -y -qq python3-pip python3-venv curl

# Create vLLM directory
VLLM_DIR="$HOME/vllm-server"
mkdir -p "$VLLM_DIR"

# Create virtual environment if it doesn't exist
if [ ! -d "$VLLM_DIR/venv" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv "$VLLM_DIR/venv"
else
    echo "Virtual environment already exists, skipping..."
fi

# Activate and install vLLM
echo "Installing vLLM (this may take 2-3 minutes)..."
source "$VLLM_DIR/venv/bin/activate"
pip install --upgrade pip -q
pip install vllm -q

# Create model cache directory
mkdir -p "$HOME/.cache/huggingface"

# Create example config file
cat > "$VLLM_DIR/config.env" << 'EOF'
# vLLM Configuration
# Edit these values and restart the service: sudo systemctl restart vllm

# Model to serve (Hugging Face model ID)
# Using Mistral 7B - no token required, excellent quality
MODEL_NAME="mistralai/Mistral-7B-Instruct-v0.3"

# API settings
HOST="0.0.0.0"
PORT="8000"

# GPU settings (adjust based on your hardware)
TENSOR_PARALLEL_SIZE="1"  # Set to GPU count for multi-GPU
GPU_MEMORY_UTILIZATION="0.9"  # Use 90% of GPU memory

# Performance settings
MAX_MODEL_LEN="4096"  # Maximum sequence length
MAX_NUM_SEQS="256"    # Maximum number of sequences

# Optional: Hugging Face token (needed for gated models like Llama)
# HF_TOKEN="hf_..."
EOF

# Create startup script
cat > "$VLLM_DIR/start.sh" << 'EOF'
#!/bin/bash
set -e

# Load config
source "$HOME/vllm-server/config.env"

# Activate venv
source "$HOME/vllm-server/venv/bin/activate"

# Set HuggingFace cache
export HF_HOME="$HOME/.cache/huggingface"

# Start vLLM server
exec python3 -m vllm.entrypoints.openai.api_server \
    --model "$MODEL_NAME" \
    --host "$HOST" \
    --port "$PORT" \
    --tensor-parallel-size "$TENSOR_PARALLEL_SIZE" \
    --gpu-memory-utilization "$GPU_MEMORY_UTILIZATION" \
    --max-model-len "$MAX_MODEL_LEN" \
    --max-num-seqs "$MAX_NUM_SEQS" \
    --trust-remote-code
EOF
chmod +x "$VLLM_DIR/start.sh"

# Create systemd service
sudo tee /etc/systemd/system/vllm.service > /dev/null << EOF
[Unit]
Description=vLLM OpenAI-Compatible API Server
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/vllm-server
Environment="PATH=$VLLM_DIR/venv/bin:/usr/local/bin:/usr/bin:/bin"
Environment="HF_HOME=$HOME/.cache/huggingface"
ExecStart=$VLLM_DIR/start.sh
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Create example scripts
mkdir -p "$HOME/vllm-examples"

cat > "$HOME/vllm-examples/test_api.py" << 'EOF'
#!/usr/bin/env python3
"""Test vLLM API with OpenAI client

Requires: pip install openai>=1.0.0
"""
from openai import OpenAI

# Point to local vLLM server
client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="EMPTY"  # vLLM doesn't require auth by default
)

# Test chat completion
response = client.chat.completions.create(
    model="mistralai/Mistral-7B-Instruct-v0.3",  # Use your model name
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "What is vLLM?"}
    ],
    temperature=0.7,
    max_tokens=150
)

print("Response:", response.choices[0].message.content)
print(f"\nTokens used: {response.usage.total_tokens}")
EOF
chmod +x "$HOME/vllm-examples/test_api.py"

cat > "$HOME/vllm-examples/streaming_example.py" << 'EOF'
#!/usr/bin/env python3
"""Streaming response example"""
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="EMPTY"
)

print("Streaming response:\n")
stream = client.chat.completions.create(
    model="mistralai/Mistral-7B-Instruct-v0.3",
    messages=[{"role": "user", "content": "Write a short poem about GPUs."}],
    stream=True,
    max_tokens=200
)

for chunk in stream:
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="", flush=True)
print("\n")
EOF
chmod +x "$HOME/vllm-examples/streaming_example.py"

cat > "$HOME/vllm-examples/curl_test.sh" << 'EOF'
#!/bin/bash
# Test vLLM API with curl

curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mistralai/Mistral-7B-Instruct-v0.3",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "Hello! What can you do?"}
    ],
    "temperature": 0.7,
    "max_tokens": 100
  }'
EOF
chmod +x "$HOME/vllm-examples/curl_test.sh"

# Fix permissions if running as root
if [ "$(id -u)" -eq 0 ]; then
    chown -R $USER:$USER "$VLLM_DIR"
    chown -R $USER:$USER "$HOME/vllm-examples"
    chown -R $USER:$USER "$HOME/.cache/huggingface" 2>/dev/null || true
fi

# Reload systemd and enable service (but don't start yet)
sudo systemctl daemon-reload
sudo systemctl enable vllm

echo ""
echo "✅ vLLM installation complete!"
echo ""
echo "⚙️  Configuration: $VLLM_DIR/config.env"
echo "📝 Examples: $HOME/vllm-examples/"
echo ""
echo "🔧 IMPORTANT: Configure before starting!"
echo ""
echo "1. Edit the model in config:"
echo "   nano $VLLM_DIR/config.env"
echo ""
echo "2. For gated models (Llama, etc), add HuggingFace token:"
echo "   - Get token: https://huggingface.co/settings/tokens"
echo "   - Add to config: HF_TOKEN=\"hf_...\""
echo ""
echo "3. Start the service:"
echo "   sudo systemctl start vllm"
echo ""
echo "4. Check status:"
echo "   sudo systemctl status vllm"
echo "   sudo journalctl -u vllm -f"
echo ""
echo "⚠️  First start downloads the model (~3-10GB) - check logs!"
echo "⚠️  To access from outside Brev, open port: 8000/tcp"
echo ""
echo "Quick test (after starting):"
echo "   pip install openai  # If not already installed"
echo "   python3 $HOME/vllm-examples/test_api.py"
echo "   bash $HOME/vllm-examples/curl_test.sh"
echo ""
echo "Popular models to try (edit config.env):"
echo "   • mistralai/Mistral-7B-Instruct-v0.3 (default - no token needed)"
echo "   • microsoft/Phi-3-mini-4k-instruct (3.8B - smaller, ~6GB VRAM)"
echo "   • Qwen/Qwen2.5-7B-Instruct (7B - excellent for coding)"
echo "   • meta-llama/Llama-3.2-3B-Instruct (3B - needs HF token)"
echo ""

