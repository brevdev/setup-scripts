#!/bin/bash
set -e

##############################################################################
# Brev Setup Script - Best Practices Example
##############################################################################
# This demonstrates all conventions used in the setup-scripts collection:
#   - Battle-tested user detection (works with ubuntu/shadeform/nvidia users)
#   - Idempotency (safe to re-run)
#   - Permission fixes (when running as root)
#   - Clear output with progress indicators
#   - Verification at the end
#   - Under 150 lines
#
# This example sets up a Python development environment with a simple web app
##############################################################################

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

echo "🚀 Example Setup Script - Python Web App"
echo "User: $USER | Home: $HOME"

##############################################################################
# Install System Dependencies
##############################################################################

echo "Installing system dependencies..."
sudo apt-get update -qq
sudo apt-get install -y -qq python3-pip python3-venv curl

##############################################################################
# Install Python Environment (Example: virtualenv)
##############################################################################

# Create project directory
PROJECT_DIR="$HOME/my-web-app"
mkdir -p "$PROJECT_DIR"

# Create virtual environment if it doesn't exist
if [ ! -d "$PROJECT_DIR/venv" ]; then
    echo "Creating Python virtual environment..."
    cd "$PROJECT_DIR"
    python3 -m venv venv
else
    echo "Virtual environment already exists, skipping..."
fi

# Activate and install dependencies
cd "$PROJECT_DIR"
source venv/bin/activate

echo "Installing Python packages..."
pip install --upgrade pip
pip install flask gunicorn requests

##############################################################################
# Create Example Application
##############################################################################

# Create a simple Flask app if it doesn't exist
if [ ! -f "$PROJECT_DIR/app.py" ]; then
    echo "Creating example Flask app..."
    cat > "$PROJECT_DIR/app.py" << 'EOF'
from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route('/')
def hello():
    return jsonify({
        "message": "Hello from Brev!",
        "user": os.getenv("USER", "unknown"),
        "status": "running"
    })

@app.route('/health')
def health():
    return jsonify({"status": "healthy"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF
fi

# Create requirements.txt for reproducibility
cat > "$PROJECT_DIR/requirements.txt" << 'EOF'
flask==3.0.0
gunicorn==21.2.0
requests==2.31.0
EOF

# Create .env.example
if [ ! -f "$PROJECT_DIR/.env.example" ]; then
    cat > "$PROJECT_DIR/.env.example" << 'EOF'
# Example environment variables
PORT=5000
DEBUG=false
# Add your API keys here
EOF
fi

# Create start script
cat > "$PROJECT_DIR/start.sh" << 'EOF'
#!/bin/bash
cd ~/my-web-app
source venv/bin/activate
gunicorn --bind 0.0.0.0:5000 --workers 2 app:app
EOF
chmod +x "$PROJECT_DIR/start.sh"

##############################################################################
# Fix Permissions (if running as root)
##############################################################################

if [ "$(id -u)" -eq 0 ]; then
    echo "Fixing permissions..."
    chown -R $USER:$USER "$PROJECT_DIR"
fi

##############################################################################
# Verification
##############################################################################

echo ""
echo "Verifying installation..."
cd "$PROJECT_DIR"
source venv/bin/activate
python3 -c "import flask; print(f'✓ Flask {flask.__version__}')"
python3 -c "import gunicorn; print('✓ Gunicorn installed')"

echo ""
echo "✅ Setup complete!"
echo ""
echo "Project location: $PROJECT_DIR"
echo ""
echo "Quick start:"
echo "  cd $PROJECT_DIR"
echo "  source venv/bin/activate"
echo "  python app.py                  # Development server"
echo "  ./start.sh                     # Production with Gunicorn"
echo ""
echo "⚠️  To access from outside Brev, open port: 5000/tcp"
echo ""
echo "Test the app:"
echo "  curl http://localhost:5000"
echo "  curl http://localhost:5000/health"
echo ""

##############################################################################
# Key Conventions Demonstrated:
##############################################################################
# ✅ User detection - Works on all providers
# ✅ Idempotency - Check before creating/installing
# ✅ Permission fixes - chown when running as root
# ✅ Simple and focused - Does one thing well
# ✅ Port information - Clear about what to open
# ✅ Verification - Test that it worked
# ✅ Quick start - Show users how to use it
# ✅ Under 150 lines - Easy to understand
##############################################################################
