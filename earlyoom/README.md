# earlyoom - Early Out-Of-Memory Daemon

Prevents system freezes and hangs caused by out-of-memory conditions.

## What it does

**earlyoom** monitors available memory and swap space. When they fall below configurable thresholds, it kills processes to free up resources before the system completely runs out of memory and becomes unresponsive.

This is especially useful for:
- ML workloads that can accidentally consume all memory
- Long-running Jupyter notebooks
- Multi-user development environments
- Any scenario where OOM conditions could freeze the system

## What it installs

- **earlyoom** - The Early OOM daemon (from Ubuntu package or compiled from source)
- **systemd service** - Runs earlyoom automatically at startup
- **Configuration** - Sensible defaults for Brev environments

## Configuration

Default configuration:
- **Memory threshold**: 10% - Starts killing processes when available memory drops below 10%
- **Swap threshold**: 5% - Starts killing processes when available swap drops below 5%
- **Memory reports**: Every 60 seconds to system logs
- **Protected processes**: `sshd` and `systemd` are avoided

The daemon will:
1. Monitor memory/swap continuously
2. When thresholds are breached, select a victim process (highest `oom_score`)
3. Send SIGTERM (graceful shutdown) first
4. If memory doesn't improve, send SIGKILL
5. Log all actions to system journal

## Usage

```bash
bash setup.sh
```

Takes ~1-2 minutes.

## Managing the service

```bash
# Check status and configuration
sudo systemctl status earlyoom

# View live logs
sudo journalctl -u earlyoom -f

# Stop/start service
sudo systemctl stop earlyoom
sudo systemctl start earlyoom

# Disable automatic startup
sudo systemctl disable earlyoom
```

## Customizing thresholds

Edit the configuration:

```bash
sudo systemctl edit earlyoom
```

Example custom configuration:

```ini
[Service]
ExecStart=
# Start killing at 5% available memory, 3% available swap
ExecStart=/usr/bin/earlyoom -m 5 -s 3 -r 300 --avoid '(^|/)sshd$'
```

Then reload:

```bash
sudo systemctl daemon-reload
sudo systemctl restart earlyoom
```

## Command-line options

Key options (see `man earlyoom` or `earlyoom -h` for full list):

- `-m PERCENT` - Minimum available memory % (default: 10)
- `-s PERCENT` - Minimum available swap % (default: 10)
- `-M SIZE` - Minimum available memory in MiB
- `-S SIZE` - Minimum available swap in MiB
- `-r INTERVAL` - Memory report interval in seconds (0 to disable)
- `--avoid REGEX` - Avoid killing processes matching regex
- `--prefer REGEX` - Prefer killing processes matching regex
- `--sort-by-rss` - Kill by largest RSS instead of oom_score
- `--dryrun` - Test mode (don't actually kill processes)

## Monitoring memory

Check current memory status:

```bash
# Human-readable overview
free -h

# Detailed memory info
cat /proc/meminfo | grep -E 'MemTotal|MemAvailable|SwapTotal|SwapFree'

# Watch memory in real-time
watch -n 1 free -h
```

## How it works

Linux's built-in OOM killer only activates when memory is **completely** exhausted, which often means the system has already frozen (no memory left for keyboard input, ssh, etc.).

**earlyoom** runs in userspace and monitors memory proactively:

1. Polls `/proc/meminfo` for `MemAvailable` and `SwapFree`
2. When threshold is breached, scans `/proc/[pid]/` for all processes
3. Selects victim based on `oom_score` (or RSS with `--sort-by-rss`)
4. Sends SIGTERM for graceful shutdown
5. If memory situation doesn't improve, sends SIGKILL
6. Logs all actions to systemd journal

This keeps your system responsive even under extreme memory pressure.

## Use with Brev CLI

```bash
# Start workspace with earlyoom protection
brev start my-workspace \
  --setup-script https://raw.githubusercontent.com/brevdev/setup-scripts/main/earlyoom/setup.sh
```

## References

- **GitHub**: [rfjakob/earlyoom](https://github.com/rfjakob/earlyoom)
- **Man page**: `man earlyoom` (after installation)
- **License**: MIT

## Why earlyoom on Brev?

Brev environments often run:
- Memory-intensive ML models
- Multiple Jupyter kernels
- GPU workloads that can consume large amounts of system RAM
- Background services and development tools

Without protection, a runaway process can freeze your entire environment, requiring a hard reboot. **earlyoom** prevents this by intervening early, keeping your environment responsive and accessible.

