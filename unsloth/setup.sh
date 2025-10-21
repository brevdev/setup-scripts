#!/bin/bash
set -e

# ============================================================================
# Unsloth Baseline Setup Script for NVIDIA Brev
# ============================================================================
# This script provides a comprehensive baseline installation of Unsloth and
# all common dependencies needed for fine-tuning LLMs, vision models, and
# audio models on Brev GPU instances.
#
# Compatible with all 181+ converted Unsloth notebooks.
# ============================================================================

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

# Parse command line arguments
# Default: Install everything (baseline for all notebooks)
INSTALL_VISION=true
INSTALL_AUDIO=true
SKIP_EXAMPLES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --minimal|--text-only)
            INSTALL_VISION=false
            INSTALL_AUDIO=false
            shift
            ;;
        --no-vision)
            INSTALL_VISION=false
            shift
            ;;
        --no-audio)
            INSTALL_AUDIO=false
            shift
            ;;
        --skip-examples)
            SKIP_EXAMPLES=true
            shift
            ;;
        --help)
            echo "Unsloth Baseline Setup Script for NVIDIA Brev"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "By default, installs ALL dependencies for text, vision, and audio models."
            echo "This ensures compatibility with all 181+ converted Unsloth notebooks."
            echo ""
            echo "Options:"
            echo "  --minimal        Install only text model dependencies (smallest install)"
            echo "  --text-only      Same as --minimal"
            echo "  --no-vision      Skip vision dependencies"
            echo "  --no-audio       Skip audio dependencies"
            echo "  --skip-examples  Skip cloning example notebooks repository"
            echo "  --help           Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                    # Full install (recommended - works with all notebooks)"
            echo "  $0 --minimal          # Text models only (Llama, Mistral, etc.)"
            echo "  $0 --no-audio         # Text + vision, but no audio"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run '$0 --help' for usage information"
            exit 1
            ;;
    esac
done

echo "============================================"
echo "🚀 Unsloth Baseline Setup for NVIDIA Brev"
echo "============================================"
echo "User: $USER | Home: $HOME"
echo ""

# ============================================================================
# System Verification
# ============================================================================

echo "[1/8] Verifying system requirements..."

# Verify GPU
if ! command -v nvidia-smi &> /dev/null; then
    echo "⚠️  Warning: No NVIDIA GPU detected. Unsloth requires a GPU."
    exit 1
fi
GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)
echo "✓ GPU detected: $GPU_NAME"

# Verify Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: Python 3 not found. Please install Python 3 first."
    exit 1
fi
PYTHON_VERSION=$(python3 --version)
echo "✓ Python: $PYTHON_VERSION"
echo "  Location: $(which python3)"

# Update system packages (if we have apt)
if command -v apt-get &> /dev/null; then
    echo "✓ Updating system packages..."
    apt-get update -qq 2>/dev/null || true
    apt-get install -y -qq git wget curl build-essential 2>/dev/null || true
fi

# ============================================================================
# Python Environment Setup
# ============================================================================

echo ""
echo "[2/8] Setting up Python environment..."

# Detect package manager (prefer uv if available)
PACKAGE_MANAGER="pip"
if command -v uv &> /dev/null; then
    PACKAGE_MANAGER="uv"
    echo "✓ Using uv package manager (faster)"
else
    echo "✓ Using pip package manager"
    # Upgrade pip if using it
    python3 -m pip install --upgrade pip -q 2>/dev/null || true
fi

# Function to install packages with the detected manager
install_package() {
    if [ "$PACKAGE_MANAGER" = "uv" ]; then
        uv pip install "$@" 2>&1 | grep -v "^Resolved\|^Prepared\|^Installed" || true
    else
        python3 -m pip install "$@" -q
    fi
}

# Configure PyTorch cache directories
echo "✓ Configuring PyTorch cache directories..."
if [ -d "/ephemeral" ] && [ -w "/ephemeral" ]; then
    export TORCHINDUCTOR_CACHE_DIR="/ephemeral/torch_cache"
    export TORCH_COMPILE_DIR="/ephemeral/torch_cache"
    export TRITON_CACHE_DIR="/ephemeral/triton_cache"
    mkdir -p "$TORCHINDUCTOR_CACHE_DIR" "$TRITON_CACHE_DIR" 2>/dev/null || true
    echo "  Using /ephemeral for caches (larger scratch space)"
else
    export TORCHINDUCTOR_CACHE_DIR="$HOME/.cache/torch/inductor"
    export TORCH_COMPILE_DIR="$HOME/.cache/torch/inductor"
    export TRITON_CACHE_DIR="$HOME/.cache/triton"
    mkdir -p "$TORCHINDUCTOR_CACHE_DIR" "$TRITON_CACHE_DIR" 2>/dev/null || true
    echo "  Using home directory for caches"
fi
export XDG_CACHE_HOME="$HOME/.cache"

# Add to bashrc for persistence
if ! grep -q "TORCHINDUCTOR_CACHE_DIR" "$HOME/.bashrc" 2>/dev/null; then
    cat >> "$HOME/.bashrc" << 'BASHEOF'

# PyTorch cache configuration (added by unsloth setup)
if [ -d "/ephemeral" ] && [ -w "/ephemeral" ]; then
    export TORCHINDUCTOR_CACHE_DIR="/ephemeral/torch_cache"
    export TORCH_COMPILE_DIR="/ephemeral/torch_cache"
    export TRITON_CACHE_DIR="/ephemeral/triton_cache"
else
    export TORCHINDUCTOR_CACHE_DIR="$HOME/.cache/torch/inductor"
    export TORCH_COMPILE_DIR="$HOME/.cache/torch/inductor"
    export TRITON_CACHE_DIR="$HOME/.cache/triton"
fi
export XDG_CACHE_HOME="$HOME/.cache"
BASHEOF
fi

# ============================================================================
# Core ML Dependencies
# ============================================================================

echo ""
echo "[3/8] Installing core ML packages..."
echo "  (This may take several minutes)"

# PyTorch with CUDA support
echo "✓ Installing PyTorch with CUDA support..."
install_package --upgrade torch torchvision torchaudio

# Core training libraries
echo "✓ Installing core training libraries..."
install_package \
    transformers>=4.40.0 \
    datasets>=2.18.0 \
    accelerate>=0.28.0 \
    peft>=0.10.0 \
    trl>=0.8.0 \
    bitsandbytes>=0.43.0

# ============================================================================
# Unsloth Installation (Conda Variant)
# ============================================================================

echo ""
echo "[4/8] Installing Unsloth (conda variant)..."
echo "  (This is the recommended variant for Brev environments)"

# Install Unsloth with conda variant for better compatibility
install_package "unsloth[conda] @ git+https://github.com/unslothai/unsloth.git"

# ============================================================================
# Jupyter Environment
# ============================================================================

echo ""
echo "[5/8] Setting up Jupyter environment..."

if ! command -v jupyter &> /dev/null; then
    echo "✓ Installing Jupyter Lab..."
    install_package jupyterlab>=4.0.0 ipykernel>=6.29.0 ipywidgets>=8.1.0 notebook>=7.0.0
else
    echo "✓ Jupyter already installed, ensuring latest version..."
    install_package --upgrade jupyterlab ipykernel ipywidgets notebook
fi

# Fix Jupyter kernel configuration (ensure it uses python3, not python)
echo "✓ Verifying Jupyter kernel configuration..."
KERNEL_DIR="$HOME/.local/share/jupyter/kernels/python3"
if [ -f "$KERNEL_DIR/kernel.json" ]; then
    # Check if kernel.json has "python" instead of "python3"
    if grep -q '"python"' "$KERNEL_DIR/kernel.json" 2>/dev/null; then
        echo "  Fixing kernel to use python3..."
        sed -i.bak 's/"python"/"python3"/g' "$KERNEL_DIR/kernel.json" 2>/dev/null || \
        sed -i '' 's/"python"/"python3"/g' "$KERNEL_DIR/kernel.json" 2>/dev/null || true
    fi
fi

# Register current Python as Jupyter kernel if needed
python3 -m ipykernel install --user --name=python3 --display-name="Python 3" 2>/dev/null || true

# ============================================================================
# Additional Dependencies
# ============================================================================

echo ""
echo "[6/8] Installing additional utilities..."

# Monitoring and logging
echo "✓ Installing monitoring tools..."
install_package wandb>=0.16.0 tensorboard>=2.15.0

# Utilities
echo "✓ Installing utility packages..."
install_package \
    tqdm>=4.66.0 \
    numpy>=1.24.0 \
    pandas>=2.0.0 \
    scikit-learn>=1.3.0 \
    huggingface-hub>=0.20.0

# Optional: Vision dependencies
if [ "$INSTALL_VISION" = true ]; then
    echo "✓ Installing vision model dependencies..."
    install_package pillow opencv-python
fi

# Optional: Audio dependencies
if [ "$INSTALL_AUDIO" = true ]; then
    echo "✓ Installing audio model dependencies..."
    install_package librosa>=0.10.0 soundfile>=0.12.0
fi

# ============================================================================
# Workspace Setup
# ============================================================================

echo ""
echo "[7/8] Creating workspace directories..."

# Create standard workspace structure
mkdir -p "$HOME/workspace/models"
mkdir -p "$HOME/workspace/outputs"
mkdir -p "$HOME/workspace/checkpoints"
mkdir -p "$HOME/workspace/datasets"
mkdir -p "$HOME/workspace/notebooks"

# Also create /workspace if we have permissions (common on Brev)
if [ -w /workspace ] || [ "$(id -u)" -eq 0 ]; then
    mkdir -p /workspace/models
    mkdir -p /workspace/outputs
    mkdir -p /workspace/checkpoints
    mkdir -p /workspace/datasets
    echo "✓ Created /workspace directories"
fi

echo "✓ Workspace directories created"

# ============================================================================
# Verification & Examples
# ============================================================================

echo ""
echo "[8/8] Verifying installation..."

python3 -c "
import sys
import torch

print('Core packages:')
print(f'  ✓ PyTorch: {torch.__version__}')
print(f'  ✓ CUDA available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'  ✓ CUDA version: {torch.version.cuda}')
    print(f'  ✓ GPU count: {torch.cuda.device_count()}')

# Check PyTorch version compatibility
version_str = torch.__version__.split('+')[0]
major, minor = map(int, version_str.split('.')[:2])
if major < 2 or (major == 2 and minor < 1):
    print(f'  ⚠️  Warning: PyTorch {torch.__version__} may have compatibility issues')
else:
    print(f'  ✓ PyTorch version is compatible')

# Test Unsloth import
try:
    from unsloth import FastLanguageModel
    print(f'  ✓ Unsloth imported successfully')
except Exception as e:
    print(f'  ❌ Unsloth import failed: {str(e)}')
    sys.exit(1)

# Test other key imports
import transformers
import datasets
import peft
import trl
print(f'  ✓ Transformers: {transformers.__version__}')
print(f'  ✓ Datasets: {datasets.__version__}')
print(f'  ✓ PEFT: {peft.__version__}')
print(f'  ✓ TRL: {trl.__version__}')
" || exit 1

# Create test script
if [ "$SKIP_EXAMPLES" = false ]; then
    echo ""
    echo "Creating example scripts..."
    mkdir -p "$HOME/unsloth-examples"
    
    cat > "$HOME/unsloth-examples/test_install.py" << 'EOF'
#!/usr/bin/env python3
"""Test script to verify Unsloth installation."""
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
    model,
    r = 16,
    target_modules = ["q_proj", "k_proj", "v_proj", "o_proj"],
    lora_alpha = 16,
    lora_dropout = 0,
    bias = "none",
)

print(f"✅ Model loaded successfully!")
print(f"   GPU Memory: {torch.cuda.memory_allocated() / 1e9:.2f}GB")
print(f"   Device: {torch.cuda.get_device_name(0)}")
print("Ready for fine-tuning! 🚀")
EOF
    chmod +x "$HOME/unsloth-examples/test_install.py"
    
    # Clone notebooks repository
    echo "Cloning Unsloth notebooks repository..."
    if [ -d "$HOME/unsloth-notebooks" ]; then
        echo "  Repository already exists, updating..."
        cd "$HOME/unsloth-notebooks"
        git pull -q 2>/dev/null || true
    else
        cd "$HOME"
        git clone -q https://github.com/unslothai/notebooks.git unsloth-notebooks 2>/dev/null || true
        
        # Fix permissions if running as root
        if [ "$(id -u)" -eq 0 ]; then
            chown -R "$USER:$USER" "$HOME/unsloth-notebooks" 2>/dev/null || true
        fi
    fi
    echo "  ✓ Notebooks available at: ~/unsloth-notebooks"
fi

# ============================================================================
# Summary & Next Steps
# ============================================================================

echo ""
echo "============================================"
echo "✅ Setup Complete!"
echo "============================================"
echo ""
echo "📊 Installation Summary:"
echo "  ✓ Package manager: $PACKAGE_MANAGER"
echo "  ✓ PyTorch cache: ${TORCHINDUCTOR_CACHE_DIR}"
echo "  ✓ Unsloth (conda variant)"
echo "  ✓ PyTorch with CUDA"
echo "  ✓ Core ML libraries (transformers, datasets, peft, trl)"
echo "  ✓ Jupyter Lab environment (kernel verified)"
echo "  ✓ Monitoring tools (wandb, tensorboard)"
if [ "$INSTALL_VISION" = true ]; then
    echo "  ✓ Vision dependencies (torchvision, pillow, opencv)"
else
    echo "  ⊘ Vision dependencies (skipped with --minimal or --no-vision)"
fi
if [ "$INSTALL_AUDIO" = true ]; then
    echo "  ✓ Audio dependencies (librosa, soundfile)"
else
    echo "  ⊘ Audio dependencies (skipped with --minimal or --no-audio)"
fi
echo ""

echo "📁 Workspace Structure:"
echo "  $HOME/workspace/"
echo "  ├── models/         # Pre-trained models"
echo "  ├── outputs/        # Training outputs"
echo "  ├── checkpoints/    # Model checkpoints"
echo "  ├── datasets/       # Datasets"
echo "  └── notebooks/      # Your notebooks"
echo ""

if [ "$SKIP_EXAMPLES" = false ]; then
    echo "🧪 Test Installation:"
    echo "  python3 ~/unsloth-examples/test_install.py"
    echo ""
    echo "📓 Example Notebooks:"
    echo "  ~/unsloth-notebooks/"
    echo ""
fi

# Check if Jupyter is already running
if lsof -i :8888 >/dev/null 2>&1 || pgrep -f "jupyter.*lab" >/dev/null 2>&1; then
    echo "💡 Jupyter Lab is already running!"
    echo "   Access it via your Brev URL (port 8888)"
else
    echo "🚀 Start Jupyter Lab:"
    echo "  jupyter lab --ip=0.0.0.0 --port=8888"
    echo ""
    echo "  Or add to ~/.bashrc for auto-start:"
    echo "  echo 'jupyter lab --ip=0.0.0.0 --port=8888 &' >> ~/.bashrc"
fi

echo ""
echo "📚 Resources:"
echo "  • Unsloth Docs:  https://docs.unsloth.ai"
echo "  • Brev Docs:     https://docs.nvidia.com/brev"
echo "  • Notebooks:     https://github.com/unslothai/notebooks"
echo ""
echo "🎯 Popular Models:"
echo "  • unsloth/llama-3.2-1b-bnb-4bit     (1B - fastest)"
echo "  • unsloth/llama-3.2-3b-bnb-4bit     (3B - balanced)"
echo "  • unsloth/mistral-7b-bnb-4bit       (7B - powerful)"
echo "  • unsloth/gemma-2-9b-bnb-4bit       (9B - advanced)"
echo ""
echo "Happy fine-tuning! 🎉"

