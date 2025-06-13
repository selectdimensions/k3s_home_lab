#!/bin/bash
# setup-ssh-keys.sh - Distribute SSH keys to all Pi nodes

set -e

NODES=("pi-master:192.168.1.120" "pi-worker-1:192.168.1.121" "pi-worker-2:192.168.1.122" "pi-worker-3:192.168.1.123")
SSH_KEY_NAME="pi_cluster_key"
USERNAME="hezekiah"  # Change to your username

echo "🔐 Setting up SSH keys for Pi cluster"

# Generate SSH key if it doesn't exist
if [ ! -f ~/.ssh/$SSH_KEY_NAME ]; then
    echo "🔑 Generating new SSH key..."
    ssh-keygen -t ed25519 -f ~/.ssh/$SSH_KEY_NAME -C "$USERNAME@pi-cluster" -N ""
fi

# Create SSH config
cat > ~/.ssh/config << EOF
# Pi Cluster SSH Configuration
$(for node_info in "${NODES[@]}"; do
    hostname=$(echo $node_info | cut -d: -f1)
    ip=$(echo $node_info | cut -d: -f2)
    cat << EOL

Host $hostname
    HostName $ip
    User $USERNAME
    IdentityFile ~/.ssh/$SSH_KEY_NAME
    IdentitiesOnly yes
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

EOL
done)
EOF

echo "📋 SSH config created"

# Copy public key to all nodes
for node_info in "${NODES[@]}"; do
    hostname=$(echo $node_info | cut -d: -f1)
    ip=$(echo $node_info | cut -d: -f2)
    
    echo "📤 Copying SSH key to $hostname ($ip)..."
    
    # This will prompt for password initially
    ssh-copy-id -i ~/.ssh/$SSH_KEY_NAME.pub $USERNAME@$ip || {
        echo "❌ Failed to copy key to $hostname"
        echo "💡 Make sure the Pi is accessible and SSH is enabled"
        continue
    }
    
    echo "✅ SSH key installed on $hostname"
done

# Test connections
echo "🧪 Testing SSH connections..."
for node_info in "${NODES[@]}"; do
    hostname=$(echo $node_info | cut -d: -f1)
    
    if ssh $hostname "echo 'Connection to $hostname successful'" 2>/dev/null; then
        echo "✅ $hostname - OK"
    else
        echo "❌ $hostname - FAILED"
    fi
done

echo "🎉 SSH key setup complete!"