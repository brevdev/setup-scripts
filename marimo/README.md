# Marimo Notebook Server

Interactive notebook server with Marimo - a reactive Python notebook.

## What it installs

- **Python 3** & **pip** - If not already installed
- **Marimo** - Reactive Python notebooks
- **Brev GPU notebooks** - GPU validation, multi-GPU training, etc. (always included)
- **Marimo examples** - Sample notebooks from marimo-team/examples (customizable)
- **PyTorch with CUDA** - GPU-accelerated machine learning
- **Data science packages** - pandas, numpy, scikit-learn, plotly, etc.

## Features

- **Runs as systemd service** - Auto-starts with the system
- **Accessible via web** - Default port 8080
- **Example notebooks included** - Ready to explore
- **Battle-tested user detection** - Works with ubuntu, nvidia, shadeform users

## ⚠️ Required Port

To access from outside Brev, open:
- **8080/tcp** (default marimo port)

## Usage

```bash
bash setup.sh
```

Takes ~2-3 minutes.

## Configuration

**Use your own notebook repository (merges with Brev notebooks):**
```bash
MARIMO_REPO_URL="https://github.com/your-org/your-notebooks.git" bash setup.sh
```

**Skip cloning marimo-team examples (still includes Brev notebooks):**
```bash
MARIMO_REPO_URL="" bash setup.sh
```

**Custom notebooks directory:**
```bash
MARIMO_NOTEBOOKS_DIR="my-notebooks" bash setup.sh
```

**Note:** Brev GPU notebooks from [brevdev/marimo](https://github.com/brevdev/marimo) are **always** included and merged into your notebooks directory.

## What you get

```bash
# Service management
sudo systemctl status marimo
sudo systemctl restart marimo
sudo systemctl stop marimo

# View logs
sudo journalctl -u marimo -f

# Access notebooks
http://localhost:8080
# Or via Brev URL
```

## Example notebooks

### Brev GPU Notebooks (always included)

From [brevdev/marimo](https://github.com/brevdev/marimo):
- **gpu_validation.py** - GPU testing, metrics, stress testing
- **multi_gpu_training.py** - Multi-GPU training examples
- **llm_finetuning_dashboard.py** - LLM fine-tuning with monitoring
- **graph_analytics_cugraph.py** - GPU-accelerated graph analytics
- **nerf_training_viewer.py** - NeRF training visualization

### Marimo Team Examples (optional, included by default)

From [marimo-team/examples](https://github.com/marimo-team/examples):
- Data visualization examples
- Interactive widgets
- Machine learning demos
- And more!

## Advanced

**Change the port:**
Edit `/etc/systemd/system/marimo.service` and change `--port 8080` to your desired port, then:
```bash
sudo systemctl daemon-reload
sudo systemctl restart marimo
```

**Add more notebooks:**
```bash
cd ~/marimo-examples  # Or your custom directory
git pull  # Update examples
# Or add your own .py files
```

## Troubleshooting

**Service won't start:**
```bash
sudo journalctl -u marimo -n 50  # View recent logs
sudo systemctl status marimo      # Check status
```

**Can't access web UI:**
- Check service is running: `sudo systemctl status marimo`
- Check firewall: `sudo ufw status`
- Try: `http://localhost:8080` or your Brev instance URL

**Marimo not found:**
```bash
pipx list                     # Check if installed
pipx install marimo           # Reinstall if needed
```

