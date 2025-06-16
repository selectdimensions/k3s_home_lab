#!/bin/bash
# Perform cluster maintenance operations

set -e

# Set default values
PT_operation="${PT_operation:-all}"
PT_force="${PT_force:-false}"
PT_reboot_if_needed="${PT_reboot_if_needed:-false}"

echo "🔧 Starting maintenance operation: $PT_operation"

# Set kubectl command
KUBECTL_CMD="kubectl"
[ -f /usr/local/bin/k3s ] && KUBECTL_CMD="/usr/local/bin/k3s kubectl"

# Function to check if running on master node
is_master_node() {
    systemctl is-active k3s >/dev/null 2>&1
}

# Function to update system packages
update_packages() {
    echo "📦 Updating system packages..."
    
    # Update package cache
    apt-get update
    
    # Show available upgrades
    echo "Available upgrades:"
    apt list --upgradable 2>/dev/null || true
    
    if [ "$PT_force" != "true" ]; then
        echo "Proceed with package updates? (y/N)"
        read -n 1 response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo "Package update skipped"
            return 0
        fi
    fi
    
    # Perform upgrade
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
    
    # Clean up
    apt-get autoremove -y
    apt-get autoclean
    
    # Check if reboot is required
    if [ -f /var/run/reboot-required ]; then
        echo "⚠️  System reboot required for kernel updates"
        if [ "$PT_reboot_if_needed" = "true" ]; then
            echo "🔄 Scheduling reboot in 1 minute..."
            shutdown -r +1 "System reboot for kernel updates"
        else
            echo "💡 Run with reboot_if_needed=true to automatically reboot"
        fi
    fi
    
    echo "✅ Package update completed"
}

# Function to restart K3s services
restart_services() {
    echo "🔄 Restarting K3s services..."
    
    if is_master_node; then
        echo "Restarting K3s server..."
        systemctl restart k3s
        sleep 10
        
        # Wait for API server to be ready
        echo "⏳ Waiting for API server..."
        for i in {1..30}; do
            if $KUBECTL_CMD get nodes >/dev/null 2>&1; then
                echo "✅ API server is ready"
                break
            fi
            sleep 5
        done
    else
        echo "Restarting K3s agent..."
        systemctl restart k3s-agent
        sleep 5
    fi
    
    echo "✅ Services restarted"
}

# Function to cleanup Docker/containerd images
cleanup_images() {
    echo "🧹 Cleaning up container images..."
    
    # Show current image usage
    echo "Current image usage:"
    if command -v crictl >/dev/null 2>&1; then
        crictl images
        echo ""
        
        # Remove unused images
        echo "Removing unused images..."
        crictl rmi --prune 2>/dev/null || true
        
        echo "After cleanup:"
        crictl images
    elif command -v docker >/dev/null 2>&1; then
        docker images
        echo ""
        
        # Remove unused images
        echo "Removing unused images..."
        docker image prune -f
        
        echo "After cleanup:"
        docker images
    else
        echo "⚠️  No container runtime found for image cleanup"
    fi
    
    echo "✅ Image cleanup completed"
}

# Function to perform disk cleanup
disk_cleanup() {
    echo "💾 Performing disk cleanup..."
    
    echo "Disk usage before cleanup:"
    df -h
    
    # Clean system logs
    echo "Cleaning system logs..."
    journalctl --vacuum-time=7d
    
    # Clean temporary files
    echo "Cleaning temporary files..."
    rm -rf /tmp/* 2>/dev/null || true
    rm -rf /var/tmp/* 2>/dev/null || true
    
    # Clean package cache
    echo "Cleaning package cache..."
    apt-get clean
    
    # Clean K3s logs if they exist
    if [ -d /var/log/pods ]; then
        echo "Cleaning old pod logs..."
        find /var/log/pods -name "*.log" -mtime +7 -delete 2>/dev/null || true
    fi
    
    echo "Disk usage after cleanup:"
    df -h
    
    echo "✅ Disk cleanup completed"
}

# Function to rotate logs
log_rotation() {
    echo "📄 Performing log rotation..."
    
    # Force log rotation
    logrotate -f /etc/logrotate.conf 2>/dev/null || true
    
    # Rotate systemd journal
    journalctl --rotate
    journalctl --vacuum-time=7d
    
    # Check if K3s has specific log files to rotate
    if [ -f /var/log/k3s.log ]; then
        echo "Rotating K3s logs..."
        if [ -f /etc/logrotate.d/k3s ]; then
            logrotate -f /etc/logrotate.d/k3s
        else
            # Create basic K3s logrotate config
            cat > /etc/logrotate.d/k3s << 'EOL'
/var/log/k3s.log {
    daily
    missingok
    rotate 7
    compress
    notifempty
    create 0644 root root
    postrotate
        systemctl reload k3s || true
    endscript
}
EOL
            logrotate -f /etc/logrotate.d/k3s
        fi
    fi
    
    echo "✅ Log rotation completed"
}

# Function to perform all maintenance operations
perform_all_maintenance() {
    echo "🔧 Performing comprehensive maintenance..."
    
    update_packages
    cleanup_images
    disk_cleanup
    log_rotation
    restart_services
    
    echo "✅ All maintenance operations completed"
}

# Show system status before maintenance
echo "📊 System status before maintenance:"
echo "Uptime: $(uptime)"
echo "Memory: $(free -h | grep Mem)"
echo "Disk: $(df -h / | tail -1)"
echo "Load: $(cat /proc/loadavg)"

if is_master_node && command -v kubectl >/dev/null 2>&1; then
    echo "K8s nodes: $($KUBECTL_CMD get nodes --no-headers | wc -l)"
    echo "Running pods: $($KUBECTL_CMD get pods --all-namespaces --no-headers | grep Running | wc -l)"
fi

echo ""

# Execute requested operation
case "$PT_operation" in
    "update_packages")
        update_packages
        ;;
    "restart_services")
        restart_services
        ;;
    "cleanup_images")
        cleanup_images
        ;;
    "disk_cleanup")
        disk_cleanup
        ;;
    "log_rotation")
        log_rotation
        ;;
    "all")
        perform_all_maintenance
        ;;
    *)
        echo "❌ Unknown operation: $PT_operation"
        exit 1
        ;;
esac

# Show system status after maintenance
echo ""
echo "📊 System status after maintenance:"
echo "Memory: $(free -h | grep Mem)"
echo "Disk: $(df -h / | tail -1)"
echo "Load: $(cat /proc/loadavg)"

if is_master_node && command -v kubectl >/dev/null 2>&1; then
    echo "K8s cluster status:"
    $KUBECTL_CMD get nodes
fi

echo ""
echo "✅ Maintenance operation '$PT_operation' completed successfully!"
