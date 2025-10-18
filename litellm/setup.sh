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

echo "🔄 Setting up LiteLLM proxy..."
echo "User: $USER | Home: $HOME"

# Note: Brev already has Docker installed
echo "Using existing Docker installation..."

# Create config directory
mkdir -p "$HOME/.litellm"

# Fix permissions if running as root
if [ "$(id -u)" -eq 0 ]; then
    chown $USER:$USER "$HOME/.litellm"
fi

# Create example config
cat > "$HOME/.litellm/config.yaml" << 'EOF'
model_list:
  # OpenAI
  - model_name: gpt-4
    litellm_params:
      model: gpt-4
      api_key: os.environ/OPENAI_API_KEY
  
  # Anthropic
  - model_name: claude-3-5-sonnet
    litellm_params:
      model: claude-3-5-sonnet-20241022
      api_key: os.environ/ANTHROPIC_API_KEY
  
  # Local Ollama (if running)
  - model_name: llama3.2
    litellm_params:
      model: ollama/llama3.2
      api_base: http://localhost:11434

# Logging
litellm_settings:
  drop_params: true
  success_callback: ["langfuse"]
EOF

# Create environment file template
cat > "$HOME/.litellm/.env.example" << 'EOF'
# Add your API keys here, then rename to .env
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
# Optional: LangFuse for observability
LANGFUSE_PUBLIC_KEY=
LANGFUSE_SECRET_KEY=
EOF

# Pull and run LiteLLM container
echo "Starting LiteLLM proxy..."
docker run -d \
  --name litellm \
  --restart unless-stopped \
  -p 4000:4000 \
  -v "$HOME/.litellm/config.yaml:/app/config.yaml" \
  ghcr.io/berriai/litellm:main-latest \
  --config /app/config.yaml \
  --port 4000 \
  --num_workers 4 2>/dev/null || echo "LiteLLM container already running"

# Wait for service
echo "Waiting for LiteLLM to start..."
sleep 3

# Create example Python script
cat > "$HOME/.litellm/example.py" << 'EOF'
#!/usr/bin/env python3
"""Example using LiteLLM proxy"""
import openai

# Point to LiteLLM proxy
openai.api_base = "http://localhost:4000"
openai.api_key = "anything"  # Not needed for local proxy

# Use any model through OpenAI client
response = openai.ChatCompletion.create(
    model="gpt-4",  # or claude-3-5-sonnet, or llama3.2
    messages=[{"role": "user", "content": "Hello!"}]
)

print(response.choices[0].message.content)
EOF
chmod +x "$HOME/.litellm/example.py"

# Fix all permissions if running as root
if [ "$(id -u)" -eq 0 ]; then
    chown -R $USER:$USER "$HOME/.litellm"
fi

# Verify
echo ""
echo "Verifying installation..."
docker ps --filter "name=litellm" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "✅ LiteLLM proxy ready!"
echo ""
echo "Configuration: $HOME/.litellm/config.yaml"
echo "API Endpoint: http://localhost:4000"
echo ""
echo "⚠️  To access from outside Brev, open port: 4000/tcp"
echo ""
echo "Quick start:"
echo "  1. Add API keys to $HOME/.litellm/.env"
echo "  2. Restart: docker restart litellm"
echo "  3. Use OpenAI SDK pointing to localhost:4000"
echo ""
echo "Test endpoint:"
echo "  curl http://localhost:4000/health"
echo ""
echo "Example usage:"
echo "  python3 $HOME/.litellm/example.py"
echo ""
echo "Manage:"
echo "  docker logs litellm       # View logs"
echo "  docker restart litellm    # Restart proxy"
echo "  docker stop litellm       # Stop proxy"

