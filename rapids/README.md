# RAPIDS - GPU-Accelerated Data Science

⚡ **10-50x faster** pandas, scikit-learn, and NetworkX using NVIDIA GPUs.

## What is RAPIDS?

RAPIDS is NVIDIA's suite of GPU-accelerated data science libraries that provide drop-in replacements for popular Python libraries:

- **cuDF** → GPU pandas (DataFrames on GPU)
- **cuML** → GPU scikit-learn (ML algorithms on GPU)
- **cuGraph** → GPU NetworkX (graph analytics on GPU)
- **Dask-CUDA** → Multi-GPU scaling

## What it installs

- **RAPIDS 24.08** - Full suite (cuDF, cuML, cuGraph)
- **Python 3.11** - In isolated conda environment
- **Jupyter Lab** - For interactive development
- **Example notebook** - Quickstart tutorial
- **Benchmark script** - See the speedup yourself!

## Requirements

- **NVIDIA GPU** (required - Brev provides this!)
- **12GB+ VRAM** recommended (works on 8GB but smaller datasets)
- **CUDA 11.x/12.x** (Brev already has this installed)

## Usage

```bash
bash setup.sh
```

Takes ~8-12 minutes (RAPIDS is a large package).

## ⚠️ Required Port

To access Jupyter Lab from outside Brev, open:
- **8888/tcp** (Jupyter Lab)

## Quick Start

**Run the benchmark:**
```bash
conda activate rapids
python ~/rapids-examples/benchmark.py
```

Expected output:
```
⚡ Speedup: 25.3x faster with GPU!
   pandas: 3.456s
   cuDF:   0.137s
```

**Start Jupyter Lab:**
```bash
conda activate rapids
jupyter lab --ip=0.0.0.0 --port=8888
```

Then open the example notebook: `rapids_quickstart.ipynb`

## Code Examples

### Basic cuDF Usage (Drop-in pandas replacement)

```python
import cudf

# Create GPU DataFrame (same API as pandas!)
df = cudf.DataFrame({
    'a': [1, 2, 3, 4, 5],
    'b': [10, 20, 30, 40, 50]
})

# Standard pandas operations work
print(df.describe())
print(df.groupby('a')['b'].mean())
filtered = df[df['a'] > 2]
```

### Convert Between pandas and cuDF

```python
import pandas as pd
import cudf

# pandas → GPU
df_pandas = pd.read_csv('data.csv')
df_gpu = cudf.from_pandas(df_pandas)

# Do GPU operations...
result = df_gpu.groupby('category').sum()

# GPU → pandas (only when needed)
df_final = result.to_pandas()
```

### GPU Machine Learning with cuML

```python
from cuml.ensemble import RandomForestClassifier
from cuml.model_selection import train_test_split
import cudf

# Load data on GPU
X = cudf.read_csv('features.csv')
y = cudf.read_csv('labels.csv')

# Train on GPU (same API as scikit-learn!)
X_train, X_test, y_train, y_test = train_test_split(X, y)
model = RandomForestClassifier(n_estimators=100)
model.fit(X_train, y_train)
score = model.score(X_test, y_test)

print(f"Accuracy: {score:.3f}")
```

### Multi-GPU with Dask-CUDA

```python
from dask_cuda import LocalCUDACluster
from dask.distributed import Client
import dask_cudf

# Setup multi-GPU cluster
cluster = LocalCUDACluster()
client = Client(cluster)

# Read data distributed across GPUs
df = dask_cudf.read_csv('large_data.csv')

# Operations scale across all GPUs
result = df.groupby('category').mean().compute()
```

## When to Use RAPIDS

### ✅ Great for:

- **Large datasets** (1M+ rows) - Best speedup
- **Repeated operations** - Keep data on GPU
- **ETL pipelines** - Fast data processing
- **Feature engineering** - Batch transformations
- **ML training** - GPU-accelerated models
- **Multi-GPU systems** - Scale with Dask-CUDA

### ⚠️ Less beneficial for:

- **Small datasets** (<100K rows) - GPU transfer overhead
- **One-off queries** - pandas might be simpler
- **Heavy visualization** - Need to transfer to CPU
- **String-heavy data** - Some limitations vs pandas

## Performance Tips

1. **Keep data on GPU**: Minimize `.to_pandas()` calls
2. **Batch operations**: Chain operations before moving to CPU
3. **Right-size datasets**: Best speedup on 1M-100M+ rows
4. **Use appropriate dtypes**: Smaller dtypes = more GPU memory
5. **Multi-GPU**: Use `dask-cuda` for datasets larger than single GPU VRAM

## Common Operations

### Reading Data

```python
import cudf

# CSV (GPU-accelerated parsing!)
df = cudf.read_csv('large_file.csv')

# Parquet (very fast)
df = cudf.read_parquet('data.parquet')

# JSON
df = cudf.read_json('data.json')
```

### GroupBy Operations

```python
# GroupBy + aggregations (massive speedup!)
result = df.groupby('category').agg({
    'revenue': 'sum',
    'users': 'count',
    'score': 'mean'
})
```

### Joins

```python
# GPU-accelerated joins
result = df1.merge(df2, on='key', how='inner')
```

### Sorting

```python
# GPU sort
df_sorted = df.sort_values('column', ascending=False)
```

## Real-World Example: ETL Pipeline

```python
import cudf
import time

start = time.time()

# Read large CSV
df = cudf.read_csv('transactions.csv')  # 10M rows

# Clean data
df = df.dropna()
df['date'] = cudf.to_datetime(df['date'])

# Feature engineering
df['revenue_per_user'] = df['revenue'] / df['users']
df['month'] = df['date'].dt.month

# Aggregations
monthly_stats = df.groupby(['month', 'category']).agg({
    'revenue': 'sum',
    'users': 'count',
    'revenue_per_user': 'mean'
})

# Export
monthly_stats.to_csv('results.csv')

print(f"Pipeline completed in {time.time() - start:.2f}s")
# vs pandas: ~10-30x faster!
```

## Benchmarks

On a typical Brev GPU instance (A10G):

| Dataset Size | Operation | pandas (CPU) | cuDF (GPU) | Speedup |
|-------------|-----------|-------------|-----------|---------|
| 10M rows | GroupBy + Agg | 3.2s | 0.13s | **25x** |
| 10M rows | Sort | 2.8s | 0.09s | **31x** |
| 10M rows | Merge | 4.1s | 0.18s | **23x** |
| 100M rows | Read CSV | 28s | 1.2s | **23x** |

**Your mileage may vary** based on:
- GPU model (A10G, A100, H100, etc.)
- Data characteristics (numeric vs strings)
- Operation complexity

## Multi-GPU Configuration

For Brev instances with multiple GPUs (2x, 4x, 8x):

```python
from dask_cuda import LocalCUDACluster
from dask.distributed import Client
import dask_cudf

# Automatically use all GPUs
cluster = LocalCUDACluster()
client = Client(cluster)

# Read and process across all GPUs
df = dask_cudf.read_csv('huge_file.csv')
result = df.groupby('key').mean().compute()

print(f"Processed across {len(cluster.workers)} GPUs")
```

## Troubleshooting

**Out of memory:**
```python
# Use smaller chunks
df = cudf.read_csv('file.csv', chunksize=1000000)
for chunk in df:
    process(chunk)
```

**CUDA out of memory:**
```bash
# Check GPU memory
nvidia-smi

# Free GPU memory in Python
import gc
import cudf
del df  # Delete large dataframes
gc.collect()
```

**Performance not as expected:**
- Ensure data is large enough (>1M rows)
- Check you're not repeatedly transferring CPU↔GPU
- Profile with `%%time` in Jupyter
- Verify GPU is being used: `nvidia-smi`

**Import errors:**
```bash
# Reactivate environment
conda activate rapids

# Verify installation
python ~/rapids-examples/test_rapids.py
```

## Learning Resources

- **RAPIDS Docs**: https://docs.rapids.ai/
- **cuDF API**: https://docs.rapids.ai/api/cudf/stable/
- **cuML API**: https://docs.rapids.ai/api/cuml/stable/
- **Examples**: https://github.com/rapidsai/notebooks
- **Blog**: https://medium.com/rapids-ai

## Examples Directory

After setup, check `~/rapids-examples/`:

```
~/rapids-examples/
├── benchmark.py              # pandas vs cuDF speed test
├── rapids_quickstart.ipynb   # Interactive tutorial
└── test_rapids.py            # Quick installation test
```

## Comparison with Other Libraries

| Library | Speed | API | GPU Required | Use Case |
|---------|-------|-----|-------------|----------|
| **pandas** | 1x | Native | No | Small/medium data, CPU |
| **Polars** | 3-5x | Different | No | Fast CPU processing |
| **cuDF** | 10-50x | pandas-like | Yes | Large data, GPU available |
| **Dask** | Scales | pandas-like | No | Distributed CPU |
| **Dask-CUDA** | Scales | pandas-like | Yes | Multi-GPU distributed |

## Migration Guide

Converting pandas code to cuDF is usually just changing imports:

```python
# Before (pandas)
import pandas as pd
df = pd.read_csv('data.csv')
result = df.groupby('key').mean()

# After (cuDF) - same code!
import cudf
df = cudf.read_csv('data.csv')
result = df.groupby('key').mean()
```

**Known differences:**
- Some pandas methods not yet implemented
- String operations more limited
- Some differences in `dtype` handling
- Check compatibility: https://docs.rapids.ai/api/cudf/stable/user_guide/PandasCompat.html

## Update RAPIDS

```bash
conda activate rapids
conda update -c rapidsai -c conda-forge -c nvidia rapids
```

## Uninstall

```bash
conda deactivate
conda env remove -n rapids
rm -rf ~/rapids-examples
```

## Why RAPIDS on Brev?

Perfect fit because:

✅ **Brev provides GPUs** - RAPIDS needs them  
✅ **CUDA pre-installed** - No driver hassles  
✅ **Multiple GPU configs** - Scale from 1x to 8x GPUs  
✅ **Pay per minute** - Only pay when processing large datasets  
✅ **Instant setup** - This script handles everything  

## Performance Math

Example workload: Processing 50M row dataset daily

**Without GPU (pandas on CPU):**
- Processing time: ~10 minutes
- Cost: Running instance 24/7

**With GPU (cuDF on Brev):**
- Processing time: ~30 seconds (20x faster)
- Cost: Spin up GPU, process, shut down
- **Result**: Faster + cheaper!

## Get Help

- Check examples: `~/rapids-examples/`
- Run benchmark: `python ~/rapids-examples/benchmark.py`
- Test install: `python ~/rapids-examples/test_rapids.py`
- GPU status: `nvidia-smi`
- RAPIDS docs: https://docs.rapids.ai/

---

**Pro tip**: Keep this in your workflow:
1. Develop/test with pandas on small data
2. Deploy with cuDF on full dataset with GPU
3. Use same code (minimal changes needed)!

