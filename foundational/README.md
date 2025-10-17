# Foundational Setup Scripts

Production-ready CUDA + ML framework setups for Brev. **Standalone, battle-tested, multi-GPU aware.**

## 🎯 Design Philosophy

All scripts are designed to be **simple and focused**:
- ✅ **Single script** - just point and go (< 16KB Brev limit)
- ✅ **Detect Brev user** dynamically (ubuntu, nvidia, shadeform, etc.)
- ✅ **Validate infrastructure** - NVIDIA drivers, CUDA (pre-installed by Brev)
- ✅ **Auto-configure multi-GPU** (1x, 2x, 4x, 8x)
- ✅ **Idempotent** - safe to run multiple times
- ✅ **Comprehensive error handling** with colored output
- ✅ **Auto-fix permissions** when run as root

## 📦 Available Scripts

### 1. `cuda-pytorch-setup.sh` ✅ COMPLETED

**Purpose:** Production-ready CUDA + PyTorch development environment with automatic multi-GPU configuration.

**What It Installs:**
- Miniconda + Python 3.11
- PyTorch 2.1+ with CUDA 12.1 support
- Essential ML libraries: transformers, datasets, accelerate
- Data science stack: numpy, pandas, scikit-learn, matplotlib, seaborn, plotly
- Training tools: wandb, tensorboard
- Jupyter Lab with GPU test notebooks

**GPU Configuration:**
- **1x GPU**: Standard training, batch_size ~32
- **2x GPU**: Data parallel training, batch_size ~64
- **4x GPU**: Larger models, batch_size ~128
- **8x GPU**: Large-scale training, batch_size ~256

**Key Features:**
- Battle-tested Brev user detection
- Validates NVIDIA drivers and CUDA (doesn't reinstall)
- Auto-configures NCCL for multi-GPU
- Creates GPU config at `~/.brev/gpu_config.sh`
- Includes simple GPU test script
- Comprehensive verification tests

**Size:** 12KB (under 16KB Brev limit) ✅

**Usage:**

**Option 1: Via Brev CLI (Recommended)**
```bash
brev start my-pytorch-workspace \
  --gpu g5.xlarge \
  --setup-script https://raw.githubusercontent.com/brevdev/setup-scripts/main/foundational/cuda-pytorch-setup.sh

# Or use default GPU (GCP T4: n1-highmem-4:nvidia-tesla-t4:1)
brev start my-pytorch-workspace \
  --setup-script https://raw.githubusercontent.com/brevdev/setup-scripts/main/foundational/cuda-pytorch-setup.sh
```

**Option 2: Direct Execution**
```bash
# SSH into your Brev instance first
curl -fsSL https://raw.githubusercontent.com/brevdev/setup-scripts/main/foundational/cuda-pytorch-setup.sh | bash
```

**After Installation:**
```bash
# Activate environment
conda activate pytorch_cuda

# Test GPU
python ~/notebooks/gpu_test.py

# Or quick test
python -c "import torch; print(f'{torch.cuda.device_count()} GPUs')"

# Start Jupyter Lab
jupyter lab --ip=0.0.0.0 --port=8888

# Multi-GPU training example (if 2+ GPUs)
torchrun --nproc_per_node=auto train.py
```

**Estimated Time:** 8-12 minutes  
**Tested on:** Ubuntu 22.04, CUDA 12.1+, L4/A100/T4/H100

**Multi-GPU Examples:**
```bash
# Single GPU (automatic)
python train_single_gpu.py

# Multi-GPU with automatic detection
torchrun --nproc_per_node=auto train_multi_gpu_ddp.py

# Specific GPU count
torchrun --nproc_per_node=4 train_multi_gpu_ddp.py
```

**Verification:**
```bash
# Check GPU configuration
nvidia-smi

# Verify PyTorch CUDA
python -c "import torch; print(torch.cuda.is_available())"

# Check multi-GPU setup
source ~/.brev/gpu_config.sh
echo "World Size: $WORLD_SIZE"
```

**Common Issues:**

| Issue | Solution |
|-------|----------|
| `conda: command not found` | Restart shell or run `source ~/.bashrc` |
| `CUDA not available` | Verify nvidia-smi works; ensure on GPU instance |
| Import errors | Activate environment: `conda activate pytorch_cuda` |
| Permission denied | Script auto-fixes permissions; re-run if needed |

---

### 2. `cuda-tensorflow-setup.sh` 🚧 PENDING

**Purpose:** CUDA + TensorFlow development environment with multi-GPU strategy configuration.

**Status:** Not yet implemented  
**Priority:** HIGH

**Planned Features:**
- TensorFlow 2.x with GPU support
- cuDNN validation
- MirroredStrategy for multi-GPU
- TensorBoard setup
- Keras integration

---

### 3. `cuda-jax-setup.sh` 🚧 PENDING

**Purpose:** JAX for high-performance ML with multi-device support.

**Status:** Not yet implemented  
**Priority:** MEDIUM

**Planned Features:**
- JAX with CUDA support
- Flax for neural networks
- Optax for optimization
- pmap for multi-device parallelism

---

## 🔧 Helper Template

See `_brev_helpers_template.sh` for reusable functions:
- `detect_brev_user()` - Battle-tested user detection
- `validate_nvidia_driver()` - Check driver installation
- `validate_cuda()` - Verify CUDA version
- `detect_gpu_config()` - Count available GPUs
- Logging functions with color output

**Important:** These functions are **inlined into each script** to keep them standalone. Don't source the template; copy functions into your script.

## 📊 Quick Reference

### GPU Memory Requirements

| Model Size | 1x GPU (16GB) | 2x GPU | 4x GPU | 8x GPU |
|------------|---------------|--------|--------|--------|
| Small (<1B) | ✅ Full FT | ✅ Full FT | ✅ Full FT | ✅ Full FT |
| Medium (7B) | ✅ Inference, LoRA | ✅ Full FT | ✅ Full FT | ✅ Full FT |
| Large (13B) | ⚠️ LoRA only | ✅ Full FT | ✅ Full FT | ✅ Full FT |
| XL (70B+) | ❌ | ⚠️ Inference only | ✅ Full FT | ✅ Full FT |

### Batch Size Recommendations

| Framework | 1x GPU | 2x GPU | 4x GPU | 8x GPU |
|-----------|--------|--------|--------|--------|
| PyTorch | 32 | 64 | 128 | 256 |
| TensorFlow | 32 | 64 | 128 | 256 |
| JAX | 32 | 64 | 128 | 256 |

*Adjust based on your model size and GPU memory*

## 🚀 Best Practices

1. **Always run on Brev GPU instances** - Scripts validate but don't install drivers
2. **Run scripts as regular user or root** - Auto-detects user and fixes permissions
3. **Check disk space** - Recommend 20GB+ free for conda packages
4. **Use conda environments** - Keeps dependencies isolated
5. **Version pin critical packages** - Ensures reproducibility
6. **Test on multiple GPU counts** - Verify scripts work on 1x, 2x, 4x, 8x setups

## 🐛 Troubleshooting

### Script fails to detect user
```bash
# Manually set user
export SUDO_USER=ubuntu  # or nvidia, shadeform
bash cuda-pytorch-setup.sh
```

### Conda installation issues
```bash
# Remove existing installation
rm -rf ~/miniconda3
# Re-run script
bash cuda-pytorch-setup.sh
```

### Multi-GPU not working
```bash
# Check NCCL setup
source ~/.brev/gpu_config.sh
echo $WORLD_SIZE

# Verify all GPUs visible
nvidia-smi
python -c "import torch; print(torch.cuda.device_count())"
```

## 📚 Resources

- [PyTorch Distributed Training](https://pytorch.org/tutorials/beginner/ddp_series_intro.html)
- [NVIDIA NCCL](https://docs.nvidia.com/deeplearning/nccl/user-guide/docs/index.html)
- [Brev Documentation](https://docs.brev.dev)
- [Multi-GPU Training Best Practices](https://pytorch.org/tutorials/intermediate/ddp_tutorial.html)

## 🤝 Contributing

When adding new foundational scripts:

1. **Use the cuda-pytorch-setup.sh as a template**
2. **Inline all helper functions** (keep scripts standalone)
3. **Test on multiple GPU configurations** (1x, 2x, 4x, 8x)
4. **Include comprehensive verification** tests
5. **Add to this README** with usage examples

---

**Next Steps:** Implement TensorFlow and JAX setups to complete the foundational trilogy! 🚀
