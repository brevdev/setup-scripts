# Brev GPU Instance Types Reference

## Usage

```bash
brev start my-workspace \
  --gpu <instance-type> \
  --setup-script https://raw.githubusercontent.com/...
```

**Default GPU:** `n1-highmem-4:nvidia-tesla-t4:1` (T4 with 16GB VRAM)

---

## Instance Type Patterns

### AWS Pattern
Format: `instance-family.size`
- Example: `g5.xlarge`, `p3.2xlarge`

### GCP Pattern  
Format: `machine-type:gpu-type:gpu-count`
- Example: `n1-highmem-4:nvidia-tesla-t4:1`

---

## AWS GPU Instances

### P4d - A100 (80GB) - Best for large model training
| Instance | GPUs | vCPU | Memory | GPU Memory |
|----------|------|------|--------|------------|
| `p4d.24xlarge` | 8x A100 | 96 | 1152 GB | 640 GB |

### P3 - V100 (16GB/32GB) - Solid all-around
| Instance | GPUs | vCPU | Memory | GPU Memory |
|----------|------|------|--------|------------|
| `p3.2xlarge` | 1x V100 | 8 | 61 GB | 16 GB |
| `p3.8xlarge` | 4x V100 | 32 | 244 GB | 64 GB |
| `p3.16xlarge` | 8x V100 | 64 | 488 GB | 128 GB |
| `p3dn.24xlarge` | 8x V100 | 96 | 768 GB | 256 GB |

### G5 - A10G (24GB) - Best price/performance for inference
| Instance | GPUs | vCPU | Memory | GPU Memory |
|----------|------|------|--------|------------|
| `g5.xlarge` | 1x A10G | 4 | 16 GB | 24 GB |
| `g5.2xlarge` | 1x A10G | 8 | 32 GB | 24 GB |
| `g5.4xlarge` | 1x A10G | 16 | 64 GB | 24 GB |
| `g5.8xlarge` | 1x A10G | 32 | 128 GB | 24 GB |
| `g5.16xlarge` | 1x A10G | 64 | 256 GB | 24 GB |
| `g5.12xlarge` | 4x A10G | 48 | 192 GB | 96 GB |
| `g5.24xlarge` | 4x A10G | 96 | 384 GB | 96 GB |
| `g5.48xlarge` | 8x A10G | 192 | 768 GB | 192 GB |

### G4dn - T4 (16GB) - Economical for inference & light training
| Instance | GPUs | vCPU | Memory | GPU Memory |
|----------|------|------|--------|------------|
| `g4dn.xlarge` | 1x T4 | 4 | 16 GB | 16 GB |
| `g4dn.2xlarge` | 1x T4 | 8 | 32 GB | 16 GB |
| `g4dn.4xlarge` | 1x T4 | 16 | 64 GB | 16 GB |
| `g4dn.8xlarge` | 1x T4 | 32 | 128 GB | 16 GB |
| `g4dn.16xlarge` | 1x T4 | 64 | 256 GB | 16 GB |
| `g4dn.12xlarge` | 4x T4 | 48 | 192 GB | 64 GB |
| `g4dn.metal` | 8x T4 | 96 | 384 GB | 128 GB |

### P2 - K80 (12GB) - Older, budget option
| Instance | GPUs | vCPU | Memory | GPU Memory |
|----------|------|------|--------|------------|
| `p2.xlarge` | 1x K80 | 4 | 61 GB | 12 GB |
| `p2.8xlarge` | 8x K80 | 32 | 488 GB | 96 GB |
| `p2.16xlarge` | 16x K80 | 64 | 732 GB | 192 GB |

### G4ad - Radeon Pro V520 (8GB) - AMD alternative
| Instance | GPUs | vCPU | Memory | GPU Memory |
|----------|------|------|--------|------------|
| `g4ad.xlarge` | 1x Radeon | 4 | 16 GB | 8 GB |
| `g4ad.2xlarge` | 1x Radeon | 8 | 32 GB | 8 GB |
| `g4ad.4xlarge` | 1x Radeon | 16 | 64 GB | 8 GB |
| `g4ad.8xlarge` | 2x Radeon | 32 | 128 GB | 16 GB |
| `g4ad.16xlarge` | 4x Radeon | 64 | 256 GB | 32 GB |

### G3 - M60 (8GB) - Legacy
| Instance | GPUs | vCPU | Memory | GPU Memory |
|----------|------|------|--------|------------|
| `g3s.xlarge` | 1x M60 | 4 | 30.5 GB | 8 GB |
| `g3.4xlarge` | 1x M60 | 16 | 122 GB | 8 GB |
| `g3.8xlarge` | 2x M60 | 32 | 244 GB | 16 GB |
| `g3.16xlarge` | 4x M60 | 64 | 488 GB | 32 GB |

---

## GCP GPU Instances (T4 only)

Format: `machine-type:nvidia-tesla-t4:gpu-count`

### N1 Standard (Balanced CPU/Memory)
| Instance | GPUs | vCPU | Memory | Example Usage |
|----------|------|------|--------|---------------|
| `n1-standard-4:nvidia-tesla-t4:1` | 1x T4 | 4 | 15 GB | Light inference |
| `n1-standard-8:nvidia-tesla-t4:1` | 1x T4 | 8 | 30 GB | Training |
| `n1-standard-16:nvidia-tesla-t4:2` | 2x T4 | 16 | 60 GB | Multi-GPU training |
| `n1-standard-32:nvidia-tesla-t4:4` | 4x T4 | 32 | 120 GB | Large-scale training |

### N1 High-CPU (More CPU, less memory)
| Instance | GPUs | vCPU | Memory | Example Usage |
|----------|------|------|--------|---------------|
| `n1-highcpu-4:nvidia-tesla-t4:1` | 1x T4 | 4 | 3.6 GB | CPU-intensive inference |
| `n1-highcpu-8:nvidia-tesla-t4:1` | 1x T4 | 8 | 7.2 GB | Data preprocessing |
| `n1-highcpu-16:nvidia-tesla-t4:2` | 2x T4 | 16 | 14.4 GB | Parallel workloads |
| `n1-highcpu-32:nvidia-tesla-t4:4` | 4x T4 | 32 | 28.8 GB | High-throughput |

### N1 High-Memory (More memory) - **DEFAULT**
| Instance | GPUs | vCPU | Memory | Example Usage |
|----------|------|------|--------|---------------|
| `n1-highmem-2:nvidia-tesla-t4:1` | 1x T4 | 2 | 13 GB | Memory-intensive |
| **`n1-highmem-4:nvidia-tesla-t4:1`** ✅ | 1x T4 | 4 | 26 GB | **DEFAULT** |
| `n1-highmem-8:nvidia-tesla-t4:1` | 1x T4 | 8 | 52 GB | Large models |
| `n1-highmem-16:nvidia-tesla-t4:2` | 2x T4 | 16 | 104 GB | Multi-GPU training |
| `n1-highmem-32:nvidia-tesla-t4:4` | 4x T4 | 32 | 208 GB | Large-scale training |

### N1 Ultra-Memory / Mega-Memory (Massive RAM)
| Instance | GPUs | vCPU | Memory | Example Usage |
|----------|------|------|--------|---------------|
| `n1-ultramem-40:nvidia-tesla-t4:1` | 1x T4 | 40 | 961 GB | Huge datasets in RAM |
| `n1-ultramem-80:nvidia-tesla-t4:2` | 2x T4 | 80 | 1922 GB | Extreme memory needs |
| `n1-megamem-96:nvidia-tesla-t4:4` | 4x T4 | 96 | 1433 GB | Maximum capacity |

---

## Quick Reference by Use Case

### 💡 **Inference (Cost-Optimized)**
```bash
# T4 - Best value
--gpu g4dn.xlarge                            # AWS: 1x T4
--gpu n1-highmem-4:nvidia-tesla-t4:1        # GCP: 1x T4 (default)

# A10G - Better performance
--gpu g5.xlarge                              # AWS: 1x A10G
```

### 🏋️ **Training Small Models (< 7B parameters)**
```bash
# Single GPU
--gpu g5.2xlarge                             # AWS: 1x A10G
--gpu n1-highmem-8:nvidia-tesla-t4:1        # GCP: 1x T4

# Multi-GPU
--gpu g5.12xlarge                            # AWS: 4x A10G
--gpu n1-highmem-16:nvidia-tesla-t4:2       # GCP: 2x T4
```

### 🚀 **Training Medium Models (7B-13B parameters)**
```bash
# Multi-GPU required
--gpu g5.12xlarge                            # AWS: 4x A10G
--gpu p3.8xlarge                             # AWS: 4x V100
--gpu n1-highmem-32:nvidia-tesla-t4:4       # GCP: 4x T4
```

### 🔥 **Training Large Models (70B+ parameters)**
```bash
# Need A100 or 8x GPUs
--gpu p4d.24xlarge                           # AWS: 8x A100 (80GB each)
--gpu g5.48xlarge                            # AWS: 8x A10G
--gpu p3.16xlarge                            # AWS: 8x V100
```

### 🎨 **Stable Diffusion / Image Generation**
```bash
# SDXL needs ~16GB VRAM
--gpu g5.xlarge                              # AWS: 1x A10G (24GB)
--gpu g4dn.xlarge                            # AWS: 1x T4 (16GB)
--gpu n1-highmem-4:nvidia-tesla-t4:1        # GCP: 1x T4 (16GB)
```

### 🤖 **Fine-Tuning with LoRA/QLoRA**
```bash
# Single GPU sufficient
--gpu g5.xlarge                              # AWS: 1x A10G
--gpu n1-highmem-4:nvidia-tesla-t4:1        # GCP: 1x T4 (default)
```

---

## Complete Valid Instance Types

Copy-paste for reference:

### AWS Instances
```
p4d.24xlarge
p3.2xlarge p3.8xlarge p3.16xlarge p3dn.24xlarge
p2.xlarge p2.8xlarge p2.16xlarge
g5.xlarge g5.2xlarge g5.4xlarge g5.8xlarge g5.16xlarge g5.12xlarge g5.24xlarge g5.48xlarge
g5g.xlarge g5g.2xlarge g5g.4xlarge g5g.8xlarge g5g.16xlarge g5g.metal
g4dn.xlarge g4dn.2xlarge g4dn.4xlarge g4dn.8xlarge g4dn.16xlarge g4dn.12xlarge g4dn.metal
g4ad.xlarge g4ad.2xlarge g4ad.4xlarge g4ad.8xlarge g4ad.16xlarge
g3s.xlarge g3.4xlarge g3.8xlarge g3.16xlarge
```

### GCP Instances (T4)
See full list in `brev-cli/pkg/instancetypes/instancetypes.go` - over 60 combinations of:
- Machine types: `n1-standard`, `n1-highcpu`, `n1-highmem`, `n1-ultramem`, `n1-megamem`
- GPU counts: `:1`, `:2`, `:4`
- All with `:nvidia-tesla-t4:`

---

## Examples

```bash
# Default (GCP T4)
brev start my-workspace \
  --setup-script https://raw.githubusercontent.com/.../setup.sh

# AWS A10G (good price/performance)
brev start my-workspace \
  --gpu g5.xlarge \
  --setup-script https://raw.githubusercontent.com/.../setup.sh

# AWS V100 (4x for larger models)
brev start my-workspace \
  --gpu p3.8xlarge \
  --setup-script https://raw.githubusercontent.com/.../setup.sh

# GCP T4 with more memory
brev start my-workspace \
  --gpu n1-highmem-8:nvidia-tesla-t4:1 \
  --setup-script https://raw.githubusercontent.com/.../setup.sh

# GCP T4 multi-GPU (2x)
brev start my-workspace \
  --gpu n1-highmem-16:nvidia-tesla-t4:2 \
  --setup-script https://raw.githubusercontent.com/.../setup.sh
```

---

## Notes

1. **Default is GCP T4**: If you don't specify `--gpu`, you get `n1-highmem-4:nvidia-tesla-t4:1`
2. **AWS vs GCP**: AWS has more GPU variety (A100, V100, A10G), GCP only has T4 in this list
3. **Multi-GPU**: GCP pattern shows GPU count explicitly (`:1`, `:2`, `:4`), AWS uses instance size
4. **Pricing**: Generally T4 < A10G < V100 < A100
5. **Availability**: Not all instance types available in all regions

---

## Source

Definitive list maintained in: `brev-cli/pkg/instancetypes/instancetypes.go`

