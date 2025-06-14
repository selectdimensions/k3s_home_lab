#!/bin/bash
# setup-network.sh - Configure network settings on all nodes

set -e

# Use hostnames from SSH config instead of declaring IPs again
NODES=("pi-master" "pi-worker-1" "pi-worker-2" "pi-worker-3")
declare -A NODE_IPS=(
    ["pi-master"]="192.168.0.120"
    ["pi-worker-1"]="192.168.0.121"
    ["pi-worker-2"]="192.168.0.122"
    ["pi-worker-3"]="192.168.0.123"
)

GATEWAY="192.168.0.1"
DNS="8.8.8.8,1.1.1.1"

echo "🌐 Configuring network for all Pi nodes"

for hostname in "${NODES[@]}"; do
    ip=${NODE_IPS[$hostname]}
    echo "📡 Configuring $hostname with IP $ip"

    # Check if configuration already exists
    if ssh $hostname "grep -q 'Static IP configuration for $hostname' /etc/dhcpcd.conf" 2>/dev/null; then
        echo "✅ Network configuration already exists for $hostname, skipping..."
        continue
    fi

    # Run network configuration on remote node
    ssh $hostname "sudo tee -a /etc/dhcpcd.conf > /dev/null" << EOF

# Static IP configuration for $hostname - Added $(date)
interface eth0
static ip_address=$ip/24
static routers=$GATEWAY
static domain_name_servers=$DNS
EOF

    # Update hostname if different
    current_hostname=$(ssh $hostname "hostname")
    if [ "$current_hostname" != "$hostname" ]; then
        ssh $hostname "sudo hostnamectl set-hostname $hostname"
        echo "🏷️  Updated hostname from $current_hostname to $hostname"
    fi
    
    # Update /etc/hosts with all cluster nodes
    if ! ssh $hostname "grep -q 'Pi Cluster nodes' /etc/hosts" 2>/dev/null; then
        ssh $hostname "sudo tee -a /etc/hosts > /dev/null" << EOF

# Pi Cluster nodes - Added $(date)
$(for h in "${NODES[@]}"; do
    echo "${NODE_IPS[$h]} $h"
done)
EOF
        echo "🌐 Updated /etc/hosts for $hostname"
    fi

    echo "✅ Network configured for $hostname"
done

echo "🎉 Network configuration complete!"
echo "💡 Changes will take effect after reboot"