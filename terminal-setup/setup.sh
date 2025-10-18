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

# Install zsh
sudo apt-get update
sudo apt-get install -y zsh

# Install oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install modern CLI tools
echo "Installing modern CLI tools..."
sudo apt-get install -y fzf ripgrep bat fd-find

# Install eza (modern ls)
wget -q -c https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz -O - | tar xz
sudo chmod +x eza
sudo mv eza /usr/local/bin/

# Add useful aliases
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

# Change default shell
sudo chsh -s $(which zsh) $USER

echo ""
echo "✅ Terminal setup complete!"
echo ""
echo "Quick start:"
echo "  ll              # Better ls"
echo "  cat file.txt    # Syntax highlighting"
echo "  rg pattern      # Fast search"
echo "  fzf             # Fuzzy file finder"
echo ""
echo "⚠️  Log out and back in to use zsh"

