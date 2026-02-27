#!/bin/bash
# ---------------------------------------------------------
# Automated L2TP/IPsec Split-Tunnel Client Setup
# ---------------------------------------------------------

# Exit immediately if a command exits with a non-zero status
set -e

# --- USER VARIABLES (Update these before running) ---
CONN_NAME="cnn_name" # Define your custom connection name here
REMOTE_IP="host/ip" # The public IP of your remote VPN server
IPSEC_PSK="psk" # Pre-Shared Key
VPN_USER="username"
VPN_PASS="passwd"
TARGET_SUBNET="192.168.X.X/24" # The internal network to route through the VPN

echo "Starting deployment for connection: $CONN_NAME..."

# 1. Update and install ONLY the modern packages 
# This completely avoids installing the legacy 'strongswan-starter' daemon
apt-get update
apt-get install -y charon-systemd strongswan-swanctl libstrongswan-extra-plugins xl2tpd ppp

# 2. Configure strongSwan (IPsec tunnel) using modern vici
cat <<EOF > /etc/swanctl/swanctl.conf
connections {
    $CONN_NAME {
        version = 1
        encap = yes
        remote_addrs = $REMOTE_IP
        local { auth = psk }
        remote { auth = psk }
        children {
            l2tp-transport {
                mode = transport
                # Correct vici syntax for L2TP over IPsec
                local_ts = dynamic[udp]
                remote_ts = dynamic[udp/1701]
                start_action = start
            }
        }
    }
}
secrets {
    ike-psk { secret = "$IPSEC_PSK" }
}
EOF

# 3. Configure xl2tpd (L2TP protocol)
cat <<EOF > /etc/xl2tpd/xl2tpd.conf
[lac $CONN_NAME]
lns = $REMOTE_IP
ppp debug = yes
