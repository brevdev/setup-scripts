#!/bin/bash
set -e

##############################################################################
# Brev Setup Script - earlyoom (Early Out-Of-Memory Daemon)
##############################################################################
# Installs and configures earlyoom to prevent system freezes due to OOM
# conditions. Monitors memory/swap and kills processes before system hangs.
##############################################################################

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

echo "🛡️  Setting up earlyoom (Early OOM Daemon)..."
echo "User: $USER | Home: $HOME"

##############################################################################
# Install earlyoom
##############################################################################

if command -v earlyoom &> /dev/null; then
    echo "earlyoom already installed, checking version..."
    earlyoom -v
else
    echo "Installing earlyoom..."
    sudo apt-get update -qq
    
    # Try installing from package manager first (available on Ubuntu 20.04+)
    if sudo apt-cache show earlyoom &> /dev/null; then
        sudo apt-get install -y -qq earlyoom
        echo "Installed earlyoom from package manager"
    else
        # Fallback: compile from source
        echo "Package not available, compiling from source..."
        sudo apt-get install -y -qq build-essential git pandoc
        
        TEMP_DIR=$(mktemp -d)
        cd "$TEMP_DIR"
        
        git clone --depth 1 https://github.com/rfjakob/earlyoom.git
        cd earlyoom
        make
        sudo make install
        
        # Clean up
        cd ~
        rm -rf "$TEMP_DIR"
        
        echo "Compiled and installed earlyoom from source"
    fi
fi

##############################################################################
# Configure earlyoom
##############################################################################

# Create systemd service configuration override if needed
OVERRIDE_DIR="/etc/systemd/system/earlyoom.service.d"
sudo mkdir -p "$OVERRIDE_DIR"

# Configure earlyoom with sensible defaults for Brev environments
# - Start killing at 10% available memory
# - Start killing at 5% available swap
# - Prefer to kill processes with higher oom_score
# - Report memory stats every 60 seconds
sudo tee "$OVERRIDE_DIR/brev-config.conf" > /dev/null << 'EOF'
[Service]
# Memory thresholds: kill when available memory/swap falls below these values
# -m = minimum % memory available (default 10%)
# -s = minimum % swap available (default 10%)
# -r = memory report interval in seconds (0 to disable)
ExecStart=
ExecStart=/usr/bin/earlyoom -m 10 -s 5 -r 60 --avoid '(^|/)sshd$' --avoid '(^|/)systemd$'
EOF

##############################################################################
# Enable and start earlyoom service
##############################################################################

echo "Enabling and starting earlyoom service..."
sudo systemctl daemon-reload
sudo systemctl enable earlyoom
sudo systemctl restart earlyoom

# Wait a moment for service to start
sleep 2

##############################################################################
# Verification
##############################################################################

echo ""
echo "Verifying installation..."

# Check version
VERSION=$(earlyoom -v 2>&1 | head -n1)
echo "✓ $VERSION"

# Check service status
if systemctl is-active --quiet earlyoom; then
    echo "✓ earlyoom service is active and running"
else
    echo "⚠️  earlyoom service is not running"
    sudo systemctl status earlyoom --no-pager
    exit 1
fi

# Show current configuration
echo ""
echo "Current configuration:"
systemctl cat earlyoom | grep -A3 "ExecStart=" | tail -n2

echo ""
echo "✅ earlyoom setup complete!"
echo ""
echo "What it does:"
echo "  • Monitors available memory and swap"
echo "  • Kills processes before system freezes due to OOM"
echo "  • Configured to kill at 10% mem / 5% swap available"
echo "  • Avoids killing sshd and systemd processes"
echo ""
echo "Service management:"
echo "  sudo systemctl status earlyoom    # Check status"
echo "  sudo systemctl stop earlyoom      # Stop service"
echo "  sudo systemctl start earlyoom     # Start service"
echo "  sudo journalctl -u earlyoom -f    # View logs"
echo ""
echo "Check current memory status:"
echo "  free -h"
echo "  cat /proc/meminfo | grep MemAvailable"
echo ""

