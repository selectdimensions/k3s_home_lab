#!/bin/bash
# bootstrap-cluster.sh - Complete cluster bootstrap

set -e

echo "🎬 Starting complete Pi cluster bootstrap"

# Step 1: Setup SSH keys
echo "Step 1/4: Setting up SSH keys..."
./setup-ssh-keys.sh

# Step 2: Configure network
echo "Step 2/4: Configuring network..."
./setup-network.sh

# Step 3: Reboot all nodes
echo "Step 3/4: Rebooting all nodes..."
for hostname in pi-master pi-worker-1 pi-worker-2 pi-worker-3; do
    ssh $hostname "sudo reboot" &
done

echo "⏳ Waiting 60 seconds for nodes to reboot..."
sleep 60

# Wait for nodes to come back online
for hostname in pi-master pi-worker-1 pi-worker-2 pi-worker-3; do
    while ! ssh $hostname "echo 'Node ready'" 2>/dev/null; do
        echo "⏳ Waiting for $hostname to come online..."
        sleep 10
    done
    echo "✅ $hostname is online"
done

# Step 4: Deploy cluster
echo "Step 4/4: Deploying cluster..."
./deploy-cluster.sh

echo "🎉 Cluster bootstrap complete!"
echo "🔗 Access your cluster:"
echo "   kubectl get nodes"
echo "   kubectl get pods -A"