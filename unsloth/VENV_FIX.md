# Virtual Environment Fix for Brev Setup Script

## Problem

After running `setup.sh`, notebooks still had to install `unsloth` and dependencies inside Jupyter Lab, even though the setup script completed successfully.

## Root Cause

**Environment Mismatch:**
- **setup.sh**: Installed packages using system `python3` 
  - Packages went to: `/usr/local/lib/python3.x/` or `/usr/lib/python3.x/`
- **Jupyter Lab**: Kernel configured to use `~/.venv/bin/python3`
  - Looked for packages in: `~/.venv/lib/python3.x/site-packages/`

```
┌─────────────────────────────────────────┐
│  setup.sh (as root/system)              │
│  ├─ Uses: python3                       │
│  └─ Installs to: /usr/lib/python3.x/   │
└─────────────────────────────────────────┘
                  ⬇️
        ❌ Packages not visible to...
                  ⬇️
┌─────────────────────────────────────────┐
│  Jupyter Lab (as nvidia user)           │
│  ├─ Uses: ~/.venv/bin/python3           │
│  └─ Looks in: ~/.venv/lib/.../packages │
└─────────────────────────────────────────┘
```

## Solution

**Detect and use Brev's virtual environment:**

```bash
# Before (old code)
python3 -m pip install unsloth

# After (new code)
PYTHON_BIN="python3"
if [ -f "$HOME/.venv/bin/python3" ]; then
    PYTHON_BIN="$HOME/.venv/bin/python3"
    export PATH="$HOME/.venv/bin:$PATH"
fi

$PYTHON_BIN -m pip install unsloth
```

## Changes Made

1. **Detect venv**: Check if `~/.venv/bin/python3` exists
2. **Set variables**: `$PYTHON_BIN` and `$PIP_BIN` point to venv or system
3. **Update all commands**:
   - Package installation: `$PYTHON_BIN -m pip install ...`
   - Kernel registration: `$PYTHON_BIN -m ipykernel install ...`
   - Verification: `$PYTHON_BIN -c "import unsloth"`
4. **Kernel config**: Update `kernel.json` to use `$PYTHON_BIN` path

## Result

✅ **Packages installed in setup.sh are now immediately available in Jupyter notebooks**

The notebooks will:
1. Check if `unsloth` is already installed → ✅ Found!
2. Skip installation
3. Proceed directly to model loading

## Testing

To verify the fix works:

```bash
# 1. Run setup script
bash setup.sh

# 2. Check unsloth is in venv
~/.venv/bin/python3 -c "from unsloth import FastLanguageModel; print('✓ Available')"

# 3. Start Jupyter Lab
jupyter lab

# 4. Open any notebook and run first cell
# Should see: "✅ Unsloth already available"
# Should NOT see: "⚠️ Unsloth not found - will install"
```

## Compatibility

- ✅ Works with Brev venv at `~/.venv`
- ✅ Falls back to system Python if no venv
- ✅ Compatible with both `uv` and `pip`
- ✅ Still under 16KB Brev lifecycle script limit (10.5KB)

