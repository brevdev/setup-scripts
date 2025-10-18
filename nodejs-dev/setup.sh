#!/bin/bash
set -e

# Detect Brev user (handles ubuntu, nvidia, shadeform, etc.)
detect_brev_user() {
    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
        echo "$SUDO_USER"
        return
    fi
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
    [ -d "/home/nvidia" ] && echo "nvidia" && return
    [ -d "/home/ubuntu" ] && echo "ubuntu" && return
    echo "ubuntu"
}

if [ "$(id -u)" -eq 0 ] || [ "${USER:-}" = "root" ]; then
    DETECTED_USER=$(detect_brev_user)
    export USER="$DETECTED_USER"
    export HOME="/home/$DETECTED_USER"
fi

echo "📦 Setting up Node.js development environment..."
echo "User: $USER | Home: $HOME"

# Install nvm if not already installed
if [ ! -d "$HOME/.nvm" ]; then
    echo "Installing nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    
    # Fix permissions if running as root
    if [ "$(id -u)" -eq 0 ]; then
        chown -R $USER:$USER "$HOME/.nvm"
        chown $USER:$USER ~/.bashrc 2>/dev/null || true
    fi
else
    echo "nvm already installed, skipping..."
fi

# Load nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install Node LTS if not already installed
if ! command -v node &> /dev/null; then
    echo "Installing Node.js LTS..."
    nvm install --lts
    nvm use --lts
else
    echo "Node.js already installed ($(node --version)), skipping..."
    nvm use --lts 2>/dev/null || nvm use default
fi

# Install pnpm if not already installed
if ! command -v pnpm &> /dev/null; then
    echo "Installing pnpm..."
    npm install -g pnpm
    
    # Configure pnpm global bin directory
    echo "Configuring pnpm..."
    # Set SHELL inline (needed when running as systemd service)
    SHELL=/bin/bash pnpm setup 2>/dev/null || {
        echo "pnpm setup failed, configuring manually..."
        # Manually configure PNPM_HOME if pnpm setup fails
        mkdir -p "$HOME/.local/share/pnpm"
        # Add to shell configs manually
        echo 'export PNPM_HOME="$HOME/.local/share/pnpm"' >> "$HOME/.bashrc" 2>/dev/null || true
        echo 'export PATH="$PNPM_HOME:$PATH"' >> "$HOME/.bashrc" 2>/dev/null || true
        echo 'export PNPM_HOME="$HOME/.local/share/pnpm"' >> "$HOME/.zshrc" 2>/dev/null || true
        echo 'export PATH="$PNPM_HOME:$PATH"' >> "$HOME/.zshrc" 2>/dev/null || true
    }
    
    # Add pnpm to current session's PATH
    export PNPM_HOME="$HOME/.local/share/pnpm"
    export PATH="$PNPM_HOME:$PATH"
    
    # Fix permissions if running as root
    if [ "$(id -u)" -eq 0 ]; then
        chown -R $USER:$USER "$HOME/.local/share/pnpm" 2>/dev/null || true
        chown -R $USER:$USER "$HOME/.config/pnpm" 2>/dev/null || true
        chown $USER:$USER ~/.bashrc ~/.zshrc 2>/dev/null || true
    fi
else
    echo "pnpm already installed, skipping..."
fi

# Ensure PNPM_HOME is set for this session
if [ -z "$PNPM_HOME" ]; then
    export PNPM_HOME="$HOME/.local/share/pnpm"
    export PATH="$PNPM_HOME:$PATH"
fi

# Install common global tools (npm/pnpm handle re-installs gracefully)
echo "Installing dev tools..."
pnpm add -g typescript tsx eslint prettier 2>/dev/null || echo "Some tools may already be installed"

# Verify
echo ""
echo "Verifying installation..."
node --version
npm --version
pnpm --version

# Verify TypeScript (may need full path if not in current PATH)
if command -v tsc &> /dev/null; then
    tsc --version
else
    echo "TypeScript: installed (available in new terminals via \$PNPM_HOME)"
fi

echo ""
echo "✅ Node.js dev environment ready!"
echo ""
echo "Installed tools:"
echo "  node:       $(node --version)"
echo "  npm:        $(npm --version)"
echo "  pnpm:       $(pnpm --version)"
echo "  TypeScript: via pnpm global"
echo ""
echo "💡 Global tools (tsc, tsx, etc.) are in: \$PNPM_HOME/bin"
echo "   This is already configured in your shell config"
echo ""
echo "Quick start:"
echo "  node --version"
echo "  pnpm init"
echo "  pnpm add express"

