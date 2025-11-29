#!/bin/bash
# Deploy data engineering stack (NiFi, Trino, PostgreSQL, MinIO)

set -e

# Set default values
PT_components="${PT_components:-all}"
PT_namespace="${PT_namespace:-data-engineering}"
PT_storage_class="${PT_storage_class:-local-path}"
PT_data_size="${PT_data_size:-20Gi}"

echo "🔄 Deploying data engineering stack: $PT_components"
echo "📁 Namespace: $PT_namespace"
echo "💾 Storage class: $PT_storage_class"
echo "📊 Data volume size: $PT_data_size"

# Set kubectl command
KUBECTL_CMD="kubectl"
[ -f /usr/local/bin/k3s ] && KUBECTL_CMD="/usr/local/bin/k3s kubectl"

# Create namespace
echo "📁 Creating namespace: $PT_namespace"
$KUBECTL_CMD create namespace $PT_namespace --dry-run=client -o yaml | $KUBECTL_CMD apply -f -

# Function to deploy MinIO (S3-compatible storage)
deploy_minio() {
    echo "🗃️  Deploying MinIO..."

    # Create MinIO credentials secret
    cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: minio-credentials
  namespace: $PT_namespace
type: Opaque
stringData:
  MINIO_ROOT_USER: "admin"
  MINIO_ROOT_PASSWORD: "minio123!"
EOF

    # Create MinIO PVC
    cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: minio-pvc
  namespace: $PT_namespace
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: $PT_storage_class
  resources:
    requests:
      storage: $PT_data_size
EOF

    # Create MinIO Deployment
    cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  namespace: $PT_namespace
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
        image: minio/minio:RELEASE.2023-12-14T18-51-57Z
        args:
          - server
          - /data
          - --console-address
          - ":9001"
        env:
        - name: MINIO_ROOT_USER
          valueFrom:
            secretKeyRef:
              name: minio-credentials
              key: MINIO_ROOT_USER
        - name: MINIO_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: minio-credentials
              key: MINIO_ROOT_PASSWORD
        ports:
        - containerPort: 9000
          name: api
        - containerPort: 9001
          name: console
        volumeMounts:
        - name: minio-storage
          mountPath: /data
        livenessProbe:
          httpGet:
            path: /minio/health/live
            port: 9000
          initialDelaySeconds: 30
          periodSeconds: 20
        readinessProbe:
          httpGet:
            path: /minio/health/ready
            port: 9000
          initialDelaySeconds: 10
          periodSeconds: 5
      volumes:
      - name: minio-storage
        persistentVolumeClaim:
          claimName: minio-pvc
EOF

    # Create MinIO Services with MetalLB LoadBalancer
    cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: v1
kind: Service
metadata:
  name: minio-api
  namespace: $PT_namespace
  annotations:
    metallb.universe.tf/loadBalancerIPs: "192.168.0.203"
spec:
  selector:
    app: minio
  ports:
    - protocol: TCP
      port: 9000
      targetPort: 9000
      name: api
    - protocol: TCP
      port: 9001
      targetPort: 9001
      name: console
  type: LoadBalancer
EOF

    echo "✅ MinIO deployed"
}

# Function to deploy PostgreSQL
deploy_postgresql() {
    echo "🐘 Deploying PostgreSQL..."

    # Create PostgreSQL credentials secret
    cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: postgresql-credentials
  namespace: $PT_namespace
type: Opaque
stringData:
  POSTGRES_USER: "dataeng"
  POSTGRES_PASSWORD: "postgres123!"
  POSTGRES_DB: "dataengineering"
EOF

    # Create PostgreSQL PVC
    cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgresql-pvc
  namespace: $PT_namespace
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: $PT_storage_class
  resources:
    requests:
      storage: $PT_data_size
EOF

    # Create PostgreSQL Deployment
    cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgresql
  namespace: $PT_namespace
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
        image: postgres:15-alpine
        env:
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgresql-credentials
              key: POSTGRES_USER
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgresql-credentials
              key: POSTGRES_PASSWORD
        - name: POSTGRES_DB
          valueFrom:
            secretKeyRef:
              name: postgresql-credentials
              key: POSTGRES_DB
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgresql-storage
          mountPath: /var/lib/postgresql/data
        livenessProbe:
          exec:
            command:
              - /bin/sh
              - -c
              - exec pg_isready -U "\$POSTGRES_USER" -h 127.0.0.1 -p 5432
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
              - /bin/sh
              - -c
              - exec pg_isready -U "\$POSTGRES_USER" -h 127.0.0.1 -p 5432
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: postgresql-storage
        persistentVolumeClaim:
          claimName: postgresql-pvc
EOF

    # Create PostgreSQL Service with MetalLB LoadBalancer
    cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: v1
kind: Service
metadata:
  name: postgresql
  namespace: $PT_namespace
  annotations:
    metallb.universe.tf/loadBalancerIPs: "192.168.0.204"
spec:
  selector:
    app: postgresql
  ports:
    - protocol: TCP
      port: 5432
      targetPort: 5432
  type: LoadBalancer
EOF

    echo "✅ PostgreSQL deployed"
}

# Function to deploy Apache NiFi
deploy_nifi() {
    echo "🌊 Deploying Apache NiFi..."

    # Create NiFi PVC
    cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nifi-pvc
  namespace: $PT_namespace
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: $PT_storage_class
  resources:
    requests:
      storage: $PT_data_size
EOF

    # Create NiFi Deployment
    cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nifi
  namespace: $PT_namespace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nifi
  template:
    metadata:
      labels:
        app: nifi
    spec:
      containers:
      - name: nifi
        image: apache/nifi:1.24.0
        env:
        - name: SINGLE_USER_CREDENTIALS_USERNAME
          value: "admin"
        - name: SINGLE_USER_CREDENTIALS_PASSWORD
          value: "nifi123456789!"
        - name: NIFI_WEB_HTTP_PORT
          value: "8080"
        - name: NIFI_CLUSTER_IS_NODE
          value: "false"
        - name: NIFI_ZK_CONNECT_STRING
          value: "localhost:2181"
        - name: NIFI_ELECTION_MAX_WAIT
          value: "1 min"
        ports:
        - containerPort: 8080
          name: http
        - containerPort: 8443
          name: https
        volumeMounts:
        - name: nifi-storage
          mountPath: /opt/nifi/nifi-current/data
        livenessProbe:
          httpGet:
            path: /nifi-api/system-diagnostics
            port: 8080
          initialDelaySeconds: 180
          periodSeconds: 30
          timeoutSeconds: 10
        readinessProbe:
          httpGet:
            path: /nifi-api/system-diagnostics
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 15
        resources:
          requests:
            memory: "2Gi"
            cpu: "500m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
      volumes:
      - name: nifi-storage
        persistentVolumeClaim:
          claimName: nifi-pvc
EOF

    # Create NiFi Service with MetalLB LoadBalancer
    cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: v1
kind: Service
metadata:
  name: nifi
  namespace: $PT_namespace
  annotations:
    metallb.universe.tf/loadBalancerIPs: "192.168.0.200"
spec:
  selector:
    app: nifi
  ports:
    - protocol: TCP
      port: 8080
      targetPort: 8080
      name: http
    - protocol: TCP
      port: 8443
      targetPort: 8443
      name: https
  type: LoadBalancer
EOF

    echo "✅ NiFi deployed"
}

# Function to deploy Trino (SQL query engine)
deploy_trino() {
    echo "⚡ Deploying Trino..."

    # Create Trino ConfigMap
    cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: trino-config
  namespace: $PT_namespace
data:
  config.properties: |
    coordinator=true
    node-scheduler.include-coordinator=true
    http-server.http.port=8080
    query.max-memory=2GB
    query.max-memory-per-node=1GB
    discovery-server.enabled=true
    discovery.uri=http://localhost:8080

  node.properties: |
    node.environment=production
    node.id=ffffffff-ffff-ffff-ffff-ffffffffffff
    node.data-dir=/data/trino

  jvm.config: |
    -server
    -Xmx2G
    -XX:+UseG1GC
    -XX:G1HeapRegionSize=32M
    -XX:+UseGCOverheadLimit
    -XX:+ExplicitGCInvokesConcurrent
    -XX:+HeapDumpOnOutOfMemoryError
    -XX:+ExitOnOutOfMemoryError
    -Djdk.attach.allowAttachSelf=true

  log.properties: |
    io.trino=INFO

  catalog-postgresql.properties: |
    connector.name=postgresql
    connection-url=jdbc:postgresql://postgresql:5432/dataengineering
    connection-user=dataeng
    connection-password=postgres123!

  catalog-minio.properties: |
    connector.name=hive-hadoop2
    hive.metastore.uri=thrift://localhost:9083
    hive.s3.endpoint=http://minio-api:9000
    hive.s3.access-key=admin
    hive.s3.secret-key=minio123!
    hive.s3.path-style-access=true
    hive.s3.ssl.enabled=false
EOF

    # Create Trino Deployment
    cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: trino
  namespace: $PT_namespace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: trino
  template:
    metadata:
      labels:
        app: trino
    spec:
      containers:
      - name: trino
        image: trinodb/trino:435
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: trino-config
          mountPath: /etc/trino
        - name: trino-data
          mountPath: /data/trino
        livenessProbe:
          httpGet:
            path: /v1/info
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /v1/info
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 15
        resources:
          requests:
            memory: "2Gi"
            cpu: "500m"
          limits:
            memory: "3Gi"
            cpu: "1500m"
      volumes:
      - name: trino-config
        configMap:
          name: trino-config
      - name: trino-data
        emptyDir: {}
EOF

    # Create Trino Service with MetalLB LoadBalancer
    cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: v1
kind: Service
metadata:
  name: trino
  namespace: $PT_namespace
  annotations:
    metallb.universe.tf/loadBalancerIPs: "192.168.0.202"
spec:
  selector:
    app: trino
  ports:
    - protocol: TCP
      port: 8080
      targetPort: 8080
  type: LoadBalancer
EOF

    echo "✅ Trino deployed"
}

# Deploy components based on selection
case "$PT_components" in
    "minio")
        deploy_minio
        ;;
    "postgresql")
        deploy_postgresql
        ;;
    "nifi")
        deploy_nifi
        ;;
    "trino")
        deploy_trino
        ;;
    "all")
        deploy_minio
        deploy_postgresql
        deploy_nifi
        deploy_trino
        ;;
    *)
        echo "❌ Unknown component: $PT_components"
        exit 1
        ;;
esac

# Wait for deployments to be ready
echo "⏳ Waiting for deployments to be ready..."
$KUBECTL_CMD wait --for=condition=available --timeout=600s deployment --all -n $PT_namespace

# Show deployment status
echo ""
echo "✅ Data engineering stack deployed successfully!"
echo "📊 Deployments:"
$KUBECTL_CMD get deployments -n $PT_namespace

echo ""
echo "📊 Services:"
$KUBECTL_CMD get services -n $PT_namespace

echo ""
echo "🌐 Direct Access URLs (via MetalLB LoadBalancer):"
echo "  NiFi:          http://192.168.0.200:8080"
echo "  Trino:         http://192.168.0.202:8080"
echo "  MinIO Console: http://192.168.0.203:9001"
echo "  MinIO API:     http://192.168.0.203:9000"
echo "  PostgreSQL:    psql -h 192.168.0.204 -U dataeng -d dataengineering"
echo ""
echo "🔄 Port-forward alternative (if LoadBalancer not available):"
echo "  MinIO Console: kubectl port-forward svc/minio-api 9001:9001 -n $PT_namespace"
echo "  MinIO API: kubectl port-forward svc/minio-api 9000:9000 -n $PT_namespace"
echo "  NiFi: kubectl port-forward svc/nifi 8080:8080 -n $PT_namespace"
echo "  Trino: kubectl port-forward svc/trino 8080:8080 -n $PT_namespace"
echo "  PostgreSQL: kubectl port-forward svc/postgresql 5432:5432 -n $PT_namespace"

echo ""
echo "📋 Default Credentials:"
echo "  MinIO: admin / minio123!"
echo "  NiFi: admin / nifi123456789!"
echo "  PostgreSQL: dataeng / postgres123!"
