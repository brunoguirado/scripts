#!/usr/bin/env bash

# Secure OpenClaw Installation Script for Debian
# This script installs OpenClaw securely using a dedicated non-root user.

set -euo pipefail

# --- 1. Pre-flight Checks ---

if [[ "$EUID" -ne 0 ]]; then
    echo "Error: This script must be run as root to install dependencies and configure users."
    exit 1
fi

echo "=> Proceeding with secure OpenClaw installation as root."

# --- 2. Install System Dependencies ---

echo "=> Updating system and installing required packages..."
apt-get update
apt-get install -y curl gnupg ca-certificates apt-transport-https sudo git

# --- 3. Install Node.js (v24 or v22.16+ recommended) ---

echo "=> Installing Node.js from NodeSource..."
# OpenClaw recommends Node.js 24
NODE_MAJOR=24

# Set up NodeSource keyring and repository
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg || true
# Ensure keyring is updated if already exists
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor --yes -o /etc/apt/keyrings/nodesource.gpg

echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list

apt-get update
apt-get install -y nodejs

# Verify Node.js installation
node_version=$(node -v)
echo "=> Installed Node.js version: $node_version"

# --- 4. Prepare Service Account and Directories ---

OPENCLAW_USER="openclaw"
OPENCLAW_HOME="/opt/openclaw"
OPENCLAW_STATE="$OPENCLAW_HOME/state"
OPENCLAW_CONFIG="$OPENCLAW_HOME/config"

echo "=> Creating dedicated system user '$OPENCLAW_USER'..."
if ! id -u "$OPENCLAW_USER" >/dev/null 2>&1; then
    useradd --system \
            --shell /usr/sbin/nologin \
            --home-dir "$OPENCLAW_HOME" \
            --user-group \
            "$OPENCLAW_USER"
    echo "-> User '$OPENCLAW_USER' created."
else
    echo "-> User '$OPENCLAW_USER' already exists."
fi

echo "=> Creating secured directory structure under $OPENCLAW_HOME..."
mkdir -p "$OPENCLAW_STATE"
mkdir -p "$OPENCLAW_CONFIG"

# Set restrictive permissions
chown -R "$OPENCLAW_USER":"$OPENCLAW_USER" "$OPENCLAW_HOME"
chmod 700 "$OPENCLAW_HOME"
chmod 700 "$OPENCLAW_STATE"
chmod 700 "$OPENCLAW_CONFIG"

# --- 5. Install OpenClaw ---

echo "=> Installing OpenClaw scoped to $OPENCLAW_USER..."
# Configure npm for the openclaw user to install globally within its restricted home directory
sudo -u "$OPENCLAW_USER" bash -c "mkdir -p $OPENCLAW_HOME/.npm-global"
sudo -u "$OPENCLAW_USER" bash -c "npm config set prefix '$OPENCLAW_HOME/.npm-global'"

# Install openclaw
echo "-> Running npm install openclaw..."
sudo -u "$OPENCLAW_USER" bash -c "npm install -g openclaw@latest"

# The binary should be available at $OPENCLAW_HOME/.npm-global/bin/openclaw
OPENCLAW_BIN="$OPENCLAW_HOME/.npm-global/bin/openclaw"
if [[ ! -f "$OPENCLAW_BIN" ]]; then
    echo "Error: OpenClaw installation failed or binary not found at $OPENCLAW_BIN"
    exit 1
fi
echo "-> OpenClaw installed successfully at $OPENCLAW_BIN"

# --- 6. Set up Systemd Service ---

SERVICE_FILE="/etc/systemd/system/openclaw.service"
echo "=> Creating secure systemd service at $SERVICE_FILE..."

cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=OpenClaw Gateway Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$OPENCLAW_USER
Group=$OPENCLAW_USER

# Environment paths overriding settings for security
Environment="OPENCLAW_HOME=$OPENCLAW_HOME"
Environment="OPENCLAW_STATE_DIR=$OPENCLAW_STATE"
Environment="OPENCLAW_CONFIG_PATH=$OPENCLAW_CONFIG"
Environment="PATH=$OPENCLAW_HOME/.npm-global/bin:/usr/bin:/bin"

# ExecStart using the installed binary
ExecStart=$OPENCLAW_BIN gateway start

Restart=on-failure
RestartSec=5

# ---- Security Hardening ----
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
NoNewPrivileges=true
ProtectKernelLogs=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictRealtime=true
# ----------------------------

[Install]
WantedBy=multi-user.target
EOF

# Ensure correct permissions on the service file
chmod 644 "$SERVICE_FILE"

# --- 7. Enable and Start Service ---

echo "=> Reloading systemd and enabling OpenClaw service..."
systemctl daemon-reload
systemctl enable openclaw.service
systemctl start openclaw.service

echo -e "\e[1;32m=======================================================================\e[0m"
echo -e "\e[1;32mOpenClaw Installation Complete!\e[0m"
echo "The gateway relies on systemd service 'openclaw.service'."
echo "To check the service status, run: systemctl status openclaw"
echo "To view gateway logs securely:    journalctl -u openclaw -f"
echo ""
echo -e "\e[1;31m===================== ⚠️  ATENÇÃO: PASSO OBRIGATÓRIO ⚠️  =====================\e[0m"
echo -e "\e[1;33mO serviço OpenClaw só funcionará perfeitamente e o gateway vai iniciar\e[0m"
echo -e "\e[1;33mapós você rodar o ONBOARDING inicial para definir as chaves de API.\e[0m"
echo ""
echo -e "\e[1;37mExecute COMANDO ABAIXO agora mesmo no seu terminal para configurar:\e[0m"
echo ""
echo -e "\e[1;36msudo -u $OPENCLAW_USER -H bash -c \"export PATH=$OPENCLAW_HOME/.npm-global/bin:\\\$PATH && openclaw onboard\"\e[0m"
echo ""
echo -e "\e[1;31m=============================================================================\e[0m"
