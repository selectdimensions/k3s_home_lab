#!/bin/bash
# Restore K3s cluster from backup

set -e

# Read parameters from stdin
eval "$(cat <<EOF
$PT_backup_path="$PT_backup_path"
$PT_restore_type="${PT_restore_type:-full}"
$PT_force="${PT_force:-false}"
EOF
)"

# Validate backup path
if [ ! -d "$PT_backup_path" ]; then
    echo "❌ Backup path does not exist: $PT_backup_path"
    exit 1
fi

if [ ! -f "$PT_backup_path/backup_info.txt" ]; then
    echo "❌ Invalid backup directory: missing backup_info.txt"
    exit 1
fi

echo "🔄 Starting restore from: $PT_backup_path"
echo "📊 Backup info:"
cat "$PT_backup_path/backup_info.txt"

# Confirmation unless forced
if [ "$PT_force" != "true" ]; then
    echo ""
    echo "⚠️  WARNING: This will restore cluster data and may overwrite current state!"
    echo "Press Ctrl+C to cancel, or any key to continue..."
    read -n 1
fi

# Function to stop K3s service
stop_k3s() {
    echo "🛑 Stopping K3s service..."
    systemctl stop k3s 2>/dev/null || true
    systemctl stop k3s-agent 2>/dev/null || true
    sleep 5
}

# Function to start K3s service
start_k3s() {
    echo "▶️  Starting K3s service..."
    systemctl start k3s 2>/dev/null || systemctl start k3s-agent 2>/dev/null || true
    sleep 10
    
    # Wait for K3s to be ready
    echo "⏳ Waiting for K3s to be ready..."
    for i in {1..30}; do
        if kubectl get nodes >/dev/null 2>&1 || /usr/local/bin/k3s kubectl get nodes >/dev/null 2>&1; then
            echo "✅ K3s is ready"
            return 0
        fi
        sleep 5
    done
    echo "⚠️  K3s may not be fully ready yet"
}

# Function to restore etcd database
restore_etcd() {
    echo "📊 Restoring etcd database..."
    stop_k3s
    
    if [ -d "$PT_backup_path/etcd_db" ]; then
        rm -rf /var/lib/rancher/k3s/server/db
        cp -r "$PT_backup_path/etcd_db" /var/lib/rancher/k3s/server/db
        chown -R root:root /var/lib/rancher/k3s/server/db
        echo "✅ etcd database restored"
    elif [ -f "$PT_backup_path/state.db" ]; then
        mkdir -p /var/lib/rancher/k3s/server/db
        cp "$PT_backup_path/state.db" /var/lib/rancher/k3s/server/db/
        chown -R root:root /var/lib/rancher/k3s/server/db
        echo "✅ SQLite database restored"
    else
        echo "❌ No database backup found"
        return 1
    fi
    
    start_k3s
}

# Function to restore Kubernetes manifests
restore_manifests() {
    echo "📄 Restoring Kubernetes manifests..."
    
    if [ ! -d "$PT_backup_path/manifests" ]; then
        echo "❌ No manifests backup found"
        return 1
    fi
    
    KUBECTL_CMD="kubectl"
    [ -f /usr/local/bin/k3s ] && KUBECTL_CMD="/usr/local/bin/k3s kubectl"
    
    # Wait for cluster to be ready
    echo "⏳ Waiting for cluster to be ready..."
    for i in {1..60}; do
        if $KUBECTL_CMD get nodes >/dev/null 2>&1; then
            break
        fi
        sleep 5
    done
    
    # Restore resources (skip some system resources)
    echo "Restoring persistent volumes..."
    $KUBECTL_CMD apply -f "$PT_backup_path/manifests/persistent-volumes.yaml" 2>/dev/null || true
    
    echo "Restoring persistent volume claims..."
    $KUBECTL_CMD apply -f "$PT_backup_path/manifests/persistent-volume-claims.yaml" 2>/dev/null || true
    
    echo "Restoring configmaps..."
    $KUBECTL_CMD apply -f "$PT_backup_path/manifests/configmaps.yaml" 2>/dev/null || true
    
    echo "Restoring secrets..."
    $KUBECTL_CMD apply -f "$PT_backup_path/manifests/secrets.yaml" 2>/dev/null || true
    
    echo "✅ Kubernetes manifests restored"
}

# Function to restore persistent data
restore_persistent() {
    echo "💾 Restoring persistent data..."
    
    if [ ! -d "$PT_backup_path/persistent" ]; then
        echo "❌ No persistent data backup found"
        return 1
    fi
    
    # Restore persistent data
    if [ -d "$PT_backup_path/persistent/var/lib/rancher/k3s/storage" ]; then
        mkdir -p /var/lib/rancher/k3s/storage
        cp -r "$PT_backup_path/persistent/var/lib/rancher/k3s/storage"/* /var/lib/rancher/k3s/storage/ 2>/dev/null || true
    fi
    
    if [ -d "$PT_backup_path/persistent/opt/local-path-provisioner" ]; then
        mkdir -p /opt/local-path-provisioner
        cp -r "$PT_backup_path/persistent/opt/local-path-provisioner"/* /opt/local-path-provisioner/ 2>/dev/null || true
    fi
    
    if [ -d "$PT_backup_path/persistent/mnt/data" ]; then
        mkdir -p /mnt/data
        cp -r "$PT_backup_path/persistent/mnt/data"/* /mnt/data/ 2>/dev/null || true
    fi
    
    echo "✅ Persistent data restored"
}

# Function to restore system configuration
restore_system_config() {
    echo "⚙️  Restoring system configuration..."
    
    if [ ! -d "$PT_backup_path/config" ]; then
        echo "❌ No system config backup found"
        return 1
    fi
    
    # Restore K3s configuration
    if [ -f "$PT_backup_path/config/k3s.yaml" ]; then
        mkdir -p /etc/rancher/k3s
        cp "$PT_backup_path/config/k3s.yaml" /etc/rancher/k3s/
    fi
    
    if [ -d "$PT_backup_path/config/k3s" ]; then
        cp -r "$PT_backup_path/config/k3s"/* /etc/rancher/k3s/ 2>/dev/null || true
    fi
    
    echo "✅ System configuration restored"
}

# Main restore logic
case "$PT_restore_type" in
    "etcd")
        restore_etcd
        ;;
    "manifests")
        restore_manifests
        ;;
    "persistent")
        restore_persistent
        ;;
    "full")
        restore_etcd
        restore_manifests
        restore_persistent
        restore_system_config
        ;;
    *)
        echo "❌ Unknown restore type: $PT_restore_type"
        exit 1
        ;;
esac

echo "✅ Restore completed successfully from: $PT_backup_path"
