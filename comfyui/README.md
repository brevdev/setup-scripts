# ComfyUI

Powerful node-based interface for Stable Diffusion image generation.

## What it installs

- **ComfyUI** - Node-based UI for Stable Diffusion
- **ComfyUI-Manager** - Model manager & custom node installer (⭐ **NEW**)
- **PyTorch** - With CUDA GPU support
- **Stable Diffusion 1.5** - Starter model (pre-downloaded)
- **Systemd service** - Auto-starts with system
- **Python virtual environment** - Clean isolation

## Features

- **Node-based workflow** - Visual programming for image generation
- **GPU accelerated** - Uses NVIDIA GPU automatically
- **Flexible pipelines** - Chain models, samplers, upscalers
- **Custom nodes** - Extensible with community plugins
- **Multiple models** - Support for SD 1.5, SDXL, LoRAs, etc.
- **Batch processing** - Generate multiple images

## ⚠️ Required Port

To access from outside Brev, open:
- **8188/tcp** (ComfyUI web interface)

## Requirements

- NVIDIA GPU (required for good performance)
- 8GB+ VRAM recommended
- ~10GB disk space for models

## Usage

```bash
bash setup.sh
```

Takes ~5-10 minutes (downloads model).

## What you get

- **Web UI:** `http://localhost:8188`
- **Installation:** `~/ComfyUI`
- **Models:** `~/ComfyUI/models/checkpoints`
- **Service:** Auto-starts on boot

## Quick Start

**Access the UI:**
```bash
# Open in browser (or via your Brev URL with port 8188)
http://localhost:8188
```

**⭐ Download Models (using ComfyUI-Manager):**
1. Click the **"Manager"** button in the top menu
2. Click **"Install Models"**
3. Search for models (e.g., "SDXL", "Realistic Vision")
4. Click **"Install"** - downloads directly to the remote server
5. Models appear in ComfyUI automatically

**Basic workflow:**
1. Load the default workflow (already loaded)
2. Enter your prompt in the text box
3. Click "Queue Prompt"
4. Wait for image generation
5. View result in the UI

## Manage Service

```bash
sudo systemctl status comfyui      # Check status
sudo systemctl restart comfyui     # Restart
sudo systemctl stop comfyui        # Stop
sudo systemctl start comfyui       # Start
sudo journalctl -u comfyui -f      # View logs
```

**Run manually (if you prefer):**
```bash
cd ~/ComfyUI
./start.sh
```

## Download More Models

### Option 1: Use ComfyUI-Manager (Recommended ⭐)

**In the web UI:**
1. Click **"Manager"** button (top menu)
2. Click **"Install Models"**
3. Browse or search for models
4. Click **"Install"** next to any model
5. Models download directly to the server

**Supported sources:**
- Hugging Face models
- CivitAI models
- Built-in model database

This is the easiest way for remote servers!

### Option 2: Manual Download (Advanced)

ComfyUI supports many model types. Download via SSH:

**Stable Diffusion 1.5** (already installed):
```bash
cd ~/ComfyUI/models/checkpoints
# Already have: v1-5-pruned-emaonly.safetensors
```

**SDXL (Stable Diffusion XL):**
```bash
cd ~/ComfyUI/models/checkpoints
wget https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors
```

**From CivitAI:**
```bash
cd ~/ComfyUI/models/checkpoints
# Get download link from civitai.com, then:
wget -O model_name.safetensors "your_download_link"
```

### LoRA Models

Add LoRAs for style/character control:
```bash
mkdir -p ~/ComfyUI/models/loras
cd ~/ComfyUI/models/loras
# Browse: https://civitai.com/models?types=LORA
```

### VAE (Image Quality)

```bash
mkdir -p ~/ComfyUI/models/vae
cd ~/ComfyUI/models/vae
wget https://huggingface.co/stabilityai/sd-vae-ft-mse-original/resolve/main/vae-ft-mse-840000-ema-pruned.safetensors
```

### Upscalers

```bash
mkdir -p ~/ComfyUI/models/upscale_models
cd ~/ComfyUI/models/upscale_models
# Download RealESRGAN, ESRGAN, etc.
```

## Model Directory Structure

```
~/ComfyUI/models/
├── checkpoints/        # Base Stable Diffusion models
├── loras/             # LoRA models
├── vae/               # VAE models
├── upscale_models/    # Upscalers (RealESRGAN, etc.)
├── controlnet/        # ControlNet models
├── embeddings/        # Textual inversions
└── clip/              # CLIP models
```

## Example Workflows

### Basic Text-to-Image

1. Load default workflow
2. Set checkpoint to "v1-5-pruned-emaonly.safetensors"
3. Enter prompt: "a beautiful sunset over mountains, highly detailed"
4. Set negative prompt: "blurry, low quality"
5. Click "Queue Prompt"

### Image-to-Image

1. Add "Load Image" node
2. Upload your image
3. Connect to VAE Encode
4. Connect to KSampler
5. Lower denoise to 0.5-0.7
6. Generate

### High Resolution

1. Generate base image (512x512)
2. Add "Upscale Image" node
3. Add another KSampler with lower denoise (0.4)
4. Generate high-res image

## Custom Nodes

### Using ComfyUI-Manager (Easiest)

ComfyUI-Manager is already installed! Install custom nodes via the UI:

1. Click **"Manager"** button
2. Click **"Install Custom Nodes"**
3. Search for the node you want
4. Click **"Install"**
5. Click **"Restart"** when prompted

**Popular custom nodes:**
- ComfyUI-Impact-Pack - Advanced features
- ComfyUI-AnimateDiff - Animation support
- ComfyUI-ControlNet-Aux - ControlNet preprocessors
- ComfyUI-VideoHelperSuite - Video generation

### Manual Installation (Alternative)

```bash
cd ~/ComfyUI/custom_nodes
git clone https://github.com/[custom-node-repo]
cd ~/ComfyUI
pip install -r custom_nodes/[node-name]/requirements.txt
sudo systemctl restart comfyui
```

## GPU Memory Tips

**For 8GB VRAM:**
- Use SD 1.5 (not SDXL)
- Keep resolution at 512x512
- Use lower batch sizes

**For 12GB+ VRAM:**
- Can use SDXL
- Generate up to 768x768
- Use batch processing

**For 24GB+ VRAM:**
- Full SDXL with refiner
- Generate 1024x1024+
- Multiple images in batch

## Performance Tips

1. **Use FP16:** Most models work fine with FP16 precision
2. **Enable xformers:** Faster attention (usually auto-enabled)
3. **Lower steps:** 20-30 steps usually sufficient
4. **Batch images:** Generate multiple at once
5. **Keep models on disk:** Don't load too many models simultaneously

## Troubleshooting

**Out of memory:**
- Lower resolution
- Use SD 1.5 instead of SDXL
- Close other GPU applications
- Restart: `sudo systemctl restart comfyui`

**Service won't start:**
```bash
sudo journalctl -u comfyui -n 50
# Check for Python errors
```

**Black/green images:**
- Update VAE
- Check model compatibility
- Verify GPU drivers

**Slow generation:**
- Verify GPU is being used: `nvidia-smi`
- Check CUDA is available
- Lower image resolution

**Can't access UI:**
- Check service: `sudo systemctl status comfyui`
- Check port: `lsof -i :8188`
- View logs: `sudo journalctl -u comfyui -f`

## Python API

Use ComfyUI programmatically:

```python
import requests
import json

# Queue a prompt
workflow = {
    # Your workflow JSON here
}

response = requests.post(
    "http://localhost:8188/prompt",
    json={"prompt": workflow}
)

prompt_id = response.json()["prompt_id"]
print(f"Queued: {prompt_id}")
```

## Update ComfyUI

```bash
cd ~/ComfyUI
git pull
source venv/bin/activate
pip install -r requirements.txt
sudo systemctl restart comfyui
```

## Uninstall

```bash
sudo systemctl stop comfyui
sudo systemctl disable comfyui
sudo rm /etc/systemd/system/comfyui.service
rm -rf ~/ComfyUI
```

## Resources

- **GitHub:** https://github.com/comfyanonymous/ComfyUI
- **Examples:** https://comfyanonymous.github.io/ComfyUI_examples/
- **Models:** https://civitai.com/
- **Reddit:** https://www.reddit.com/r/StableDiffusion/
- **Discord:** https://discord.gg/comfyui

## Keyboard Shortcuts

- **Ctrl + Enter:** Queue prompt
- **Ctrl + Shift + Enter:** Queue prompt (front of queue)
- **Ctrl + Z:** Undo
- **Ctrl + Y:** Redo
- **Delete:** Delete selected nodes
- **Ctrl + C/V:** Copy/paste nodes
- **Space + Drag:** Pan canvas
- **Scroll:** Zoom canvas

## Common Samplers

- **DPM++ 2M Karras:** Good default, fast
- **Euler a:** Fast, good for SD 1.5
- **DPM++ SDE Karras:** High quality, slower
- **DDIM:** Consistent results
- **UniPC:** Fast, good quality

Start with 20-30 steps for most samplers.

## Popular Model Sources

- **Hugging Face:** https://huggingface.co/models?pipeline_tag=text-to-image
- **Civitai:** https://civitai.com/models (largest community)
- **Stability AI:** Official models
- **RunDiffusion:** Curated models

