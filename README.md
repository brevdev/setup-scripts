# Brev Setup Scripts

Simple, practical setup scripts for common developer environments.

**What Brev already provides:** NVIDIA drivers, CUDA toolkit, Docker, NVIDIA Container Toolkit

## Available Scripts

### 🐍 Python Development
```bash
cd python-dev && bash setup.sh
```
**Installs:** pyenv, Python 3.11, Jupyter Lab, common packages (pandas, numpy, matplotlib)  
**Time:** ~3-5 minutes

### 📦 Node.js Development
```bash
cd nodejs-dev && bash setup.sh
```
**Installs:** nvm, Node LTS, pnpm, TypeScript, ESLint, Prettier  
**Time:** ~2-3 minutes

### 💻 Terminal Setup
```bash
cd terminal-setup && bash setup.sh
```
**Installs:** zsh, oh-my-zsh, fzf, ripgrep, bat, eza (modern CLI tools)  
**Time:** ~2-3 minutes  
**Note:** Automatically switches to zsh when complete

### ☸️ Local Kubernetes
```bash
cd k8s-local && bash setup.sh
```
**Installs:** microk8s, helm, GPU operator, k9s, kubectl  
**Time:** ~3-5 minutes  
**Note:** kubectl works immediately via ~/.kube/config

### 🤖 ML Quickstart
```bash
cd ml-quickstart && bash setup.sh
```
**Installs:** Miniconda, PyTorch with CUDA, Jupyter Lab, transformers  
**Time:** ~5-8 minutes (PyTorch is large)

### 🦙 Ollama
```bash
cd ollama && bash setup.sh
```
**Installs:** Ollama with GPU support, llama3.2 model (pre-downloaded)  
**Time:** ~3-5 minutes  
**Port:** 11434/tcp for API access

### 🚀 Unsloth
```bash
cd unsloth && bash setup.sh
```
**Installs:** Unsloth for fast fine-tuning, PyTorch with CUDA, LoRA/QLoRA support  
**Time:** ~5-8 minutes  
**Note:** Requires NVIDIA GPU

### 🔄 LiteLLM
```bash
cd litellm && bash setup.sh
```
**Installs:** Universal LLM proxy (use any LLM with OpenAI API format)  
**Time:** ~1-2 minutes  
**Port:** 4000/tcp for API access

### 🔍 Qdrant
```bash
cd qdrant && bash setup.sh
```
**Installs:** Vector database for RAG and semantic search  
**Time:** ~1-2 minutes  
**Port:** 6333/tcp for API + dashboard

### 🎨 ComfyUI
```bash
cd comfyui && bash setup.sh
```
**Installs:** Node-based UI for Stable Diffusion, SD 1.5 model  
**Time:** ~5-10 minutes  
**Port:** 8188/tcp for web interface  
**Note:** Requires NVIDIA GPU

### 🗄️ Databases
```bash
cd databases && bash setup.sh
```
**Installs:** PostgreSQL 16, Redis 7 (in Docker containers)  
**Time:** ~1-2 minutes

### 📓 Marimo
```bash
cd marimo && bash setup.sh
```
**Installs:** Marimo reactive notebooks as systemd service  
**Time:** ~2-3 minutes  
**Port:** 8080/tcp for web access

## Quick Start

**Pick what you need:**

```bash
# Python ML developer
cd ml-quickstart && bash setup.sh

# Web developer
cd nodejs-dev && bash setup.sh
cd databases && bash setup.sh

# Terminal power user
cd terminal-setup && bash setup.sh

# Kubernetes developer
cd k8s-local && bash setup.sh
```

**Use with Brev CLI:**

```bash
# Start workspace with Python setup
brev start my-workspace \
  --setup-script https://raw.githubusercontent.com/brevdev/setup-scripts/main/python-dev/setup.sh

# Start workspace with ML setup
brev start my-ml-workspace \
  --gpu g5.xlarge \
  --setup-script https://raw.githubusercontent.com/brevdev/setup-scripts/main/ml-quickstart/setup.sh
```

## Design Philosophy

Each script is:
- ✅ **Simple** - One purpose, no complexity
- ✅ **Short** - Under 150 lines each
- ✅ **Fast** - Takes 2-8 minutes
- ✅ **Standalone** - No dependencies between scripts
- ✅ **Practical** - Installs what developers actually use

We don't:
- ❌ Install what Brev already provides (NVIDIA drivers, CUDA, Docker)
- ❌ Add complex GPU detection logic
- ❌ Support multi-node/HPC scenarios
- ❌ Over-engineer solutions

## Examples

**Python data science:**
```bash
cd python-dev && bash setup.sh
# Then:
ipython
jupyter lab --ip=0.0.0.0
```

**Machine learning with GPU:**
```bash
cd ml-quickstart && bash setup.sh
# Then:
conda activate ml
python gpu_check.py
```

**Local LLM with Ollama:**
```bash
cd ollama && bash setup.sh
# Then:
ollama run llama3.2
ollama list
```

**Fast LLM fine-tuning with Unsloth:**
```bash
cd unsloth && bash setup.sh
# Then:
conda activate unsloth
python ~/unsloth-examples/test_install.py
```

**Universal LLM proxy with LiteLLM:**
```bash
cd litellm && bash setup.sh
# Then use any LLM with OpenAI SDK:
# openai.api_base = "http://localhost:4000"
```

**Vector database with Qdrant:**
```bash
cd qdrant && bash setup.sh
# Then:
pip install qdrant-client
python ~/qdrant_example.py
```

**Image generation with ComfyUI:**
```bash
cd comfyui && bash setup.sh
# Then open: http://localhost:8188
```

**Modern terminal:**
```bash
cd terminal-setup && bash setup.sh
# Automatically drops you into zsh, then:
ll    # Better ls
cat file.txt  # Syntax highlighting
fzf   # Fuzzy finder
```

**Local database:**
```bash
cd databases && bash setup.sh
# Then:
docker exec -it postgres psql -U postgres
docker exec -it redis redis-cli
```

## File Structure

```
brev-setup-scripts/
├── README.md                    # This file
├── python-dev/
│   ├── setup.sh                 # Python development environment
│   └── README.md
├── nodejs-dev/
│   ├── setup.sh                 # Node.js development environment
│   └── README.md
├── terminal-setup/
│   ├── setup.sh                 # Modern terminal with zsh
│   └── README.md
├── k8s-local/
│   ├── setup.sh                 # Local Kubernetes
│   └── README.md
├── ml-quickstart/
│   ├── setup.sh                 # PyTorch ML environment
│   └── README.md
├── ollama/
│   ├── setup.sh                 # Ollama LLM inference
│   └── README.md
├── unsloth/
│   ├── setup.sh                 # Unsloth fast fine-tuning
│   └── README.md
├── litellm/
│   ├── setup.sh                 # Universal LLM proxy
│   └── README.md
├── qdrant/
│   ├── setup.sh                 # Vector database
│   └── README.md
├── comfyui/
│   ├── setup.sh                 # ComfyUI for Stable Diffusion
│   └── README.md
├── databases/
│   ├── setup.sh                 # PostgreSQL + Redis
│   └── README.md
└── marimo/
    ├── setup.sh                 # Marimo reactive notebooks
    └── README.md
```

## Contributing

Want to add a script? Keep it simple:

1. **One purpose** - Install one thing well
2. **Short** - Under 150 lines
3. **Fast** - Completes in < 10 minutes
4. **Verify** - Include a verification step
5. **Document** - Show quick start commands

## License

Apache 2.0
