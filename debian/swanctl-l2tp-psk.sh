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
pppoptfile = /etc/ppp/options.l2tpd.$CONN_NAME
length bit = yes
EOF

# 4. Configure pppd (Authentication and parameters)
cat <<EOF > /etc/ppp/options.l2tpd.$CONN_NAME
ipcp-accept-local
ipcp-accept-remote
refuse-eap
require-mschap-v2
noccp
noauth
mtu 1410
mru 1410
usepeerdns
connect-delay 5000
name $VPN_USER
password $VPN_PASS
EOF

# 5. Create dynamic routing hooks for the target subnet
cat <<EOF > /etc/ppp/ip-up.d/${CONN_NAME}-route
#!/bin/bash
# Automatically add route when the VPN interface goes up
if [ "\$PPP_IFACE" == "ppp0" ]; then
    ip route add $TARGET_SUBNET dev \$PPP_IFACE
fi
EOF
chmod +x /etc/ppp/ip-up.d/${CONN_NAME}-route

cat <<EOF > /etc/ppp/ip-down.d/${CONN_NAME}-route
#!/bin/bash
# Automatically remove route when the VPN interface goes down
if [ "\$PPP_IFACE" == "ppp0" ]; then
    ip route del $TARGET_SUBNET dev \$PPP_IFACE
fi
EOF
chmod +x /etc/ppp/ip-down.d/${CONN_NAME}-route

# 6. Apply configurations and restart services
echo "Starting modern services..."

# Enable and start the modern daemon natively
systemctl enable --now strongswan xl2tpd
systemctl restart strongswan xl2tpd

# Brief pause to ensure the vici socket is fully created
sleep 2

# Load configurations into the charon-systemd daemon
swanctl --load-all

echo "---------------------------------------------------------"
echo "Deployment Complete!"
echo "To connect:    echo 'c $CONN_NAME' > /var/run/xl2tpd/l2tp-control"
echo "To disconnect: echo 'd $CONN_NAME' > /var/run/xl2tpd/l2tp-control"
echo "To check IPsec status: swanctl --list-sas"
echo "---------------------------------------------------------"

