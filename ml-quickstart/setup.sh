#!/bin/bash
set -e

# Detect Brev user (handles ubuntu, nvidia, shadeform, etc.)
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

echo "🤖 Setting up ML environment..."
echo "User: $USER | Home: $HOME"

# Install conda (miniconda) if not already installed
if [ ! -d "$HOME/miniconda3" ]; then
    echo "Installing Miniconda..."
    wget -q --show-progress https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
    bash Miniconda3-latest-Linux-x86_64.sh -b -p $HOME/miniconda3
    rm Miniconda3-latest-Linux-x86_64.sh
    
    # Init conda
    $HOME/miniconda3/bin/conda init bash
    
    # Fix permissions if running as root
    if [ "$(id -u)" -eq 0 ]; then
        chown -R $USER:$USER "$HOME/miniconda3"
        chown $USER:$USER ~/.bashrc 2>/dev/null || true
    fi
else
    echo "Miniconda already installed, skipping..."
fi

# Load conda
eval "$($HOME/miniconda3/bin/conda shell.bash hook)"

# Create ML environment if it doesn't exist
if ! conda env list | grep -q "^ml "; then
    echo "Creating ML environment..."
    # Use conda-forge to avoid TOS requirements
    conda create -n ml python=3.11 -c conda-forge -y
else
    echo "ML environment already exists, skipping..."
fi

conda activate ml

# Install PyTorch with CUDA (Brev already has CUDA installed)
echo "Installing PyTorch with CUDA..."
conda install pytorch torchvision torchaudio pytorch-cuda=12.1 -c pytorch -c nvidia -y

# Install ML essentials
echo "Installing ML packages..."

# Install Jupyter if not already installed (Brev often pre-installs it)
if ! command -v jupyter &> /dev/null; then
    echo "Installing Jupyter Lab..."
    pip install jupyter jupyterlab
else
    echo "Jupyter already installed, skipping..."
fi

pip install transformers datasets accelerate
pip install pandas matplotlib seaborn plotly

# Create test script
mkdir -p ~/ml-test
cat > ~/ml-test/gpu_check.py << 'EOF'
import torch
print(f"PyTorch: {torch.__version__}")
print(f"CUDA available: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"GPU: {torch.cuda.get_device_name(0)}")
    print(f"GPU count: {torch.cuda.device_count()}")
EOF

# Verify
echo ""
echo "Verifying installation..."
python ~/ml-test/gpu_check.py

echo ""
echo "✅ ML environment ready!"
echo ""
echo "Quick start:"
echo "  conda activate ml"
echo "  python ~/ml-test/gpu_check.py"
echo "  jupyter lab --ip=0.0.0.0 --port=8888"
echo ""
echo "⚠️  To access Jupyter from outside Brev, open port: 8888/tcp"

