#!/bin/bash
# prepare-nodes.sh - Prepare all Pi nodes for K3s

set -e

NODES=("pi-master" "pi-worker-1" "pi-worker-2" "pi-worker-3")

echo "🔧 Preparing all Pi nodes for K3s installation"

prepare_node() {
    local node=$1
    echo "📋 Preparing $node..."
    
    ssh $node << 'EOF'
# Update system
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install required packages
echo "📦 Installing required packages..."
sudo apt install -y curl wget git htop nano

# Enable cgroups (required for K3s)
echo "⚙️  Configuring cgroups..."
if ! grep -q "cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1" /boot/firmware/cmdline.txt 2>/dev/null; then
    if [ -f /boot/firmware/cmdline.txt ]; then
        sudo sed -i '$ s/$/ cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1/' /boot/firmware/cmdline.txt
    elif [ -f /boot/cmdline.txt ]; then
        sudo sed -i '$ s/$/ cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1/' /boot/cmdline.txt
    fi
    echo "✅ cgroups enabled (reboot required)"
    touch /var/run/reboot-required
else
    echo "✅ cgroups already enabled"
fi

# Disable swap (K3s requirement)
echo "⚙️  Disabling swap..."
sudo dphys-swapfile swapoff 2>/dev/null || true
sudo dphys-swapfile uninstall 2>/dev/null || true
sudo update-rc.d dphys-swapfile remove 2>/dev/null || true
sudo systemctl disable dphys-swapfile 2>/dev/null || true

# Set timezone
echo "🕐 Setting timezone..."
sudo timedatectl set-timezone America/New_York

# Show system info
current_hostname=$(hostname)
echo "📊 System information for $current_hostname:"
echo "   OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "   Kernel: $(uname -r)"
echo "   Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "   IP: $(hostname -I | awk '{print $1}')"

echo "✅ Node preparation complete"
EOF

    if [ $? -eq 0 ]; then
        echo "✅ $node prepared successfully"
    else
        echo "❌ Failed to prepare $node"
        return 1
    fi
}

# Prepare all nodes in parallel for speed
echo "🚀 Preparing all nodes (this may take a few minutes)..."

for node in "${NODES[@]}"; do
    prepare_node $node &
done

# Wait for all background jobs to complete
wait

echo "🎉 All nodes prepared!"