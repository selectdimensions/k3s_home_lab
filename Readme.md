Excellent! You're absolutely right about making this setup repeatable and idempotent. Let me help you create a comprehensive setup system for your Raspberry Pi cluster that can be easily reproduced. This is definitely where infrastructure-as-code shines!

## Quick Setup Scripts for Raspberry Pi Cluster

Here's a complete automation solution:

### 1. Initial Pi Setup Script (Run on each Pi)

Create `pi-setup.sh`:

```bash
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
```

### 2. SSH Key Distribution Script

Create `setup-ssh-keys.sh`:

```bash
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
```

### 3. Network Configuration Script

Create `setup-network.sh`:

```bash
#!/bin/bash
# setup-network.sh - Configure network settings on all nodes

set -e

declare -A NODES=(
    ["pi-master"]="192.168.1.10"
    ["pi-worker-1"]="192.168.1.11"
    ["pi-worker-2"]="192.168.1.12"
    ["pi-worker-3"]="192.168.1.13"
)

GATEWAY="192.168.1.1"
DNS="8.8.8.8,1.1.1.1"

echo "🌐 Configuring network for all Pi nodes"

for hostname in "${!NODES[@]}"; do
    ip=${NODES[$hostname]}
    
    echo "📡 Configuring $hostname with IP $ip"
    
    # Run network configuration on remote node
    ssh $hostname "sudo tee /etc/dhcpcd.conf > /dev/null" << EOF
# Static IP configuration for $hostname
interface eth0
static ip_address=$ip/24
static routers=$GATEWAY
static domain_name_servers=$DNS

# Fallback to DHCP if static fails
profile static_eth0
static ip_address=$ip/24
static routers=$GATEWAY
static domain_name_servers=$DNS

interface eth0
fallback static_eth0
EOF

    # Update hostname
    ssh $hostname "sudo hostnamectl set-hostname $hostname"
    
    # Update /etc/hosts with all cluster nodes
    ssh $hostname "sudo tee -a /etc/hosts > /dev/null" << EOF

# Pi Cluster nodes
$(for h in "${!NODES[@]}"; do
    echo "${NODES[$h]} $h"
done)
EOF

    echo "✅ Network configured for $hostname"
done

echo "🔄 Restarting networking on all nodes..."
for hostname in "${!NODES[@]}"; do
    ssh $hostname "sudo systemctl restart dhcpcd" &
done
wait

echo "🎉 Network configuration complete!"
```

### 4. Master Deployment Script

Create `deploy-cluster.sh`:

```bash
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
```

### 5. One-Click Complete Setup

Create `bootstrap-cluster.sh`:

```bash
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
```

## Usage Instructions:

1. **Flash all Pi SD cards** with Raspberry Pi OS Lite
2. **Enable SSH** by creating empty `ssh` file in boot partition
3. **Boot each Pi** and run initial setup:
   ```bash
   # On each Pi individually (connect via monitor/keyboard first time)
   wget https://your-repo/pi-setup.sh

   wget https://raw.githubusercontent.com/selectdimensions/k3s_home_lab/main/pi-setup.sh
   
   chmod +x pi-setup.sh

   ./pi-setup.sh pi-master 192.168.1.10  # Adjust hostname and IP

   sudo reboot
   ```
4. **Run complete bootstrap** from your local machine:
   ```bash
   wget https://raw.githubusercontent.com/selectdimensions/k3s_home_lab/main/

   chmod +x *.sh

   ./bootstrap-cluster.sh
   ```

## Benefits of This Approach:

- **Idempotent**: Can run multiple times safely
- **Repeatable**: Nuke SD cards and rebuild quickly
- **Modular**: Each script handles one concern
- **Error handling**: Scripts fail fast with clear messages
- **Network-aware**: Handles static IPs and SSH properly

This gives you a solid foundation to build your Terraform and GitOps workflows on top of! The cluster will be ready for your NiFi, Trino, and other data engineering tools.



---

I have raspberry raspberry pi os lite installed how can I edit all the ip address?

and get the set up going quickly with some scripts to get the basics out of the way like the SSH for all of them, the static Ip addresses, lets stop there for now. just the basic setup so i can then SSH into them and use VSCode or would it be best to just use scripts...? I was thinking could make the setup scripts to include the setup scripts repeatable (idempotent) so that I could nuke the sd cards and it wouldn't take forever to start over again with setting up ssh and setting the IPs and network setup. this is where terraform would really come in handy!?

---

🗂️ 1. Overview
Product Name & Version: PiClusterOps v1.0
Document Owner: Hezekiah Jenkins
Last Updated Date: 2025-06-10
Stakeholders: Hezekiah Jenkins, DevOps Team, Data Engineering Learners
Purpose & Scope: Define and guide the deployment and operation of a Raspberry Pi 5-based Kubernetes cluster for educational, experimental, and light production use with a focus on data engineering tools like NiFi, Trino, SQL, and Python.
Assumptions & Constraints: Limited by ARM architecture, microSD I/O, and thermals; assumes local network availability; constrained to homelab scale.
________________________________________
🧠 2. Functional Requirements
•	Deploy and manage a fully containerized Kubernetes cluster using K3s.
•	Integrate NiFi for data flow orchestration.
•	Install Trino for federated SQL querying.
•	Provide PostgreSQL and MinIO for storage and SQL backend.
•	Enable Python-based data analysis (e.g., JupyterLab, FastAPI microservices).
•	Monitor and visualize system and data health (Prometheus, Grafana, ELK).
User Stories: - As a data engineer, I want to run NiFi flows that write to PostgreSQL or MinIO. - As a developer, I want to query different datasets via Trino and analyze them in Python. - As a sysadmin, I want GitOps-style deployment via Flux CD and Terraform.
External System Interactions: - API access to public data (weather, finance) - GitHub for version control - Optional: cloud backup services
________________________________________
⚙️ 3. Hardware Requirements
🧲 Compute:
•	Processor: Broadcom BCM2712 (ARM Cortex-A76)
•	CPU Cores: 4 cores per Pi (16 total)
•	GPU: VideoCore VII (no CUDA support)
•	RAM: 8GB LPDDR4 per Pi
•	Storage: 64GB U3 microSD cards + optional USB SSDs
🧱 Embedded/Peripheral:
•	4x Raspberry Pi 5 SBCs
•	Optional: temperature and environmental sensors for data ingestion demo
🔌 Power/Connectivity:
•	USB-C 5V/5A power per Pi
•	Gigabit Ethernet to central switch
•	USB 3.0 ports for external storage
🪊 Environmental:
•	Active cooling required
•	Custom 3D printed or modular rack case
________________________________________
💻 4. Software Requirements
🧰 Operating Systems:
•	Raspberry Pi OS 64-bit (Bookworm)
🛆 System Software:
•	Docker, K3s
•	Terraform, Helm
•	cert-manager, Vault
🧑‍💻 Application Software:
•	Apache NiFi
•	Trino + Hive catalog
•	PostgreSQL
•	MinIO
•	Python 3.12 + JupyterLab
•	FastAPI (optional)
•	Prometheus, Grafana, Fluentd, ELK
🧪 Dev/Test Tools:
•	GitHub + Flux CD
•	pytest, flake8
•	VS Code Server
🔐 Licensing:
•	All software: MIT/Apache 2.0 compliant (open source)
________________________________________
🌐 5. Network Requirements
•	Static IPs via DHCP reservation:
o	Master: 10.0.0.10
o	Workers: 10.0.0.11-13
•	VLANs: Management (10.0.0.x), Services (10.0.1.x), Pods (10.0.2.x)
•	MetalLB Range: 10.0.0.200 - 10.0.0.250
•	DNS: CoreDNS + external Cloudflare
•	VPN: WireGuard for remote access (optional)
________________________________________
🛡️ 6. Security & Firewall Requirements
🔐 Auth/AuthZ:
•	OAuth2 for dashboard apps (via KrakenD)
•	RBAC for K3s
•	Vault for secret injection
🔥 Firewall:
•	Block public access to ports 22, 80, 443 unless via VPN
•	Allow 30000-32767 NodePort range only internally
🛠️ Network Zones:
•	DMZ: External API gateway
•	Internal: K3s pods and services
•	Restricted: Vault, PostgreSQL
📂 Auditing:
•	Fluentd + ELK
•	Prometheus alert rules + Grafana dashboards
________________________________________
🗃️ 7. Storage & Backup
•	Types: Object (MinIO), Block (Longhorn optional), File (NFS)
•	Retention: 30-day log rotation; 7-day full backups
•	Backup: Velero or rsync-to-NAS
•	Encryption: TLS + Vault-integrated secrets + rest encryption (MinIO S3 SSE)
________________________________________
📡 8. Monitoring & Logging
•	Prometheus + Node Exporter
•	Grafana Dashboards per pod, cluster, NiFi metrics
•	Fluentd shipping to Logstash
•	Kibana dashboards for NiFi/Trino logs
________________________________________
🧪 9. Test & QA Environment
•	Pi 5 node in dev mode for regression testing
•	Trino queries and NiFi flows tested with mock data
•	Use Trino CLI + Python scripts for validation
________________________________________
🚀 10. Deployment & Infra
•	IaC: Terraform modules for networking, apps, storage
•	Flux CD: GitOps config sync (every 1 min)
•	Helm Charts: NiFi, Trino, Prometheus stack
•	CDN: Optional Cloudflare proxy to KrakenD endpoint
•	Edge/Cloud Hybrid: Local compute; remote Git and API usage
________________________________________
🧑‍💼 11. Roles & Access
•	Admin: Full cluster + Vault
•	Dev: Flux, Jupyter, Trino
•	Guest: Read-only dashboard via Grafana
•	Remote Access: SSH keys + optional WireGuard + MFA script
________________________________________
📋 12. Change Management
•	GitOps PR-based workflow
•	Semantic versioning: vMAJOR.MINOR.PATCH
•	Monthly software patching window
•	Rollbacks via Flux CD image tags + Terraform state reversion


---

I'll refine the PRD with your detailed information, focusing on creating a comprehensive deployment plan that incorporates both the data engineering tools and cluster management components.

# PiClusterOps v1.0 - Detailed Implementation Plan

## 1. Cluster Architecture

### Base Infrastructure (Terraform)
```hcl
# main.tf
module "k3s_cluster" {
  source = "./modules/k3s"
  
  master_ip = "10.0.0.10"
  worker_ips = ["10.0.0.11", "10.0.0.12", "10.0.0.13"]
  
  network_config = {
    pod_cidr     = "10.0.2.0/24"
    service_cidr = "10.0.1.0/24"
  }
}

module "storage" {
  source = "./modules/storage"
  
  minio_config = {
    replicas = 4
    storage_size = "32Gi"
    access_key = var.minio_access_key
    secret_key = var.minio_secret_key
  }
  
  postgresql_config = {
    version = "14"
    storage_size = "20Gi"
    replicas = 2
  }
}
```

## 2. Network Layout

### MetalLB Configuration
```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - 10.0.0.200-10.0.0.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2-advert
  namespace: metallb-system
```

## 3. Data Platform Components

### Trino Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: trino-coordinator
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: trino-coordinator
        image: trinodb/trino:latest
        resources:
          limits:
            memory: "4Gi"
            cpu: "2"
        volumeMounts:
        - name: trino-config
          mountPath: /etc/trino
```

### NiFi Configuration
```yaml
apiVersion: nifi.apache.org/v1
kind: NifiCluster
metadata:
  name: nifi
spec:
  nodes: 3
  resources:
    limits:
      memory: "3Gi"
      cpu: "1"
  zkAddresses:
    - "zk-0.zk-headless.default.svc.cluster.local:2181"
```

## 4. Monitoring Stack

### Prometheus Configuration
```yaml
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  name: prometheus
spec:
  serviceAccountName: prometheus
  serviceMonitorSelector:
    matchLabels:
      team: devops
  resources:
    requests:
      memory: "1Gi"
      cpu: "500m"
  retention: 15d
```

## 5. GitOps Configuration

### Flux CD Setup
```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: cluster-config
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/your-org/piclusterops
  ref:
    branch: main
---
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: apps
  namespace: flux-system
spec:
  interval: 10m
  path: ./apps
  prune: true
  sourceRef:
    kind: GitRepository
    name: cluster-config
```

## 6. Security Implementation

### Network Policies
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitoring
spec:
  podSelector:
    matchLabels:
      app: prometheus
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
```

## 7. Storage Configuration

### Persistent Volume Claims
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nifi-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: local-path
```