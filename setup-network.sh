#!/bin/bash
# setup-network.sh - Configure network settings on all nodes

set -e

declare -A NODES=(
    ["pi-master"]="192.168.1.10"
    ["pi-worker-1"]="192.168.1.11"
    ["pi-worker-2"]="192.168.1.12"
    ["pi-worker-3"]="192.168.1.13"
)

GATEWAY="192.168.1.1"
DNS="8.8.8.8,1.1.1.1"

echo "🌐 Configuring network for all Pi nodes"

for hostname in "${!NODES[@]}"; do
    ip=${NODES[$hostname]}
    
    echo "📡 Configuring $hostname with IP $ip"
    
    # Run network configuration on remote node
    ssh $hostname "sudo tee /etc/dhcpcd.conf > /dev/null" << EOF
# Static IP configuration for $hostname
interface eth0
static ip_address=$ip/24
static routers=$GATEWAY
static domain_name_servers=$DNS

# Fallback to DHCP if static fails
profile static_eth0
static ip_address=$ip/24
static routers=$GATEWAY
static domain_name_servers=$DNS

interface eth0
fallback static_eth0
EOF

    # Update hostname
    ssh $hostname "sudo hostnamectl set-hostname $hostname"
    
    # Update /etc/hosts with all cluster nodes
    ssh $hostname "sudo tee -a /etc/hosts > /dev/null" << EOF

# Pi Cluster nodes
$(for h in "${!NODES[@]}"; do
    echo "${NODES[$h]} $h"
done)
EOF

    echo "✅ Network configured for $hostname"
done

echo "🔄 Restarting networking on all nodes..."
for hostname in "${!NODES[@]}"; do
    ssh $hostname "sudo systemctl restart dhcpcd" &
done
wait

echo "🎉 Network configuration complete!"