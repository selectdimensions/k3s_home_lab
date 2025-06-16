#!/bin/bash
# Deploy data platform services

set -e

# Read JSON input
eval "$(jq -r '@sh "ENVIRONMENT=\(.environment) SERVICES=\(.services)"')"

ENVIRONMENT=${ENVIRONMENT:-prod}
SERVICES=${SERVICES:-"metallb,postgresql,minio,nifi,prometheus,grafana"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Function to check if kubectl is available
check_kubectl() {
    if command -v kubectl >/dev/null 2>&1; then
        return 0
    elif [ -f /usr/local/bin/k3s ]; then
        alias kubectl='/usr/local/bin/k3s kubectl'
        return 0
    else
        error "kubectl not available"
        return 1
    fi
}

# Function to deploy MetalLB
deploy_metallb() {
    log "Deploying MetalLB..."
    
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
    
    # Wait for MetalLB to be ready
    kubectl wait --namespace metallb-system \
        --for=condition=ready pod \
        --selector=app=metallb \
        --timeout=300s
    
    # Configure IP pool
    cat <<EOF | kubectl apply -f -
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
  name: example
  namespace: metallb-system
spec:
  ipAddressPools:
  - first-pool
EOF
    
    log "✅ MetalLB deployed"
}

# Function to deploy PostgreSQL
deploy_postgresql() {
    log "Deploying PostgreSQL..."
    
    kubectl create namespace data-platform --dry-run=client -o yaml | kubectl apply -f -
    
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgresql
  namespace: data-platform
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgresql
  template:
    metadata:
      labels:
        app: postgresql
    spec:
      containers:
      - name: postgresql
        image: postgres:16-alpine
        env:
        - name: POSTGRES_DB
          value: "cluster_db"
        - name: POSTGRES_USER
          value: "cluster_user"
        - name: POSTGRES_PASSWORD
          value: "SecurePostgresPassword123"
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: postgres-storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: postgresql
  namespace: data-platform
spec:
  type: LoadBalancer
  ports:
  - port: 5432
    targetPort: 5432
  selector:
    app: postgresql
EOF
    
    log "✅ PostgreSQL deployed"
}

# Function to deploy MinIO
deploy_minio() {
    log "Deploying MinIO..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  namespace: data-platform
spec:
  replicas: 1
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      labels:
        app: minio
    spec:
      containers:
      - name: minio
        image: minio/minio:latest
        args:
        - server
        - /data
        - --console-address
        - ":9001"
        env:
        - name: MINIO_ROOT_USER
          value: "admin"
        - name: MINIO_ROOT_PASSWORD
          value: "SecureMinioPassword123"
        ports:
        - containerPort: 9000
        - containerPort: 9001
        volumeMounts:
        - name: minio-storage
          mountPath: /data
      volumes:
      - name: minio-storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: minio-api
  namespace: data-platform
spec:
  type: LoadBalancer
  ports:
  - port: 9000
    targetPort: 9000
  selector:
    app: minio
---
apiVersion: v1
kind: Service
metadata:
  name: minio-console
  namespace: data-platform
spec:
  type: LoadBalancer
  ports:
  - port: 9001
    targetPort: 9001
  selector:
    app: minio
EOF
    
    log "✅ MinIO deployed"
}

# Function to deploy monitoring stack
deploy_monitoring() {
    log "Deploying Prometheus and Grafana..."
    
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # Add Prometheus Helm repo and install
    if command -v helm >/dev/null 2>&1; then
        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
        helm repo update
        
        helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
            --namespace monitoring \
            --set prometheus.service.type=LoadBalancer \
            --set grafana.service.type=LoadBalancer \
            --set grafana.adminPassword=admin123
    else
        info "Helm not available, skipping Prometheus/Grafana deployment"
    fi
    
    log "✅ Monitoring deployed"
}

# Main deployment function
main() {
    log "🚀 Starting data platform deployment"
    log "Environment: $ENVIRONMENT"
    log "Services: $SERVICES"
    
    if ! check_kubectl; then
        error "kubectl not available, cannot deploy services"
        exit 1
    fi
    
    # Split services and deploy each one
    IFS=',' read -ra SERVICE_ARRAY <<< "$SERVICES"
    for service in "${SERVICE_ARRAY[@]}"; do
        case "$service" in
            metallb)
                deploy_metallb
                ;;
            postgresql)
                deploy_postgresql
                ;;
            minio)
                deploy_minio
                ;;
            prometheus|grafana)
                deploy_monitoring
                ;;
            *)
                info "Skipping unknown service: $service"
                ;;
        esac
    done
    
    log "✅ Data platform deployment complete!"
    
    # Output status
    echo ""
    info "Checking deployment status..."
    kubectl get pods --all-namespaces | grep -E "(data-platform|monitoring|metallb-system)"
    echo ""
    info "Services available:"
    kubectl get svc --all-namespaces | grep LoadBalancer
}

main "$@"
