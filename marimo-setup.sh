#!/bin/bash

set -euo pipefail

####################################################################################
##### Marimo Setup for Brev
####################################################################################
# Defaults to cloning marimo-team/examples repository
# Set MARIMO_REPO_URL to use your own notebooks repository
# Set MARIMO_REPO_URL="" to skip cloning entirely
####################################################################################

# Detect the actual Brev user dynamically
# This handles ubuntu, nvidia, shadeform, or any other user
# Uses Brev-specific markers to identify the correct user
if [ -z "${USER:-}" ] || [ "${USER:-}" = "root" ]; then
    # Check if run via sudo first
    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
        USER="$SUDO_USER"
    else
        # Find actual Brev user by checking for Brev-specific markers:
        # 1. .lifecycle-script-ls-*.log files (unique to Brev user)
        # 2. .verb-setup.log file (Brev-specific)
        # 3. .cache symlink to /ephemeral/cache
        DETECTED_USER=""
        
        # First pass: Look for Brev lifecycle script logs (most reliable)
        for user_home in /home/*; do
            username=$(basename "$user_home")
            # Check for Brev lifecycle script log files
            if ls "$user_home"/.lifecycle-script-ls-*.log 2>/dev/null | grep -q .; then
                DETECTED_USER="$username"
                break
            fi
            # Check for Brev verb setup log
            if [ -f "$user_home/.verb-setup.log" ]; then
                DETECTED_USER="$username"
                break
            fi
        done
        
        # Second pass: Check for .cache symlink to /ephemeral/cache
        if [ -z "$DETECTED_USER" ]; then
            for user_home in /home/*; do
                username=$(basename "$user_home")
                if [ -L "$user_home/.cache" ] && [ "$(readlink "$user_home/.cache")" = "/ephemeral/cache" ]; then
                    DETECTED_USER="$username"
                    break
                fi
            done
        fi
        
        # Third pass: Use UID check, but skip known service users
        if [ -z "$DETECTED_USER" ]; then
            for user_home in /home/*; do
                username=$(basename "$user_home")
                # Skip known service users
                if [ "$username" = "launchpad" ]; then
                    continue
                fi
                # Check if user has UID >= 1000 (interactive user)
                if id "$username" &>/dev/null; then
                    user_uid=$(id -u "$username" 2>/dev/null || echo 0)
                    if [ "$user_uid" -ge 1000 ]; then
                        DETECTED_USER="$username"
                        break
                    fi
                fi
            done
        fi
        
        # Fall back to known common users if all detection fails
        if [ -z "$DETECTED_USER" ]; then
            if [ -d "/home/nvidia" ]; then
                DETECTED_USER="nvidia"
            elif [ -d "/home/ubuntu" ]; then
                DETECTED_USER="ubuntu"
            else
                DETECTED_USER="ubuntu"
            fi
        fi
        USER="$DETECTED_USER"
    fi
fi

# Force HOME to be the detected user's home directory
# Don't use ${HOME:-...} because HOME is already set to /root when running as root
HOME="/home/$USER"

REPO_URL="${MARIMO_REPO_URL:-https://github.com/marimo-team/examples.git}"
NOTEBOOKS_DIR="${MARIMO_NOTEBOOKS_DIR:-marimo-examples}"
NOTEBOOKS_COPIED=0

(echo ""; echo "##### Detected Environment #####"; echo "";)
(echo "User: $USER"; echo "";)
(echo "Home: $HOME"; echo "";)

##### Install Python and pip if not available #####
if ! command -v pip3 &> /dev/null; then
    (echo ""; echo "##### Installing Python and pip3 #####"; echo "";)
    sudo apt-get update
    sudo apt-get install -y python3 python3-pip python3-venv
fi

##### Install Marimo #####
(echo ""; echo "##### Installing Marimo #####"; echo "";)
pip3 install --upgrade marimo

##### Add to PATH #####
echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc" 2>/dev/null || true
echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc" 2>/dev/null || true
export PATH="$HOME/.local/bin:$PATH"

##### Clone notebooks if URL provided #####
if [ -n "$REPO_URL" ]; then
    (echo ""; echo "##### Cloning notebooks from $REPO_URL #####"; echo "";)
    cd "$HOME"
    git clone "$REPO_URL" "$NOTEBOOKS_DIR" 2>/dev/null || echo "Repository already exists"
    
    # Install PyTorch with CUDA support first (large download)
    (echo ""; echo "##### Installing PyTorch with CUDA support #####"; echo "";)
    pip3 install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
    
    # Install common packages for marimo examples
    (echo ""; echo "##### Installing common packages for marimo examples #####"; echo "";)
    pip3 install --no-cache-dir --upgrade \
        polars altair plotly pandas numpy scipy scikit-learn \
        matplotlib seaborn pyarrow openai anthropic requests \
        beautifulsoup4 pillow 'marimo[sql]' duckdb sqlalchemy \
        instructor mohtml openai-whisper opencv-python python-dotenv \
        wigglystuff yt-dlp psutil pynvml GPUtil
    
    # Install dependencies if requirements.txt exists
    if [ -f "$HOME/$NOTEBOOKS_DIR/requirements.txt" ]; then
        (echo ""; echo "##### Installing additional dependencies from requirements.txt #####"; echo "";)
        pip3 install -r "$HOME/$NOTEBOOKS_DIR/requirements.txt"
    fi
    
    # Copy all marimo notebooks from this repo to notebooks directory
    (echo ""; echo "##### Adding custom marimo notebooks to notebooks directory #####"; echo "";)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Build list of directories to search
    # Start with obvious locations
    MARIMO_SOURCE_DIRS=(
        "$SCRIPT_DIR"
        "$HOME/marimo"
    )
    
    # Dynamically detect all user home directories and add their marimo subdirs
    # This handles ubuntu, nvidia, shadeform, or any other Brev user
    for user_home in /home/*; do
        if [ -d "$user_home/marimo" ]; then
            MARIMO_SOURCE_DIRS+=("$user_home/marimo")
        fi
    done
    
    # Add generic locations
    MARIMO_SOURCE_DIRS+=("/workspace")
    
    for SOURCE_DIR in "${MARIMO_SOURCE_DIRS[@]}"; do
        if [ -d "$SOURCE_DIR" ]; then
            # Find all .py files and check if they're marimo notebooks
            for notebook in "$SOURCE_DIR"/*.py; do
                [ -f "$notebook" ] || continue
                # Check if file contains marimo.App (indicates it's a marimo notebook)
                if grep -q "marimo.App" "$notebook" 2>/dev/null; then
                    NOTEBOOK_NAME=$(basename "$notebook")
                    cp "$notebook" "$HOME/$NOTEBOOKS_DIR/$NOTEBOOK_NAME" || true
                    echo "  [+] Copied: $NOTEBOOK_NAME"
                    NOTEBOOKS_COPIED=$((NOTEBOOKS_COPIED + 1))
                fi
            done
        fi
    done
    
    if [ "$NOTEBOOKS_COPIED" -gt 0 ]; then
        echo "  Total notebooks copied: $NOTEBOOKS_COPIED"
    else
        echo "  No marimo notebooks found to copy"
    fi
fi

##### Ensure notebooks directory exists with proper permissions #####
(echo ""; echo "##### Ensuring notebooks directory exists #####"; echo "";)

# Create directory as the target user to avoid permission issues
if [ "$(id -u)" -eq 0 ] && [ -n "$USER" ]; then
    # Running as root - create directory as target user
    # First ensure HOME directory exists and has proper permissions
    mkdir -p "$HOME"
    chown "$USER:$USER" "$HOME" 2>/dev/null || true
    
    # Create notebooks directory as the target user
    sudo -u "$USER" mkdir -p "$HOME/$NOTEBOOKS_DIR" 2>/dev/null || mkdir -p "$HOME/$NOTEBOOKS_DIR"
    
    # Ensure proper ownership and permissions
    chown -R "$USER:$USER" "$HOME/$NOTEBOOKS_DIR"
    chmod -R 755 "$HOME/$NOTEBOOKS_DIR"
    echo "Created $HOME/$NOTEBOOKS_DIR as user $USER"
else
    # Running as regular user
    mkdir -p "$HOME/$NOTEBOOKS_DIR"
    echo "Created $HOME/$NOTEBOOKS_DIR"
fi

##### Create systemd service for Marimo #####
(echo ""; echo "##### Setting up Marimo systemd service #####"; echo "";)
sudo tee /etc/systemd/system/marimo.service > /dev/null << EOF
[Unit]
Description=Marimo Notebook Server
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/$NOTEBOOKS_DIR
Environment="PATH=/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin"
Environment="HOME=$HOME"
Environment="MARIMO_PORT=${MARIMO_PORT:-8080}"
ExecStart=/usr/local/bin/marimo edit --host 0.0.0.0 --port \${MARIMO_PORT} --headless --no-token
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=marimo

[Install]
WantedBy=multi-user.target
EOF

##### Fix ownership of shell config files if running as root #####
if [ "$(id -u)" -eq 0 ] && [ -n "$USER" ]; then
    chown -R "$USER:$USER" "$HOME/.bashrc" "$HOME/.zshrc" 2>/dev/null || true
fi

##### Enable and start Marimo service #####
(echo ""; echo "##### Enabling and starting Marimo service #####"; echo "";)
sudo systemctl daemon-reload
sudo systemctl enable marimo.service 2>/dev/null || true
sudo systemctl start marimo.service

# Wait for service to start
sleep 2

(echo ""; echo ""; echo "==============================================================="; echo "";)
(echo "  Setup Complete! Marimo is now running"; echo "";)
(echo "==============================================================="; echo "";)
(echo ""; echo "Notebooks Location: $HOME/$NOTEBOOKS_DIR"; echo "";)
(echo "Access URL: http://localhost:${MARIMO_PORT:-8080}"; echo "";)
if [ "$NOTEBOOKS_COPIED" -gt 0 ]; then
    (echo "Custom Notebooks: $NOTEBOOKS_COPIED notebook(s) added"; echo "";)
fi
(echo ""; echo "Useful commands:"; echo "";)
(echo "  - Check status:  sudo systemctl status marimo"; echo "";)
(echo "  - View logs:     sudo journalctl -u marimo -f"; echo "";)
(echo "  - Restart:       sudo systemctl restart marimo"; echo "";)
(echo ""; echo "==============================================================="; echo "";)
