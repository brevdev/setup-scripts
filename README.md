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
**Note:** Log out and back in after running

### ☸️ Local Kubernetes
```bash
cd k8s-local && bash setup.sh
```
**Installs:** microk8s, helm, GPU operator, k9s  
**Time:** ~3-5 minutes  
**Note:** Log out and back in after running

### 🤖 ML Quickstart
```bash
cd ml-quickstart && bash setup.sh
```
**Installs:** Miniconda, PyTorch with CUDA, Jupyter Lab, transformers  
**Time:** ~5-8 minutes (PyTorch is large)

### 🗄️ Databases
```bash
cd databases && bash setup.sh
```
**Installs:** PostgreSQL 16, Redis 7 (in Docker containers)  
**Time:** ~1-2 minutes

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

**Modern terminal:**
```bash
cd terminal-setup && bash setup.sh
# Log out and back in, then:
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
└── databases/
    ├── setup.sh                 # PostgreSQL + Redis
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
