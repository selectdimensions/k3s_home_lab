#!/bin/bash
# setup-ssh-keys.sh - Distribute SSH keys to all Pi nodes (updated)

set -e

declare -A NODES=(
    ["pi-master"]="192.168.0.120"   # Update to match your network
    ["pi-worker-1"]="192.168.0.121"
    ["pi-worker-2"]="192.168.0.122"
    ["pi-worker-3"]="192.168.0.123"
)

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

echo "📋 SSH config created"

# Function to wait for SSH to be available
wait_for_ssh() {
    local host=$1
    local max_attempts=30
    local attempt=1
    
    echo "⏳ Waiting for SSH on $host..."
    while [ $attempt -le $max_attempts ]; do
        if timeout 5 ssh -o ConnectTimeout=5 $host "echo 'SSH ready'" 2>/dev/null; then
            echo "✅ SSH is ready on $host"
            return 0
        fi
        echo "   Attempt $attempt/$max_attempts failed, retrying in 10 seconds..."
        sleep 10
        ((attempt++))
    done
    
    echo "❌ SSH not available on $host after $max_attempts attempts"
    return 1
}

# Copy public key to all nodes
for hostname in "${!NODES[@]}"; do
    ip=${NODES[$hostname]}
    
    echo "📤 Setting up SSH key for $hostname ($ip)..."
    
    # Wait for SSH to be available
    if ! wait_for_ssh $hostname; then
        echo "❌ Skipping $hostname - SSH not available"
        continue
    fi
    
    # Copy SSH key (will prompt for password)
    if ssh-copy-id -i ~/.ssh/$SSH_KEY_NAME.pub $USERNAME@$ip; then
        echo "✅ SSH key copied to $hostname"
        
        # Now disable password authentication
        ssh $hostname "sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config"
        ssh $hostname "sudo systemctl restart ssh"
        echo "🔒 Password authentication disabled on $hostname"
    else
        echo "❌ Failed to copy key to $hostname"
        continue
    fi
done

# Test connections
echo "🧪 Testing SSH connections..."
for hostname in "${!NODES[@]}"; do
    if ssh $hostname "echo 'Connection to $hostname successful'" 2>/dev/null; then
        echo "✅ $hostname - OK"
        # Show the actual IP
        actual_ip=$(ssh $hostname "hostname -I | awk '{print \$1}'")
        echo "   IP: $actual_ip"
    else
        echo "❌ $hostname - FAILED"
    fi
done

echo "🎉 SSH key setup complete!"