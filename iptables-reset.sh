#!/bin/bash
# ---------------------------------------------------------
# Safe iptables Flush & Reset (Senior Method)
# ---------------------------------------------------------

echo "Resetting iptables to default state..."

# 1. Set default policies to ACCEPT 
# CRITICAL: This prevents SSH lockout when rules are flushed.
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# 2. Flush all rules across all standard tables
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -t raw -F
iptables -t raw -X

# 3. Save the empty state persistently
# If you skip this, your old rules will return the next time the server reboots.
netfilter-persistent save

echo "---------------------------------------------------------"
echo "iptables successfully cleared and saved!"
echo "---------------------------------------------------------"
