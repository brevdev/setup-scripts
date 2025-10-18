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

# Install conda if needed
if ! command -v conda &> /dev/null; then
    echo "Installing Miniconda..."
    wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh
    bash /tmp/miniconda.sh -b -p "$HOME/miniconda3"
    rm /tmp/miniconda.sh
    eval "$($HOME/miniconda3/bin/conda shell.bash hook)"
    conda init bash
    
    # Fix permissions if running as root
    if [ "$(id -u)" -eq 0 ]; then
        chown -R $USER:$USER "$HOME/miniconda3"
        chown $USER:$USER ~/.bashrc 2>/dev/null || true
    fi
else
    echo "Conda already installed"
    eval "$(conda shell.bash hook)"
fi

# Accept conda TOS to avoid non-interactive errors
echo "Accepting conda Terms of Service..."
conda config --set allow_conda_downgrades true 2>/dev/null || true
conda config --set channel_priority flexible 2>/dev/null || true
# Accept TOS for main Anaconda channels if command exists (conda >= 24.x)
if conda tos --help &> /dev/null; then
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main 2>/dev/null || true
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r 2>/dev/null || true
fi

# Create unsloth environment
if conda env list | grep -q "^unsloth "; then
    echo "Unsloth environment exists, activating..."
    conda activate unsloth
else
    echo "Creating unsloth environment..."
    # Use conda-forge to avoid TOS requirements
    conda create -n unsloth python=3.10 -c conda-forge -y
    conda activate unsloth
fi

# Upgrade pip first
echo "Upgrading pip..."
pip install --upgrade pip

# Install PyTorch with CUDA
echo "Installing PyTorch with CUDA support..."
pip install --upgrade --no-cache-dir torch torchvision torchaudio

# Install Unsloth (recommended simple method from official docs)
# See: https://docs.unsloth.ai/get-started/install-and-update/pip-install
echo "Installing Unsloth (this may take a few minutes)..."
pip install unsloth

# Install additional dependencies for fine-tuning
echo "Installing additional dependencies..."
pip install trl peft accelerate bitsandbytes datasets transformers wandb tensorboard

# Install ipykernel so this environment can be used in Jupyter
pip install ipykernel
python -m ipykernel install --user --name=unsloth --display-name="Python (unsloth)"

# Install Jupyter if not already installed
if ! command -v jupyter &> /dev/null; then
    echo "Installing Jupyter Lab..."
    pip install jupyter jupyterlab
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
echo "✅ Unsloth environment ready!"
echo ""
echo "Quick start:"
echo "  conda activate unsloth"
echo "  python $HOME/unsloth-examples/test_install.py"
echo ""

# Check if Jupyter is already running
if lsof -i :8888 >/dev/null 2>&1 || pgrep -f "jupyter.*lab" >/dev/null 2>&1; then
    echo "💡 Jupyter Lab is already running on this instance!"
    echo "   Access it via your Brev URL (port 8888 should already be open)"
    echo ""
    echo "   To use the 'unsloth' conda environment in Jupyter:"
    echo "   1. Open Jupyter in your browser"
    echo "   2. Select the 'Python (unsloth)' kernel when creating a notebook"
    echo "   3. Or activate in a terminal: conda activate unsloth"
else
    echo "Start Jupyter Lab:"
    echo "  jupyter lab --ip=0.0.0.0 --port=8888"
    echo ""
    echo "⚠️  To access Jupyter from outside Brev, open port: 8888/tcp"
fi

echo ""
echo "Popular models:"
echo "  unsloth/llama-3.2-1b-bnb-4bit (smallest)"
echo "  unsloth/llama-3.2-3b-bnb-4bit"
echo "  unsloth/mistral-7b-bnb-4bit"
echo ""
echo "Docs: https://github.com/unslothai/unsloth"

