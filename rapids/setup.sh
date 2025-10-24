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

echo "⚡ Setting up RAPIDS GPU-Accelerated Data Science..."
echo "User: $USER | Home: $HOME"

# Verify GPU
if ! command -v nvidia-smi &> /dev/null; then
    echo "❌ Error: No NVIDIA GPU detected. RAPIDS requires a GPU."
    exit 1
fi

GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)
GPU_COUNT=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)
echo "✓ GPU detected: $GPU_NAME"
echo "✓ GPU count: $GPU_COUNT"

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
    
    # Create RAPIDS environment if it doesn't exist
    if ! sudo -H -u $USER bash -c "source $CONDA_HOME/bin/activate && conda env list | grep -q '^rapids '"; then
        echo "Creating RAPIDS environment..."
        echo "This will take 5-10 minutes (RAPIDS is large)..."
        
        # Detect CUDA version from nvidia-smi
        CUDA_VERSION=$(nvidia-smi | grep "CUDA Version" | awk '{print $9}' | cut -d. -f1,2)
        echo "Detected CUDA version: $CUDA_VERSION"
        
        # RAPIDS requires CUDA 11.x or 12.x - use 12.0 for broad compatibility
        sudo -H -u $USER bash -c "source $CONDA_HOME/bin/activate && conda create -n rapids -c rapidsai -c conda-forge -c nvidia rapids=24.08 python=3.11 cuda-version=12.0 -y"
    else
        echo "RAPIDS environment already exists, skipping..."
    fi
else
    # Load conda
    eval "$($CONDA_HOME/bin/conda shell.bash hook)"
    
    # Configure conda (conda-forge is default in Miniforge, no TOS required)
    conda config --set channel_priority flexible 2>/dev/null || true
    
    # Create RAPIDS environment if it doesn't exist
    if ! conda env list | grep -q "^rapids "; then
        echo "Creating RAPIDS environment..."
        echo "This will take 5-10 minutes (RAPIDS is large)..."
        
        # Detect CUDA version from nvidia-smi
        CUDA_VERSION=$(nvidia-smi | grep "CUDA Version" | awk '{print $9}' | cut -d. -f1,2)
        echo "Detected CUDA version: $CUDA_VERSION"
        
        # RAPIDS requires CUDA 11.x or 12.x - use 12.0 for broad compatibility
        conda create -n rapids -c rapidsai -c conda-forge -c nvidia \
            rapids=24.08 python=3.11 cuda-version=12.0 -y
    else
        echo "RAPIDS environment already exists, skipping..."
    fi
fi

# Install additional tools (running as the correct user)
echo "Installing additional tools..."
if [ "$(id -u)" -eq 0 ]; then
    sudo -H -u $USER bash -c "source $CONDA_HOME/bin/activate && conda activate rapids && pip install jupyterlab matplotlib seaborn plotly"
    sudo -H -u $USER bash -c "source $CONDA_HOME/bin/activate && conda activate rapids && pip install ipykernel"
    sudo -H -u $USER bash -c "source $CONDA_HOME/bin/activate && conda activate rapids && python -m ipykernel install --user --name=rapids --display-name='Python (rapids)'"
else
    conda activate rapids
    pip install jupyterlab matplotlib seaborn plotly
    pip install ipykernel
    python -m ipykernel install --user --name=rapids --display-name="Python (rapids)"
fi

# Create examples directory
mkdir -p ~/rapids-examples

# Create benchmark script
cat > ~/rapids-examples/benchmark.py << 'EOF'
"""
RAPIDS vs Pandas Benchmark
Demonstrates the speed difference between pandas and cuDF
"""
import time
import pandas as pd
import cudf
import numpy as np

# Configuration
ROWS = 10_000_000  # 10M rows
print(f"📊 Benchmarking with {ROWS:,} rows\n")

# Generate test data
print("Generating test data...")
data = {
    'a': np.random.randn(ROWS),
    'b': np.random.randn(ROWS),
    'c': np.random.randint(0, 100, ROWS),
    'category': np.random.choice(['A', 'B', 'C', 'D'], ROWS)
}

# Pandas benchmark
print("\n🐼 Testing pandas (CPU)...")
df_pandas = pd.DataFrame(data)
start = time.time()
result_pandas = df_pandas.groupby('category').agg({
    'a': 'mean',
    'b': 'sum',
    'c': 'max'
}).sort_values('a', ascending=False)
pandas_time = time.time() - start
print(f"   Time: {pandas_time:.3f}s")
print(result_pandas)

# cuDF benchmark
print("\n🚀 Testing cuDF (GPU)...")
df_cudf = cudf.DataFrame(data)
start = time.time()
result_cudf = df_cudf.groupby('category').agg({
    'a': 'mean',
    'b': 'sum',
    'c': 'max'
}).sort_values('a', ascending=False)
cudf_time = time.time() - start
print(f"   Time: {cudf_time:.3f}s")
print(result_cudf)

# Results
print(f"\n⚡ Speedup: {pandas_time/cudf_time:.1f}x faster with GPU!")
print(f"   pandas: {pandas_time:.3f}s")
print(f"   cuDF:   {cudf_time:.3f}s")
EOF

# Download or link to example notebook instead of embedding it
echo "📓 RAPIDS Examples available at: https://github.com/rapidsai/notebooks"
echo "   You can clone examples with: git clone https://github.com/rapidsai/notebooks ~/rapids-notebooks"

# Create simple test script
cat > ~/rapids-examples/test_rapids.py << 'EOF'
"""Quick RAPIDS installation test"""
import cudf
import cuml
import sys

print("✓ RAPIDS Installation Test\n")

# Test cuDF
df = cudf.DataFrame({'a': [1, 2, 3], 'b': [4, 5, 6]})
result = df['a'].sum()
print(f"✓ cuDF working: sum = {result}")

# Test cuML
from cuml.linear_model import LinearRegression
model = LinearRegression()
print("✓ cuML working: LinearRegression loaded")

# GPU info
import subprocess
gpu_info = subprocess.run(['nvidia-smi', '--query-gpu=name,memory.total', '--format=csv,noheader'], 
                         capture_output=True, text=True)
print(f"\n✓ GPU: {gpu_info.stdout.strip()}")

print("\n✅ RAPIDS is ready!")
EOF

# Fix all permissions if running as root
if [ "$(id -u)" -eq 0 ]; then
    echo "Fixing permissions..."
    chown -R $USER:$USER "$CONDA_HOME"
    chown -R $USER:$USER "$HOME/rapids-examples"
fi

# Run test
echo ""
echo "Verifying RAPIDS installation..."
if [ "$(id -u)" -eq 0 ]; then
    sudo -H -u $USER bash -c "source $CONDA_HOME/bin/activate && conda activate rapids && python ~/rapids-examples/test_rapids.py"
else
    conda activate rapids
    python ~/rapids-examples/test_rapids.py
fi

echo ""
echo "✅ RAPIDS ready!"
echo ""
echo "⚡ GPU-accelerated data science with $GPU_COUNT GPU(s)"
echo ""
echo "Quick start:"
echo "  conda activate rapids"
echo "  python ~/rapids-examples/benchmark.py    # See the speedup!"
echo ""
echo "Examples:"
echo "  ~/rapids-examples/benchmark.py           # pandas vs cuDF benchmark"
echo "  ~/rapids-examples/test_rapids.py         # Quick test"
echo ""
echo "More examples:"
echo "  git clone https://github.com/rapidsai/notebooks ~/rapids-notebooks"
echo ""

# Check if Jupyter is already running
if lsof -i :8888 >/dev/null 2>&1 || pgrep -f "jupyter.*lab" >/dev/null 2>&1; then
    echo "💡 Jupyter Lab is already running on this instance!"
    echo "   Access it via your Brev URL (port 8888 should already be open)"
    echo ""
    echo "   To use the 'rapids' conda environment in Jupyter:"
    echo "   1. Open Jupyter in your browser"
    echo "   2. Select the 'Python (rapids)' kernel when creating a notebook"
    echo "   3. Or activate in a terminal: conda activate rapids"
else
    echo "Start Jupyter Lab:"
    echo "  jupyter lab --ip=0.0.0.0 --port=8888"
    echo ""
    echo "⚠️  To access Jupyter from outside Brev, open port: 8888/tcp"
fi

echo ""
echo "Performance tips:"
echo "  - Use cuDF for datasets >1M rows (best speedup)"
echo "  - Keep data on GPU between operations"
echo "  - Use .to_pandas() only when necessary"
echo "  - Multi-GPU? Use dask-cuda for scaling"



