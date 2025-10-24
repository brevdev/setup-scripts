#!/bin/bash
set -e

# Detect Brev user (handles ubuntu, nvidia, shadeform, etc.)
detect_brev_user() {
    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
        echo "$SUDO_USER"
        return
    fi
    # Check for Brev-specific markers
    for user_home in /home/*; do
        username=$(basename "$user_home")
        [ "$username" = "launchpad" ] && continue
        if ls "$user_home"/.lifecycle-script-ls-*.log 2>/dev/null | grep -q . || \
           [ -f "$user_home/.verb-setup.log" ] || \
           { [ -L "$user_home/.cache" ] && [ "$(readlink "$user_home/.cache")" = "/ephemeral/cache" ]; }; then
            echo "$username"
            return
        fi
    done
    # Fallback to common users
    [ -d "/home/nvidia" ] && echo "nvidia" && return
    [ -d "/home/ubuntu" ] && echo "ubuntu" && return
    echo "ubuntu"
}

# Set USER and HOME if running as root
if [ "$(id -u)" -eq 0 ] || [ "${USER:-}" = "root" ]; then
    DETECTED_USER=$(detect_brev_user)
    export USER="$DETECTED_USER"
    export HOME="/home/$DETECTED_USER"
fi

echo "🐍 Setting up Python development environment..."
echo "User: $USER | Home: $HOME"

# Install pyenv dependencies
sudo apt-get update -qq
sudo apt-get install -y -qq build-essential libssl-dev zlib1g-dev \
  libbz2-dev libreadline-dev libsqlite3-dev curl \
  libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev

# Install pyenv if not already installed
if [ ! -d "$HOME/.pyenv" ]; then
    echo "Installing pyenv..."
    if [ "$(id -u)" -eq 0 ]; then
        # Install pyenv as the user, not as root
        sudo -H -u $USER bash -c "curl https://pyenv.run | bash"
    else
        curl https://pyenv.run | bash
    fi
else
    echo "pyenv already installed, skipping..."
fi

# Add to bashrc if not already there
if ! grep -q "PYENV_ROOT" "$HOME/.bashrc" 2>/dev/null; then
    echo "Adding pyenv to .bashrc..."
    cat >> "$HOME/.bashrc" << 'EOF'

# pyenv configuration
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
EOF
    
    # Fix permissions if running as root
    if [ "$(id -u)" -eq 0 ]; then
        chown $USER:$USER "$HOME/.bashrc"
    fi
else
    echo "pyenv already in .bashrc, skipping..."
fi

# Install Python 3.11 if not already installed (as the user)
if [ "$(id -u)" -eq 0 ]; then
    # Check if Python 3.11 is installed
    if ! sudo -H -u $USER bash -c "export PYENV_ROOT=$HOME/.pyenv && export PATH=\$PYENV_ROOT/bin:\$PATH && eval \"\$(pyenv init -)\" && pyenv versions | grep -q '3.11'"; then
        echo "Installing Python 3.11..."
        sudo -H -u $USER bash -c "export PYENV_ROOT=$HOME/.pyenv && export PATH=\$PYENV_ROOT/bin:\$PATH && eval \"\$(pyenv init -)\" && pyenv install 3.11"
    else
        echo "Python 3.11 already installed, skipping..."
    fi
    # Set global Python version
    sudo -H -u $USER bash -c "export PYENV_ROOT=$HOME/.pyenv && export PATH=\$PYENV_ROOT/bin:\$PATH && eval \"\$(pyenv init -)\" && pyenv global 3.11"
else
    # Running as user - load pyenv for this session
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
    
    if ! pyenv versions | grep -q "3.11"; then
        echo "Installing Python 3.11..."
        pyenv install 3.11
    else
        echo "Python 3.11 already installed, skipping..."
    fi
    pyenv global 3.11
fi

# Install common tools (running as the correct user)
echo "Installing common packages..."
if [ "$(id -u)" -eq 0 ]; then
    sudo -H -u $USER bash -c "export PYENV_ROOT=$HOME/.pyenv && export PATH=\$PYENV_ROOT/bin:\$PATH && eval \"\$(pyenv init -)\" && pip install --upgrade pip"
    sudo -H -u $USER bash -c "export PYENV_ROOT=$HOME/.pyenv && export PATH=\$PYENV_ROOT/bin:\$PATH && eval \"\$(pyenv init -)\" && pip install ipython"
else
    pip install --upgrade pip
    pip install ipython
fi

# Install Jupyter if not already installed (Brev often pre-installs it)
if ! command -v jupyter &> /dev/null; then
    echo "Installing Jupyter Lab..."
    if [ "$(id -u)" -eq 0 ]; then
        sudo -H -u $USER bash -c "export PYENV_ROOT=$HOME/.pyenv && export PATH=\$PYENV_ROOT/bin:\$PATH && eval \"\$(pyenv init -)\" && pip install jupyter jupyterlab"
    else
        pip install jupyter jupyterlab
    fi
else
    echo "Jupyter already installed, skipping..."
fi

if [ "$(id -u)" -eq 0 ]; then
    sudo -H -u $USER bash -c "export PYENV_ROOT=$HOME/.pyenv && export PATH=\$PYENV_ROOT/bin:\$PATH && eval \"\$(pyenv init -)\" && pip install requests pandas numpy matplotlib seaborn plotly"
    sudo -H -u $USER bash -c "export PYENV_ROOT=$HOME/.pyenv && export PATH=\$PYENV_ROOT/bin:\$PATH && eval \"\$(pyenv init -)\" && pip install ruff black pytest mypy"
else
    pip install requests pandas numpy matplotlib seaborn plotly
    pip install ruff black pytest mypy
fi

# Verify
echo ""
echo "Verifying installation..."
if [ "$(id -u)" -eq 0 ]; then
    sudo -H -u $USER bash -c "export PYENV_ROOT=$HOME/.pyenv && export PATH=\$PYENV_ROOT/bin:\$PATH && eval \"\$(pyenv init -)\" && python --version"
    sudo -H -u $USER bash -c "export PYENV_ROOT=$HOME/.pyenv && export PATH=\$PYENV_ROOT/bin:\$PATH && eval \"\$(pyenv init -)\" && jupyter --version"
    sudo -H -u $USER bash -c "export PYENV_ROOT=$HOME/.pyenv && export PATH=\$PYENV_ROOT/bin:\$PATH && eval \"\$(pyenv init -)\" && ipython --version"
else
    python --version
    jupyter --version
    ipython --version
fi

echo ""
echo "✅ Python dev environment ready!"
echo ""
echo "Quick start:"
echo "  python --version"
echo "  ipython"
echo ""

# Check if Jupyter is already running
if lsof -i :8888 >/dev/null 2>&1 || pgrep -f "jupyter.*lab" >/dev/null 2>&1; then
    echo "💡 Jupyter Lab is already running on this instance!"
    echo "   Access it via your Brev URL (port 8888 should already be open)"
else
    echo "Start Jupyter Lab:"
    echo "  jupyter lab --ip=0.0.0.0 --port=8888"
    echo ""
    echo "⚠️  To access Jupyter from outside Brev, open port: 8888/tcp"
fi

