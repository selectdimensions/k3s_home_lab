#!/bin/bash
# Disaster Recovery Script

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Configuration
BACKUP_NAME="${1:-latest}"
ENVIRONMENT="${2:-prod}"
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/config}"

# Pre-flight checks
preflight_checks() {
    log "Running preflight checks..."
    
    # Check required tools
    for tool in kubectl velero terraform ansible; do
        if ! command -v $tool &> /dev/null; then
            error "$tool is not installed"
            exit 1
        fi
    done
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log "Preflight checks passed"
}

# Restore cluster state
restore_cluster() {
    log "Starting cluster restoration..."
    
    # 1. Restore Terraform state
    log "Restoring Terraform state..."
    cd terraform/environments/$ENVIRONMENT
    terraform init
    terraform refresh
    
    # 2. Ensure nodes are configured
    log "Verifying node configuration..."
    cd ../../../ansible
    ansible-playbook -i inventories/$ENVIRONMENT/hosts.yml playbooks/verify-nodes.yml
    
    # 3. Restore Kubernetes resources via Velero
    log "Restoring Kubernetes resources..."
    if [ "$BACKUP_NAME" == "latest" ]; then
        BACKUP_NAME=$(velero backup get --output json | jq -r '.items | sort_by(.metadata.creationTimestamp) | last | .metadata.name')
    fi
    
    log "Using backup: $BACKUP_NAME"
    velero restore create --from-backup $BACKUP_NAME --wait
    
    # 4. Verify restoration
    log "Verifying restoration..."
    kubectl get nodes
    kubectl get pods -A
    
    # 5. Run post-restore hooks
    log "Running post-restore hooks..."
    ./scripts/post-restore-hooks.sh
    
    log "Restoration complete!"
}

# Main execution
main() {
    log "Pi Cluster Disaster Recovery"
    log "============================"
    
    preflight_checks
    
    warning "This will restore the cluster to backup: $BACKUP_NAME"
    read -p "Continue? (yes/no) " -r
    
    if [[ $REPLY == "yes" ]]; then
        restore_cluster
    else
        log "Restoration cancelled"
        exit 0
    fi
}

main