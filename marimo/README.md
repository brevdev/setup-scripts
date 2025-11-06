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
- **Secure by default** - Bound to localhost with token authentication
- **Example notebooks included** - Ready to explore
- **Battle-tested user detection** - Works with ubuntu, nvidia, shadeform users

## 🔒 Security

- **Localhost binding** - Service is bound to `127.0.0.1` only (not exposed to network)
- **Token authentication** - Cryptographically secure token required for access
- **Secure token storage** - Token stored in `~/.config/marimo/token` with restricted permissions (600)

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


# View authentication token
cat ~/.config/marimo/token
```

## Access & Authentication

### Local Access

The service is bound to `localhost` (127.0.0.1) for security. Access it locally:

```bash
# Open in browser on the server
http://localhost:8080
```

You'll be prompted for the authentication token. Retrieve it with:

```bash
cat ~/.config/marimo/token
```

### Remote Access via SSH Port Forwarding

For secure remote access, use SSH port forwarding:

```bash
# From your local machine
ssh -L 8080:localhost:8080 user@your-server

# Then access in your local browser
http://localhost:8080
```

The token is still required for authentication.

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
Edit `/etc/systemd/system/marimo.service` and change `MARIMO_PORT` environment variable, then:
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
- Access locally: `http://localhost:8080`
- For remote access, use SSH port forwarding (see above)

**Authentication token not working:**
- Verify token file exists: `ls -la ~/.config/marimo/token`
- Check token permissions: `chmod 600 ~/.config/marimo/token`
- View token: `cat ~/.config/marimo/token`
- Restart service: `sudo systemctl restart marimo`

**Marimo not found:**
```bash
pipx list                     # Check if installed
pipx install marimo           # Reinstall if needed
```
