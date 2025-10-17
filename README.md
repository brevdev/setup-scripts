# Brev Setup Scripts

> **Stop wasting time on environment setup. Start shipping code.**

## The Problem

You've been there. A new developer joins your team. They spend the first 3 days:
- Installing dependencies (wrong versions)
- Setting up databases (different config than production)
- Fighting with Python virtual environments
- Debugging "works on my machine" issues
- Following a 47-step onboarding doc that's 6 months out of date

Or maybe you're working on a side project. You need to spin up a GPU instance, but first you need to spend 30 minutes installing CUDA, PyTorch, and all your ML dependencies. Then you do it again next week when you need a different GPU.

**This sucks. Brev fixes it.**

## The Solution: Infrastructure + Environment as Code

Brev gives you instant access to powerful cloud hardware (GPUs, CPUs, whatever you need) with your development environment automatically configured. No manual setup. No "works on my machine." Just:

```bash
brev start https://github.com/your-org/your-project
# Coffee break ☕
# Come back to a fully configured dev environment, ready to code
```

Setup scripts are how you define "what does ready to code mean" for your project. They're bash scripts that run once when your environment spins up, installing dependencies and configuring everything automatically.

## Why This Matters

**For Individual Developers:**
- Spin up new environments quickly, not spending hours on setup
- Experiment fearlessly - break something? `brev reset` and you're back to working
- Work on multiple projects without dependency conflicts
- Access GPUs/powerful hardware without the setup headache

**For Teams:**
- New developers productive on day one, not day three
- Everyone has identical environments - no more "works on my machine"
- Environment changes are code-reviewed and version-controlled
- Onboarding is automatic

**Real Example:** A data science team reduced new hire onboarding from days to a single automated process. Their setup script installs Python, CUDA, PyTorch, downloads their models, and configures their data pipelines. Every single time. Perfectly.

## Quick Start: Your First Setup Script

The simplest way is to add a `.brev/setup.sh` file to your repo. Here's a complete example for a Node.js project:

```bash
#!/bin/bash
set -euo pipefail

# Install Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install dependencies
npm install

# Copy environment template
cp .env.example .env

echo "✅ Setup complete! Ready to code."
```

That's it. Commit this to your repo as `.brev/setup.sh`, then:

```bash
brev start https://github.com/your-org/your-repo
```

Brev will automatically detect and run your setup script. When it's done, you have a fully configured development environment.

### Other Ways to Use Setup Scripts

**Use a Gist or external URL:**
```bash
brev start https://github.com/your-org/your-repo \
  --setup-script https://gist.githubusercontent.com/you/abc123/raw/setup.sh
```

**Share setup scripts across multiple projects:**
```bash
# Store setup scripts in a dedicated repo, use across many projects
brev start https://github.com/your-org/your-repo \
  --setup-repo https://github.com/your-org/setup-scripts \
  --setup-path .brev/setup.sh
```

**Personal setup scripts:** Configure setup scripts that run on ALL your workspaces via the Brev Console (Account Settings → Terminal Settings). Great for shell customizations, personal tools, and dotfiles.

## Common Workflows

**Start a workspace (defaults to T4 GPU):**
```bash
brev start https://github.com/your-org/your-repo
```

**Specify GPU type:**
```bash
# L4 GPU (good price/performance for inference)
brev start https://github.com/your-org/your-repo --gpu g2-standard-4

# A100 GPU (for serious training)
brev start https://github.com/your-org/your-repo --gpu a2-highgpu-1g

# V100 GPU (older but reliable)
brev start https://github.com/your-org/your-repo --gpu p3.2xlarge

# CPU-only instance (cheaper for non-ML work)
brev start https://github.com/your-org/your-repo --cpu 4x16
```

**Common GPU Options:**
| GPU Type | Instance | Use Case | 
|----------|----------|----------|
| **T4** (default) | `n1-highmem-4:nvidia-tesla-t4:1` | Light ML, development, prototyping |
| **L4** | `g2-standard-4` to `g2-standard-96` | Cost-effective inference, Stable Diffusion |
| **A10** | `gpu_1x_a10` | Good balance for training & inference |
| **V100** | `p3.2xlarge` to `p3.16xlarge` | Training, established workflows |
| **A100** | `a2-highgpu-1g` to `a2-megagpu-16g` | LLM training, large models |
| **A10G** | `g5.xlarge` to `g5.48xlarge` | AWS regions, ML inference |

**CPU Options:**
- `2x8` - 2 vCPU, 8GB RAM (default)
- `4x16` - 4 vCPU, 16GB RAM
- `8x32` - 8 vCPU, 32GB RAM

For the full list of 300+ GPU/CPU combinations, see: https://brev.dev/docs/reference/gpu

**Start from your current directory:**
```bash
cd your-project/
brev start .  # Automatically finds .brev/setup.sh
```

**Name your workspace:**
```bash
brev start https://github.com/your-org/your-repo --name my-experiment
```

**Experimenting? Reset your environment:**
```bash
# Made a mess? No problem. Reset re-runs your setup script on a fresh environment
brev reset my-workspace
```

**Create fresh environment:**
```bash
# Sometimes you just want to start from scratch
brev recreate my-workspace
```

## Real-World Examples

These aren't toy examples - they're battle-tested setups used by real teams. Copy, modify, and use them.

### Web App (Node.js + TypeScript)

Perfect for frontend/backend projects. Sets up Node 18, Yarn, installs dependencies, and creates your `.env` file.

```bash
#!/bin/bash
set -euo pipefail

# Install Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install Yarn  
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo apt update && sudo apt install -y yarn

# Install dependencies and setup environment
npm install
cp .env.example .env

echo "✅ Ready to code!"
```

### ML/Data Science (Python + PyTorch + Jupyter)

Spin up a GPU instance with PyTorch, CUDA, and Jupyter ready to go. No more manual CUDA installation ever again.

```bash
#!/bin/bash
set -euo pipefail

# Install Python tooling
sudo apt-get update
sudo apt-get install -y python3-pip python3-venv

# Install Poetry for dependency management
curl -sSL https://install.python-poetry.org | python3 -
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
export PATH="$HOME/.local/bin:$PATH"

# Install project dependencies (includes PyTorch with CUDA)
poetry install

# Install Jupyter
pip3 install jupyter jupyterlab

echo "✅ ML environment ready! Run 'jupyter lab' to start."
```

### Go Microservice

Sets up Go 1.21, common Go tools (gopls, golangci-lint), and downloads your dependencies.

```bash
#!/bin/bash
set -euo pipefail

# Install Go 1.21
GO_VERSION="1.21.0"
wget "https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz"
rm "go${GO_VERSION}.linux-amd64.tar.gz"

# Setup Go environment
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
echo 'export GOPATH=$HOME/go' >> ~/.bashrc
echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.bashrc
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
export GOPATH=$HOME/go

# Install development tools
go install golang.org/x/tools/gopls@latest
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

# Download dependencies
go mod download

echo "✅ Go environment ready!"
```

### Full-Stack App (Node + Python + PostgreSQL + Redis)

The "everything" setup - perfect for complex applications. Frontend, backend, database, cache, all configured.

```bash
#!/bin/bash
set -euo pipefail

# Install Node.js for frontend
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install Python for backend
sudo apt-get install -y python3-pip python3-venv

# Install and start PostgreSQL
sudo apt-get install -y postgresql postgresql-contrib
sudo systemctl start postgresql
sudo -u postgres createdb myapp_dev

# Install and start Redis
sudo apt-get install -y redis-server
sudo systemctl start redis-server

# Setup frontend
cd frontend && npm install && cd ..

# Setup backend
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cd ..

# Create environment file
cp .env.example .env

echo "✅ Full stack ready!"
echo "Frontend: cd frontend && npm start"
echo "Backend: cd backend && source venv/bin/activate && python manage.py runserver"
```

### More Examples

**Rust:**
```bash
#!/bin/bash
set -euo pipefail

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"
echo 'source "$HOME/.cargo/env"' >> ~/.bashrc

# Install tools
cargo install cargo-watch cargo-edit
rustup component add rustfmt clippy

cargo build
echo "✅ Rust environment ready!"
```

**Docker:**
```bash
#!/bin/bash
set -euo pipefail

# Install Docker
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker $USER

# Start your containers
sg docker -c "docker-compose up -d"

echo "✅ Docker ready!"
```

## Writing Good Setup Scripts

**Start with error handling:**
```bash
#!/bin/bash
set -euo pipefail  # Exit on error, undefined variables, or pipe failures
```

**Always use `-y` for non-interactive installs:**
```bash
sudo apt-get install -y nodejs  # No prompts
```

**Pin versions for reproducibility:**
```bash
GO_VERSION="1.21.0"  # Explicit versions, not "latest"
```

**Update PATH for both bash and zsh:**
```bash
echo 'export PATH=$PATH:/usr/local/bin' >> ~/.bashrc
echo 'export PATH=$PATH:/usr/local/bin' >> ~/.zshrc
```

**Don't run long-running processes:**
```bash
# ❌ Don't do this - will hang forever
npm start

# ✅ Do this instead - install and exit
npm install
```

**Check the logs if something breaks:**
```bash
cat .brev/logs/setup.log
```

## Troubleshooting

**Script not running?**
- Make sure `.brev/setup.sh` exists in your repo
- Check it's executable: `chmod +x .brev/setup.sh`
- Check logs: `cat .brev/logs/setup.log`

**Workspace stuck in "Starting" state?**
- Your script is probably running a long-running process (`npm start`, `jupyter notebook`, etc.)
- Setup scripts should install and configure, not run servers
- Remove any commands that don't exit

**Dependencies not found after setup?**
- Did you update both `.bashrc` and `.zshrc`?
- Try: `source ~/.bashrc && source ~/.zshrc`
- Make sure you're exporting variables: `export PATH=$PATH:/new/path`

**Permission errors?**
- Use `sudo` for system packages: `sudo apt-get install -y nodejs`
- Don't use `sudo` for user packages: `npm install` (not `sudo npm install`)
- Don't use `sudo` for pip: `pip3 install --user package`

## How Brev Uses Setup Scripts Internally

When you run `brev start`:
1. Brev spins up your chosen hardware (GPU/CPU)
2. Clones your git repository
3. Runs your setup script from the project directory
4. Captures all output to `.brev/logs/setup.log`
5. Marks workspace as "Ready" when script exits successfully

**Technical Details:**
- Working directory: `/home/ubuntu/<your-project>/` (or `/home/nvidia/`, etc.)
- Runs as the instance user, not root
- Executes after git clone, before marking instance ready
- Setup script failures will mark the workspace as "Failed"

## Need Help?

- [Brev Discord](https://discord.gg/NVDyv7TUgJ) - Ask questions, share your setup scripts
- [Brev Docs](https://docs.brev.dev) - Full documentation
- [GitHub Issues](https://github.com/brevdev/brev-cli/issues) - Report bugs

---

**tl;dr:** Create `.brev/setup.sh` in your repo, install your dependencies, commit it, and `brev start` will give you a ready-to-code environment automatically. Stop wasting time on setup. Start building.

