#!/bin/bash
# pi-setup.sh - Initial Raspberry Pi configuration
# Usage: ./pi-setup.sh <hostname> <static_ip>

set -e

HOSTNAME=${1:-pi-node}
STATIC_IP=${2:-192.168.1.100}
GATEWAY="192.168.1.1"  # Adjust for your network
DNS="8.8.8.8,1.1.1.1"

echo "🚀 Setting up $HOSTNAME with IP $STATIC_IP"

# Update system
sudo apt update && sudo apt upgrade -y

# Set hostname
sudo hostnamectl set-hostname $HOSTNAME
echo "127.0.1.1 $HOSTNAME" | sudo tee -a /etc/hosts

# Configure static IP
sudo tee /etc/dhcpcd.conf.backup > /dev/null << EOF
# Backup of original dhcpcd.conf made $(date)
$(cat /etc/dhcpcd.conf)
EOF

sudo tee -a /etc/dhcpcd.conf > /dev/null << EOF

# Static IP configuration for $HOSTNAME
interface eth0
static ip_address=$STATIC_IP/24
static routers=$GATEWAY
static domain_name_servers=$DNS
EOF

# Enable SSH
sudo systemctl enable ssh
sudo systemctl start ssh

# Configure SSH security
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Create SSH directory for current user
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Install essential packages
sudo apt install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    docker.io \
    docker-compose

# Add user to docker group
sudo usermod -aG docker $USER

# Enable cgroup memory (required for K3s)
sudo sed -i 's/$/ cgroup_memory=1 cgroup_enable=memory/' /boot/firmware/cmdline.txt

echo "✅ Basic setup complete for $HOSTNAME"
echo "⚠️  Please reboot to apply all changes"
echo "📝 After reboot, run the SSH key setup script"