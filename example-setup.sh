#!/bin/bash

##############################################################################
# Brev Setup Script - Best Practices Example
##############################################################################
# This script demonstrates best practices for Brev setup scripts.
# Copy and modify for your own projects!
#
# Execution context:
#   - Runs ONCE when workspace is created or reset
#   - Working directory: /home/ubuntu/<your-project-name>/
#   - User: ubuntu (or nvidia/shadeform depending on provider)
#   - Logs: .brev/logs/setup.log
##############################################################################

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

##############################################################################
# Helper Functions
##############################################################################

# Print section headers for better log readability
print_section() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
    echo ""
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

##############################################################################
# System Setup
##############################################################################

print_section "Updating system packages"
sudo apt-get update

##############################################################################
# Language/Runtime Installation
##############################################################################

# Example: Install Node.js with specific version
print_section "Installing Node.js 18.x"
if ! command_exists node; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
    echo "✓ Node.js installed: $(node --version)"
else
    echo "✓ Node.js already installed: $(node --version)"
fi

# Example: Install Python packages
print_section "Installing Python dependencies"
if ! command_exists pip3; then
    sudo apt-get install -y python3-pip python3-venv
fi

# Pin versions for reproducibility!
pip3 install --user \
    numpy==1.24.3 \
    pandas==2.0.3 \
    requests==2.31.0

##############################################################################
# Project Dependencies
##############################################################################

print_section "Installing project dependencies"

# For Node projects
if [ -f "package.json" ]; then
    echo "Found package.json, installing npm dependencies..."
    npm install
fi

# For Python projects
if [ -f "requirements.txt" ]; then
    echo "Found requirements.txt, installing pip dependencies..."
    pip3 install --user -r requirements.txt
fi

# For Python projects with Poetry
if [ -f "pyproject.toml" ]; then
    echo "Found pyproject.toml, installing with Poetry..."
    if ! command_exists poetry; then
        curl -sSL https://install.python-poetry.org | python3 -
    fi
    poetry install
fi

##############################################################################
# Environment Configuration
##############################################################################

print_section "Configuring environment"

# Create .env file from template if it exists
if [ -f ".env.example" ] && [ ! -f ".env" ]; then
    echo "Creating .env from .env.example..."
    cp .env.example .env
    echo "✓ .env created (remember to add your secrets!)"
fi

# Update PATH for tools installed in user space
# IMPORTANT: Update both .bashrc and .zshrc for compatibility
update_path() {
    local new_path="$1"
    local bashrc="$HOME/.bashrc"
    local zshrc="$HOME/.zshrc"
    
    # Add to .bashrc if not already present
    if ! grep -q "$new_path" "$bashrc" 2>/dev/null; then
        echo "export PATH=\"$new_path:\$PATH\"" >> "$bashrc"
        echo "✓ Added $new_path to .bashrc"
    fi
    
    # Add to .zshrc if not already present
    if ! grep -q "$new_path" "$zshrc" 2>/dev/null; then
        echo "export PATH=\"$new_path:\$PATH\"" >> "$zshrc"
        echo "✓ Added $new_path to .zshrc"
    fi
}

# Example: Add user pip packages to PATH
update_path "$HOME/.local/bin"

# Export for current session
export PATH="$HOME/.local/bin:$PATH"

##############################################################################
# Database Setup (if needed)
##############################################################################

# Example: Install and start PostgreSQL
# Uncomment if your project needs a database
#
# print_section "Setting up PostgreSQL"
# if ! command_exists psql; then
#     sudo apt-get install -y postgresql postgresql-contrib
#     sudo systemctl start postgresql
#     
#     # Create development database
#     sudo -u postgres createdb myapp_dev || echo "Database already exists"
#     echo "✓ PostgreSQL installed and running"
# fi

##############################################################################
# Additional Tools (Examples)
##############################################################################

# Example: Install Docker (if needed)
# Uncomment if your project uses Docker
#
# print_section "Installing Docker"
# if ! command_exists docker; then
#     curl -fsSL https://get.docker.com -o get-docker.sh
#     sudo sh get-docker.sh
#     sudo usermod -aG docker $USER
#     rm get-docker.sh
#     echo "✓ Docker installed"
#     echo "⚠ Note: You may need to log out and back in for docker group to take effect"
# fi

# Example: Install Rust
# Uncomment if your project uses Rust
#
# print_section "Installing Rust"
# if ! command_exists cargo; then
#     curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
#     source "$HOME/.cargo/env"
#     echo 'source "$HOME/.cargo/env"' >> "$HOME/.bashrc"
#     echo 'source "$HOME/.cargo/env"' >> "$HOME/.zshrc"
#     echo "✓ Rust installed: $(rustc --version)"
# fi

##############################################################################
# GPU/ML-Specific Setup (if needed)
##############################################################################

# Example: Verify CUDA is available (on GPU instances)
# if command_exists nvidia-smi; then
#     print_section "GPU Information"
#     nvidia-smi
#     
#     # Example: Install PyTorch with CUDA support
#     print_section "Installing PyTorch with CUDA"
#     pip3 install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
# fi

##############################################################################
# Verification & Summary
##############################################################################

print_section "Setup Complete!"

# Show installed versions for verification
echo "Installed tools:"
command_exists node && echo "  Node.js: $(node --version)"
command_exists npm && echo "  npm: $(npm --version)"
command_exists python3 && echo "  Python: $(python3 --version)"
command_exists pip3 && echo "  pip: $(pip3 --version)"
command_exists git && echo "  Git: $(git --version)"

echo ""
echo "✅ Environment setup complete!"
echo ""
echo "Next steps:"
echo "  - Check .env file and add your secrets"
echo "  - Review .brev/logs/setup.log if you encountered any issues"
echo "  - Start coding! 🚀"
echo ""

##############################################################################
# Common Patterns & Tips
##############################################################################
#
# 1. VERSION PINNING
#    Always specify exact versions for reproducibility:
#    ✓ npm install express@4.18.2
#    ✗ npm install express
#
# 2. IDEMPOTENCY
#    Check if things are already installed before installing:
#    if ! command_exists tool; then
#        install_tool
#    fi
#
# 3. ERROR HANDLING
#    Use set -euo pipefail at the top
#    Script will exit on any error
#
# 4. NON-INTERACTIVE
#    Always use -y flags for apt-get, npm, etc.
#    sudo apt-get install -y nodejs
#
# 5. PATH UPDATES
#    Update both .bashrc AND .zshrc
#    Export for current session too
#
# 6. LOGGING
#    Use echo statements liberally
#    Output goes to .brev/logs/setup.log
#
# 7. DON'T RUN SERVERS
#    ✗ npm start
#    ✗ python manage.py runserver
#    ✗ jupyter notebook
#    These will hang the setup process!
#
# 8. CONDITIONAL SETUP
#    Check for files before running setup:
#    if [ -f "package.json" ]; then npm install; fi
#
##############################################################################

