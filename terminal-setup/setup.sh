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

echo "💻 Setting up terminal..."
echo "User: $USER | Home: $HOME"

# Install zsh if not already installed
if ! command -v zsh &> /dev/null; then
    echo "Installing zsh..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq zsh
else
    echo "zsh already installed, skipping..."
fi

# Install oh-my-zsh if not already installed
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing oh-my-zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    
    # Fix permissions if running as root
    if [ "$(id -u)" -eq 0 ]; then
        chown -R $USER:$USER "$HOME/.oh-my-zsh"
    fi
else
    echo "oh-my-zsh already installed, skipping..."
fi

# Install modern CLI tools
echo "Installing modern CLI tools..."
sudo apt-get update -qq
sudo apt-get install -y -qq fzf ripgrep bat fd-find

# Install eza (modern ls) if not already installed
if [ ! -f /usr/local/bin/eza ]; then
    echo "Installing eza..."
    wget -q -c https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz -O - | tar xz
    sudo chmod +x eza
    sudo mv eza /usr/local/bin/
else
    echo "eza already installed, skipping..."
fi

# Create .zshrc if it doesn't exist
touch ~/.zshrc

# Add useful aliases if not already there
if ! grep -q "Modern CLI aliases" ~/.zshrc; then
    echo "Adding aliases to .zshrc..."
    cat >> ~/.zshrc << 'EOF'

# Modern CLI aliases
alias ll='eza -la'
alias ls='eza'
alias cat='batcat'
alias find='fd'
alias grep='rg'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph'
EOF
    
    # Fix permissions if running as root
    if [ "$(id -u)" -eq 0 ]; then
        chown $USER:$USER ~/.zshrc
    fi
else
    echo "Aliases already in .zshrc, skipping..."
fi

# Change default shell if not already zsh
if [ "$SHELL" != "$(which zsh)" ]; then
    echo "Changing default shell to zsh..."
    sudo chsh -s $(which zsh) $USER 2>/dev/null || echo "Note: Shell change may require logout"
else
    echo "Default shell is already zsh"
fi

echo ""
echo "✅ Terminal setup complete!"
echo ""
echo "Quick start:"
echo "  ll              # Better ls"
echo "  cat file.txt    # Syntax highlighting"
echo "  rg pattern      # Fast search"
echo "  fzf             # Fuzzy file finder"
echo ""
echo "Starting zsh now (default shell will be zsh for new sessions)..."

# Start zsh immediately if not already in it
if [ -n "$BASH_VERSION" ]; then
    exec zsh
fi

