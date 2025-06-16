#!/bin/bash
# Deploy monitoring stack (Prometheus, Grafana, AlertManager)

set -e

# Set default values
PT_stack_components="${PT_stack_components:-all}"
PT_namespace="${PT_namespace:-monitoring}"  
PT_persistent_storage="${PT_persistent_storage:-true}"
PT_retention_days="${PT_retention_days:-15}"

echo "🔄 Setting up monitoring stack: $PT_stack_components"
echo "📊 Namespace: $PT_namespace"
echo "💾 Persistent storage: $PT_persistent_storage"
echo "📅 Retention: $PT_retention_days days"

# Set kubectl command
KUBECTL_CMD="kubectl"
[ -f /usr/local/bin/k3s ] && KUBECTL_CMD="/usr/local/bin/k3s kubectl"

# Create namespace
echo "📁 Creating namespace: $PT_namespace"
$KUBECTL_CMD create namespace $PT_namespace --dry-run=client -o yaml | $KUBECTL_CMD apply -f -

# Function to deploy Prometheus
deploy_prometheus() {
    echo "📊 Deploying Prometheus..."
    
    # Create Prometheus ConfigMap
    cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: $PT_namespace
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
    
    rule_files:
      - "/etc/prometheus/rules/*.yml"
    
    alerting:
      alertmanagers:
        - static_configs:
            - targets:
              - alertmanager:9093
    
    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']
      
      - job_name: 'kubernetes-nodes'
        kubernetes_sd_configs:
          - role: node
        relabel_configs:
          - source_labels: [__address__]
            regex: '(.*):10250'
            target_label: __address__
            replacement: '\${1}:9100'
      
      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
      
      - job_name: 'kube-state-metrics'
        static_configs:
          - targets: ['kube-state-metrics:8080']
EOF
    
    # Create Prometheus Deployment
    cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: $PT_namespace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:v2.40.0
        args:
          - '--config.file=/etc/prometheus/prometheus.yml'
          - '--storage.tsdb.path=/prometheus/'
          - '--web.console.libraries=/etc/prometheus/console_libraries'
          - '--web.console.templates=/etc/prometheus/consoles'
          - '--storage.tsdb.retention.time=${PT_retention_days}d'
          - '--web.enable-lifecycle'
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: config-volume
          mountPath: /etc/prometheus/
        - name: prometheus-storage
          mountPath: /prometheus/
      volumes:
      - name: config-volume
        configMap:
          name: prometheus-config
      - name: prometheus-storage
        $([ "$PT_persistent_storage" = "true" ] && echo "persistentVolumeClaim:" || echo "emptyDir: {}")
        $([ "$PT_persistent_storage" = "true" ] && echo "  claimName: prometheus-pvc")
EOF

    # Create PVC if persistent storage is enabled
    if [ "$PT_persistent_storage" = "true" ]; then
        cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prometheus-pvc
  namespace: $PT_namespace
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
EOF
    fi
    
    # Create Prometheus Service
    cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: $PT_namespace
spec:
  selector:
    app: prometheus
  ports:
    - protocol: TCP
      port: 9090
      targetPort: 9090
  type: ClusterIP
EOF

    echo "✅ Prometheus deployed"
}

# Function to deploy Grafana
deploy_grafana() {
    echo "📈 Deploying Grafana..."
    
    # Create Grafana ConfigMap for datasources
    cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: $PT_namespace
data:
  prometheus.yaml: |
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus:9090
      access: proxy
      isDefault: true
EOF
    
    # Create Grafana Deployment
    cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: $PT_namespace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:9.3.0
        ports:
        - containerPort: 3000
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          value: "admin123"
        - name: GF_INSTALL_PLUGINS
          value: "grafana-piechart-panel"
        volumeMounts:
        - name: grafana-storage
          mountPath: /var/lib/grafana
        - name: grafana-datasources
          mountPath: /etc/grafana/provisioning/datasources/
      volumes:
      - name: grafana-storage
        $([ "$PT_persistent_storage" = "true" ] && echo "persistentVolumeClaim:" || echo "emptyDir: {}")
        $([ "$PT_persistent_storage" = "true" ] && echo "  claimName: grafana-pvc")
      - name: grafana-datasources
        configMap:
          name: grafana-datasources
EOF

    # Create PVC if persistent storage is enabled
    if [ "$PT_persistent_storage" = "true" ]; then
        cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: grafana-pvc
  namespace: $PT_namespace
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
EOF
    fi
    
    # Create Grafana Service
    cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: $PT_namespace
spec:
  selector:
    app: grafana
  ports:
    - protocol: TCP
      port: 3000
      targetPort: 3000
  type: ClusterIP
EOF

    echo "✅ Grafana deployed (admin/admin123)"
}

# Function to deploy AlertManager
deploy_alertmanager() {
    echo "🚨 Deploying AlertManager..."
    
    # Create AlertManager ConfigMap
    cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: $PT_namespace
data:
  alertmanager.yml: |
    global:
      smtp_smarthost: 'localhost:587'
      smtp_from: 'alertmanager@k3s-cluster.local'
    
    route:
      group_by: ['alertname']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 1h
      receiver: 'web.hook'
    
    receivers:
    - name: 'web.hook'
      webhook_configs:
      - url: 'http://localhost:5001/alerts'
EOF
    
    # Create AlertManager Deployment
    cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alertmanager
  namespace: $PT_namespace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: alertmanager
  template:
    metadata:
      labels:
        app: alertmanager
    spec:
      containers:
      - name: alertmanager
        image: prom/alertmanager:v0.25.0
        args:
          - '--config.file=/etc/alertmanager/alertmanager.yml'
          - '--storage.path=/alertmanager'
        ports:
        - containerPort: 9093
        volumeMounts:
        - name: config-volume
          mountPath: /etc/alertmanager/
        - name: alertmanager-storage
          mountPath: /alertmanager
      volumes:
      - name: config-volume
        configMap:
          name: alertmanager-config
      - name: alertmanager-storage
        emptyDir: {}
EOF
    
    # Create AlertManager Service
    cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: v1
kind: Service
metadata:
  name: alertmanager
  namespace: $PT_namespace
spec:
  selector:
    app: alertmanager
  ports:
    - protocol: TCP
      port: 9093
      targetPort: 9093
  type: ClusterIP
EOF

    echo "✅ AlertManager deployed"
}

# Function to deploy Node Exporter
deploy_node_exporter() {
    echo "📊 Deploying Node Exporter..."
    
    cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
  namespace: $PT_namespace
spec:
  selector:
    matchLabels:
      app: node-exporter
  template:
    metadata:
      labels:
        app: node-exporter
    spec:
      hostNetwork: true
      hostPID: true
      containers:
      - name: node-exporter
        image: prom/node-exporter:v1.5.0
        args:
          - '--path.procfs=/host/proc'
          - '--path.sysfs=/host/sys'
          - '--collector.filesystem.ignored-mount-points=^/(sys|proc|dev|host|etc)(\$|/)'
        ports:
        - containerPort: 9100
          hostPort: 9100
        volumeMounts:
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
EOF

    echo "✅ Node Exporter deployed"
}

# Deploy components based on selection
case "$PT_stack_components" in
    "prometheus")
        deploy_prometheus
        ;;
    "grafana")
        deploy_grafana
        ;;
    "alertmanager")
        deploy_alertmanager
        ;;
    "all")
        deploy_node_exporter
        deploy_prometheus
        deploy_alertmanager
        deploy_grafana
        ;;
    *)
        echo "❌ Unknown stack component: $PT_stack_components"
        exit 1
        ;;
esac

# Wait for deployments to be ready
echo "⏳ Waiting for deployments to be ready..."
$KUBECTL_CMD wait --for=condition=available --timeout=300s deployment --all -n $PT_namespace

# Show service information
echo ""
echo "✅ Monitoring stack deployed successfully!"
echo "📊 Services:"
$KUBECTL_CMD get services -n $PT_namespace

echo ""
echo "🌐 Access URLs (use kubectl port-forward):"
echo "  Prometheus: kubectl port-forward svc/prometheus 9090:9090 -n $PT_namespace"
echo "  Grafana: kubectl port-forward svc/grafana 3000:3000 -n $PT_namespace"
echo "  AlertManager: kubectl port-forward svc/alertmanager 9093:9093 -n $PT_namespace"
