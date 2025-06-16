#!/bin/bash
# Get comprehensive cluster overview

set -e

# Set default values
PT_include_pods="${PT_include_pods:-true}"
PT_include_services="${PT_include_services:-true}"
PT_include_storage="${PT_include_storage:-true}"

echo "🚀 K3s Cluster Overview"
echo "======================="
echo "🖥️  Node: $(hostname)"
echo "📅 Date: $(date)"
echo ""

# Set kubectl command
KUBECTL_CMD="kubectl"
[ -f /usr/local/bin/k3s ] && KUBECTL_CMD="/usr/local/bin/k3s kubectl"

# Function to check if kubectl is available
check_kubectl() {
    if command -v kubectl >/dev/null 2>&1; then
        return 0
    elif [ -f /usr/local/bin/k3s ]; then
        alias kubectl='/usr/local/bin/k3s kubectl'
        return 0
    else
        echo "❌ kubectl not available"
        return 1
    fi
}

# Function to display cluster information
show_cluster_info() {
    echo "🔧 Cluster Information:"
    echo "K3s Version: $(k3s --version 2>/dev/null | head -n1 || echo "Unknown")"
    echo "Kubernetes Version: $($KUBECTL_CMD version --client --short 2>/dev/null || echo "Unknown")"
    echo ""
}

# Function to show node status
show_nodes() {
    echo "📊 Node Status:"
    if $KUBECTL_CMD get nodes -o wide 2>/dev/null; then
        echo ""
    else
        echo "❌ Unable to get node status"
        return 1
    fi
}

# Function to show namespace overview
show_namespaces() {
    echo "🏠 Namespaces:"
    $KUBECTL_CMD get namespaces 2>/dev/null || echo "❌ Unable to get namespaces"
    echo ""
}

# Function to show deployments by namespace
show_deployments() {
    echo "🚀 Deployments Overview:"
    
    # Check monitoring namespace
    if $KUBECTL_CMD get namespace monitoring >/dev/null 2>&1; then
        echo "📊 Monitoring Stack (monitoring namespace):"
        $KUBECTL_CMD get deployments -n monitoring 2>/dev/null || echo "  No deployments found"
        echo ""
    fi
    
    # Check data engineering namespace
    if $KUBECTL_CMD get namespace data-engineering >/dev/null 2>&1; then
        echo "📊 Data Engineering Stack (data-engineering namespace):"
        $KUBECTL_CMD get deployments -n data-engineering 2>/dev/null || echo "  No deployments found"
        echo ""
    fi
    
    # Check system namespaces
    echo "🔧 System Deployments:"
    $KUBECTL_CMD get deployments -n kube-system 2>/dev/null || echo "  No deployments found"
    echo ""
}

# Function to show detailed pod information
show_pods() {
    if [ "$PT_include_pods" = "true" ]; then
        echo "🐳 Pod Status by Namespace:"
        
        # System pods
        echo "  System Pods (kube-system):"
        $KUBECTL_CMD get pods -n kube-system -o wide 2>/dev/null || echo "    No pods found"
        echo ""
        
        # Monitoring pods
        if $KUBECTL_CMD get namespace monitoring >/dev/null 2>&1; then
            echo "  Monitoring Pods:"
            $KUBECTL_CMD get pods -n monitoring -o wide 2>/dev/null || echo "    No pods found"
            echo ""
        fi
        
        # Data engineering pods
        if $KUBECTL_CMD get namespace data-engineering >/dev/null 2>&1; then
            echo "  Data Engineering Pods:"
            $KUBECTL_CMD get pods -n data-engineering -o wide 2>/dev/null || echo "    No pods found"
            echo ""
        fi
    fi
}

# Function to show services
show_services() {
    if [ "$PT_include_services" = "true" ]; then
        echo "🌐 Services Overview:"
        
        # All services summary
        echo "  All Services:"
        $KUBECTL_CMD get services --all-namespaces 2>/dev/null || echo "    Unable to get services"
        echo ""
    fi
}

# Function to show storage information
show_storage() {
    if [ "$PT_include_storage" = "true" ]; then
        echo "💾 Storage Information:"
        
        # Persistent Volumes
        echo "  Persistent Volumes:"
        $KUBECTL_CMD get pv 2>/dev/null || echo "    No persistent volumes found"
        echo ""
        
        # Persistent Volume Claims
        echo "  Persistent Volume Claims:"
        $KUBECTL_CMD get pvc --all-namespaces 2>/dev/null || echo "    No PVCs found"
        echo ""
    fi
}

# Function to show system resources
show_system_resources() {
    echo "💻 System Resources:"
    echo "  Memory: $(free -h | grep Mem | awk '{print $3"/"$2}')"
    echo "  Disk: $(df -h / | tail -1 | awk '{print $3"/"$2" ("$5" used)"}')"
    echo "  Load: $(cat /proc/loadavg | cut -d' ' -f1-3)"
    echo "  Uptime: $(uptime -p)"
    echo ""
}

# Function to show service health
show_service_health() {
    echo "🔍 Service Health Check:"
    
    # Check system services
    if systemctl is-active --quiet k3s 2>/dev/null; then
        echo "  ✅ K3s server: Running"
    elif systemctl is-active --quiet k3s-agent 2>/dev/null; then
        echo "  ✅ K3s agent: Running"
    else
        echo "  ❌ K3s service: Not running"
    fi
    
    if systemctl is-active --quiet docker 2>/dev/null; then
        echo "  ✅ Docker: Running"
    else
        echo "  ⚠️  Docker: Not running (may be using containerd)"
    fi
    
    # Check if API server is responsive
    if $KUBECTL_CMD cluster-info >/dev/null 2>&1; then
        echo "  ✅ Kubernetes API: Responsive"
    else
        echo "  ❌ Kubernetes API: Not responsive"
    fi
    
    echo ""
}

# Function to show recent events
show_recent_events() {
    echo "📝 Recent Cluster Events (last 10):"
    $KUBECTL_CMD get events --sort-by='.lastTimestamp' --all-namespaces | tail -10 2>/dev/null || echo "  Unable to get events"
    echo ""
}

# Function to show quick access commands
show_access_info() {
    echo "🔗 Quick Access Commands:"
    echo ""
    
    if $KUBECTL_CMD get service -n monitoring prometheus >/dev/null 2>&1; then
        echo "  Prometheus:"
        echo "    kubectl port-forward svc/prometheus 9090:9090 -n monitoring"
    fi
    
    if $KUBECTL_CMD get service -n monitoring grafana >/dev/null 2>&1; then
        echo "  Grafana:"
        echo "    kubectl port-forward svc/grafana 3000:3000 -n monitoring"
    fi
    
    if $KUBECTL_CMD get service -n data-engineering minio-console >/dev/null 2>&1; then
        echo "  MinIO Console:"
        echo "    kubectl port-forward svc/minio-console 9001:9001 -n data-engineering"
    fi
    
    if $KUBECTL_CMD get service -n data-engineering nifi >/dev/null 2>&1; then
        echo "  NiFi:"
        echo "    kubectl port-forward svc/nifi 8080:8080 -n data-engineering"
    fi
    
    echo ""
}

# Main execution
if ! check_kubectl; then
    exit 1
fi

show_cluster_info
show_nodes
show_namespaces
show_deployments
show_pods
show_services
show_storage
show_system_resources
show_service_health
show_recent_events
show_access_info

echo "✅ Cluster overview complete"
