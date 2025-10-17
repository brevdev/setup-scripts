#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

###############################################################################
# NVIDIA CUDA + PyTorch Setup for Brev
# Installs: Miniconda, PyTorch with CUDA, ML libraries, Jupyter Lab
# Auto-configures: Single/Multi-GPU (1x, 2x, 4x, 8x)
# Tested: Ubuntu 22.04, CUDA 12.1+, L4/A100/T4/H100
###############################################################################

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

GPU_COUNT=0; GPU_NAME=""; GPU_MEMORY=""; CUDA_VERSION=""; WORLD_SIZE=1
BREV_USER=""; BREV_HOME=""

cleanup() {
    log_error "Setup failed. You can re-run this script (it's idempotent)."
}
trap cleanup ERR

###############################################################################
# Brev User Detection (battle-tested from marimo-setup.sh)
###############################################################################
detect_brev_user() {
    local DETECTED_USER=""
    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
        DETECTED_USER="$SUDO_USER"
    else
        for user_home in /home/*; do
            username=$(basename "$user_home")
            if ls "$user_home"/.lifecycle-script-ls-*.log 2>/dev/null | grep -q .; then
                DETECTED_USER="$username"; break
            fi
            if [ -f "$user_home/.verb-setup.log" ]; then
                DETECTED_USER="$username"; break
            fi
        done
        if [ -z "$DETECTED_USER" ]; then
            for user_home in /home/*; do
                username=$(basename "$user_home")
                if [ -L "$user_home/.cache" ] && [ "$(readlink "$user_home/.cache")" = "/ephemeral/cache" ]; then
                    DETECTED_USER="$username"; break
                fi
            done
        fi
        if [ -z "$DETECTED_USER" ]; then
            for user_home in /home/*; do
                username=$(basename "$user_home")
                if [ "$username" = "launchpad" ]; then continue; fi
                if id "$username" &>/dev/null; then
                    user_uid=$(id -u "$username" 2>/dev/null || echo 0)
                    if [ "$user_uid" -ge 1000 ]; then
                        DETECTED_USER="$username"; break
                    fi
                fi
            done
        fi
        if [ -z "$DETECTED_USER" ]; then
            [ -d "/home/nvidia" ] && DETECTED_USER="nvidia" || DETECTED_USER="ubuntu"
        fi
    fi
    echo "$DETECTED_USER"
}

###############################################################################
# Validation
###############################################################################
validate_gpu() {
    log_step "Validating GPU..."
    if ! command -v nvidia-smi &> /dev/null; then
        log_error "nvidia-smi not found. Ensure you're on a GPU-enabled Brev instance."
        exit 1
    fi
    GPU_COUNT=$(nvidia-smi --list-gpus 2>/dev/null | wc -l)
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
    GPU_MEMORY=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1)
    log_info "${GPU_COUNT}x GPU: ${GPU_NAME} (${GPU_MEMORY}MB each)"
    [ "$GPU_COUNT" -eq 1 ] && WORLD_SIZE=1 || WORLD_SIZE=$GPU_COUNT
}

validate_cuda() {
    log_step "Validating CUDA..."
    CUDA_VERSION=$(nvidia-smi 2>/dev/null | grep -oP 'CUDA Version: \K[0-9.]+' || echo "unknown")
    log_info "CUDA: $CUDA_VERSION"
    if [[ "$CUDA_VERSION" != "unknown" ]]; then
        local major=$(echo "$CUDA_VERSION" | cut -d. -f1)
        [ "$major" -lt 12 ] && log_warn "CUDA < 12.0. Recommend 12.1+"
    fi
}

check_disk_space() {
    local avail=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    log_info "Disk space: ${avail}GB"
    [ "$avail" -lt 20 ] && log_warn "Low disk space. Recommend 20GB+"
}

###############################################################################
# Conda Installation
###############################################################################
install_conda() {
    log_step "Installing Miniconda..."
    if command -v conda &> /dev/null; then
        log_info "Conda already installed"
        eval "$(conda shell.bash hook)"
        return
    fi
    wget -q --show-progress https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh
    bash /tmp/miniconda.sh -b -p "$BREV_HOME/miniconda3"
    rm /tmp/miniconda.sh
    eval "$($BREV_HOME/miniconda3/bin/conda shell.bash hook)"
    "$BREV_HOME/miniconda3/bin/conda" init bash 2>/dev/null || true
    "$BREV_HOME/miniconda3/bin/conda" init zsh 2>/dev/null || true
    "$BREV_HOME/miniconda3/bin/conda" config --set auto_activate_base false
    if [ "$(id -u)" -eq 0 ]; then
        chown -R "$BREV_USER:$BREV_USER" "$BREV_HOME/miniconda3" 2>/dev/null || true
        chown "$BREV_USER:$BREV_USER" "$BREV_HOME/.bashrc" "$BREV_HOME/.zshrc" 2>/dev/null || true
    fi
    log_info "✓ Miniconda installed"
}

###############################################################################
# PyTorch Environment
###############################################################################
create_pytorch_env() {
    log_step "Creating PyTorch environment..."
    conda activate base || eval "$(conda shell.bash hook)"
    if conda env list | grep -q "^pytorch_cuda "; then
        log_info "Environment exists, updating..."
        conda activate pytorch_cuda
    else
        conda create -n pytorch_cuda python=3.11 -y
        conda activate pytorch_cuda
    fi
    log_info "Installing PyTorch with CUDA..."
    conda install pytorch torchvision torchaudio pytorch-cuda=12.1 -c pytorch -c nvidia -y
    log_info "✓ PyTorch installed"
}

install_ml_packages() {
    log_step "Installing ML packages..."
    conda activate pytorch_cuda
    pip install -q jupyter jupyterlab ipywidgets
    pip install -q transformers datasets accelerate
    pip install -q pandas numpy scikit-learn matplotlib seaborn plotly
    pip install -q wandb tensorboard
    log_info "✓ Packages installed"
}

###############################################################################
# Multi-GPU Configuration
###############################################################################
setup_multi_gpu_config() {
    [ "$GPU_COUNT" -le 1 ] && return
    log_step "Configuring multi-GPU..."
    local config_dir="$BREV_HOME/.brev"
    mkdir -p "$config_dir"
    cat > "$config_dir/gpu_config.sh" << EOF
#!/bin/bash
export WORLD_SIZE=$GPU_COUNT
export MASTER_ADDR=localhost
export MASTER_PORT=29500
export NCCL_DEBUG=INFO
export NCCL_IB_DISABLE=1
export NCCL_P2P_DISABLE=0
export NCCL_SOCKET_IFNAME=lo
EOF
    chmod +x "$config_dir/gpu_config.sh"
    if ! grep -q "source.*gpu_config.sh" "$BREV_HOME/.bashrc"; then
        echo "source $config_dir/gpu_config.sh" >> "$BREV_HOME/.bashrc"
    fi
    [ "$(id -u)" -eq 0 ] && chown -R "$BREV_USER:$BREV_USER" "$config_dir" 2>/dev/null || true
    log_info "✓ Multi-GPU config: $config_dir/gpu_config.sh"
}

###############################################################################
# Jupyter Setup
###############################################################################
setup_jupyter() {
    log_step "Setting up Jupyter..."
    conda activate pytorch_cuda
    jupyter lab --generate-config 2>/dev/null || true
    local nb_dir="$BREV_HOME/notebooks"
    mkdir -p "$nb_dir"
    # Create simple test notebook
    cat > "$nb_dir/gpu_test.py" << 'EOF'
import torch
print(f"PyTorch: {torch.__version__}")
print(f"CUDA available: {torch.cuda.is_available()}")
print(f"GPU count: {torch.cuda.device_count()}")
if torch.cuda.is_available():
    for i in range(torch.cuda.device_count()):
        print(f"GPU {i}: {torch.cuda.get_device_name(i)}")
EOF
    [ "$(id -u)" -eq 0 ] && chown -R "$BREV_USER:$BREV_USER" "$nb_dir" 2>/dev/null || true
    log_info "✓ Jupyter configured. Notebooks: $nb_dir"
}

###############################################################################
# Verification
###############################################################################
verify_installation() {
    log_step "Verifying installation..."
    conda activate pytorch_cuda
    python3 << 'EOF'
import torch
assert torch.cuda.is_available(), "CUDA not available!"
gpu_count = torch.cuda.device_count()
print(f"✓ CUDA available with {gpu_count} GPU(s)")
for i in range(gpu_count):
    print(f"  GPU {i}: {torch.cuda.get_device_name(i)}")
EOF
    python3 << 'EOF'
import torch
x = torch.randn(1000, 1000).cuda()
y = x @ x.T
torch.cuda.synchronize()
print("✓ GPU computation successful")
EOF
    if [ "$GPU_COUNT" -gt 1 ]; then
        python3 << 'EOF'
import torch, torch.nn as nn
model = nn.DataParallel(nn.Linear(100, 100)).cuda()
x = torch.randn(32, 100).cuda()
y = model(x)
print(f"✓ Multi-GPU DataParallel works ({torch.cuda.device_count()} GPUs)")
EOF
    fi
    log_info "${GREEN}All tests passed!${NC}"
}

###############################################################################
# Summary
###############################################################################
print_summary() {
    cat << EOF

${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${GREEN}✓ CUDA + PyTorch Setup Complete!${NC}
${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

${YELLOW}GPU Configuration:${NC}
  • ${GPU_COUNT}x ${GPU_NAME}
  • ${GPU_MEMORY}MB per GPU
  • CUDA ${CUDA_VERSION}

${YELLOW}Environment:${NC}
  • Activate: ${GREEN}conda activate pytorch_cuda${NC}

${YELLOW}Quick Start:${NC}
  ${GREEN}# Test GPU${NC}
  python -c "import torch; print(f'{torch.cuda.device_count()} GPUs')"

  ${GREEN}# Start Jupyter${NC}
  jupyter lab --ip=0.0.0.0 --port=8888

  ${GREEN}# Test notebook${NC}
  python ~/notebooks/gpu_test.py

$(if [ "$GPU_COUNT" -gt 1 ]; then
cat << MULTI

${YELLOW}Multi-GPU Training:${NC}
  ${GREEN}# DataParallel (simple)${NC}
  model = nn.DataParallel(model).cuda()

  ${GREEN}# DistributedDataParallel (recommended)${NC}
  torchrun --nproc_per_node=${GPU_COUNT} train.py

  ${GREEN}# Recommended batch size: $((32 * GPU_COUNT))${NC}
MULTI
fi)

${YELLOW}Resources:${NC}
  • PyTorch: https://pytorch.org/docs/
  • Multi-GPU: https://pytorch.org/tutorials/beginner/ddp_series_intro.html
  • Brev: https://docs.brev.dev

${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${GREEN}Happy Training! 🚀${NC}
${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

EOF
}

###############################################################################
# Main
###############################################################################
main() {
    echo ""
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "  CUDA + PyTorch Setup for Brev"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    BREV_USER=$(detect_brev_user)
    BREV_HOME="/home/$BREV_USER"
    export BREV_USER BREV_HOME
    
    log_info "User: $BREV_USER | Home: $BREV_HOME"
    
    validate_gpu
    validate_cuda
    check_disk_space
    install_conda
    create_pytorch_env
    install_ml_packages
    setup_multi_gpu_config
    setup_jupyter
    
    echo ""
    verify_installation
    echo ""
    print_summary
}

main "$@"
