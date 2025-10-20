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

echo "🚀 Setting up Unsloth for fast fine-tuning..."
echo "User: $USER | Home: $HOME"

# Verify GPU
if ! command -v nvidia-smi &> /dev/null; then
    echo "⚠️  Warning: No NVIDIA GPU detected. Unsloth requires a GPU."
    exit 1
fi
echo "GPU detected: $(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)"

# Use system Python (Brev instances come with Python pre-installed)
# This ensures Jupyter Lab and notebooks can access unsloth
if ! command -v python3 &> /dev/null; then
    echo "⚠️  Error: Python 3 not found. Please install Python 3 first."
    exit 1
fi

echo "Using Python: $(python3 --version)"
echo "Python location: $(which python3)"

# Upgrade pip first
echo "Upgrading pip..."
python3 -m pip install --upgrade pip

# Install PyTorch with CUDA
echo "Installing PyTorch with CUDA support..."
python3 -m pip install --upgrade --no-cache-dir torch torchvision torchaudio

# Install Unsloth (recommended simple method from official docs)
# See: https://docs.unsloth.ai/get-started/install-and-update/pip-install
echo "Installing Unsloth (this may take a few minutes)..."
python3 -m pip install unsloth

# Install additional dependencies for fine-tuning
echo "Installing additional dependencies..."
python3 -m pip install trl peft accelerate bitsandbytes datasets transformers wandb tensorboard

# Install Jupyter if not already installed (Brev usually has it pre-installed)
if ! command -v jupyter &> /dev/null; then
    echo "Installing Jupyter Lab..."
    python3 -m pip install jupyter jupyterlab
else
    echo "Jupyter already installed, skipping..."
fi

# Create example script
mkdir -p "$HOME/unsloth-examples"
cat > "$HOME/unsloth-examples/test_install.py" << 'EOF'
#!/usr/bin/env python3
from unsloth import FastLanguageModel
import torch

print("Loading model with Unsloth...")
model, tokenizer = FastLanguageModel.from_pretrained(
    model_name = "unsloth/llama-3.2-1b-bnb-4bit",
    max_seq_length = 2048,
    dtype = None,
    load_in_4bit = True,
)

model = FastLanguageModel.get_peft_model(
    model, r=16,
    target_modules = ["q_proj", "k_proj", "v_proj", "o_proj"],
    lora_alpha = 16,
    lora_dropout = 0,
    bias = "none",
)

print(f"✅ Model loaded! GPU Memory: {torch.cuda.memory_allocated() / 1e9:.2f}GB")
print("Ready for fine-tuning!")
EOF
chmod +x "$HOME/unsloth-examples/test_install.py"

# Verify installation
echo ""
echo "Verifying installation..."
python -c "
import torch
import sys

print(f'✓ PyTorch: {torch.__version__}')
print(f'✓ CUDA available: {torch.cuda.is_available()}')

# Check PyTorch version (simple version check)
version_str = torch.__version__.split('+')[0]
major, minor = map(int, version_str.split('.')[:2])
if major < 2 or (major == 2 and minor < 5):
    print(f'⚠️  Warning: PyTorch {torch.__version__} detected.')
    print('   Unsloth requires PyTorch >= 2.5.0 for torch.int1 support')
    print('   This may cause compatibility issues.')
else:
    print(f'✓ PyTorch version {torch.__version__} is compatible with Unsloth')

# Test unsloth import
try:
    from unsloth import FastLanguageModel
    print(f'✓ Unsloth imported successfully')
except Exception as e:
    print(f'❌ Unsloth import failed: {str(e)}')
    print('')
    print('This usually means PyTorch version is incompatible.')
    print('Try running: pip install --upgrade torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121')
    sys.exit(1)
"

echo ""
echo "✅ Unsloth installed successfully!"
echo ""
echo "Quick start:"
echo "  python3 $HOME/unsloth-examples/test_install.py"
echo ""

# Clone unslothai/notebooks repository for examples
echo "Cloning unslothai/notebooks for example notebooks..."
if [ -d "$HOME/unsloth-notebooks" ]; then
    echo "Repository already exists, updating..."
    cd "$HOME/unsloth-notebooks"
    git pull
else
    cd "$HOME"
    git clone https://github.com/unslothai/notebooks.git unsloth-notebooks
    
    # Fix permissions if running as root
    if [ "$(id -u)" -eq 0 ]; then
        chown -R $USER:$USER "$HOME/unsloth-notebooks"
    fi
fi

echo "✓ Unsloth notebooks cloned to $HOME/unsloth-notebooks"
echo ""

# Check if Jupyter is already running
if lsof -i :8888 >/dev/null 2>&1 || pgrep -f "jupyter.*lab" >/dev/null 2>&1; then
    echo "💡 Jupyter Lab is already running on this instance!"
    echo "   Access it via your Brev URL (port 8888 should already be open)"
    echo ""
    echo "   📓 Unsloth notebooks are available at: ~/unsloth-notebooks"
    echo "   Just open any .ipynb file and start fine-tuning!"
else
    echo "Start Jupyter Lab:"
    echo "  jupyter lab --ip=0.0.0.0 --port=8888"
    echo ""
    echo "⚠️  To access Jupyter from outside Brev, open port: 8888/tcp"
    echo ""
    echo "   📓 Once started, navigate to ~/unsloth-notebooks for example notebooks"
fi

echo ""
echo "Popular models:"
echo "  unsloth/llama-3.2-1b-bnb-4bit (smallest)"
echo "  unsloth/llama-3.2-3b-bnb-4bit"
echo "  unsloth/mistral-7b-bnb-4bit"
echo ""
echo "Docs: https://github.com/unslothai/unsloth"

