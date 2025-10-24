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

# Install conda (miniforge - open source, no licensing restrictions) if not already installed
if [ ! -d "$HOME/miniforge3" ] && [ ! -d "$HOME/miniconda3" ]; then
    echo "Installing Miniforge (conda-forge based, fully open source)..."
    if [ "$(id -u)" -eq 0 ]; then
        # Install as the user, not as root
        sudo -H -u $USER bash -c "cd $HOME && wget -q --show-progress https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh && bash Miniforge3-Linux-x86_64.sh -b -p $HOME/miniforge3 && rm Miniforge3-Linux-x86_64.sh"
        # Init conda as the user
        sudo -H -u $USER bash -c "$HOME/miniforge3/bin/conda init bash"
    else
        wget -q --show-progress https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
        bash Miniforge3-Linux-x86_64.sh -b -p $HOME/miniforge3
        rm Miniforge3-Linux-x86_64.sh
        $HOME/miniforge3/bin/conda init bash
    fi
else
    if [ -d "$HOME/miniconda3" ]; then
        echo "⚠️  Warning: Miniconda detected. Consider migrating to Miniforge for licensing compliance."
        echo "   Miniforge uses conda-forge channels (fully open source, no commercial licensing restrictions)."
    else
        echo "Miniforge already installed, skipping..."
    fi
fi

# Set CONDA_HOME based on what's installed (prefer miniforge)
if [ -d "$HOME/miniforge3" ]; then
    CONDA_HOME="$HOME/miniforge3"
elif [ -d "$HOME/miniconda3" ]; then
    CONDA_HOME="$HOME/miniconda3"
else
    echo "❌ Error: No conda installation found."
    exit 1
fi

# Configure and create conda environment as the user
if [ "$(id -u)" -eq 0 ]; then
    # Configure conda (conda-forge is default in Miniforge, no TOS required)
    sudo -H -u $USER bash -c "source $CONDA_HOME/bin/activate && conda config --set channel_priority flexible 2>/dev/null || true"
    
    # Create ML environment if it doesn't exist
    if ! sudo -H -u $USER bash -c "source $CONDA_HOME/bin/activate && conda env list | grep -q '^ml '"; then
        echo "Creating ML environment..."
        sudo -H -u $USER bash -c "source $CONDA_HOME/bin/activate && conda create -n ml python=3.11 -c conda-forge -y"
    else
        echo "ML environment already exists, skipping..."
    fi
else
    # Load conda
    eval "$($CONDA_HOME/bin/conda shell.bash hook)"
    
    # Configure conda (conda-forge is default in Miniforge, no TOS required)
    conda config --set channel_priority flexible 2>/dev/null || true
    
    # Create ML environment if it doesn't exist
    if ! conda env list | grep -q "^ml "; then
        echo "Creating ML environment..."
        conda create -n ml python=3.11 -c conda-forge -y
    else
        echo "ML environment already exists, skipping..."
    fi
fi

# Install packages into conda environment (running as the correct user)
echo "Installing PyTorch with CUDA..."
if [ "$(id -u)" -eq 0 ]; then
    sudo -H -u $USER bash -c "source $CONDA_HOME/bin/activate && conda activate ml && pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121"
else
    conda activate ml
    pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
fi

# Install ML essentials
echo "Installing ML packages..."

# Install Jupyter if not already installed (Brev often pre-installs it)
if ! command -v jupyter &> /dev/null; then
    echo "Installing Jupyter Lab..."
    if [ "$(id -u)" -eq 0 ]; then
        sudo -H -u $USER bash -c "source $CONDA_HOME/bin/activate && conda activate ml && pip install jupyter jupyterlab"
    else
        conda activate ml
        pip install jupyter jupyterlab
    fi
else
    echo "Jupyter already installed, skipping..."
fi

if [ "$(id -u)" -eq 0 ]; then
    sudo -H -u $USER bash -c "source $CONDA_HOME/bin/activate && conda activate ml && pip install transformers datasets accelerate"
    sudo -H -u $USER bash -c "source $CONDA_HOME/bin/activate && conda activate ml && pip install pandas matplotlib seaborn plotly"
    sudo -H -u $USER bash -c "source $CONDA_HOME/bin/activate && conda activate ml && pip install ipykernel"
    sudo -H -u $USER bash -c "source $CONDA_HOME/bin/activate && conda activate ml && python -m ipykernel install --user --name=ml --display-name='Python (ml)'"
else
    conda activate ml
    pip install transformers datasets accelerate
    pip install pandas matplotlib seaborn plotly
    pip install ipykernel
    python -m ipykernel install --user --name=ml --display-name="Python (ml)"
fi

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
if [ "$(id -u)" -eq 0 ]; then
    sudo -H -u $USER bash -c "source $CONDA_HOME/bin/activate && conda activate ml && python ~/ml-test/gpu_check.py"
else
    conda activate ml
    python ~/ml-test/gpu_check.py
fi

echo ""
echo "✅ ML environment ready!"
echo ""
echo "Quick start:"
echo "  conda activate ml"
echo "  python ~/ml-test/gpu_check.py"
echo ""

# Check if Jupyter is already running
if lsof -i :8888 >/dev/null 2>&1 || pgrep -f "jupyter.*lab" >/dev/null 2>&1; then
    echo "💡 Jupyter Lab is already running on this instance!"
    echo "   Access it via your Brev URL (port 8888 should already be open)"
    echo ""
    echo "   To use the 'ml' conda environment in Jupyter:"
    echo "   1. Open Jupyter in your browser"
    echo "   2. The 'ml' kernel should be available in the kernel list"
    echo "   3. Or activate in a terminal: conda activate ml"
else
    echo "Start Jupyter Lab:"
    echo "  jupyter lab --ip=0.0.0.0 --port=8888"
    echo ""
    echo "⚠️  To access Jupyter from outside Brev, open port: 8888/tcp"
fi


