#!/bin/bash

set -euo pipefail

####################################################################################
##### Marimo Setup for Brev
####################################################################################
# Defaults to cloning marimo-team/examples repository
# Set MARIMO_REPO_URL to use your own notebooks repository
# Set MARIMO_REPO_URL="" to skip cloning entirely
#
# ALWAYS includes Brev-specific notebooks from https://github.com/brevdev/marimo.git
# These are merged into the notebooks directory alongside MARIMO_REPO_URL notebooks
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
# Run as the detected user, not as root
if [ "$(id -u)" -eq 0 ]; then
    sudo -H -u "$USER" pip3 install --upgrade marimo
else
    pip3 install --upgrade marimo
fi

##### Add to PATH #####
echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc" 2>/dev/null || true
echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc" 2>/dev/null || true
export PATH="$HOME/.local/bin:$PATH"

##### Clone notebooks if URL provided #####
if [ -n "$REPO_URL" ]; then
    (echo ""; echo "##### Cloning notebooks from $REPO_URL #####"; echo "";)
    cd "$HOME"
    git clone "$REPO_URL" "$NOTEBOOKS_DIR" 2>/dev/null || echo "Repository already exists"
    
    # Install dependencies if requirements.txt exists
    if [ -f "$HOME/$NOTEBOOKS_DIR/requirements.txt" ]; then
        (echo ""; echo "##### Installing additional dependencies from requirements.txt #####"; echo "";)
        if [ "$(id -u)" -eq 0 ]; then
            sudo -H -u "$USER" pip3 install -r "$HOME/$NOTEBOOKS_DIR/requirements.txt"
        else
            pip3 install -r "$HOME/$NOTEBOOKS_DIR/requirements.txt"
        fi
    fi
fi

##### Install PyTorch with CUDA support #####
(echo ""; echo "##### Installing PyTorch with CUDA support #####"; echo "";)
if [ "$(id -u)" -eq 0 ]; then
    sudo -H -u "$USER" pip3 install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
else
    pip3 install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
fi

# LOCK torchvision version to prevent upgrades that break compatibility
(echo ""; echo "##### Locking torchvision version to prevent upgrades #####"; echo "";)
if [ "$(id -u)" -eq 0 ]; then
    TORCHVISION_VERSION=$(sudo -H -u "$USER" python3 -c "import torchvision; print(torchvision.__version__)" 2>/dev/null || echo "")
else
    TORCHVISION_VERSION=$(python3 -c "import torchvision; print(torchvision.__version__)" 2>/dev/null || echo "")
fi
echo "  Locked torchvision version: $TORCHVISION_VERSION"

# Install transformers with LOCKED torchvision version
(echo ""; echo "##### Installing transformers (with locked torchvision) #####"; echo "";)
if [ "$(id -u)" -eq 0 ]; then
    sudo -H -u "$USER" pip3 install --no-cache-dir transformers accelerate safetensors "torchvision==$TORCHVISION_VERSION"
else
    pip3 install --no-cache-dir transformers accelerate safetensors "torchvision==$TORCHVISION_VERSION"
fi

# Install common packages for marimo examples with LOCKED torchvision
# This ensures no package can upgrade torchvision to an incompatible version
(echo ""; echo "##### Installing common packages (with locked torchvision) #####"; echo "";)
if [ "$(id -u)" -eq 0 ]; then
    sudo -H -u "$USER" pip3 install --no-cache-dir \
        polars altair plotly pandas numpy scipy scikit-learn \
        matplotlib seaborn pyarrow openai anthropic requests \
        beautifulsoup4 pillow 'marimo[sql]' duckdb sqlalchemy \
        instructor mohtml openai-whisper opencv-python python-dotenv \
        wigglystuff yt-dlp psutil pynvml GPUtil \
        networkx diffusers "torchvision==$TORCHVISION_VERSION"
else
    pip3 install --no-cache-dir \
        polars altair plotly pandas numpy scipy scikit-learn \
        matplotlib seaborn pyarrow openai anthropic requests \
        beautifulsoup4 pillow 'marimo[sql]' duckdb sqlalchemy \
        instructor mohtml openai-whisper opencv-python python-dotenv \
        wigglystuff yt-dlp psutil pynvml GPUtil \
        networkx diffusers "torchvision==$TORCHVISION_VERSION"
fi

# Optional: Install TensorRT-related packages if CUDA is available
(echo ""; echo "##### Installing optional NVIDIA packages (TensorRT, etc.) #####"; echo "";)
if [ "$(id -u)" -eq 0 ]; then
    sudo -H -u "$USER" pip3 install --no-cache-dir torch-tensorrt "torchvision==$TORCHVISION_VERSION" 2>/dev/null || echo "  torch-tensorrt not available (needs TensorRT installed)"
else
    pip3 install --no-cache-dir torch-tensorrt "torchvision==$TORCHVISION_VERSION" 2>/dev/null || echo "  torch-tensorrt not available (needs TensorRT installed)"
fi

# Note: RAPIDS packages (cudf, cugraph) require conda installation
# These are optional - notebooks will fall back to CPU equivalents if not available
# To install RAPIDS:
#   conda install -c rapidsai -c conda-forge -c nvidia cudf=24.08 cugraph=24.08 python=3.11 cuda-version=12.0

##### Always pull Brev-specific marimo notebooks and merge them in #####
(echo ""; echo "##### Adding Brev marimo notebooks to notebooks directory #####"; echo "";)
BREV_MARIMO_REPO="https://github.com/brevdev/marimo.git"
BREV_MARIMO_TEMP="/tmp/brevdev-marimo-$$"

# Clone Brev marimo repo to temporary location
if git clone "$BREV_MARIMO_REPO" "$BREV_MARIMO_TEMP" 2>/dev/null; then
    echo "  Cloned Brev marimo notebooks"
    
    # Copy all .py files (marimo notebooks) from the root of brevdev/marimo
    for notebook in "$BREV_MARIMO_TEMP"/*.py; do
        [ -f "$notebook" ] || continue
        NOTEBOOK_NAME=$(basename "$notebook")
        
        # Skip setup files
        if [[ "$NOTEBOOK_NAME" == "setup.py" ]] || [[ "$NOTEBOOK_NAME" == "__"* ]]; then
            continue
        fi
        
        cp "$notebook" "$HOME/$NOTEBOOKS_DIR/$NOTEBOOK_NAME" || true
        echo "  [+] Copied: $NOTEBOOK_NAME"
        NOTEBOOKS_COPIED=$((NOTEBOOKS_COPIED + 1))
    done
    
    # Clean up temporary directory
    rm -rf "$BREV_MARIMO_TEMP"
    
    if [ "$NOTEBOOKS_COPIED" -gt 0 ]; then
        echo "  Total Brev notebooks copied: $NOTEBOOKS_COPIED"
    else
        echo "  No Brev notebooks found to copy"
    fi
else
    echo "  Warning: Could not clone Brev marimo repo, skipping"
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

# Determine where marimo is actually installed
if [ "$(id -u)" -eq 0 ]; then
    # When running as root, marimo was installed as the user to ~/.local/bin
    MARIMO_BIN="$HOME/.local/bin/marimo"
else
    # When not root, check where marimo actually is
    MARIMO_BIN=$(which marimo 2>/dev/null || echo "$HOME/.local/bin/marimo")
fi

##### Generate secure authentication token #####
(echo ""; echo "##### Generating secure authentication token #####"; echo "";)

# Create config directory with proper permissions
if [ "$(id -u)" -eq 0 ]; then
    sudo -u "$USER" mkdir -p "$HOME/.config/marimo" 2>/dev/null || mkdir -p "$HOME/.config/marimo"
    chown -R "$USER:$USER" "$HOME/.config/marimo" 2>/dev/null || true
else
    mkdir -p "$HOME/.config/marimo"
fi

# Generate cryptographically secure token
MARIMO_TOKEN=$(python3 -c "import secrets; print(secrets.token_hex(32))" 2>/dev/null)

# Validate token generation
if [ -z "$MARIMO_TOKEN" ]; then
    echo "ERROR: Failed to generate authentication token"
    exit 1
fi

# Store token securely with restricted permissions
if [ "$(id -u)" -eq 0 ]; then
    echo "$MARIMO_TOKEN" | sudo -u "$USER" tee "$HOME/.config/marimo/token" > /dev/null
    chmod 600 "$HOME/.config/marimo/token"
    chown "$USER:$USER" "$HOME/.config/marimo/token"
else
    echo "$MARIMO_TOKEN" > "$HOME/.config/marimo/token"
    chmod 600 "$HOME/.config/marimo/token"
fi

(echo ""; echo "=========================================="; echo "  SECURITY: Authentication Token Generated"; echo "=========================================="; echo "";)
(echo "Token location: $HOME/.config/marimo/token"; echo "";)


sudo tee /etc/systemd/system/marimo.service > /dev/null << EOF
[Unit]
Description=Marimo Notebook Server
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/$NOTEBOOKS_DIR
Environment="PATH=$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
Environment="HOME=$HOME"
Environment="MARIMO_PORT=${MARIMO_PORT:-8080}"
Environment="MARIMO_TOKEN=$MARIMO_TOKEN"
ExecStart=$MARIMO_BIN edit --host 127.0.0.1 --port \${MARIMO_PORT} --headless --token --token-password \${MARIMO_TOKEN}
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

##### Verify marimo binary is accessible #####
echo "Verifying marimo installation..."
if [ -f "$MARIMO_BIN" ]; then
    echo "✓ Found marimo at: $MARIMO_BIN"
    ls -la "$MARIMO_BIN"
else
    echo "⚠️  Warning: marimo binary not found at expected location: $MARIMO_BIN"
    echo "   Searching for marimo..."
    find "$HOME/.local/bin" -name "marimo" -type f 2>/dev/null || echo "   Not found in ~/.local/bin"
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
(echo "Security: Service is bound to localhost (127.0.0.1) only"; echo "";)
(echo "   Authentication token required"; echo "";)
if [ "$NOTEBOOKS_COPIED" -gt 0 ]; then
    (echo "Custom Notebooks: $NOTEBOOKS_COPIED notebook(s) added"; echo "";)
fi
(echo ""; echo "Remote Access:"; echo "";)
(echo "   For remote access, use SSH port forwarding:"; echo "";)
(echo "   ssh -L ${MARIMO_PORT:-8080}:localhost:${MARIMO_PORT:-8080} user@server"; echo "";)
(echo "   Then access http://localhost:${MARIMO_PORT:-8080} from your local browser"; echo "";)
(echo ""; echo "Useful commands:"; echo "";)
(echo "  - Check status:  sudo systemctl status marimo"; echo "";)
(echo "  - View logs:     sudo journalctl -u marimo -f"; echo "";)
(echo "  - Restart:       sudo systemctl restart marimo"; echo "";)
(echo "  - View token:    cat $HOME/.config/marimo/token"; echo "";)
(echo ""; echo "==============================================================="; echo "";)
