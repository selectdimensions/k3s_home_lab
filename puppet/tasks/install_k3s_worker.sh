#!/bin/bash
# Install K3s worker node
set -e

# Parse input parameters
eval "$(jq -r '@sh "
K3S_VERSION=\(.k3s_version)
K3S_TOKEN=\(.k3s_token)
MASTER_IP=\(.master_ip)
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

log "Starting K3s worker installation..."
log "Version: $K3S_VERSION"
log "Master IP: $MASTER_IP"
log "Environment: $ENVIRONMENT"

# Check if K3s agent is already installed and running
if systemctl is-active --quiet k3s-agent; then
    log "K3s agent is already running, checking connection to master..."
    if timeout 10 curl -k https://$MASTER_IP:6443/ping 2>/dev/null; then
        log "K3s agent is already connected to master"
        STATUS="success"
        MESSAGE="K3s worker already running and connected to master"
    else
        log "K3s agent not connected to master, reinstalling..."
        sudo systemctl stop k3s-agent || add_error "Failed to stop K3s agent service"
    fi
fi

# Test connectivity to master
if [ "$STATUS" = "success" ] && [ "$MESSAGE" = "" ]; then
    log "Testing connectivity to master at $MASTER_IP:6443..."
    if ! timeout 10 curl -k https://$MASTER_IP:6443/ping; then
        add_error "Cannot connect to K3s master at $MASTER_IP:6443"
    fi
fi

# Prepare installation if not already running
if [ "$STATUS" = "success" ] && [ "$MESSAGE" = "" ]; then
    log "Installing K3s worker..."

    # Set environment variables
    export K3S_URL="https://$MASTER_IP:6443"
    export K3S_TOKEN="$K3S_TOKEN"

    # Worker-specific configuration
    NODE_NAME=$(hostname)
    NODE_IP=$(hostname -I | awk '{print $1}')

    # Build agent arguments
    AGENT_ARGS=""
    AGENT_ARGS="$AGENT_ARGS --node-name=$NODE_NAME"
    AGENT_ARGS="$AGENT_ARGS --node-ip=$NODE_IP"

    # Kubelet args for Pi optimization
    AGENT_ARGS="$AGENT_ARGS --kubelet-arg=max-pods=110"
    AGENT_ARGS="$AGENT_ARGS --kubelet-arg=image-gc-high-threshold=85"
    AGENT_ARGS="$AGENT_ARGS --kubelet-arg=image-gc-low-threshold=80"
    AGENT_ARGS="$AGENT_ARGS --kubelet-arg=container-log-max-size=10Mi"
    AGENT_ARGS="$AGENT_ARGS --kubelet-arg=container-log-max-files=5"

    export INSTALL_K3S_EXEC="agent $AGENT_ARGS"

    # Install K3s worker
    INSTALL_CMD="curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$K3S_VERSION sh -"

    if eval "$INSTALL_CMD"; then
        log "K3s worker installation completed"

        # Wait for agent to connect
        log "Waiting for K3s agent to connect to cluster..."
        timeout=300
        elapsed=0
        while [ $elapsed -lt $timeout ]; do
            if systemctl is-active --quiet k3s-agent; then
                log "K3s agent service is active"
                break
            fi
            sleep 5
            elapsed=$((elapsed + 5))
        done

        if [ $elapsed -ge $timeout ]; then
            add_error "Timeout waiting for K3s agent to start"
        else
            # Verify connection by checking if we can reach the API server
            if timeout 30 curl -k -s https://$MASTER_IP:6443/ping > /dev/null; then
                MESSAGE="K3s worker installed and connected to master successfully"
                log "$MESSAGE"
            else
                add_error "K3s worker installed but cannot verify connection to master"
            fi
        fi
    else
        add_error "K3s worker installation failed"
    fi
fi

# Generate output
jq -n \
  --arg status "$STATUS" \
  --arg message "$MESSAGE" \
  --arg k3s_version "$K3S_VERSION" \
  --arg node_name "$(hostname)" \
  --arg node_ip "$(hostname -I | awk '{print $1}')" \
  --arg master_ip "$MASTER_IP" \
  --argjson errors "$(printf '%s\n' "${ERRORS[@]}" | jq -R . | jq -s .)" \
  '{
    status: $status,
    message: $message,
    k3s_version: $k3s_version,
    node_name: $node_name,
    node_ip: $node_ip,
    master_ip: $master_ip,
    errors: $errors,
    timestamp: now | strftime("%Y-%m-%d %H:%M:%S UTC")
  }'
