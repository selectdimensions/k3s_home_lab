#!/bin/bash
# setup-ssh-keys.sh - Check and verify SSH keys for Pi cluster

set -e

echo "🔐 Checking SSH key configuration for Pi cluster"

# Check if we're using existing SSH config
if grep -q "pi-master" ~/.ssh/config 2>/dev/null && grep -q "pi_k3s_cluster" ~/.ssh/config 2>/dev/null; then
    echo "✅ Existing SSH configuration detected"
    echo "🔑 Using pi_k3s_cluster keys from existing config"
    
    # Test all connections
    NODES=("pi-master" "pi-worker-1" "pi-worker-2" "pi-worker-3")
    all_working=true
    
    for node in "${NODES[@]}"; do
        if ssh $node "echo 'SSH test successful for $node'" 2>/dev/null; then
            echo "✅ $node - SSH working"
        else
            echo "❌ $node - SSH failed"
            all_working=false
        fi
    done
    
    if [ "$all_working" = true ]; then
        echo "🎉 All SSH connections working! Skipping SSH setup."
        exit 0
    else
        echo "⚠️  Some SSH connections failed. Manual intervention required."
        exit 1
    fi
fi

# If we get here, SSH config doesn't exist, so create it
declare -A NODES=(
    ["pi-master"]="192.168.0.120"
    ["pi-worker-1"]="192.168.0.121"
    ["pi-worker-2"]="192.168.0.122"
    ["pi-worker-3"]="192.168.0.123"
)

SSH_KEY_NAME="pi_cluster_key"
USERNAME="hezekiah"

echo "🔧 Setting up new SSH configuration..."

# Generate SSH key if it doesn't exist
if [ ! -f ~/.ssh/$SSH_KEY_NAME ]; then
    echo "🔑 Generating new SSH key..."
    ssh-keygen -t ed25519 -f ~/.ssh/$SSH_KEY_NAME -C "$USERNAME@pi-cluster" -N ""
else
    echo "🔑 SSH key already exists, skipping generation."
fi

# Create SSH config (preserve existing if present)
if [ -f ~/.ssh/config ]; then
    cp ~/.ssh/config ~/.ssh/config.backup
    echo "📋 Backed up existing SSH config"
fi

# Append Pi cluster config
cat >> ~/.ssh/config << EOF

# Pi Cluster SSH Configuration - Added $(date)
$(for hostname in "${!NODES[@]}"; do
    ip=${NODES[$hostname]}
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

echo "📋 SSH config updated"
echo "⚠️  You'll need to copy SSH keys to each Pi manually with ssh-copy-id"