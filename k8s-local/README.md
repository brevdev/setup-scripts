# Local Kubernetes

microk8s with GPU support for local Kubernetes development.

## What it installs

- **microk8s** - Lightweight Kubernetes
- **DNS addon** - For service discovery
- **GPU operator** - NVIDIA GPU support
- **kubectl** - Standalone Kubernetes CLI (no group membership needed)
- **helm** - Standalone package manager (no group membership needed)
- **k9s** - Terminal UI for Kubernetes

## Quick Setup on Brev

Copy and paste these commands for a fast setup:

```bash
# 1) Update system and install git
sudo apt-get update -y
sudo apt-get install -y git

# 2) Sparse-clone only k8s-local (avoids downloading all directories)
git clone --depth=1 --filter=blob:none --sparse https://github.com/brevdev/setup-scripts.git
cd setup-scripts
git sparse-checkout set k8s-local

# Confirm the files are present
ls -la k8s-local
cat k8s-local/README.md

# 3) Execute the script
cd k8s-local
bash setup.sh
```

Takes ~3-5 minutes.

**Ready to use immediately!** The script:
- Installs standalone kubectl and helm (not snap/microk8s versions)
- Sets up `~/.kube/config` with cluster access
- Works without group membership or `newgrp`

kubectl and helm work in any terminal - no special setup needed!

## Quick verification after the script finishes

```bash
# Ensure you're using the standalone binaries
which kubectl      # should print: /usr/local/bin/kubectl
which helm         # should print: /usr/local/bin/helm

# If it shows /snap/bin/kubectl, remove the snap alias:
sudo snap unalias kubectl

# Ensure KUBECONFIG is set (the script will add it to ~/.bashrc)
export KUBECONFIG=$HOME/.kube/config
kubectl get nodes
helm version
```

## What you get

```bash
kubectl get nodes           # View cluster nodes
kubectl get pods -A         # View all pods
helm version                # Check helm
helm list                   # List helm releases
k9s                         # Launch terminal UI
```

**No `newgrp` or logout needed!** The script installs standalone kubectl and helm that use `~/.kube/config` and work immediately without group membership.

## Deploy something

**Basic deployment:**
```bash
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort
kubectl get services
```

**Using helm:**
```bash
# Add a chart repository
helm repo add bitnami https://charts.bitnami.com/bitnami

# Install a chart
helm install my-nginx bitnami/nginx

# List releases
helm list
```

## GPU workload

```bash
kubectl run gpu-test --image=nvidia/cuda:12.0-base \
  --limits=nvidia.com/gpu=1 \
  -- nvidia-smi
kubectl logs gpu-test
```

## Troubleshooting

**"Insufficient permissions to access MicroK8s":**

This means you're using the snap version of kubectl instead of the standalone version.

```bash
# Check which kubectl you're using
which kubectl
# Should output: /usr/local/bin/kubectl

# Check which helm you're using
which helm
# Should output: /usr/local/bin/helm

# If kubectl shows /snap/bin/kubectl, remove the snap alias
sudo snap unalias kubectl

# Verify standalone tools work
kubectl get nodes
helm version
```

**kubectl not found:**

Make sure `/usr/local/bin` is in your PATH:
```bash
echo $PATH
export PATH="/usr/local/bin:$PATH"
```

**Can't access cluster:**

Ensure KUBECONFIG is set:
```bash
export KUBECONFIG=$HOME/.kube/config
kubectl get nodes
```

For persistent access, it's already in your `~/.bashrc` - just open a new terminal or:
```bash
source ~/.bashrc
```

