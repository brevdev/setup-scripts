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

# Create .kube directory if it doesn't exist and fix permissions
mkdir -p ~/.kube
if [ "$(id -u)" -eq 0 ]; then
    chown -R $USER:$USER ~/.kube
fi

# Wait for microk8s to be ready
echo "Waiting for microk8s..."
sudo microk8s status --wait-ready

# Enable essential addons
echo "Enabling addons..."
sudo microk8s enable dns
sudo microk8s enable helm3
sudo microk8s enable gpu  # NVIDIA GPU operator (Brev has NVIDIA drivers)

# Export kubeconfig so kubectl works without group membership
echo "Configuring kubectl access..."
sudo microk8s config > ~/.kube/config
chmod 600 ~/.kube/config

# Fix ownership if running as root
if [ "$(id -u)" -eq 0 ]; then
    chown $USER:$USER ~/.kube/config
fi

# Add KUBECONFIG to shell configs if not already there
for shell_config in ~/.bashrc ~/.zshrc; do
    if [ -f "$shell_config" ] && ! grep -q "KUBECONFIG.*kube/config" "$shell_config"; then
        echo "" >> "$shell_config"
        echo "# Kubernetes config" >> "$shell_config"
        echo "export KUBECONFIG=\$HOME/.kube/config" >> "$shell_config"
        
        # Fix ownership if running as root
        if [ "$(id -u)" -eq 0 ]; then
            chown $USER:$USER "$shell_config"
        fi
    fi
done

# Export for current session
export KUBECONFIG=$HOME/.kube/config

# Install kubectl alias (still useful but not required now)
sudo snap alias microk8s.kubectl kubectl 2>/dev/null || true

# Install k9s for terminal UI
echo "Installing k9s..."
wget -q https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz
tar -xzf k9s_Linux_amd64.tar.gz
sudo chmod +x k9s
sudo mv k9s /usr/local/bin/
rm k9s_Linux_amd64.tar.gz LICENSE README.md 2>/dev/null || true

# Install standalone kubectl (in addition to snap alias)
echo "Installing kubectl..."
if ! command -v kubectl &> /dev/null || kubectl version --client 2>&1 | grep -q "microk8s"; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
fi

# Final permission fix for any files created by microk8s
if [ "$(id -u)" -eq 0 ] && [ -d "$HOME/.kube" ]; then
    chown -R $USER:$USER "$HOME/.kube" 2>/dev/null || true
fi

# Verify (without sudo - should work now!)
echo ""
echo "Verifying installation..."
sudo microk8s status
export KUBECONFIG=$HOME/.kube/config
kubectl version --client
echo "Testing cluster access..."
kubectl get nodes 2>/dev/null && echo "✓ kubectl can access cluster" || echo "⚠️  kubectl access will work after sourcing shell config"

echo ""
echo "✅ Kubernetes ready!"
echo ""
echo "Kubeconfig: ~/.kube/config"
echo ""
echo "Quick start (run in a new terminal or source your shell config):"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
echo "  k9s"
echo ""
echo "Or source your shell config now:"
echo "  source ~/.bashrc"
echo ""
echo "Note: kubectl and k9s use ~/.kube/config - no group membership needed!"

