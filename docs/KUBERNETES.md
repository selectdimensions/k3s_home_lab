# Kubernetes Layer - Manifests & Helm

> **Kubernetes manifests, Kustomize overlays, and Helm values for workload deployment**

📍 **Location**: `k8s/`
☸️ **Strategy**: Kustomize + Helm
🌍 **Overlays**: dev, staging, prod

[← Back to Index](./INDEX.md)

---

## Table of Contents

- [Overview](#overview)
- [Directory Structure](#directory-structure)
- [Base Configuration](#base-configuration)
- [Overlays](#overlays)
- [Helm Values](#helm-values)
- [Data Stack](#data-stack)
- [Monitoring Stack](#monitoring-stack)
- [Deployment Workflow](#deployment-workflow)

---

## Overview

The Kubernetes layer uses a **Kustomize + Helm** hybrid approach:

- **Kustomize**: Base configurations with environment-specific overlays
- **Helm**: Pre-packaged charts for complex applications (NiFi, Trino, etc.)

### Architecture

```text
┌─────────────────────────────────────────────────────────────────┐
│                      k8s/ directory                              │
├─────────────────────────────────────────────────────────────────┤
│  base/                   ← Shared configurations                 │
│  ├── kustomization.yaml                                          │
│  ├── namespace.yaml                                              │
│  ├── monitoring/         ← Monitoring base resources             │
│  ├── networkpolicies/    ← Network security                      │
│  └── rbac/               ← Role-based access control             │
│                                                                  │
│  overlays/               ← Environment-specific patches          │
│  ├── dev/                                                        │
│  ├── staging/                                                    │
│  └── prod/                                                       │
│                                                                  │
│  helm-values/            ← Helm chart values                     │
│  ├── nifi-values.yaml                                            │
│  ├── trino-values.yaml                                           │
│  ├── minio-values.yaml                                           │
│  └── postgresql-values.yaml                                      │
│                                                                  │
│  applications/           ← Application-specific manifests        │
└─────────────────────────────────────────────────────────────────┘
```

---

## Directory Structure

```text
k8s/
├── base/                           # Base configurations
│   ├── kustomization.yaml          # Base kustomization
│   ├── namespace.yaml              # Namespace definitions
│   ├── monitoring/                 # Monitoring resources
│   │   ├── kustomization.yaml
│   │   └── servicemonitor.yaml
│   ├── networkpolicies/            # Network policies
│   │   ├── kustomization.yaml
│   │   └── default-deny.yaml
│   └── rbac/                       # RBAC configurations
│       ├── kustomization.yaml
│       ├── cluster-role.yaml
│       └── service-accounts.yaml
│
├── overlays/                       # Environment overlays
│   ├── dev/
│   │   └── kustomization.yaml
│   ├── staging/
│   │   └── kustomization.yaml
│   └── prod/
│       └── kustomization.yaml
│
├── helm-values/                    # Helm chart values
│   ├── nifi-values.yaml            # Apache NiFi
│   ├── trino-values.yaml           # Trino SQL
│   ├── minio-values.yaml           # MinIO S3
│   └── postgresql-values.yaml      # PostgreSQL
│
└── applications/                   # Application manifests
    └── (empty - uses Helm)
```

---

## Base Configuration

### kustomization.yaml

```yaml
# k8s/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - namespace.yaml
```

### namespace.yaml

Defines cluster namespaces:

```yaml
# k8s/base/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: data-engineering
  labels:
    app.kubernetes.io/name: data-engineering
---
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
```

### Namespaces

| Namespace | Purpose |
|-----------|---------|
| `data-engineering` | Data stack (NiFi, Trino, MinIO, PostgreSQL) |
| `monitoring` | Prometheus, Grafana |
| `ingress` | Ingress controllers |
| `metallb-system` | MetalLB load balancer |

---

## Overlays

### Development (dev)

Minimal resources for local testing.

```yaml
# k8s/overlays/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

patchesStrategicMerge:
  - resource-limits.yaml

commonLabels:
  environment: dev
```

### Staging

Pre-production configuration.

```yaml
# k8s/overlays/staging/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

commonLabels:
  environment: staging
```

### Production (prod)

Full resources with HA configuration.

```yaml
# k8s/overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

patchesStrategicMerge:
  - replicas-patch.yaml
  - resource-limits.yaml

commonLabels:
  environment: prod
```

---

## Helm Values

### Apache NiFi

**File**: `k8s/helm-values/nifi-values.yaml`

**Chart**: `cetic/nifi` or custom

```yaml
# NiFi Helm Chart Values
replicaCount: 1

image:
  repository: apache/nifi
  tag: "1.23.2"
  pullPolicy: IfNotPresent

resources:
  limits:
    cpu: 2000m
    memory: 4Gi
  requests:
    cpu: 1000m
    memory: 2Gi

persistence:
  enabled: true
  storageClass: "local-path"
  size: 20Gi

auth:
  admin: "admin"
  # Password via Kubernetes secret

service:
  type: LoadBalancer
  port: 8080
  httpsPort: 8443

env:
  - name: NIFI_WEB_HTTP_HOST
    value: "0.0.0.0"
  - name: NIFI_WEB_HTTPS_PORT
    value: "8443"
  - name: NIFI_CLUSTER_IS_NODE
    value: "true"
```

**Access**:
```powershell
.\Make.ps1 nifi-ui
# http://localhost:8080/nifi
# Credentials: admin / nifi123456789!
```

### Trino

**File**: `k8s/helm-values/trino-values.yaml`

**Chart**: `trinodb/trino`

```yaml
# Trino Helm Chart Values
server:
  workers: 2
  coordinatorExtraConfig: |
    query.max-memory=2GB
    query.max-memory-per-node=512MB

coordinator:
  resources:
    limits:
      cpu: 1000m
      memory: 2Gi
    requests:
      cpu: 500m
      memory: 1Gi

worker:
  resources:
    limits:
      cpu: 1000m
      memory: 2Gi
    requests:
      cpu: 500m
      memory: 1Gi

catalogs:
  postgresql: |
    connector.name=postgresql
    connection-url=jdbc:postgresql://postgresql:5432/dataplatform
    connection-user=trino
    connection-password=${POSTGRES_PASSWORD}
  hive: |
    connector.name=hive
    hive.metastore.uri=thrift://metastore:9083
    hive.s3.endpoint=http://minio:9000
    hive.s3.aws-access-key=${MINIO_ACCESS_KEY}
    hive.s3.aws-secret-key=${MINIO_SECRET_KEY}
```

### MinIO

**File**: `k8s/helm-values/minio-values.yaml`

**Chart**: `minio/minio`

```yaml
# MinIO Helm Chart Values
mode: standalone

replicas: 1

resources:
  limits:
    cpu: 1000m
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 1Gi

persistence:
  enabled: true
  size: 50Gi
  storageClass: "local-path"

rootUser: admin
rootPassword: "" # Set via secret

consoleService:
  type: LoadBalancer
  port: 9001

service:
  type: ClusterIP
  port: 9000

buckets:
  - name: data-lake
    policy: none
  - name: warehouse
    policy: none
```

### PostgreSQL

**File**: `k8s/helm-values/postgresql-values.yaml`

**Chart**: `bitnami/postgresql`

```yaml
# PostgreSQL Helm Chart Values
auth:
  postgresPassword: "" # Set via secret
  database: dataplatform
  username: dataplatform

primary:
  resources:
    limits:
      cpu: 1000m
      memory: 1Gi
    requests:
      cpu: 250m
      memory: 256Mi

  persistence:
    enabled: true
    size: 20Gi
    storageClass: "local-path"

metrics:
  enabled: true
  serviceMonitor:
    enabled: true
```

---

## Data Stack

### Deployed Components

| Component | Namespace | Service | Port |
|-----------|-----------|---------|------|
| Apache NiFi | data-engineering | nifi | 8080, 8443 |
| Trino | data-engineering | trino | 8080 |
| MinIO | data-engineering | minio | 9000, 9001 |
| PostgreSQL | data-engineering | postgresql | 5432 |

### Data Flow

```text
┌─────────────────────────────────────────────────────────────────┐
│                      Data Engineering Stack                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────────┐  │
│   │  NiFi   │───▶│  MinIO  │◀───│  Trino  │───▶│ PostgreSQL  │  │
│   │ (ETL)   │    │  (S3)   │    │  (SQL)  │    │   (OLTP)    │  │
│   └─────────┘    └─────────┘    └─────────┘    └─────────────┘  │
│       │              │              │                │           │
│       ▼              ▼              ▼                ▼           │
│   Data Flows    Object Store   SQL Queries     Metadata        │
│   Automation    Data Lake      Analytics       Storage         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Deployment

```powershell
# Deploy entire data stack
.\Make.ps1 deploy-data-stack

# Or via Puppet task
.\bolt.ps1 task run pi_cluster_automation::deploy_data_stack --targets masters
```

---

## Monitoring Stack

### Components

| Component | Namespace | Port | Purpose |
|-----------|-----------|------|---------|
| Prometheus | monitoring | 9090 | Metrics collection |
| Grafana | monitoring | 3000 | Visualization |
| AlertManager | monitoring | 9093 | Alert routing |

### Deployment

```powershell
# Deploy monitoring stack
.\Make.ps1 setup-monitoring

# Access Grafana
.\Make.ps1 grafana-ui
# http://localhost:3000
```

---

## Deployment Workflow

### Using Kustomize

```powershell
# Preview manifests
kubectl kustomize k8s/overlays/dev

# Apply to cluster
kubectl apply -k k8s/overlays/dev
```

### Using Make.ps1

```powershell
# Apply manifests for environment
.\Make.ps1 apply-manifests -Environment dev
```

### Using Helm

```powershell
# Add repositories
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add minio https://charts.min.io
helm repo update

# Install NiFi (example)
helm upgrade --install nifi ./charts/nifi \
  --namespace data-engineering \
  --values k8s/helm-values/nifi-values.yaml

# Install PostgreSQL
helm upgrade --install postgresql bitnami/postgresql \
  --namespace data-engineering \
  --values k8s/helm-values/postgresql-values.yaml
```

---

## Current Cluster State

### Pods (data-engineering namespace)

```text
NAME                          READY   STATUS    RESTARTS   AGE
nifi-7b859694c5-7zxf5         1/1     Running   0          2h
minio-674bcff6bb-2nqzh        1/1     Running   0          2h
postgresql-68d6fbfd66-6bc7w   1/1     Running   0          2h
trino-7df98d7946-vwgvm        1/1     Running   0          2h
```

### Services

```powershell
kubectl get svc -n data-engineering
```

```text
NAME         TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)
nifi         LoadBalancer   10.43.x.x       pending       8080:xxxxx/TCP
minio        ClusterIP      10.43.x.x       <none>        9000/TCP
minio-console LoadBalancer  10.43.x.x       pending       9001:xxxxx/TCP
postgresql   ClusterIP      10.43.x.x       <none>        5432/TCP
trino        ClusterIP      10.43.x.x       <none>        8080/TCP
```

---

## Storage

### StorageClass

The cluster uses K3s's built-in `local-path` provisioner:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
```

### Persistent Volume Claims

```powershell
kubectl get pvc -n data-engineering
```

| PVC | Size | StorageClass |
|-----|------|--------------|
| nifi-data | 20Gi | local-path |
| postgresql-data | 20Gi | local-path |
| minio-data | 50Gi | local-path |

---

## Network Policies

### Default Deny (Recommended)

```yaml
# k8s/base/networkpolicies/default-deny.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

### Allow Data Stack Communication

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-data-stack
  namespace: data-engineering
spec:
  podSelector: {}
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: data-engineering
```

---

## RBAC

### Service Account

```yaml
# k8s/base/rbac/service-accounts.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: data-platform-sa
  namespace: data-engineering
```

### Cluster Role

```yaml
# k8s/base/rbac/cluster-role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: data-platform-role
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "configmaps", "secrets"]
    verbs: ["get", "list", "watch"]
```

---

## Troubleshooting

### Check Pod Status

```powershell
kubectl get pods -n data-engineering
kubectl describe pod <pod-name> -n data-engineering
```

### View Logs

```powershell
kubectl logs -f <pod-name> -n data-engineering
```

### Access Pod Shell

```powershell
kubectl exec -it <pod-name> -n data-engineering -- /bin/bash
```

### Port Forwarding

```powershell
# Manual port forward
kubectl port-forward svc/nifi 8080:8080 -n data-engineering

# Or via Make.ps1
.\Make.ps1 nifi-ui
```

---

## Related Documentation

- [AUTOMATION.md](./AUTOMATION.md) - Make.ps1 Kubernetes commands
- [TERRAFORM.md](./TERRAFORM.md) - Terraform generates Helm values
- [PUPPET.md](./PUPPET.md) - Puppet deploys Kubernetes resources

---

[← Back to Index](./INDEX.md)
