#!/bin/bash
# setup-system.sh - Configure system settings on all nodes

set -e

NODES=("pi-master" "pi-worker-1" "pi-worker-2" "pi-worker-3")

echo "⚙️  Configuring system settings on all nodes..."

for node in "${NODES[@]}"; do
    echo "📋 Configuring $node..."
    
    ssh $node << 'EOF'
# Configure DNS for better resolution
echo "🌐 Configuring DNS..."
if [ ! -f /etc/resolv.conf.head ]; then
    echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf.head > /dev/null
    echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf.head > /dev/null
fi

# Optimize system settings for K3s
echo "🧠 Optimizing system settings..."
if ! grep -q "vm.max_map_count" /etc/sysctl.conf 2>/dev/null; then
    echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf
    echo 'fs.inotify.max_user_instances=1024' | sudo tee -a /etc/sysctl.conf
    echo 'fs.inotify.max_user_watches=1048576' | sudo tee -a /etc/sysctl.conf
    echo "✅ System parameters added"
else
    echo "✅ System parameters already configured"
fi

# Configure log rotation to prevent disk fill
echo "📝 Configuring log rotation..."
sudo mkdir -p /etc/docker
if [ ! -f /etc/docker/daemon.json ]; then
    cat | sudo tee /etc/docker/daemon.json << EOL
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOL
    echo "✅ Docker logging configured"
fi

echo "✅ System configuration complete"
EOF

    echo "✅ $node configured"
done

echo "🎉 System configuration complete on all nodes!"