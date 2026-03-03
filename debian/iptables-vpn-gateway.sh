#!/bin/bash
# ---------------------------------------------------------
# Turn Server into a VPN Gateway (NAT & IP Forwarding)
# ---------------------------------------------------------

# Exit immediately if a command exits with a non-zero status
set -e

echo "Configuring Server as a VPN Gateway..."

# 1. Enable Kernel IP Forwarding (Senior Method: Isolated config file)
# This allows the Linux kernel to route packets between different interfaces
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-vpn-gateway.conf
sysctl --system

# 2. Install iptables-persistent non-interactively
# This ensures our NAT rules survive a server reboot
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y iptables iptables-persistent

# 3. Explicitly ALLOW Forwarding between interfaces
# Allow traffic coming from anywhere to go out via ppp0
iptables -C FORWARD -i eth0 -o ppp0 -j ACCEPT 2>/dev/null || \
iptables -A FORWARD -i eth0 -o ppp0 -j ACCEPT

# Allow established return traffic from ppp0 back to the origin
iptables -C FORWARD -i ppp0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
iptables -A FORWARD -i ppp0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# 4. Configure Outbound NAT (Masquerade)
iptables -t nat -C POSTROUTING -o ppp0 -j MASQUERADE 2>/dev/null || \
iptables -t nat -A POSTROUTING -o ppp0 -j MASQUERADE

# 5. Save the iptables rules persistently
netfilter-persistent save

echo "---------------------------------------------------------"
echo "Gateway Setup Complete!"
echo "Other machines routing through this server can now reach the VPN."
echo ""
echo "Add a static route on macOS/Windows pointing to the Linux VPN Server"
echo "Replace LINUX_SERVER_IP with the actual IP address of your Linux machine"
echo "sudo route -n delete -net 192.168.X.X/24"
echo "sudo route -n add -net 192.168.X.X/24 LINUX_SERVER_IP"
echo ""
echo "---------------------------------------------------------"
