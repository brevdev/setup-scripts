# ML Quickstart

PyTorch with CUDA for GPU-accelerated machine learning.

## What it installs

- **Miniforge** - Open source conda package manager (fully licensed for commercial use)
- **Python 3.11** - Latest Python
- **PyTorch with CUDA 12.1** - GPU-accelerated ML
- **Jupyter Lab** - Interactive notebooks
- **transformers** - Hugging Face transformers
- **datasets** - ML datasets
- **pandas, matplotlib, seaborn** - Data analysis

## Usage

```bash
bash setup.sh
```

Takes ~5-8 minutes (PyTorch is large).

## What you get

```bash
conda activate ml           # Activate ML environment
python gpu_check.py         # Test GPU
jupyter lab                 # Start notebooks
```

## ⚠️ Required Port

To access Jupyter Lab from outside Brev, open:
- **8888/tcp** (Jupyter Lab default port)

## Quick GPU test

```python
import torch
print(torch.cuda.is_available())  # Should be True
print(torch.cuda.get_device_name(0))
```

## Train a model

```python
import torch
import torch.nn as nn

# Simple model
model = nn.Linear(100, 10).cuda()
x = torch.randn(32, 100).cuda()
y = model(x)
print(f"Output shape: {y.shape}")  # [32, 10]
```

