#!/bin/bash
# Install K3s master node
set -e

# Parse input parameters
eval "$(jq -r '@sh "
K3S_VERSION=\(.k3s_version)
K3S_TOKEN=\(.k3s_token)
CLUSTER_CIDR=\(.cluster_cidr)
SERVICE_CIDR=\(.service_cidr)
CLUSTER_DNS=\(.cluster_dns)
INSTALL_TRAEFIK=\(.install_traefik)
INSTALL_LOCAL_STORAGE=\(.install_local_storage)
DEBUG=\(.debug_mode)
ENVIRONMENT=\(.environment)
"')"

if [ "$DEBUG" = "true" ]; then
    set -x
fi

# Initialize status
STATUS="success"
MESSAGE=""
ERRORS=()

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

# Function to add error
add_error() {
    ERRORS+=("$1")
    STATUS="failed"
    log "ERROR: $1"
}

log "Starting K3s master installation..."
log "Version: $K3S_VERSION"
log "Environment: $ENVIRONMENT"

# Check if K3s is already installed
if systemctl is-active --quiet k3s; then
    log "K3s is already running, checking version..."
    CURRENT_VERSION=$(k3s --version | head -1 | awk '{print $3}')
    if [ "$CURRENT_VERSION" = "$K3S_VERSION" ]; then
        log "K3s $K3S_VERSION is already installed and running"
        STATUS="success"
        MESSAGE="K3s master already running with correct version"
    else
        log "K3s version mismatch. Current: $CURRENT_VERSION, Requested: $K3S_VERSION"
        log "Stopping K3s for upgrade..."
        sudo systemctl stop k3s || add_error "Failed to stop K3s service"
    fi
fi

# Prepare installation command
INSTALL_CMD="curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$K3S_VERSION"

# Add environment variables
export K3S_TOKEN="$K3S_TOKEN"
export INSTALL_K3S_EXEC="server"

# Build server arguments
SERVER_ARGS=""

# Cluster configuration
SERVER_ARGS="$SERVER_ARGS --cluster-cidr=$CLUSTER_CIDR"
SERVER_ARGS="$SERVER_ARGS --service-cidr=$SERVICE_CIDR"
SERVER_ARGS="$SERVER_ARGS --cluster-dns=$CLUSTER_DNS"

# Disable components based on parameters
DISABLE_COMPONENTS=""
if [ "$INSTALL_TRAEFIK" = "false" ]; then
    DISABLE_COMPONENTS="traefik"
fi

if [ "$INSTALL_LOCAL_STORAGE" = "false" ]; then
    if [ -n "$DISABLE_COMPONENTS" ]; then
        DISABLE_COMPONENTS="$DISABLE_COMPONENTS,local-storage"
    else
        DISABLE_COMPONENTS="local-storage"
    fi
fi

if [ -n "$DISABLE_COMPONENTS" ]; then
    SERVER_ARGS="$SERVER_ARGS --disable=$DISABLE_COMPONENTS"
fi

# Additional server configuration
SERVER_ARGS="$SERVER_ARGS --write-kubeconfig-mode=0644"
SERVER_ARGS="$SERVER_ARGS --disable-cloud-controller"
SERVER_ARGS="$SERVER_ARGS --disable-network-policy"

# Kubelet args for Pi optimization
SERVER_ARGS="$SERVER_ARGS --kubelet-arg=max-pods=110"
SERVER_ARGS="$SERVER_ARGS --kubelet-arg=image-gc-high-threshold=85"
SERVER_ARGS="$SERVER_ARGS --kubelet-arg=image-gc-low-threshold=80"

# Set node name and IP
NODE_NAME=$(hostname)
NODE_IP=$(hostname -I | awk '{print $1}')
SERVER_ARGS="$SERVER_ARGS --node-name=$NODE_NAME"
SERVER_ARGS="$SERVER_ARGS --node-ip=$NODE_IP"

if [ "$STATUS" = "success" ]; then
    log "Installing K3s master with args: $SERVER_ARGS"

    # Set the exec args and run installation
    export INSTALL_K3S_EXEC="server $SERVER_ARGS"

    if eval "$INSTALL_CMD"; then
        log "K3s master installation completed successfully"

        # Wait for K3s to be ready
        log "Waiting for K3s to be ready..."
        timeout=300
        elapsed=0
        while [ $elapsed -lt $timeout ]; do
            if sudo k3s kubectl get nodes --no-headers 2>/dev/null | grep -q "Ready"; then
                log "K3s master is ready"
                break
            fi
            sleep 5
            elapsed=$((elapsed + 5))
        done

        if [ $elapsed -ge $timeout ]; then
            add_error "Timeout waiting for K3s master to be ready"
        else
            # Get node and cluster info
            NODE_STATUS=$(sudo k3s kubectl get nodes --no-headers | head -1)
            K3S_VERSION_RUNNING=$(sudo k3s --version | head -1 | awk '{print $3}')

            MESSAGE="K3s master installed successfully. Node: $NODE_STATUS, Version: $K3S_VERSION_RUNNING"

            # Copy kubeconfig for user access
            if [ -f /etc/rancher/k3s/k3s.yaml ]; then
                sudo cp /etc/rancher/k3s/k3s.yaml /tmp/k3s-kubeconfig
                sudo chown $(whoami):$(whoami) /tmp/k3s-kubeconfig
                log "Kubeconfig copied to /tmp/k3s-kubeconfig"
            fi
        fi
    else
        add_error "K3s master installation failed"
    fi
fi

# Generate output
jq -n \
  --arg status "$STATUS" \
  --arg message "$MESSAGE" \
  --arg k3s_version "$K3S_VERSION" \
  --arg node_name "$NODE_NAME" \
  --arg node_ip "$NODE_IP" \
  --argjson errors "$(printf '%s\n' "${ERRORS[@]}" | jq -R . | jq -s .)" \
  '{
    status: $status,
    message: $message,
    k3s_version: $k3s_version,
    node_name: $node_name,
    node_ip: $node_ip,
    errors: $errors,
    kubeconfig_path: "/tmp/k3s-kubeconfig",
    timestamp: now | strftime("%Y-%m-%d %H:%M:%S UTC")
  }'
