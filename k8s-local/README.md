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

**Ready to use immediately!** The script sets up `~/.kube/config` and exports it to your current shell.

For new terminals, the KUBECONFIG is automatically loaded via your shell config.

## What you get

```bash
kubectl get nodes           # View cluster nodes
kubectl get pods -A         # View all pods
k9s                         # Launch terminal UI
helm list                   # List helm releases
```

Note: kubectl and k9s use `~/.kube/config` - no group membership needed!

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

