# Python Development Environment

Simple Python setup with modern tools.

## What it installs

- **pyenv** - Python version management
- **Python 3.11** - Latest stable Python
- **Jupyter Lab** - Interactive notebooks
- **Common packages**: requests, pandas, numpy, matplotlib, seaborn, plotly
- **Dev tools**: ruff, black, pytest, mypy

## Usage

```bash
bash setup.sh
```

Takes ~3-5 minutes.

## What you get

```bash
python --version          # Python 3.11.x
ipython                   # Enhanced Python REPL
jupyter lab               # Start Jupyter Lab
pyenv versions            # See installed Python versions
```

## Examples

**Start Jupyter Lab:**
```bash
jupyter lab --ip=0.0.0.0 --port=8888
```

## ⚠️ Required Port

To access Jupyter Lab from outside Brev, open:
- **8888/tcp** (Jupyter Lab default port)

**Install more packages:**
```bash
pip install transformers torch
```

**Switch Python versions:**
```bash
pyenv install 3.10
pyenv global 3.10
```

