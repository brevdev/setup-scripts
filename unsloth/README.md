# Unsloth

Fast and memory-efficient LLM fine-tuning with LoRA/QLoRA.

## What it installs

- **Unsloth** - 2x faster fine-tuning, 50% less memory
- **PyTorch** - With CUDA support
- **Transformers** - HuggingFace library
- **PEFT** - Parameter-efficient fine-tuning
- **TRL** - Transformer Reinforcement Learning
- **bitsandbytes** - Quantization support
- **Jupyter Lab** - For notebooks

## Features

- **2x faster training** - Optimized kernels for NVIDIA GPUs
- **50% less memory** - Train larger models on single GPU
- **LoRA/QLoRA support** - Parameter-efficient fine-tuning
- **4-bit quantization** - Fit bigger models in VRAM
- **Works with HuggingFace** - Compatible with any transformer model

## ⚠️ Required Port

To access Jupyter Lab from outside Brev, open:
- **8888/tcp** (Jupyter Lab default port)

## Requirements

- NVIDIA GPU (required)
- 8GB+ VRAM recommended
- CUDA 12.1+ (Brev provides this)

## Usage

```bash
bash setup.sh
```

Takes ~5-8 minutes (installs PyTorch and dependencies).

## What you get

After running the setup script:

```bash
python3 ~/unsloth-examples/test_install.py         # Test installation
cd ~/unsloth-notebooks                             # 100+ example notebooks
jupyter lab                                        # Start Jupyter (if not running)
```

The setup script automatically:
- Installs unsloth and all dependencies to your system Python
- Clones the official [unslothai/notebooks](https://github.com/unslothai/notebooks) repository to `~/unsloth-notebooks`
- Works seamlessly with Jupyter Lab (no need to select kernels)

## Quick Example

```python
from unsloth import FastLanguageModel
import torch

# Load model (2x faster!)
model, tokenizer = FastLanguageModel.from_pretrained(
    model_name = "unsloth/llama-3.2-1b-bnb-4bit",
    max_seq_length = 2048,
    dtype = None,
    load_in_4bit = True,
)

# Add LoRA adapters
model = FastLanguageModel.get_peft_model(
    model,
    r = 16,
    target_modules = ["q_proj", "k_proj", "v_proj", "o_proj",
                      "gate_proj", "up_proj", "down_proj"],
    lora_alpha = 16,
    lora_dropout = 0,
    bias = "none",
    use_gradient_checkpointing = True,
)

# Now ready for training!
```

## Fine-tuning Example

```python
from unsloth import FastLanguageModel
from datasets import load_dataset
from trl import SFTTrainer
from transformers import TrainingArguments

# Load model
model, tokenizer = FastLanguageModel.from_pretrained(
    model_name = "unsloth/llama-3.2-1b-bnb-4bit",
    max_seq_length = 2048,
    load_in_4bit = True,
)

# Add LoRA
model = FastLanguageModel.get_peft_model(model, r=16, ...)

# Load dataset
dataset = load_dataset("yahma/alpaca-cleaned", split="train[:1000]")

# Train
trainer = SFTTrainer(
    model = model,
    train_dataset = dataset,
    dataset_text_field = "text",
    max_seq_length = 2048,
    tokenizer = tokenizer,
    args = TrainingArguments(
        per_device_train_batch_size = 2,
        gradient_accumulation_steps = 4,
        warmup_steps = 10,
        max_steps = 60,
        fp16 = True,
        logging_steps = 1,
        output_dir = "outputs",
    ),
)

trainer.train()
model.save_pretrained("lora_model")
```

## Supported Models

Unsloth provides optimized versions of popular models:

**Llama:**
- `unsloth/llama-3.2-1b-bnb-4bit` (Smallest, great for testing)
- `unsloth/llama-3.2-3b-bnb-4bit`
- `unsloth/llama-3.1-8b-bnb-4bit`

**Mistral:**
- `unsloth/mistral-7b-bnb-4bit`
- `unsloth/mistral-7b-instruct-v0.3-bnb-4bit`

**Other:**
- `unsloth/Phi-3-mini-4k-instruct`
- `unsloth/gemma-7b-bnb-4bit`
- `unsloth/qwen2-7b-bnb-4bit`

Or use any HuggingFace model with `FastLanguageModel.from_pretrained()`

## Memory Requirements

| Model Size | 4-bit Quantized | Full Precision |
|------------|-----------------|----------------|
| 1B         | ~2GB VRAM      | ~4GB VRAM     |
| 3B         | ~4GB VRAM      | ~12GB VRAM    |
| 7B         | ~6GB VRAM      | ~28GB VRAM    |
| 13B        | ~10GB VRAM     | ~52GB VRAM    |

With Unsloth + 4-bit quantization, you can fine-tune 7B models on GPUs with just 8GB VRAM!

## Training Tips

**Speed up training:**
- Use `gradient_checkpointing = True`
- Increase `per_device_train_batch_size` if you have VRAM
- Use `fp16 = True` or `bf16 = True`

**Save memory:**
- Use 4-bit quantization (`load_in_4bit = True`)
- Lower `max_seq_length`
- Use smaller LoRA rank (`r = 8` instead of `r = 16`)

**Better results:**
- Train for more steps
- Use higher LoRA rank (`r = 64`)
- Use more training data
- Tune learning rate

## Examples in Repository

Check `~/unsloth-examples/` for:
- `quick_finetune.py` - Test model loading
- `finetune_example.py` - Complete training pipeline

## Track Training

**With Weights & Biases:**
```python
# First: pip install wandb
import wandb
wandb.init(project="my-finetune")

# Then add to TrainingArguments:
args = TrainingArguments(
    report_to="wandb",
    ...
)
```

**With TensorBoard:**
```bash
tensorboard --logdir outputs/runs
```

## Save and Load Models

**Save LoRA adapters:**
```python
model.save_pretrained("lora_model")
tokenizer.save_pretrained("lora_model")
```

**Load for inference:**
```python
from unsloth import FastLanguageModel

model, tokenizer = FastLanguageModel.from_pretrained(
    model_name = "lora_model",
    max_seq_length = 2048,
    dtype = None,
    load_in_4bit = True,
)
```

**Convert to full model:**
```python
model.save_pretrained_merged("full_model", tokenizer, save_method="merged_16bit")
```

## Troubleshooting

**CUDA out of memory:**
- Use smaller model or 4-bit quantization
- Reduce `per_device_train_batch_size`
- Reduce `max_seq_length`
- Lower LoRA rank

**Training is slow:**
- Verify GPU is being used: `nvidia-smi`
- Ensure CUDA is available: `python -c "import torch; print(torch.cuda.is_available())"`
- Use `fp16 = True` in TrainingArguments

**Import errors:**
```bash
python3 -m pip install --upgrade unsloth transformers
```

## Resources

- **GitHub:** https://github.com/unslothai/unsloth
- **Docs:** https://docs.unsloth.ai/
- **Discord:** https://discord.gg/unsloth

