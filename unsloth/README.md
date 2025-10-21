# Unsloth Baseline Setup Script for NVIDIA Brev

A comprehensive, production-ready setup script that installs Unsloth and all necessary dependencies for fine-tuning LLMs, vision models, and audio models on NVIDIA Brev GPU instances.

**Compatible with all 181+ converted Unsloth notebooks.**

## Features

✅ **Brev-Native**: Automatically detects Brev user environment and configures accordingly  
✅ **Smart Package Manager**: Detects and uses `uv` (faster) or falls back to `pip`  
✅ **Optimized Caching**: Automatically uses `/ephemeral` for PyTorch caches when available  
✅ **Jupyter Kernel Fix**: Ensures Jupyter kernel uses `python3` (prevents import errors)  
✅ **GPU Verification**: Validates NVIDIA GPU presence and CUDA availability  
✅ **Conda Variant**: Uses the recommended `unsloth[conda]` variant for maximum compatibility  
✅ **Complete ML Stack**: Installs PyTorch, Transformers, PEFT, TRL, and all training dependencies  
✅ **Jupyter Environment**: Sets up Jupyter Lab with proper kernel and widget support  
✅ **Optional Dependencies**: Support for vision and audio model fine-tuning  
✅ **Workspace Setup**: Creates organized directory structure for models, outputs, and datasets  
✅ **Verification**: Tests all installations and provides diagnostic information  
✅ **Examples Included**: Clones official notebooks and creates test scripts  

## Quick Start

### Full Installation (Default - Recommended)

```bash
bash setup.sh
```

**By default, installs EVERYTHING for all 181+ notebooks:**
- ✅ Unsloth (conda variant)
- ✅ PyTorch with CUDA
- ✅ Core ML libraries (transformers, datasets, peft, trl, bitsandbytes)
- ✅ Jupyter Lab
- ✅ Monitoring tools (wandb, tensorboard)
- ✅ **Vision dependencies** (torchvision, pillow, opencv) - for Gemma3-Vision, Qwen2-VL, etc.
- ✅ **Audio dependencies** (librosa, soundfile) - for Whisper, TTS/STT models
- ✅ Standard utilities

This ensures **all 181+ notebooks work out of the box** with no surprises!

### Minimal Installation (Text Models Only)

If you only need text models (Llama, Mistral, Gemma, etc.) and want to save time/space:

```bash
bash setup.sh --minimal
# or
bash setup.sh --text-only
```

Skips vision and audio dependencies (~1GB less, ~2 minutes faster).

### Custom Installation

Skip specific components:

```bash
# Text + Vision, skip audio
bash setup.sh --no-audio

# Text + Audio, skip vision
bash setup.sh --no-vision

# Skip example notebooks
bash setup.sh --skip-examples
```

## Usage Options

```bash
bash setup.sh [OPTIONS]

Options:
  --minimal        Install only text model dependencies (smallest/fastest)
  --text-only      Same as --minimal
  --no-vision      Skip vision dependencies (keeps audio)
  --no-audio       Skip audio dependencies (keeps vision)
  --skip-examples  Skip cloning example notebooks repository
  --help           Show help message

Default: Installs ALL dependencies (text + vision + audio)
```

## What Gets Installed

### Core ML Stack

| Package | Version | Purpose |
|---------|---------|---------|
| torch | >=2.1.0 | PyTorch with CUDA support |
| transformers | >=4.40.0 | HuggingFace Transformers |
| datasets | >=2.18.0 | Dataset loading and processing |
| accelerate | >=0.28.0 | Distributed training |
| peft | >=0.10.0 | Parameter-efficient fine-tuning |
| trl | >=0.8.0 | Transformer reinforcement learning |
| bitsandbytes | >=0.43.0 | Quantization support |
| unsloth | latest | Fast fine-tuning (conda variant) |

### Jupyter Environment

- jupyterlab (>=4.0.0)
- ipykernel (>=6.29.0)
- ipywidgets (>=8.1.0)
- notebook (>=7.0.0)

### Monitoring & Logging

- wandb (>=0.16.0) - Experiment tracking
- tensorboard (>=2.15.0) - TensorBoard logging

### Utilities

- tqdm, numpy, pandas, scikit-learn
- huggingface-hub

### Vision Dependencies (Installed by Default)

- torchvision
- pillow
- opencv-python

**Skip with:** `--minimal` or `--no-vision`

### Audio Dependencies (Installed by Default)

- librosa (>=0.10.0)
- soundfile (>=0.12.0)

**Skip with:** `--minimal` or `--no-audio`

## Directory Structure

After installation, the following workspace structure is created:

```
$HOME/workspace/
├── models/         # Pre-trained models and weights
├── outputs/        # Training outputs and logs
├── checkpoints/    # Model checkpoints during training
├── datasets/       # Training datasets
└── notebooks/      # Your Jupyter notebooks

/workspace/         # Also created if permissions allow
├── models/
├── outputs/
├── checkpoints/
└── datasets/

$HOME/unsloth-examples/
└── test_install.py # Test script to verify installation

$HOME/unsloth-notebooks/  # Official Unsloth notebooks (if not --skip-examples)
└── nb/
    ├── Llama3_(8B).ipynb
    ├── Gemma3_(4B).ipynb
    └── ... (181+ notebooks)
```

## Post-Installation

### Test Your Installation

```bash
python3 ~/unsloth-examples/test_install.py
```

This loads a small Llama 3.2 1B model to verify everything works.

### Start Jupyter Lab

```bash
jupyter lab --ip=0.0.0.0 --port=8888
```

Access via your Brev URL on port 8888.

### Try an Example Notebook

```bash
cd ~/unsloth-notebooks/nb
# Open any notebook in Jupyter Lab
```

## Compatibility

### Supported Models

All 181+ Unsloth notebooks are supported, including:

**Text Models:**
- Llama 2/3/3.1/3.2 (1B - 70B)
- Mistral/Mixtral (7B - 8x22B)
- Qwen 2/2.5/3 (0.5B - 72B)
- Gemma 2/3 (2B - 27B)
- Phi 3/4 (3.8B - 14B)
- GPT-OSS (20B - 120B)

**Vision Models:**
- Gemma 3 Vision
- Qwen2-VL
- Qwen3-VL
- Pixtral
- Llama 3.2 Vision

**Audio Models:**
- Whisper (Large V3)
- Sesame-CSM
- Orpheus-TTS
- Llasa-TTS
- Oute-TTS
- Spark-TTS

### GPU Requirements

Minimum:
- NVIDIA GPU with CUDA support
- 16GB VRAM (for 1B-7B models with 4-bit quantization)

Recommended:
- L4 (24GB VRAM) for 7B models
- A100-40GB for 13B-20B models
- A100-80GB for 70B+ models

### Brev Instance Types

Tested and verified on:
- Brev Standard (ubuntu user)
- Brev NVIDIA (nvidia user)
- Brev Shadeform (various users)

## Environment Optimizations

This script includes several Brev-specific optimizations discovered during the conversion of 181+ notebooks:

### Virtual Environment Detection

**Critical for Jupyter Lab integration:**

- **Automatically detects Brev venv**: Checks for `~/.venv/bin/python3` (standard Brev setup)
- **Installs to correct environment**: Ensures packages are available to Jupyter kernel
- **Kernel registration**: Configures Jupyter to use the same Python as package installation
- **Falls back gracefully**: Uses system Python if no venv exists

This ensures **notebooks don't need to reinstall packages** that were already installed by `setup.sh`.

See [VENV_FIX.md](./VENV_FIX.md) for detailed explanation.

### Package Manager Detection

- **Automatically detects `uv`**: If available, uses `uv pip install` (faster, Brev default)
- **Falls back to `pip`**: Works on any Python environment
- **Transparent switching**: No configuration needed

### PyTorch Cache Configuration

- **Detects `/ephemeral`**: Automatically uses `/ephemeral/torch_cache` and `/ephemeral/triton_cache` when available
- **Falls back to home**: Uses `~/.cache/torch/` if `/ephemeral` doesn't exist
- **Persistent config**: Adds environment variables to `~/.bashrc` for future sessions
- **Benefits**: Better performance, more storage space for compiled kernels

Configured environment variables:
```bash
TORCHINDUCTOR_CACHE_DIR=/ephemeral/torch_cache  # or ~/.cache/torch/inductor
TORCH_COMPILE_DIR=/ephemeral/torch_cache         # or ~/.cache/torch/inductor
TRITON_CACHE_DIR=/ephemeral/triton_cache         # or ~/.cache/triton
XDG_CACHE_HOME=$HOME/.cache
```

### Jupyter Kernel Fix

Common issue: Jupyter kernel configured to use `python` instead of `python3`, causing:
```
FileNotFoundError: [Errno 2] No such file or directory: 'python'
```

**Our fix:**
- Automatically detects incorrect kernel configuration
- Updates `kernel.json` to use `python3`
- Registers current Python as Jupyter kernel
- Ensures notebooks run in the correct environment

## Troubleshooting

### PyTorch Import Error

If you get "No module named torch":
```bash
python3 -m pip install --upgrade torch torchvision torchaudio
```

### Unsloth Import Error

If Unsloth fails to import, try reinstalling:
```bash
python3 -m pip uninstall -y unsloth
python3 -m pip install "unsloth[conda] @ git+https://github.com/unslothai/unsloth.git"
```

### CUDA Not Available

Verify GPU:
```bash
nvidia-smi
python3 -c "import torch; print(torch.cuda.is_available())"
```

### Permission Errors

If running as root, the script automatically detects and uses the Brev user. If you still have permission issues:
```bash
sudo chown -R $USER:$USER $HOME/workspace
sudo chown -R $USER:$USER $HOME/unsloth-*
```

## Advanced Usage

### Custom Python Environment

If you prefer to use a virtual environment:

```bash
python3 -m venv ~/unsloth-env
source ~/unsloth-env/bin/activate
bash setup.sh
```

### Specific PyTorch Version

To install a specific PyTorch version before running the script:

```bash
pip install torch==2.5.0 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
bash setup.sh
```

### Skip Specific Steps

The script is designed to be idempotent - you can run it multiple times safely. To update only Unsloth:

```bash
python3 -m pip install --upgrade "unsloth[conda] @ git+https://github.com/unslothai/unsloth.git"
```

## Maintenance

### Update All Packages

```bash
python3 -m pip install --upgrade pip
python3 -m pip install --upgrade torch torchvision torchaudio
python3 -m pip install --upgrade transformers datasets accelerate peft trl
python3 -m pip install --upgrade "unsloth[conda] @ git+https://github.com/unslothai/unsloth.git"
```

### Update Example Notebooks

```bash
cd ~/unsloth-notebooks
git pull
```

## Resources

- **Unsloth Documentation:** https://docs.unsloth.ai
- **Brev Documentation:** https://docs.nvidia.com/brev
- **Unsloth GitHub:** https://github.com/unslothai/unsloth
- **Example Notebooks:** https://github.com/unslothai/notebooks
- **Converted Notebooks:** See `brevdev/unsloth-notebook-adaptor/converted/`

## Support

For issues related to:
- **This script:** Open an issue in the brevdev repository
- **Unsloth:** Visit https://github.com/unslothai/unsloth/issues
- **Brev platform:** Contact NVIDIA Brev support

## Version History

**v2.1.0** (October 2025)
- 🚀 Auto-detect and use `uv` package manager (faster installations)
- 🗂️ Auto-detect `/ephemeral` for PyTorch caches (better performance)
- 🔧 Auto-fix Jupyter kernel configuration (prevents `python` not found errors)
- 📦 Persistent cache configuration in `~/.bashrc`
- ✅ Based on learnings from converting 181+ notebooks

**v2.0.0** (October 2025)
- Added conda variant installation
- Added vision and audio support
- Added command-line options
- Added workspace structure
- Enhanced verification
- Compatible with 181+ notebooks

**v1.0.0** (Previous)
- Initial Unsloth setup script

## License

This setup script is provided as-is for use with NVIDIA Brev and Unsloth.
