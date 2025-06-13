#!/bin/bash
# pi-setup.sh - Initial Raspberry Pi configuration with proper static IP
# Usage: ./pi-setup.sh <hostname> <static_ip> [interface]

set -e

HOSTNAME=${1:-pi-node}
STATIC_IP=${2:-192.168.0.100}
INTERFACE=${3:-auto}  # auto, eth0, or wlan0
GATEWAY="192.168.0.1"  # Fixed to match your network
DNS="8.8.8.8,1.1.1.1"

echo "🚀 Setting up $HOSTNAME with IP $STATIC_IP"

# Detect active network interface if not specified
if [ "$INTERFACE" = "auto" ]; then
    # Check which interface has an IP
    if ip route | grep -q wlan0; then
        INTERFACE="wlan0"
        echo "📡 Detected WiFi interface (wlan0)"
    elif ip route | grep -q eth0; then
        INTERFACE="eth0"
        echo "🔌 Detected Ethernet interface (eth0)"
    else
        echo "❌ No active network interface found"
        exit 1
    fi
fi

echo "🌐 Configuring static IP on interface: $INTERFACE"

# Update system
sudo apt update && sudo apt upgrade -y

# Set hostname
sudo hostnamectl set-hostname $HOSTNAME
echo "127.0.1.1 $HOSTNAME" | sudo tee -a /etc/hosts

# Method 1: NetworkManager configuration (preferred for WiFi)
if systemctl is-active --quiet NetworkManager; then
    echo "🔧 Using NetworkManager for static IP configuration"
    
    # Get the current connection name
    CONNECTION_NAME=$(nmcli -t -f NAME con show --active | head -n1)
    
    if [ -n "$CONNECTION_NAME" ]; then
        echo "📝 Configuring connection: $CONNECTION_NAME"
        
        # Set static IP using nmcli
        sudo nmcli con mod "$CONNECTION_NAME" ipv4.addresses "$STATIC_IP/24"
        sudo nmcli con mod "$CONNECTION_NAME" ipv4.gateway "$GATEWAY"
        sudo nmcli con mod "$CONNECTION_NAME" ipv4.dns "$DNS"
        sudo nmcli con mod "$CONNECTION_NAME" ipv4.method manual
        
        # Apply the changes
        sudo nmcli con up "$CONNECTION_NAME"
        
        echo "✅ NetworkManager configuration applied"
    else
        echo "⚠️  No active NetworkManager connection found, falling back to dhcpcd"
    fi
fi

# Method 2: dhcpcd configuration (backup/alternative)
echo "🔧 Also configuring dhcpcd as backup"

# Backup original dhcpcd.conf
if [ ! -f /etc/dhcpcd.conf.backup ]; then
    sudo cp /etc/dhcpcd.conf /etc/dhcpcd.conf.backup
fi

# Remove any existing static configuration for this interface
sudo sed -i "/# Static IP configuration for $INTERFACE/,+4d" /etc/dhcpcd.conf

# Add new static IP configuration
sudo tee -a /etc/dhcpcd.conf > /dev/null << EOF

# Static IP configuration for $INTERFACE on $HOSTNAME
interface $INTERFACE
static ip_address=$STATIC_IP/24
static routers=$GATEWAY
static domain_name_servers=$DNS
EOF

# Method 3: systemd-networkd configuration (most reliable)
echo "🔧 Creating systemd-networkd configuration"

sudo mkdir -p /etc/systemd/network

if [ "$INTERFACE" = "wlan0" ]; then
    # WiFi configuration
    sudo tee /etc/systemd/network/25-wireless-static.network > /dev/null << EOF
[Match]
Name=wlan0

[Network]
DHCP=no
Address=$STATIC_IP/24
Gateway=$GATEWAY
DNS=$DNS

[Route]
Gateway=$GATEWAY
EOF
else
    # Ethernet configuration
    sudo tee /etc/systemd/network/20-ethernet-static.network > /dev/null << EOF
[Match]
Name=eth0

[Network]
DHCP=no
Address=$STATIC_IP/24
Gateway=$GATEWAY
DNS=$DNS

[Route]
Gateway=$GATEWAY
EOF
fi

# Enable SSH
sudo systemctl enable ssh
sudo systemctl start ssh

# Configure SSH security (but allow password auth initially for setup)
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
sudo sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
# Keep password auth enabled for now - we'll disable it after key setup
sudo sed -i 's/#PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Restart SSH to apply changes
sudo systemctl restart ssh

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
    docker-compose \
    net-tools \
    iputils-ping

# Add user to docker group
sudo usermod -aG docker $USER

# Enable cgroup memory (required for K3s)
if [ -f /boot/firmware/cmdline.txt ]; then
    # New Pi OS location
    sudo sed -i 's/$/ cgroup_memory=1 cgroup_enable=memory/' /boot/firmware/cmdline.txt
elif [ -f /boot/cmdline.txt ]; then
    # Old Pi OS location
    sudo sed -i 's/$/ cgroup_memory=1 cgroup_enable=memory/' /boot/cmdline.txt
fi

# Display current network configuration
echo ""
echo "📊 Current network configuration:"
ip addr show $INTERFACE | grep -E "inet |link/"

echo ""
echo "✅ Basic setup complete for $HOSTNAME"
echo "🔄 Network interface: $INTERFACE"
echo "🌐 Target static IP: $STATIC_IP"
echo ""
echo "⚠️  IMPORTANT: Please reboot to apply all changes"
echo "🔄 After reboot, verify IP with: ip addr show $INTERFACE"
echo "📝 Then run the SSH key setup script"

# Create a verification script
cat > ~/verify-setup.sh << EOF
#!/bin/bash
echo "🔍 Verifying network setup for $HOSTNAME"
echo "Interface: $INTERFACE"
echo "Expected IP: $STATIC_IP"
echo ""
echo "Current IP configuration:"
ip addr show $INTERFACE | grep inet
echo ""
echo "Routing table:"
ip route
echo ""
echo "DNS configuration:"
cat /etc/resolv.conf
echo ""
echo "Test connectivity:"
ping -c 3 $GATEWAY
EOF

chmod +x ~/verify-setup.sh

echo "📋 Created ~/verify-setup.sh for post-reboot verification"