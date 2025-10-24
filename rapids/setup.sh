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

# Install conda (miniconda) if not already installed
if [ ! -d "$HOME/miniconda3" ]; then
    echo "Installing Miniconda..."
    if [ "$(id -u)" -eq 0 ]; then
        # Install as the user, not as root
        sudo -H -u $USER bash -c "cd $HOME && wget -q --show-progress https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && bash Miniconda3-latest-Linux-x86_64.sh -b -p $HOME/miniconda3 && rm Miniconda3-latest-Linux-x86_64.sh"
        # Init conda as the user
        sudo -H -u $USER bash -c "$HOME/miniconda3/bin/conda init bash"
    else
        wget -q --show-progress https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
        bash Miniconda3-latest-Linux-x86_64.sh -b -p $HOME/miniconda3
        rm Miniconda3-latest-Linux-x86_64.sh
        $HOME/miniconda3/bin/conda init bash
    fi
else
    echo "Miniconda already installed, skipping..."
fi

# Configure and create conda environment as the user
if [ "$(id -u)" -eq 0 ]; then
    # Accept conda TOS to avoid non-interactive errors
    echo "Accepting conda Terms of Service..."
    sudo -H -u $USER bash -c "source $HOME/miniconda3/bin/activate && conda config --set allow_conda_downgrades true 2>/dev/null || true"
    sudo -H -u $USER bash -c "source $HOME/miniconda3/bin/activate && conda config --set channel_priority flexible 2>/dev/null || true"
    sudo -H -u $USER bash -c "source $HOME/miniconda3/bin/activate && conda tos --help &> /dev/null && conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main 2>/dev/null || true"
    sudo -H -u $USER bash -c "source $HOME/miniconda3/bin/activate && conda tos --help &> /dev/null && conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r 2>/dev/null || true"
    
    # Create RAPIDS environment if it doesn't exist
    if ! sudo -H -u $USER bash -c "source $HOME/miniconda3/bin/activate && conda env list | grep -q '^rapids '"; then
        echo "Creating RAPIDS environment..."
        echo "This will take 5-10 minutes (RAPIDS is large)..."
        
        # Detect CUDA version from nvidia-smi
        CUDA_VERSION=$(nvidia-smi | grep "CUDA Version" | awk '{print $9}' | cut -d. -f1,2)
        echo "Detected CUDA version: $CUDA_VERSION"
        
        # RAPIDS requires CUDA 11.x or 12.x - use 12.0 for broad compatibility
        sudo -H -u $USER bash -c "source $HOME/miniconda3/bin/activate && conda create -n rapids -c rapidsai -c conda-forge -c nvidia rapids=24.08 python=3.11 cuda-version=12.0 -y"
    else
        echo "RAPIDS environment already exists, skipping..."
    fi
else
    # Load conda
    eval "$($HOME/miniconda3/bin/conda shell.bash hook)"
    
    # Accept conda TOS to avoid non-interactive errors
    echo "Accepting conda Terms of Service..."
    conda config --set allow_conda_downgrades true 2>/dev/null || true
    conda config --set channel_priority flexible 2>/dev/null || true
    if conda tos --help &> /dev/null; then
        conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main 2>/dev/null || true
        conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r 2>/dev/null || true
    fi
    
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
    sudo -H -u $USER bash -c "source $HOME/miniconda3/bin/activate && conda activate rapids && pip install jupyterlab matplotlib seaborn plotly"
    sudo -H -u $USER bash -c "source $HOME/miniconda3/bin/activate && conda activate rapids && pip install ipykernel"
    sudo -H -u $USER bash -c "source $HOME/miniconda3/bin/activate && conda activate rapids && python -m ipykernel install --user --name=rapids --display-name='Python (rapids)'"
else
    conda activate rapids
    pip install jupyterlab matplotlib seaborn plotly
    pip install ipykernel
    python -m ipykernel install --user --name=rapids --display-name="Python (rapids)"
fi

# Create examples directory
mkdir -p ~/rapids-examples
cd ~/rapids-examples

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

# Create example notebook
cat > ~/rapids-examples/rapids_quickstart.ipynb << 'EOF'
{
 "cells": [
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "# RAPIDS Quickstart\n",
    "\n",
    "GPU-accelerated data science with drop-in pandas replacement.\n",
    "\n",
    "## What is RAPIDS?\n",
    "\n",
    "- **cuDF**: GPU DataFrame (pandas-like)\n",
    "- **cuML**: GPU Machine Learning (scikit-learn-like)\n",
    "- **cuGraph**: GPU Graph Analytics (NetworkX-like)\n",
    "- **Dask-CUDA**: Multi-GPU scaling\n",
    "\n",
    "### Speed: 10-50x faster than pandas on large datasets!"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "import cudf\n",
    "import pandas as pd\n",
    "import numpy as np\n",
    "import time\n",
    "\n",
    "print(f\"cuDF version: {cudf.__version__}\")"
   ]
  },
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "## 1. Basic cuDF Usage (Drop-in pandas replacement)"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "# Create a cuDF DataFrame (GPU)\n",
    "df = cudf.DataFrame({\n",
    "    'a': [1, 2, 3, 4, 5],\n",
    "    'b': [10, 20, 30, 40, 50],\n",
    "    'category': ['A', 'B', 'A', 'B', 'C']\n",
    "})\n",
    "\n",
    "print(\"cuDF DataFrame:\")\n",
    "print(df)\n",
    "print(f\"\\nShape: {df.shape}\")\n",
    "print(f\"Memory: GPU\")"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "# Standard pandas operations work!\n",
    "print(\"Group by category:\")\n",
    "print(df.groupby('category')['b'].mean())"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "# Filter and compute\n",
    "result = df[df['a'] > 2]['b'].sum()\n",
    "print(f\"Sum of 'b' where 'a' > 2: {result}\")"
   ]
  },
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "## 2. Speed Comparison: pandas vs cuDF"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "# Create large dataset\n",
    "ROWS = 5_000_000\n",
    "print(f\"Testing with {ROWS:,} rows...\")\n",
    "\n",
    "data = {\n",
    "    'x': np.random.randn(ROWS),\n",
    "    'y': np.random.randn(ROWS),\n",
    "    'z': np.random.randint(0, 100, ROWS),\n",
    "    'group': np.random.choice(['A', 'B', 'C', 'D', 'E'], ROWS)\n",
    "}"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "# Pandas (CPU)\n",
    "df_pandas = pd.DataFrame(data)\n",
    "start = time.time()\n",
    "result_pandas = df_pandas.groupby('group').agg({\n",
    "    'x': 'mean',\n",
    "    'y': 'std',\n",
    "    'z': 'max'\n",
    "})\n",
    "pandas_time = time.time() - start\n",
    "print(f\"🐼 Pandas time: {pandas_time:.3f}s\")"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "# cuDF (GPU)\n",
    "df_cudf = cudf.DataFrame(data)\n",
    "start = time.time()\n",
    "result_cudf = df_cudf.groupby('group').agg({\n",
    "    'x': 'mean',\n",
    "    'y': 'std',\n",
    "    'z': 'max'\n",
    "})\n",
    "cudf_time = time.time() - start\n",
    "print(f\"🚀 cuDF time: {cudf_time:.3f}s\")\n",
    "print(f\"\\n⚡ Speedup: {pandas_time/cudf_time:.1f}x faster!\")"
   ]
  },
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "## 3. Converting Between pandas and cuDF"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "# pandas → cuDF\n",
    "df_pandas = pd.DataFrame({'a': [1, 2, 3]})\n",
    "df_gpu = cudf.from_pandas(df_pandas)\n",
    "print(\"Moved to GPU:\", type(df_gpu))\n",
    "\n",
    "# cuDF → pandas\n",
    "df_cpu = df_gpu.to_pandas()\n",
    "print(\"Moved to CPU:\", type(df_cpu))"
   ]
  },
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "## 4. cuML: GPU Machine Learning"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "from cuml.ensemble import RandomForestClassifier\n",
    "from cuml.model_selection import train_test_split\n",
    "\n",
    "# Generate classification data\n",
    "n_samples = 100000\n",
    "X = cudf.DataFrame({\n",
    "    'feature1': np.random.randn(n_samples),\n",
    "    'feature2': np.random.randn(n_samples),\n",
    "    'feature3': np.random.randn(n_samples)\n",
    "})\n",
    "y = cudf.Series(np.random.randint(0, 2, n_samples))\n",
    "\n",
    "# Train GPU-accelerated Random Forest\n",
    "X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2)\n",
    "\n",
    "start = time.time()\n",
    "model = RandomForestClassifier(n_estimators=100)\n",
    "model.fit(X_train, y_train)\n",
    "score = model.score(X_test, y_test)\n",
    "train_time = time.time() - start\n",
    "\n",
    "print(f\"Training time: {train_time:.3f}s\")\n",
    "print(f\"Accuracy: {score:.3f}\")"
   ]
  },
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "## 5. Reading Large Files (Faster with GPU)"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "# Save test CSV\n",
    "test_data = cudf.DataFrame({\n",
    "    'col1': np.random.randn(1_000_000),\n",
    "    'col2': np.random.randn(1_000_000)\n",
    "})\n",
    "test_data.to_csv('test.csv', index=False)\n",
    "\n",
    "# Read with cuDF (GPU-accelerated CSV parsing)\n",
    "start = time.time()\n",
    "df = cudf.read_csv('test.csv')\n",
    "read_time = time.time() - start\n",
    "print(f\"GPU CSV read time: {read_time:.3f}s\")\n",
    "print(f\"Shape: {df.shape}\")"
   ]
  },
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "## 6. GPU Memory Info"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "# Check GPU memory\n",
    "import subprocess\n",
    "result = subprocess.run(['nvidia-smi', '--query-gpu=memory.used,memory.total', '--format=csv,noheader'], \n",
    "                       capture_output=True, text=True)\n",
    "print(\"GPU Memory:\")\n",
    "print(result.stdout)"
   ]
  },
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "## Next Steps\n",
    "\n",
    "- **cuDF docs**: https://docs.rapids.ai/api/cudf/stable/\n",
    "- **cuML docs**: https://docs.rapids.ai/api/cuml/stable/\n",
    "- **Examples**: https://github.com/rapidsai/notebooks\n",
    "- **Multi-GPU**: Use `dask-cuda` for scaling\n",
    "\n",
    "### Key Tips:\n",
    "1. Use cuDF for operations on large datasets (>1M rows)\n",
    "2. For small data, pandas might be faster (GPU transfer overhead)\n",
    "3. Keep data on GPU between operations for best performance\n",
    "4. Use `.to_pandas()` only when needed for visualization/export"
   ]
  }
 ],
 "metadata": {
  "kernelspec": {
   "display_name": "Python 3",
   "language": "python",
   "name": "python3"
  },
  "language_info": {
   "name": "python",
   "version": "3.11.0"
  }
 },
 "nbformat": 4,
 "nbformat_minor": 4
}
EOF

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
    chown -R $USER:$USER "$HOME/miniconda3"
    chown -R $USER:$USER "$HOME/rapids-examples"
fi

# Run test
echo ""
echo "Verifying RAPIDS installation..."
if [ "$(id -u)" -eq 0 ]; then
    sudo -H -u $USER bash -c "source $HOME/miniconda3/bin/activate && conda activate rapids && python ~/rapids-examples/test_rapids.py"
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
echo "  ~/rapids-examples/rapids_quickstart.ipynb # Interactive tutorial"
echo "  ~/rapids-examples/test_rapids.py         # Quick test"
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


