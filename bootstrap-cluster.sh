#!/bin/bash
# bootstrap-cluster.sh - Complete cluster bootstrap (Updated for existing SSH setup)

set -e

echo "🎬 Starting complete Pi cluster bootstrap"
echo "📋 Using existing SSH configuration with pi_k3s_cluster keys"

# Verify SSH connectivity first
echo "🔍 Verifying SSH connectivity to all nodes..."
NODES=("pi-master" "pi-worker-1" "pi-worker-2" "pi-worker-3")
failed_nodes=()

for node in "${NODES[@]}"; do
    if ssh $node "echo 'SSH test successful'" 2>/dev/null; then
        echo "✅ $node - SSH working"
    else
        echo "❌ $node - SSH failed"
        failed_nodes+=("$node")
    fi
done

if [ ${#failed_nodes[@]} -ne 0 ]; then
    echo "❌ SSH connectivity failed for: ${failed_nodes[*]}"
    echo "💡 Please fix SSH connectivity before proceeding"
    exit 1
fi

echo "✅ All nodes accessible via SSH"

# Step 1: Skip SSH setup since it's already working
echo "Step 1/4: SSH keys already configured ✅"
echo "📋 Using existing SSH config with pi_k3s_cluster keys"

# Step 2: Update and prepare all nodes
echo "Step 2/4: Updating and preparing all nodes..."
./prepare-nodes.sh

# Step 3: Configure system settings (optional reboot)
echo "Step 3/4: Configuring system settings..."
./setup-system.sh

# Check if reboot is needed
reboot_needed=false
for node in "${NODES[@]}"; do
    if ssh $node "[ -f /var/run/reboot-required ]" 2>/dev/null; then
        echo "⚠️  $node requires reboot"
        reboot_needed=true
    fi
done

if [ "$reboot_needed" = true ]; then
    echo "🔄 Rebooting nodes that require it..."
    for node in "${NODES[@]}"; do
        if ssh $node "[ -f /var/run/reboot-required ]" 2>/dev/null; then
            echo "🔄 Rebooting $node..."
            ssh $node "sudo reboot" &
        fi
    done
    
    echo "⏳ Waiting 90 seconds for nodes to reboot..."
    sleep 90
    
    # Wait for nodes to come back online
    for node in "${NODES[@]}"; do
        echo "⏳ Waiting for $node to come online..."
        while ! ssh $node "echo 'Node ready'" 2>/dev/null; do
            echo "   Still waiting for $node..."
            sleep 10
        done
        echo "✅ $node is back online"
    done
else
    echo "✅ No reboots required"
fi

# Step 4: Deploy cluster
echo "Step 4/4: Deploying K3s cluster..."
./deploy-cluster.sh

echo ""
echo "🎉 Cluster bootstrap complete!"
echo ""
echo "🔗 Next steps:"
echo "   1. Copy kubeconfig: ./copy-kubeconfig.sh"
echo "   2. Test cluster: kubectl get nodes"
echo "   3. Deploy applications: kubectl apply -f your-app.yaml"