#!/bin/bash
# deploy-cluster.sh - Deploy K3s cluster using hostnames

set -e

MASTER_NODE="pi-master"
WORKER_NODES=("pi-worker-1" "pi-worker-2" "pi-worker-3")

echo "🚀 Deploying K3s cluster"

# Step 1: Install K3s on master node
echo "📋 Installing K3s master on $MASTER_NODE..."

ssh $MASTER_NODE << 'EOF'
echo "🔽 Downloading and installing K3s master..."
curl -sfL https://get.k3s.io | sh -s - server \
    --write-kubeconfig-mode 644 \
    --disable servicelb \
    --disable traefik \
    --node-name pi-master

echo "⏳ Waiting for K3s master to be ready..."
sleep 30

# Wait for the node to be ready
sudo k3s kubectl wait --for=condition=Ready node pi-master --timeout=300s

echo "✅ K3s master is ready"
echo "📊 Master node status:"
sudo k3s kubectl get nodes -o wide
EOF

# Get master details
echo "🔍 Getting master node details..."
MASTER_IP=$(ssh $MASTER_NODE "hostname -I | awk '{print \$1}'")
TOKEN=$(ssh $MASTER_NODE "sudo cat /var/lib/rancher/k3s/server/node-token")

echo "✅ Master installed successfully"
echo "🔗 Master IP: $MASTER_IP"

# Step 2: Install K3s on worker nodes
for worker in "${WORKER_NODES[@]}"; do
    echo ""
    echo "📋 Installing K3s worker on $worker..."
    
    ssh -t $worker << EOF
echo "🔽 Downloading and installing K3s worker..."
curl -sfL https://get.k3s.io | K3S_URL=https://$MASTER_IP:6443 K3S_TOKEN=$TOKEN sh -s - agent --node-name $worker

echo "✅ K3s worker installed on $worker"
EOF
    
    if [ $? -eq 0 ]; then
        echo "✅ $worker joined the cluster successfully"
    else
        echo "❌ Failed to install K3s on $worker"
    fi
done

# Step 3: Verify cluster
echo ""
echo "🧪 Verifying cluster status..."
sleep 30

ssh -t $MASTER_NODE << 'EOF'
echo "📊 Cluster nodes:"
sudo k3s kubectl get nodes -o wide

echo ""
echo "📊 System pods:"
sudo k3s kubectl get pods -A

echo ""
echo "📊 Cluster info:"
sudo k3s kubectl cluster-info

echo ""
echo "🎯 Cluster is ready!"
EOF

# Step 4: Copy kubeconfig
echo ""
echo "📋 Copying kubeconfig..."
mkdir -p ~/.kube

# Copy and update kubeconfig
scp $MASTER_NODE:/etc/rancher/k3s/k3s.yaml ~/.kube/config
sed -i "s/127.0.0.1/$MASTER_IP/g" ~/.kube/config

echo "✅ Kubeconfig copied and configured"

if command -v kubectl &> /dev/null; then
    echo "🧪 Testing cluster access..."
    kubectl get nodes
else
    echo "⚠️  kubectl not found. Install kubectl to manage your cluster."
fi

echo ""
echo "🎉 K3s cluster deployment complete!"
echo ""
echo "📝 Your cluster is ready. Use 'kubectl get nodes' to verify."