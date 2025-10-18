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

echo "☸️  Setting up local Kubernetes..."
echo "User: $USER"

# Install microk8s
sudo snap install microk8s --classic

# Add user to group
sudo usermod -a -G microk8s $USER
sudo chown -R $USER ~/.kube

# Wait for microk8s to be ready
echo "Waiting for microk8s..."
sudo microk8s status --wait-ready

# Enable essential addons
echo "Enabling addons..."
sudo microk8s enable dns
sudo microk8s enable helm3
sudo microk8s enable gpu  # NVIDIA GPU operator (Brev has NVIDIA drivers)

# Install kubectl alias
sudo snap alias microk8s.kubectl kubectl

# Install k9s for terminal UI
echo "Installing k9s..."
wget -q https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz
tar -xzf k9s_Linux_amd64.tar.gz
sudo mv k9s /usr/local/bin/
rm k9s_Linux_amd64.tar.gz

# Verify
echo ""
echo "Verifying installation..."
sudo microk8s status
kubectl version --client

echo ""
echo "✅ Kubernetes ready!"
echo ""
echo "Quick start:"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
echo "  k9s"
echo ""
echo "⚠️  You may need to log out and back in for group changes"

