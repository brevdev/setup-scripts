# Local Kubernetes

microk8s with GPU support for local Kubernetes development.

## What it installs

- **microk8s** - Lightweight Kubernetes
- **DNS addon** - For service discovery
- **Helm 3** - Package manager for Kubernetes
- **GPU operator** - NVIDIA GPU support
- **kubectl** - Kubernetes CLI
- **k9s** - Terminal UI for Kubernetes

## Usage

```bash
bash setup.sh
```

Takes ~3-5 minutes.

**Ready to use immediately!** The script:
- Installs standalone kubectl (not the snap alias)
- Sets up `~/.kube/config` with cluster access
- Works without group membership or `newgrp`

kubectl works in any terminal - no special setup needed!

## What you get

```bash
kubectl get nodes           # View cluster nodes
kubectl get pods -A         # View all pods
k9s                         # Launch terminal UI
helm list                   # List helm releases
```

**No `newgrp` or logout needed!** The script installs standalone kubectl that uses `~/.kube/config` and works immediately without group membership.

## Deploy something

```bash
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort
kubectl get services
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

# If it shows /snap/bin/kubectl, remove the snap alias
sudo snap unalias kubectl

# Verify standalone kubectl works
kubectl get nodes
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

