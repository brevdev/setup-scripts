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

echo "☸️  Setting up Kubernetes with Dynamo + Grove..."
echo "User: $USER"

# Install microk8s
echo "Installing microk8s..."
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

# Remove any existing snap alias (it requires group membership)
sudo snap unalias kubectl 2>/dev/null || true

# Install standalone kubectl (works without group membership!)
echo "Installing standalone kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl
echo "✓ kubectl installed to /usr/local/bin/kubectl"

# Install standalone helm (works without group membership!)
echo "Installing standalone helm..."
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
echo "✓ helm installed to /usr/local/bin/helm"

# Install k9s for terminal UI
echo "Installing k9s..."
wget -q https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz
tar -xzf k9s_Linux_amd64.tar.gz
sudo chmod +x k9s
sudo mv k9s /usr/local/bin/
rm k9s_Linux_amd64.tar.gz LICENSE README.md 2>/dev/null || true

# Install local-path-provisioner for PersistentVolumeClaims
echo "Installing local-path storage provisioner..."
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml

# Wait for provisioner to be ready
echo "Waiting for storage provisioner..."
kubectl wait --for=condition=available --timeout=60s deployment/local-path-provisioner -n local-path-storage

# Set as default storage class
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
echo "✓ Storage provisioner installed and set as default"

# Final permission fix for any files created by microk8s
if [ "$(id -u)" -eq 0 ] && [ -d "$HOME/.kube" ]; then
    chown -R $USER:$USER "$HOME/.kube" 2>/dev/null || true
fi

# Verify (without sudo - should work now!)
echo ""
echo "Verifying installation..."
sudo microk8s status

# Show which binaries we're using
echo ""
echo "kubectl binary: $(which kubectl)"
echo "helm binary: $(which helm)"

# Test kubectl
export KUBECONFIG=$HOME/.kube/config
kubectl version --client
echo ""
echo "Testing cluster access..."
kubectl get nodes 2>/dev/null && echo "✓ kubectl can access cluster without group membership!" || echo "⚠️  kubectl will work after sourcing shell config"

# Test helm
echo ""
echo "Testing helm..."
helm version --short 2>/dev/null && echo "✓ helm is ready!" || echo "⚠️  helm will work after sourcing shell config"

# Verify storage class
echo ""
echo "Verifying storage class..."
kubectl get storageclass

echo ""
echo "✅ Kubernetes ready for Dynamo + Grove!"
echo ""
echo "Kubeconfig: ~/.kube/config"
echo ""
echo "Quick start (works immediately!):"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
echo "  kubectl get storageclass"
echo "  helm version"
echo "  k9s"
echo ""
echo "💡 How it works:"
echo "  - kubectl, helm, k9s are standalone binaries (/usr/local/bin/)"
echo "  - Use ~/.kube/config automatically"
echo "  - Storage provisioner ready for Dynamo/Grove PVCs"
echo "  - No group membership needed!"
echo "  - No 'newgrp' or logout required!"
echo ""
echo "Next steps:"
echo "  Follow the README.md in this directory to deploy Dynamo + Grove"
echo ""
