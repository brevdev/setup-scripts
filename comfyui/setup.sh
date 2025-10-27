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

echo "🎨 Setting up ComfyUI..."
echo "User: $USER | Home: $HOME"

# Verify GPU
if ! command -v nvidia-smi &> /dev/null; then
    echo "⚠️  Warning: No NVIDIA GPU detected. ComfyUI works best with a GPU."
fi

if command -v nvidia-smi &> /dev/null; then
    echo "GPU detected: $(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)"
fi

# Install dependencies
echo "Installing system dependencies..."
sudo apt-get update -qq
sudo apt-get install -y -qq git python3-pip python3-venv

# Clone ComfyUI
if [ -d "$HOME/ComfyUI" ]; then
    echo "ComfyUI directory exists, updating..."
    cd "$HOME/ComfyUI"
    git pull
else
    echo "Cloning ComfyUI..."
    cd "$HOME"
    git clone https://github.com/comfyanonymous/ComfyUI.git
    cd ComfyUI
    
    # Fix permissions if running as root
    if [ "$(id -u)" -eq 0 ]; then
        chown -R $USER:$USER "$HOME/ComfyUI"
    fi
fi

# Create virtual environment
echo "Creating Python environment..."
if [ "$(id -u)" -eq 0 ]; then
    sudo -H -u $USER python3 -m venv venv
else
    python3 -m venv venv
fi

# Install PyTorch with CUDA (Brev already has CUDA)
echo "Installing PyTorch with CUDA..."
if [ "$(id -u)" -eq 0 ]; then
    sudo -H -u $USER bash -c "cd $HOME/ComfyUI && source venv/bin/activate && pip install --upgrade pip"
    sudo -H -u $USER bash -c "cd $HOME/ComfyUI && source venv/bin/activate && pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121"
else
    source venv/bin/activate
    pip install --upgrade pip
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
fi

# Install ComfyUI requirements
echo "Installing ComfyUI dependencies..."
if [ "$(id -u)" -eq 0 ]; then
    sudo -H -u $USER bash -c "cd $HOME/ComfyUI && source venv/bin/activate && pip install -r requirements.txt"
else
    source venv/bin/activate
    pip install -r requirements.txt
fi

# Install ComfyUI-Manager for easy model management
echo "Installing ComfyUI-Manager..."
cd "$HOME/ComfyUI/custom_nodes"
if [ ! -d "ComfyUI-Manager" ]; then
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git
    if [ "$(id -u)" -eq 0 ]; then
        sudo -H -u $USER bash -c "cd $HOME/ComfyUI/custom_nodes/ComfyUI-Manager && source ../../venv/bin/activate && pip install -r requirements.txt"
    else
        cd ComfyUI-Manager
        source ../../venv/bin/activate
        pip install -r requirements.txt
    fi
    echo "✓ ComfyUI-Manager installed"
else
    echo "ComfyUI-Manager already exists"
fi

# Download a basic model (SD 1.5 - smaller and faster)
echo "Downloading starter model (this may take a few minutes)..."
mkdir -p "$HOME/ComfyUI/models/checkpoints"
cd "$HOME/ComfyUI/models/checkpoints"

if [ ! -f "v1-5-pruned-emaonly.safetensors" ]; then
    wget -q --show-progress https://huggingface.co/runwayml/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.safetensors
    echo "✓ Stable Diffusion 1.5 model downloaded"
else
    echo "Model already exists, skipping download"
fi

# Create start script
cat > "$HOME/ComfyUI/start.sh" << 'EOF'
#!/bin/bash
cd ~/ComfyUI
source venv/bin/activate
python main.py --listen 0.0.0.0 --port 8188
EOF
chmod +x "$HOME/ComfyUI/start.sh"

# Create systemd service
sudo tee /etc/systemd/system/comfyui.service > /dev/null << EOF
[Unit]
Description=ComfyUI
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/ComfyUI
ExecStart=$HOME/ComfyUI/venv/bin/python main.py --listen 0.0.0.0 --port 8188
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Fix all permissions if running as root (ensure everything is user-owned)
if [ "$(id -u)" -eq 0 ]; then
    echo "Fixing permissions..."
    chown -R $USER:$USER "$HOME/ComfyUI"
fi

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable comfyui
sudo systemctl start comfyui

# Wait for service
sleep 3

# Verify
echo ""
echo "Verifying installation..."
if [ "$(id -u)" -eq 0 ]; then
    sudo -H -u $USER bash -c "cd $HOME/ComfyUI && source venv/bin/activate && python -c \"import torch; print(f'✓ PyTorch {torch.__version__}'); print(f'✓ CUDA available: {torch.cuda.is_available()}')\""
else
    cd "$HOME/ComfyUI"
    source venv/bin/activate
    python -c "import torch; print(f'✓ PyTorch {torch.__version__}'); print(f'✓ CUDA available: {torch.cuda.is_available()}')"
fi

echo ""
echo "✅ ComfyUI ready!"
echo ""
echo "Access: http://localhost:8188"
echo "⚠️  Open port 8188/tcp to access from outside Brev"
echo ""
echo "Location: $HOME/ComfyUI"
echo "Models: $HOME/ComfyUI/models/checkpoints"
echo ""
echo "✨ ComfyUI-Manager installed!"
echo "   Click the 'Manager' button in the UI to:"
echo "   - Download models directly to the server"
echo "   - Install custom nodes"
echo "   - Update ComfyUI"
echo ""
echo "Manage service:"
echo "  sudo systemctl status comfyui"
echo "  sudo journalctl -u comfyui -f"
echo "  cd ~/ComfyUI && ./start.sh  # Manual start"

