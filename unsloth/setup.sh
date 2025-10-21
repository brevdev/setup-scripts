#!/bin/bash
set -e

# Unsloth Baseline Setup for NVIDIA Brev
# Compatible with all 181+ converted Unsloth notebooks

# Detect Brev user
detect_brev_user() {
    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
        echo "$SUDO_USER"
        return
    fi
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
    [ -d "/home/nvidia" ] && echo "nvidia" && return
    [ -d "/home/ubuntu" ] && echo "ubuntu" && return
    echo "ubuntu"
}

if [ "$(id -u)" -eq 0 ] || [ "${USER:-}" = "root" ]; then
    DETECTED_USER=$(detect_brev_user)
    export USER="$DETECTED_USER"
    export HOME="/home/$DETECTED_USER"
fi

# Parse arguments
INSTALL_VISION=true
INSTALL_AUDIO=true
SKIP_EXAMPLES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --minimal|--text-only) INSTALL_VISION=false; INSTALL_AUDIO=false; shift ;;
        --no-vision) INSTALL_VISION=false; shift ;;
        --no-audio) INSTALL_AUDIO=false; shift ;;
        --skip-examples) SKIP_EXAMPLES=true; shift ;;
        --help)
            echo "Unsloth Setup for NVIDIA Brev"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Default: Installs ALL dependencies (text, vision, audio)"
            echo ""
            echo "Options:"
            echo "  --minimal        Text models only"
            echo "  --no-vision      Skip vision deps"
            echo "  --no-audio       Skip audio deps"
            echo "  --skip-examples  Skip cloning notebooks"
            echo "  --help           Show this help"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo "============================================"
echo "🚀 Unsloth Setup for NVIDIA Brev"
echo "============================================"
echo "User: $USER | Home: $HOME"
echo ""

# System verification
echo "[1/8] Verifying system..."

if ! command -v nvidia-smi &> /dev/null; then
    echo "⚠️  No GPU detected"
    exit 1
fi
GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)
echo "✓ GPU: $GPU_NAME"

if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 not found"
    exit 1
fi
echo "✓ Python: $(python3 --version)"

if command -v apt-get &> /dev/null; then
    apt-get update -qq 2>/dev/null || true
    apt-get install -y -qq git wget curl build-essential 2>/dev/null || true
fi

# Python environment
echo ""
echo "[2/8] Setting up Python..."

PACKAGE_MANAGER="pip"
if command -v uv &> /dev/null; then
    PACKAGE_MANAGER="uv"
    echo "✓ Using uv (faster)"
else
    echo "✓ Using pip"
    python3 -m pip install --upgrade pip -q 2>/dev/null || true
fi

install_package() {
    if [ "$PACKAGE_MANAGER" = "uv" ]; then
        uv pip install "$@" 2>&1 | grep -v "^Resolved\|^Prepared\|^Installed" || true
    else
        python3 -m pip install "$@" -q
    fi
}

# Configure PyTorch caches
echo "✓ Configuring cache dirs..."
if [ -d "/ephemeral" ] && [ -w "/ephemeral" ]; then
    export TORCHINDUCTOR_CACHE_DIR="/ephemeral/torch_cache"
    export TORCH_COMPILE_DIR="/ephemeral/torch_cache"
    export TRITON_CACHE_DIR="/ephemeral/triton_cache"
    mkdir -p "$TORCHINDUCTOR_CACHE_DIR" "$TRITON_CACHE_DIR" 2>/dev/null || true
    echo "  Using /ephemeral"
else
    export TORCHINDUCTOR_CACHE_DIR="$HOME/.cache/torch/inductor"
    export TORCH_COMPILE_DIR="$HOME/.cache/torch/inductor"
    export TRITON_CACHE_DIR="$HOME/.cache/triton"
    mkdir -p "$TORCHINDUCTOR_CACHE_DIR" "$TRITON_CACHE_DIR" 2>/dev/null || true
    echo "  Using $HOME/.cache"
fi
export XDG_CACHE_HOME="$HOME/.cache"

# Add to bashrc
if ! grep -q "TORCHINDUCTOR_CACHE_DIR" "$HOME/.bashrc" 2>/dev/null; then
    cat >> "$HOME/.bashrc" << 'BASHEOF'

# PyTorch cache (added by unsloth setup)
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

# Core ML packages
echo ""
echo "[3/8] Installing ML packages..."

echo "✓ PyTorch + CUDA..."
install_package --upgrade torch torchvision torchaudio

echo "✓ Core libraries..."
install_package transformers>=4.40.0 datasets>=2.18.0 accelerate>=0.28.0 peft>=0.10.0 trl>=0.8.0 bitsandbytes>=0.43.0

# Unsloth
echo ""
echo "[4/8] Installing Unsloth..."
install_package "unsloth[conda] @ git+https://github.com/unslothai/unsloth.git"

# Jupyter
echo ""
echo "[5/8] Setting up Jupyter..."

if ! command -v jupyter &> /dev/null; then
    echo "✓ Installing Jupyter..."
    install_package jupyterlab>=4.0.0 ipykernel>=6.29.0 ipywidgets>=8.1.0 notebook>=7.0.0
else
    echo "✓ Updating Jupyter..."
    install_package --upgrade jupyterlab ipykernel ipywidgets notebook
fi

# Fix kernel config
echo "✓ Fixing kernel config..."
KERNEL_DIR="$HOME/.local/share/jupyter/kernels/python3"
if [ -f "$KERNEL_DIR/kernel.json" ]; then
    if grep -q '"python"' "$KERNEL_DIR/kernel.json" 2>/dev/null; then
        sed -i.bak 's/"python"/"python3"/g' "$KERNEL_DIR/kernel.json" 2>/dev/null || \
        sed -i '' 's/"python"/"python3"/g' "$KERNEL_DIR/kernel.json" 2>/dev/null || true
    fi
fi
python3 -m ipykernel install --user --name=python3 --display-name="Python 3" 2>/dev/null || true

# Additional deps
echo ""
echo "[6/8] Installing utilities..."

echo "✓ Monitoring..."
install_package wandb>=0.16.0 tensorboard>=2.15.0

echo "✓ Utilities..."
install_package tqdm>=4.66.0 numpy>=1.24.0 pandas>=2.0.0 scikit-learn>=1.3.0 huggingface-hub>=0.20.0

if [ "$INSTALL_VISION" = true ]; then
    echo "✓ Vision deps..."
    install_package pillow opencv-python
fi

if [ "$INSTALL_AUDIO" = true ]; then
    echo "✓ Audio deps..."
    install_package librosa>=0.10.0 soundfile>=0.12.0
fi

# Workspace
echo ""
echo "[7/8] Creating workspace..."

mkdir -p "$HOME/workspace"/{models,outputs,checkpoints,datasets,notebooks}

if [ -w /workspace ] || [ "$(id -u)" -eq 0 ]; then
    mkdir -p /workspace/{models,outputs,checkpoints,datasets}
fi
echo "✓ Workspace ready"

# Verification
echo ""
echo "[8/8] Verifying..."

python3 -c "
import sys, torch
print('✓ PyTorch:', torch.__version__)
print('✓ CUDA:', torch.cuda.is_available())
if torch.cuda.is_available():
    print('✓ GPU:', torch.cuda.device_count(), 'device(s)')
try:
    from unsloth import FastLanguageModel
    print('✓ Unsloth OK')
except Exception as e:
    print('❌ Unsloth failed:', e)
    sys.exit(1)
import transformers, datasets, peft, trl
print('✓ Libs OK')
" || exit 1

# Examples
if [ "$SKIP_EXAMPLES" = false ]; then
    echo ""
    echo "Creating examples..."
    mkdir -p "$HOME/unsloth-examples"
    
    cat > "$HOME/unsloth-examples/test.py" << 'EOF'
#!/usr/bin/env python3
from unsloth import FastLanguageModel
import torch

print("Loading model...")
model, tokenizer = FastLanguageModel.from_pretrained(
    model_name = "unsloth/llama-3.2-1b-bnb-4bit",
    max_seq_length = 2048,
    dtype = None,
    load_in_4bit = True,
)

model = FastLanguageModel.get_peft_model(
    model, r=16,
    target_modules=["q_proj","k_proj","v_proj","o_proj"],
    lora_alpha=16, lora_dropout=0, bias="none",
)

print(f"✅ Ready! GPU: {torch.cuda.memory_allocated()/1e9:.2f}GB")
EOF
    chmod +x "$HOME/unsloth-examples/test.py"
    
    echo "Cloning notebooks..."
    if [ -d "$HOME/unsloth-notebooks" ]; then
        cd "$HOME/unsloth-notebooks" && git pull -q 2>/dev/null || true
    else
        cd "$HOME" && git clone -q https://github.com/unslothai/notebooks.git unsloth-notebooks 2>/dev/null || true
        [ "$(id -u)" -eq 0 ] && chown -R "$USER:$USER" "$HOME/unsloth-notebooks" 2>/dev/null || true
    fi
    echo "✓ Notebooks at ~/unsloth-notebooks"
fi

# Summary
echo ""
echo "============================================"
echo "✅ Setup Complete!"
echo "============================================"
echo ""
echo "📊 Installed:"
echo "  ✓ $PACKAGE_MANAGER | Cache: ${TORCHINDUCTOR_CACHE_DIR}"
echo "  ✓ Unsloth (conda) | PyTorch + CUDA"
echo "  ✓ ML libs | Jupyter | Monitoring"
[ "$INSTALL_VISION" = true ] && echo "  ✓ Vision" || echo "  ⊘ Vision"
[ "$INSTALL_AUDIO" = true ] && echo "  ✓ Audio" || echo "  ⊘ Audio"
echo ""
echo "📁 Workspace: $HOME/workspace/"
[ "$SKIP_EXAMPLES" = false ] && echo "🧪 Test: python3 ~/unsloth-examples/test.py"
echo ""

if lsof -i :8888 >/dev/null 2>&1 || pgrep -f "jupyter.*lab" >/dev/null 2>&1; then
    echo "💡 Jupyter running on port 8888"
else
    echo "🚀 Start Jupyter:"
    echo "  jupyter lab --ip=0.0.0.0 --port=8888"
fi

echo ""
echo "📚 Docs: https://docs.unsloth.ai | https://docs.nvidia.com/brev"
echo "Happy fine-tuning! 🎉"
