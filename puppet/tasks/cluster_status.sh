#!/bin/bash
# Check K3s cluster status

set -e

# Function to check if kubectl is available
check_kubectl() {
    if command -v kubectl >/dev/null 2>&1; then
        return 0
    elif [ -f /usr/local/bin/k3s ]; then
        # Use k3s kubectl if available
        alias kubectl='/usr/local/bin/k3s kubectl'
        return 0
    else
        echo "❌ kubectl not available"
        return 1
    fi
}

# Function to check node status
check_nodes() {
    echo "📊 Node Status:"
    kubectl get nodes -o wide 2>/dev/null || echo "❌ Unable to get node status"
}

# Function to check system services
check_services() {
    echo "🔧 Service Status:"
    
    # Check K3s service
    if systemctl is-active --quiet k3s 2>/dev/null; then
        echo "✅ K3s server: Running"
    elif systemctl is-active --quiet k3s-agent 2>/dev/null; then
        echo "✅ K3s agent: Running"
    else
        echo "❌ K3s service: Not running"
    fi
    
    # Check docker if available
    if systemctl is-active --quiet docker 2>/dev/null; then
        echo "✅ Docker: Running"
    fi
}

# Function to check cluster pods
check_pods() {
    echo "🐳 Pod Status:"
    kubectl get pods --all-namespaces 2>/dev/null | grep -E "(kube-system|default)" || echo "❌ Unable to get pod status"
}

# Function to check system resources
check_resources() {
    echo "💾 System Resources:"
    echo "Memory: $(free -h | grep Mem | awk '{print $3"/"$2}')"
    echo "Disk: $(df -h / | tail -1 | awk '{print $3"/"$2" ("$5" used)"}')"
    echo "Load: $(uptime | awk -F'load average:' '{print $2}')"
}

# Main execution
main() {
    echo "🚀 K3s Cluster Health Check"
    echo "=========================="
    
    hostname=$(hostname)
    echo "🖥️  Node: $hostname"
    echo "📅 Date: $(date)"
    echo ""
    
    check_services
    echo ""
    
    if check_kubectl; then
        check_nodes
        echo ""
        check_pods
        echo ""
    fi
    
    check_resources
    echo ""
    echo "✅ Health check complete"
}

main "$@"
