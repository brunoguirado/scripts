#!/bin/bash

# --- Configuration ---
NEW_USER=${1:-dev}
SSH_DIR="/home/$NEW_USER/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root"
  exit 1
fi

echo "--- Initializing Provisioning for user: $NEW_USER ---"

# 1. Create user if it doesn't exist
if id "$NEW_USER" &>/dev/null; then
    echo "User $NEW_USER already exists. Skipping creation."
else
    useradd -m -s /bin/bash "$NEW_USER"
    usermod -aG sudo "$NEW_USER"
    echo "User $NEW_USER created and added to sudo group."
fi

# 2. Setup SSH Directory with strict permissions
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# 3. Input Public Key
echo "Paste the SSH Public Key (starts with ssh-rsa/ssh-ed25519) and press ENTER:"
read -r PUB_KEY < /dev/tty

if [[ -n "$PUB_KEY" ]]; then
    echo "$PUB_KEY" > "$AUTH_KEYS"
    chmod 600 "$AUTH_KEYS"
    chown -R "$NEW_USER":"$NEW_USER" "$SSH_DIR"
    echo "SSH Key deployed successfully."
else
    echo "Error: No key provided. Skipping SSH setup."
fi

# 4. Fix Home Permissions (Ensuring Ownership)
chown -R "$NEW_USER":"$NEW_USER" "/home/$NEW_USER"
chmod 755 "/home/$NEW_USER"

echo "--- Provisioning Complete ---"
echo "Login test: ssh $NEW_USER@<ip>"