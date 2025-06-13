#!/bin/bash
# deploy-cluster.sh - Deploy complete K3s cluster with data engineering stack

set -e

MASTER_IP="192.168.0.120"  # Update to match your master node IP
MASTER_NAME="pi-master"  # Update to match your master node hostname
# Define worker node IPs
# Update to match your worker node IPs
# Example: pi-worker-1, pi-worker-2, pi-worker-3
# Define worker node IPs
WORKER_IPS=("192.168.0.121" "192.168.0.122" "192.168.0.123")

echo "🚀 Deploying Pi Cluster with K3s and data engineering tools"

# Install K3s on master
echo "📦 Installing K3s master on pi-master..."
ssh pi-master "curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644"

# Get node token
NODE_TOKEN=$(ssh pi-master "sudo cat /var/lib/rancher/k3s/server/node-token")

# Install K3s on workers
for worker_ip in "${WORKER_IPS[@]}"; do
    worker_name=$(ssh $worker_ip hostname)
    echo "📦 Installing K3s worker on $worker_name..."
    
    ssh $worker_ip "curl -sfL https://get.k3s.io | K3S_URL=https://$MASTER_IP:6443 K3S_TOKEN=$NODE_TOKEN sh -"
done

# Copy kubeconfig locally
echo "📋 Copying kubeconfig..."
scp pi-master:/etc/rancher/k3s/k3s.yaml ~/.kube/config
sed -i "s/127.0.0.1/$MASTER_IP/g" ~/.kube/config

# Wait for nodes to be ready
echo "⏳ Waiting for all nodes to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Deploy essential components
echo "🔧 Deploying cluster components..."

# MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=90s

# MetalLB IP pool configuration
kubectl apply -f - << EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.0.200-192.168.0.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2-advert
  namespace: metallb-system
EOF

# Install Helm
echo "🎡 Installing Helm..."
ssh pi-master "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"

# Add Helm repositories
kubectl create namespace monitoring || true
kubectl create namespace data-platform || true

echo "✅ Basic cluster deployment complete!"
echo "🎯 Next steps: Deploy data engineering tools with Helm"