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
else
    echo "pnpm already installed, skipping..."
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
tsc --version

echo ""
echo "✅ Node.js dev environment ready!"
echo ""
echo "Quick start:"
echo "  node --version"
echo "  pnpm init"
echo "  pnpm add express"

