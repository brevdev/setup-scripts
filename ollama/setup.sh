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

echo "🦙 Setting up Ollama..."
echo "User: $USER | Home: $HOME"

# Install ollama
if command -v ollama &> /dev/null; then
    echo "Ollama already installed, skipping..."
else
    echo "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
fi

# Verify GPU is available
if command -v nvidia-smi &> /dev/null; then
    echo "GPU detected: $(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)"
else
    echo "⚠️  No GPU detected - Ollama will run on CPU (slower)"
fi

# Start ollama service
echo "Starting Ollama service..."
sudo systemctl enable ollama 2>/dev/null || true
sudo systemctl start ollama 2>/dev/null || true

# Wait for service to be ready
echo "Waiting for Ollama to be ready..."
sleep 3

# Pull a starter model (small but capable)
echo "Pulling llama3.2 model (this may take a few minutes)..."
ollama pull llama3.2 2>/dev/null || echo "Note: Model pull initiated in background"

# Create example script
mkdir -p "$HOME/ollama-examples"
cat > "$HOME/ollama-examples/chat.sh" << 'EOF'
#!/bin/bash
# Simple chat with Ollama
ollama run llama3.2
EOF
chmod +x "$HOME/ollama-examples/chat.sh"

cat > "$HOME/ollama-examples/api_example.py" << 'EOF'
#!/usr/bin/env python3
"""Example using Ollama API"""
import requests
import json

def chat(prompt):
    response = requests.post(
        'http://localhost:11434/api/generate',
        json={
            'model': 'llama3.2',
            'prompt': prompt,
            'stream': False
        }
    )
    return response.json()['response']

if __name__ == '__main__':
    result = chat("Why is the sky blue? Answer in one sentence.")
    print(f"Response: {result}")
EOF
chmod +x "$HOME/ollama-examples/api_example.py"

# Fix all permissions if running as root
if [ "$(id -u)" -eq 0 ]; then
    chown -R $USER:$USER "$HOME/ollama-examples"
fi

# Verify
echo ""
echo "Verifying installation..."
ollama --version
sudo systemctl is-active ollama && echo "✓ Ollama service is running"

echo ""
echo "✅ Ollama ready!"
echo ""
echo "Quick start:"
echo "  ollama run llama3.2              # Start chatting"
echo "  ollama list                      # List installed models"
echo "  ollama pull mistral              # Pull another model"
echo ""
echo "Examples:"
echo "  $HOME/ollama-examples/chat.sh"
echo "  python3 $HOME/ollama-examples/api_example.py"
echo ""
echo "⚠️  To access Ollama API from outside Brev, open port: 11434/tcp"
echo ""
echo "Popular models to try:"
echo "  ollama pull llama3.1             # Meta's Llama 3.1 (8B)"
echo "  ollama pull mistral              # Mistral 7B"
echo "  ollama pull codellama            # Code generation"
echo "  ollama pull llama3.2-vision      # Vision model"

