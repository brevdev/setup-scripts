# Dynamo + Grove on Kubernetes

Deploy NVIDIA Dynamo with Grove for disaggregated LLM serving on Kubernetes. This setup demonstrates KV-cache routing with separate prefill and decode workers for efficient inference.

## What it installs

- **microk8s** - Lightweight Kubernetes
- **DNS addon** - For service discovery
- **GPU operator** - NVIDIA GPU support
- **kubectl** - Standalone Kubernetes CLI
- **helm** - Standalone package manager
- **k9s** - Terminal UI for Kubernetes
- **local-path-provisioner** - Storage provisioner for PersistentVolumeClaims
- **Dynamo CRDs & Operator** - NVIDIA Dynamo custom resources and controller
- **Grove** - Pod scheduling and management for distributed inference
- **vLLM Runtime** - High-performance inference engine

## Architecture

This deployment creates a **disaggregated serving architecture**:

```
┌─────────────┐
│  Frontend   │  ← Routes requests via KV-cache scheduling
└──────┬──────┘
       │
       ├──────────┬──────────┐
       ▼          ▼          ▼
  ┌─────────┐ ┌─────────┐ ┌─────────┐
  │ Prefill │ │ Decode  │ │ Decode  │
  │ Worker  │ │ Worker  │ │ Worker  │
  └─────────┘ └─────────┘ └─────────┘
```

- **Frontend**: KV-router that intelligently schedules requests
- **Prefill Worker**: Handles initial prompt processing
- **Decode Workers (2x)**: Handle token generation with load balancing

## Quick Setup on Brev

First, SSH into your Brev instance with GPU support, then copy and paste these commands:

### Step 1: Clone the repository and run setup

```bash
# Update system and install git
sudo apt-get update -y
sudo apt-get install -y git

# Sparse-clone only k8s-local directory
git clone --depth=1 --filter=blob:none --sparse https://github.com/brevdev/setup-scripts.git
cd setup-scripts
git sparse-checkout set k8s-local

# Run the Dynamo setup script
cd k8s-local/dynamo
bash setup.sh
```

Takes ~3-5 minutes. The script installs Kubernetes, kubectl, helm, storage provisioner, and all dependencies.

### Step 2: Set environment variables

```bash
export NAMESPACE=vllm-v1-disagg-router
export RELEASE_VERSION=0.5.1
export KUBECONFIG=$HOME/.kube/config
```

### Step 3: Create namespace and Hugging Face token secret

Replace `<your-hf-token>` with your actual Hugging Face token from https://huggingface.co/settings/tokens

```bash
kubectl create namespace vllm-v1-disagg-router

kubectl create secret generic hf-token-secret \
  --from-literal=HF_TOKEN=<your-hf-token>
```

### Step 4: Install Dynamo CRDs

```bash
helm fetch https://helm.ngc.nvidia.com/nvidia/ai-dynamo/charts/dynamo-crds-${RELEASE_VERSION}.tgz
helm install dynamo-crds dynamo-crds-${RELEASE_VERSION}.tgz --namespace default
```

### Step 5: Install Dynamo Operator + Grove

```bash
helm fetch https://helm.ngc.nvidia.com/nvidia/ai-dynamo/charts/dynamo-platform-${RELEASE_VERSION}.tgz
helm install dynamo-platform dynamo-platform-${RELEASE_VERSION}.tgz \
  --namespace ${NAMESPACE} \
  --create-namespace \
  --set "grove.enabled=true"
```

This may take a few minutes as it pulls container images and waits for etcd and NATS to be ready.

### Step 6: Verify Grove installation

```bash
kubectl get crd | grep grove
```

Expected output:
```
podcliques.grove.io
podcliquescalinggroups.grove.io
podcliquesets.grove.io
podgangs.scheduler.grove.io
podgangsets.grove.io
```

### Step 7: Create the DynamoGraphDeployment YAML

```bash
cat > dynamo-grove.yaml <<'EOF'
apiVersion: nvidia.com/v1alpha1
kind: DynamoGraphDeployment
metadata:
  name: dynamo-grove
spec:
  services:
    Frontend:
      dynamoNamespace: vllm-v1-disagg-router
      componentType: frontend
      replicas: 1
      extraPodSpec:
        mainContainer:
          image: nvcr.io/nvidia/ai-dynamo/vllm-runtime:0.5.1
      envs:
        - name: DYN_ROUTER_MODE
          value: kv
    VllmDecodeWorker:
      dynamoNamespace: vllm-v1-disagg-router
      envFromSecret: hf-token-secret
      componentType: worker
      replicas: 2
      resources:
        limits:
          gpu: "1"
      extraPodSpec:
        mainContainer:
          image: nvcr.io/nvidia/ai-dynamo/vllm-runtime:0.5.1
          workingDir: /workspace/components/backends/vllm
          command:
          - python3
          - -m
          - dynamo.vllm
          args:
            - --model
            - Qwen/Qwen3-0.6B
    VllmPrefillWorker:
      dynamoNamespace: vllm-v1-disagg-router
      envFromSecret: hf-token-secret
      componentType: worker
      replicas: 1
      resources:
        limits:
          gpu: "1"
      extraPodSpec:
        mainContainer:
          image: nvcr.io/nvidia/ai-dynamo/vllm-runtime:0.5.1
          workingDir: /workspace/components/backends/vllm
          command:
          - python3
          - -m
          - dynamo.vllm
          args:
            - --model
            - Qwen/Qwen3-0.6B
            - --is-prefill-worker
EOF
```

### Step 8: Deploy the configuration

```bash
kubectl apply -f dynamo-grove.yaml
```

### Step 9: Monitor the deployment

Watch pods come up (this may take 3-5 minutes as images are pulled and models are loaded):

```bash
kubectl get pods -n default -w
```

Expected pods (press `Ctrl+C` to stop watching once all are `Running`):
```
NAME                                             READY   STATUS    RESTARTS   AGE
dynamo-grove-0-frontend-xxxxx                    1/1     Running   0          5m
dynamo-grove-0-vllmdecodeworker-xxxxx            1/1     Running   0          5m
dynamo-grove-0-vllmdecodeworker-xxxxx            1/1     Running   0          5m
dynamo-grove-0-vllmprefillworker-xxxxx           1/1     Running   0          5m
dynamo-platform-dynamo-operator-xxxxx            2/2     Running   0          10m
dynamo-platform-etcd-0                           1/1     Running   0          10m
dynamo-platform-nats-0                           2/2     Running   0          10m
grove-operator-xxxxx                             1/1     Running   0          10m
```

## Testing the Deployment

### Step 10: Port-forward the frontend service

```bash
kubectl port-forward svc/dynamo-grove-frontend 8000:8000 -n default &
```

### Step 11: Check available models

```bash
curl http://localhost:8000/v1/models
```

Expected output:
```json
{
  "object": "list",
  "data": [{
    "id": "Qwen/Qwen3-0.6B",
    "object": "object",
    "created": 1761718232,
    "owned_by": "nvidia"
  }]
}
```

### Step 12: Send a completion request

```bash
curl http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-0.6B",
    "prompt": "Hello, I am Zombieland Lieutenant. Who are you?",
    "max_tokens": 50
  }'
```

Expected output:
```json
{
  "id": "cmpl-f359deae-c83e-44f4-835f-56bde7707250",
  "choices": [{
    "text": " I will be the leader of the Zombieland unit, and I will be a strong leader. I will fight for the cause of the Zombieland. I will be a fighter and a leader. I will fight for the survival of",
    "index": 0,
    "finish_reason": "length"
  }],
  "created": 1761718290,
  "model": "Qwen/Qwen3-0.6B",
  "system_fingerprint": null,
  "object": "text_completion",
  "usage": null
}
```

### Step 13: Watch the frontend routing in action

```bash
kubectl logs -f $(kubectl get pods -n default -l app=dynamo-grove-0-frontend -o name | head -1) -n default
```

You'll see logs showing the **KV-router in action**:

```
2025-10-29T06:07:27.873483Z  INFO dynamo_llm::kv_router::scheduler: Runtime config found for worker_id: 2733854498618856965
2025-10-29T06:07:30.002718Z  WARN dynamo_llm::kv_router::sequence: Adding worker 2733854498618856972
2025-10-29T06:11:30.354584Z  INFO dynamo_llm::kv_router::scheduler: Formula for 2733854498618856965 with 0 cached blocks: 0.812 = 1.0 * prefill_blocks + decode_blocks = 1.0 * 0.812 + 0.000
2025-10-29T06:11:30.354622Z  INFO dynamo_llm::kv_router::scheduler: Formula for 2733854498618856972 with 0 cached blocks: 0.812 = 1.0 * prefill_blocks + decode_blocks = 1.0 * 0.812 + 0.000
2025-10-29T06:11:30.354647Z  INFO dynamo_llm::kv_router::scheduler: Selected worker: 2733854498618856965, logit: 0.812, cached blocks: 0, total blocks: 39798
```

This shows:
- **Worker discovery**: Frontend detects all decode and prefill workers
- **Smart routing**: Calculates scores based on cached KV blocks and available GPU memory
- **Load balancing**: Selects optimal worker for each request
- **Resource tracking**: Monitors GPU memory blocks (39,798 available blocks!)

## Understanding the Architecture

### How KV-Routing Works

1. **Request arrives** at the frontend router
2. **Router calculates scores** for each worker based on:
   - Cached KV blocks (reduces recomputation)
   - Available GPU memory blocks
   - Current worker load
3. **Router selects** the best worker (highest score)
4. **Worker processes** the request:
   - **Prefill worker**: Handles initial prompt processing
   - **Decode workers**: Handle token generation in parallel
5. **Response returns** through the frontend

### Benefits of Disaggregated Serving

- **Better GPU utilization**: Separate prefill and decode workloads
- **Lower latency**: Parallel decode workers handle multiple requests
- **Intelligent caching**: KV-cache routing reduces redundant computation
- **Scalability**: Add more decode workers as needed

## Advanced Usage

### Send multiple concurrent requests

```bash
for i in {1..5}; do
  curl http://localhost:8000/v1/completions \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"Qwen/Qwen3-0.6B\", \"prompt\": \"Request $i: Tell me a story\", \"max_tokens\": 30}" &
done
```

Watch the frontend logs to see how it balances load across workers!

### Monitor decode workers

```bash
kubectl logs -f $(kubectl get pods -n default -l app=dynamo-grove-0-vllmdecodeworker -o name | head -1) -n default
```

### Monitor prefill worker

```bash
kubectl logs -f $(kubectl get pods -n default -l app=dynamo-grove-0-vllmprefillworker -o name | head -1) -n default
```

### Inspect Grove's PodClique resources

```bash
kubectl get podclique -n default
```

View details of how Grove groups pods:

```bash
kubectl get podclique dynamo-grove-0-vllmdecodeworker -n default -o yaml
```

### Scale workers

Edit the `dynamo-grove.yaml` and change `replicas`:

```yaml
VllmDecodeWorker:
  replicas: 4  # Scale from 2 to 4 decode workers
```

Then apply:

```bash
kubectl apply -f dynamo-grove.yaml
```

### Use k9s for interactive management

```bash
k9s
```

- Press `:pods` to view pods
- Press `:svc` to view services
- Press `:logs` to view logs
- Press `?` for help

## Troubleshooting

### Pods stuck in Pending

Check if storage provisioner is running:

```bash
kubectl get pods -n local-path-storage
kubectl get storageclass
```

If missing, install it:

```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### Check pod status

```bash
kubectl describe pod <pod-name> -n default
```

Look at the "Events" section for errors.

### Check operator logs

```bash
kubectl logs -n vllm-v1-disagg-router deployment/dynamo-platform-dynamo-operator-controller-manager -c manager --tail=50
```

### Restart a pod

```bash
kubectl delete pod <pod-name> -n default
```

It will automatically recreate.

### Check PersistentVolumeClaims

```bash
kubectl get pvc -n vllm-v1-disagg-router
```

### GPU not available

Verify GPU is detected:

```bash
kubectl get nodes -o json | jq '.items[].status.capacity'
```

Should show `nvidia.com/gpu: "1"` or higher.

## Cleanup

### Delete the Dynamo deployment

```bash
kubectl delete -f dynamo-grove.yaml
```

### Uninstall Dynamo platform

```bash
helm uninstall dynamo-platform -n vllm-v1-disagg-router
helm uninstall dynamo-crds -n default
```

### Delete namespace

```bash
kubectl delete namespace vllm-v1-disagg-router
```

### Uninstall storage provisioner (optional)

```bash
kubectl delete -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml
```

## What You Learned

- ✅ Set up Kubernetes with GPU support on Brev
- ✅ Installed storage provisioner for persistent volumes
- ✅ Deployed NVIDIA Dynamo with Grove for distributed inference
- ✅ Configured disaggregated serving with prefill/decode workers
- ✅ Tested KV-cache routing and intelligent load balancing
- ✅ Monitored distributed inference in real-time

## Next Steps

- Try different models (change `Qwen/Qwen3-0.6B` to other HuggingFace models)
- Scale workers up/down based on load
- Implement custom routing policies
- Add monitoring with Prometheus/Grafana
- Explore multi-node deployments with Grove

## Resources

- [Dynamo Documentation](https://docs.nvidia.com/dynamo/)
- [Grove GitHub](https://github.com/ai-dynamo/grove)
- [vLLM Documentation](https://docs.vllm.ai/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

---

**Built with NVIDIA Dynamo, Grove, and vLLM** 🚀
