#!/usr/bin/env bash
set -euo pipefail

detect_brev_user() {
    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
        echo "$SUDO_USER"
        return
    fi

    for user_home in /home/*; do
        username="$(basename "$user_home")"
        [ "$username" = "launchpad" ] && continue

        if ls "$user_home"/.lifecycle-script-ls-*.log 2>/dev/null | grep -q . || \
           [ -f "$user_home/.verb-setup.log" ] || \
           { [ -L "$user_home/.cache" ] && [ "$(readlink "$user_home/.cache")" = "/ephemeral/cache" ]; }; then
            echo "$username"
            return
        fi
    done

    [ -d "/home/nvidia" ] && echo "nvidia" && return
    [ -d "/home/ubuntu" ] && echo "ubuntu" && return
    echo "ubuntu"
}

if [ "$(id -u)" -eq 0 ] || [ "${USER:-}" = "root" ]; then
    DETECTED_USER="$(detect_brev_user)"
    export USER="$DETECTED_USER"
    export HOME="/home/$DETECTED_USER"
fi

USER_NAME="${USER:-ubuntu}"
USER_HOME="${HOME:-/home/$USER_NAME}"
PORT="${PORT:-8080}"
SERVICE_NAME="${SERVICE_NAME:-code-server}"

echo "==> Using user: $USER_NAME"
echo "==> Using home: $USER_HOME"

echo "==> Updating apt"
sudo apt-get update -y
sudo apt-get install -y curl ca-certificates

echo "==> Installing Claude"
curl -fsSL https://claude.ai/install.sh | bash
echo "Claude installed"

echo "==> Installing Node.js 20"
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

echo "==> Installing Codex"
sudo npm install -g @openai/codex
echo "Codex installed"

echo "==> Installing OpenCode"
curl -fsSL https://opencode.ai/install | bash
echo "OpenCode installed"

echo "==> Ensuring user exists"
if ! id "$USER_NAME" >/dev/null 2>&1; then
    sudo useradd -m -s /bin/bash "$USER_NAME"
    USER_HOME="/home/$USER_NAME"
fi

echo "==> Installing code-server"
curl -fsSL https://code-server.dev/install.sh | sh

echo "==> Writing code-server config"
sudo -u "$USER_NAME" mkdir -p "$USER_HOME/.config/code-server"
sudo tee "$USER_HOME/.config/code-server/config.yaml" >/dev/null <<EOF
bind-addr: 127.0.0.1:${PORT}
auth: none
cert: false
EOF
sudo chown -R "$USER_NAME:$USER_NAME" "$USER_HOME/.config"

echo "==> Creating systemd unit"
sudo tee "/etc/systemd/system/${SERVICE_NAME}.service" >/dev/null <<EOF
[Unit]
Description=code-server
After=network.target

[Service]
Type=simple
User=${USER_NAME}
Group=${USER_NAME}
Environment=HOME=${USER_HOME}
WorkingDirectory=${USER_HOME}
ExecStart=/usr/bin/code-server
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "==> Enabling and starting code-server"
sudo systemctl daemon-reload
sudo systemctl enable --now "${SERVICE_NAME}"

echo
echo "Done."
echo "Claude installed"
echo "Node.js installed: $(node -v)"
echo "npm installed: $(npm -v)"
echo "Codex installed"
echo "OpenCode installed"
echo "code-server running on 127.0.0.1:${PORT} as ${USER_NAME}"
echo
echo "Useful commands:"
echo "  sudo systemctl status ${SERVICE_NAME}"
echo "  sudo journalctl -u ${SERVICE_NAME} -f"
