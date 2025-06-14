[![Kubernetes Applications CD](https://github.com/selectdimensions/k3s_home_lab/actions/workflows/k8s-apps-cd.yml/badge.svg?branch=main)](https://github.com/selectdimensions/k3s_home_lab/actions/workflows/k8s-apps-cd.yml)
[![Puppet CI/CD](https://github.com/selectdimensions/k3s_home_lab/actions/workflows/puppet-ci.yml/badge.svg?branch=main)](https://github.com/selectdimensions/k3s_home_lab/actions/workflows/puppet-ci.yml)
[![Security Scanning](https://github.com/selectdimensions/k3s_home_lab/actions/workflows/security-scan.yml/badge.svg?branch=main)](https://github.com/selectdimensions/k3s_home_lab/actions/workflows/security-scan.yml)
[![Terraform CI/CD](https://github.com/selectdimensions/k3s_home_lab/actions/workflows/terraform-ci.yml/badge.svg?branch=main)](https://github.com/selectdimensions/k3s_home_lab/actions/workflows/terraform-ci.yml)

*Thinking...*

> The user wants me to add this comprehensive requirements document to the "How It Works" document I just created. This is a detailed PRD (Product Requirements Document) for their Pi Cluster project. I should integrate this information into the existing document in a way that flows naturally and enhances the understanding of the project.
> 
> I'll add this as a new section at the beginning of the document, as it provides the formal requirements and specifications that the rest of the document implements. This will give readers the complete context before diving into the technical implementation details.

# How It Works: Pi Cluster Automation with Puppet and Terraform

## Table of Contents
1. [Product Requirements Document](#product-requirements-document)
2. [Architecture Overview](#architecture-overview)
3. [Component Breakdown](#component-breakdown)
4. [Workflow Explanation](#workflow-explanation)
5. [Setup and Execution](#setup-and-execution)
6. [Folder Structure Deep Dive](#folder-structure-deep-dive)
7. [Network Architecture](#network-architecture)
8. [Automation Flow](#automation-flow)
9. [Troubleshooting Guide](#troubleshooting-guide)

---

## Product Requirements Document

### 🗂️ 1. Overview
- **Product Name & Version**: PiClusterOps v1.0
- **Document Owner**: Hezekiah Jenkins
- **Last Updated Date**: 2025-06-10
- **Stakeholders**: Hezekiah Jenkins, DevOps Team, Data Engineering Learners
- **Purpose & Scope**: Define and guide the deployment and operation of a Raspberry Pi 5-based Kubernetes cluster for educational, experimental, and light production use with a focus on data engineering tools like NiFi, Trino, SQL, and Python.
- **Assumptions & Constraints**: Limited by ARM architecture, microSD I/O, and thermals; assumes local network availability; constrained to homelab scale.

### 🧠 2. Functional Requirements
- Deploy and manage a fully containerized Kubernetes cluster using K3s.
- Integrate NiFi for data flow orchestration.
- Install Trino for federated SQL querying.
- Provide PostgreSQL and MinIO for storage and SQL backend.
- Enable Python-based data analysis (e.g., JupyterLab, FastAPI microservices).
- Monitor and visualize system and data health (Prometheus, Grafana, ELK).

**User Stories**: 
- As a data engineer, I want to run NiFi flows that write to PostgreSQL or MinIO. 
- As a developer, I want to query different datasets via Trino and analyze them in Python. 
- As a sysadmin, I want GitOps-style deployment via Flux CD and Terraform.

**External System Interactions**: 
- API access to public data (weather, finance) 
- GitHub for version control 
- Optional: cloud backup services

### ⚙️ 3. Hardware Requirements

#### 🧲 Compute:
- **Processor**: Broadcom BCM2712 (ARM Cortex-A76)
- **CPU Cores**: 4 cores per Pi (16 total)
- **GPU**: VideoCore VII (no CUDA support)
- **RAM**: 8GB LPDDR4 per Pi
- **Storage**: 64GB U3 microSD cards + optional USB SSDs

#### 🧱 Embedded/Peripheral:
- 4x Raspberry Pi 5 SBCs
- Optional: temperature and environmental sensors for data ingestion demo

#### 🔌 Power/Connectivity:
- USB-C 5V/5A power per Pi
- Gigabit Ethernet to central switch
- USB 3.0 ports for external storage

#### 🪊 Environmental:
- Active cooling required
- Custom 3D printed or modular rack case

### 💻 4. Software Requirements

#### 🧰 Operating Systems:
- Raspberry Pi OS 64-bit (Bookworm)

#### 🛆 System Software:
- Docker, K3s
- Terraform, Helm
- cert-manager, Vault

#### 🧑‍💻 Application Software:
- Apache NiFi
- Trino + Hive catalog
- PostgreSQL
- MinIO
- Python 3.12 + JupyterLab
- FastAPI (optional)
- Prometheus, Grafana, Fluentd, ELK

#### 🧪 Dev/Test Tools:
- GitHub + Flux CD
- pytest, flake8
- VS Code Server

#### 🔐 Licensing:
- All software: MIT/Apache 2.0 compliant (open source)

### 🌐 5. Network Requirements
- **Static IPs via DHCP reservation**:
  - Master: 10.0.0.10 (192.168.0.120 in implementation)
  - Workers: 10.0.0.11-13 (192.168.0.121-123 in implementation)
- **VLANs**: Management (10.0.0.x), Services (10.0.1.x), Pods (10.0.2.x)
- **MetalLB Range**: 10.0.0.200 - 10.0.0.250 (192.168.0.200-250 in implementation)
- **DNS**: CoreDNS + external Cloudflare
- **VPN**: WireGuard for remote access (optional)

### 🛡️ 6. Security & Firewall Requirements

#### 🔐 Auth/AuthZ:
- OAuth2 for dashboard apps (via KrakenD)
- RBAC for K3s
- Vault for secret injection

#### 🔥 Firewall:
- Block public access to ports 22, 80, 443 unless via VPN
- Allow 30000-32767 NodePort range only internally

#### 🛠️ Network Zones:
- DMZ: External API gateway
- Internal: K3s pods and services
- Restricted: Vault, PostgreSQL

#### 📂 Auditing:
- Fluentd + ELK
- Prometheus alert rules + Grafana dashboards

### 🗃️ 7. Storage & Backup
- **Types**: Object (MinIO), Block (Longhorn optional), File (NFS)
- **Retention**: 30-day log rotation; 7-day full backups
- **Backup**: Velero or rsync-to-NAS
- **Encryption**: TLS + Vault-integrated secrets + rest encryption (MinIO S3 SSE)

### 📡 8. Monitoring & Logging
- Prometheus + Node Exporter
- Grafana Dashboards per pod, cluster, NiFi metrics
- Fluentd shipping to Logstash
- Kibana dashboards for NiFi/Trino logs

### 🧪 9. Test & QA Environment
- Pi 5 node in dev mode for regression testing
- Trino queries and NiFi flows tested with mock data
- Use Trino CLI + Python scripts for validation

### 🚀 10. Deployment & Infra
- **IaC**: Terraform modules for networking, apps, storage
- **Flux CD**: GitOps config sync (every 1 min)
- **Helm Charts**: NiFi, Trino, Prometheus stack
- **CDN**: Optional Cloudflare proxy to KrakenD endpoint
- **Edge/Cloud Hybrid**: Local compute; remote Git and API usage

### 🧑‍💼 11. Roles & Access
- **Admin**: Full cluster + Vault
- **Dev**: Flux, Jupyter, Trino
- **Guest**: Read-only dashboard via Grafana
- **Remote Access**: SSH keys + optional WireGuard + MFA script

### 📋 12. Change Management
- GitOps PR-based workflow
- Semantic versioning: vMAJOR.MINOR.PATCH
- Monthly software patching window
- Rollbacks via Flux CD image tags + Terraform state reversion

---

## Architecture Overview

This project implements the PiClusterOps v1.0 requirements using a combination of Infrastructure as Code (IaC) tools. The architecture uses a single Pi 5 (192.168.0.120) as both the Puppet Server and K3s master node, with three additional Pi 5s (192.168.0.121-123) serving as K3s worker nodes.

### Implementation of Requirements

The architecture directly addresses the PRD requirements:
- **Compute**: 4x Raspberry Pi 5 with 8GB RAM each (32GB total cluster memory)
- **Storage**: Distributed across MinIO for object storage, PostgreSQL for structured data
- **Networking**: Static IPs with MetalLB for LoadBalancer services
- **Security**: Puppet manages firewall rules, TLS certificates, and access controls
- **Monitoring**: Complete observability stack with Prometheus, Grafana, and ELK

### Why This Architecture?

```
┌─────────────────────────────────────────────────────────────┐
│                     Developer Machine                        │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────┐   │
│  │  Terraform  │  │ Puppet Bolt  │  │  GitHub Actions │   │
│  └──────┬──────┘  └──────┬───────┘  └────────┬────────┘   │
│         │                │                    │             │
└─────────┼────────────────┼────────────────────┼─────────────┘
          │                │                    │
          ▼                ▼                    ▼
┌─────────────────────────────────────────────────────────────┐
│                    Pi Cluster Network                        │
│                                                              │
│  ┌────────────────────────────────────┐                     │
│  │ Pi Master (192.168.0.120)          │                     │
│  │ ┌─────────────┐  ┌──────────────┐  │                     │
│  │ │Puppet Server│  │ K3s Master   │  │                     │
│  │ │   + Vault   │  │   + NiFi     │  │                     │
│  │ └─────────────┘  └──────────────┘  │                     │
│  └───────────┬────────────────────────┘                     │
│              │                                               │
│              ├──────────────┬──────────────┬────────────    │
│              ▼              ▼              ▼                │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────┐   │
│  │Worker 1 (.121)  │ │Worker 2 (.122)  │ │Worker 3 (.123)│  │
│  │┌──────────────┐ │ │┌──────────────┐ │ │┌──────────────┐│ │
│  ││ Puppet Agent │ │ ││ Puppet Agent │ │ ││ Puppet Agent ││ │
│  ││ K3s Agent    │ │ ││ K3s Agent    │ │ ││ K3s Agent    ││ │
│  ││ Trino Worker │ │ ││ PostgreSQL   │ │ ││ MinIO        ││ │
│  │└──────────────┘ │ │└──────────────┘ │ │└──────────────┘│ │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

## Component Breakdown

### 1. **Terraform** - Infrastructure Orchestration
- **Purpose**: Implements IaC requirement from PRD section 10
- **Location**: Runs from your development machine
- **What it does**:
  - Generates dynamic inventory files for Puppet Bolt
  - Triggers Puppet deployments
  - Manages cloud resources (if any)
  - Maintains infrastructure state
  - Deploys Helm charts for NiFi, Trino, and monitoring stack

### 2. **Puppet** - Configuration Management
- **Puppet Server** (192.168.0.120):
  - Central configuration authority
  - Stores and compiles Puppet code
  - Manages node certificates
  - Serves configurations to agents
  - Implements security policies from PRD section 6
  
- **Puppet Agents** (All nodes):
  - Pull configurations from Puppet Server
  - Apply system configurations
  - Report back status
  - Manage firewall rules and network zones

### 3. **Puppet Bolt** - Orchestration
- **Purpose**: Agentless task execution and orchestration
- **Location**: Runs from your development machine
- **What it does**:
  - Initial bootstrap of nodes
  - Runs deployment plans
  - Executes ad-hoc commands
  - Orchestrates complex workflows
  - Implements change management workflows (PRD section 12)

### 4. **K3s** - Kubernetes Distribution
- **Master Node** (192.168.0.120):
  - API Server
  - Scheduler
  - Controller Manager
  - etcd (embedded)
  - Hosts NiFi for data orchestration
  
- **Worker Nodes** (192.168.0.121-123):
  - Kubelet
  - Container runtime
  - Kube-proxy
  - Distributed workloads:
    - Worker 1: Trino workers
    - Worker 2: PostgreSQL
    - Worker 3: MinIO storage

### 5. **Data Engineering Stack**
As per PRD section 2 functional requirements:
- **Apache NiFi**: Data flow orchestration
- **Trino**: Federated SQL queries
- **PostgreSQL**: Relational database
- **MinIO**: S3-compatible object storage
- **JupyterLab**: Python-based analysis

### 6. **Monitoring Stack** (PRD Section 8)
- **Prometheus**: Metrics collection
- **Grafana**: Visualization dashboards
- **Fluentd**: Log aggregation
- **ELK Stack**: Log analysis and search

### 7. **Security Components** (PRD Section 6)
- **Vault**: Secret management
- **cert-manager**: TLS certificate automation
- **OAuth2 Proxy**: Dashboard authentication
- **Network Policies**: Pod-to-pod communication control

## Workflow Explanation

### Phase 1: Initial Setup
```bash
# From your development machine
cd k3s_home_lab/

# 1. Configure your inventory
vim inventory.yaml  # Set your Pi IPs and SSH details

# 2. Run initial setup
./scripts/setup/setup-from-scratch.sh
```

This script implements the deployment requirements from PRD section 10:
1. Installs Puppet Bolt locally
2. Sets up SSH keys (PRD section 11 - Remote Access)
3. Tests connectivity to all Pis
4. Installs Puppet Server on 192.168.0.120
5. Installs Puppet agents on all nodes
6. Configures network zones (PRD section 6)

### Phase 2: Infrastructure Deployment
```bash
# Initialize Terraform
cd terraform/environments/prod
terraform init

# Deploy infrastructure
terraform apply
```

Terraform implements:
1. Network configuration (PRD section 5)
2. Storage setup (PRD section 7)
3. Security policies (PRD section 6)
4. Monitoring stack (PRD section 8)

### Phase 3: Data Platform Deployment
```bash
# Deploy data engineering tools
kubectl apply -k k8s/overlays/prod/data-platform/
```

This deploys:
- NiFi with persistent storage
- Trino with Hive metastore
- PostgreSQL with backups
- MinIO with encryption
- JupyterLab with Python libraries

### Phase 4: GitOps Setup (PRD Section 10)
```bash
# Install Flux CD
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=k3s_home_lab \
  --branch=main \
  --path=./k8s/flux \
  --personal
```

## Setup and Execution

### Prerequisites Setup (PRD Section 3 - Hardware)
```bash
# 1. Flash Raspberry Pi OS 64-bit (Bookworm) to SD cards
# 2. Enable SSH on each Pi
# 3. Set static IPs via DHCP reservation:
#    - 192.168.0.120 (Master)
#    - 192.168.0.121-123 (Workers)

# On each Pi, create user and add SSH key:
ssh pi@192.168.0.120
sudo adduser hezekiah
sudo usermod -aG sudo hezekiah
mkdir -p /home/hezekiah/.ssh
echo "YOUR_PUBLIC_KEY" >> /home/hezekiah/.ssh/authorized_keys

# Enable cgroups (required for K3s)
echo " cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1" | sudo tee -a /boot/cmdline.txt
sudo reboot
```

### Running the Complete Setup

#### Step 1: Clone and Configure
```bash
git clone https://github.com/your-username/k3s_home_lab.git
cd k3s_home_lab

# Edit inventory with your specific IPs
cp inventory.yaml.example inventory.yaml
vim inventory.yaml
```

#### Step 2: Run Initial Bootstrap
```bash
# This installs Puppet infrastructure
./scripts/setup/setup-from-scratch.sh

# Verify Puppet is working
bolt command run 'puppet --version' --targets all -i inventory.yaml
```

#### Step 3: Deploy with Terraform
```bash
cd terraform/environments/prod

# Create terraform.tfvars with secure passwords
cat > terraform.tfvars << EOF
cluster_name = "pi-k3s-cluster"
postgres_password = "$(openssl rand -base64 32)"
minio_secret_key = "$(openssl rand -base64 32)"
vault_token = "$(openssl rand -base64 32)"
metallb_ip_range = "192.168.0.200-192.168.0.250"
nifi_admin_password = "$(openssl rand -base64 16)"
trino_admin_password = "$(openssl rand -base64 16)"
EOF

terraform init
terraform plan
terraform apply
```

#### Step 4: Deploy Data Platform
```bash
# Deploy NiFi
helm upgrade --install nifi apache-nifi/nifi \
  --namespace data-platform \
  --values k8s/helm-values/nifi-values.yaml

# Deploy Trino
helm upgrade --install trino trino/trino \
  --namespace data-platform \
  --values k8s/helm-values/trino-values.yaml

# Deploy MinIO
helm upgrade --install minio bitnami/minio \
  --namespace data-platform \
  --values k8s/helm-values/minio-values.yaml
```

#### Step 5: Verify Deployment
```bash
# Check K3s cluster
export KUBECONFIG=~/.kube/config
kubectl get nodes

# Should show:
# NAME        STATUS   ROLES                  AGE   VERSION
# pi-master   Ready    control-plane,master   10m   v1.28.4+k3s1
# pi-worker-1 Ready    <none>                 8m    v1.28.4+k3s1
# pi-worker-2 Ready    <none>                 8m    v1.28.4+k3s1
# pi-worker-3 Ready    <none>                 8m    v1.28.4+k3s1

# Check data platform services
kubectl get pods -n data-platform
kubectl get svc -n data-platform
```

## Folder Structure Deep Dive

### `/puppet/` - Configuration Management
```
puppet/
├── bolt-project.yaml      # Bolt configuration
├── Puppetfile            # Module dependencies
├── hiera.yaml           # Data hierarchy configuration
├── data/                # Hierarchical data
│   ├── common.yaml      # Default values (implements PRD requirements)
│   ├── nodes/           # Per-node overrides
│   │   ├── pi-master.yaml    # Master-specific configs
│   │   └── pi-worker-*.yaml  # Worker-specific configs
│   └── environments/    # Per-environment data
├── site-modules/        # Custom modules
│   ├── profiles/        # Technology-specific configs
│   │   ├── base.pp          # Base OS config
│   │   ├── security.pp      # PRD section 6 implementation
│   │   ├── monitoring.pp    # PRD section 8 implementation
│   │   ├── k3s_server.pp    # K3s master setup
│   │   ├── k3s_agent.pp     # K3s worker setup
│   │   ├── nifi.pp          # NiFi configuration
│   │   ├── trino.pp         # Trino configuration
│   │   └── storage.pp       # Storage setup (PRD section 7)
│   └── roles/           # Node role definitions
│       ├── pi_master.pp     # Master node role
│       ├── pi_worker.pp     # Worker node role
│       └── data_platform.pp # Data engineering role
└── plans/               # Bolt orchestration plans
    ├── deploy.pp        # Main deployment plan
    ├── backup.pp        # Backup orchestration (PRD section 7)
    ├── update.pp        # Change management (PRD section 12)
    └── dr_restore.pp    # Disaster recovery
```

### `/terraform/` - Infrastructure as Code
```
terraform/
├── environments/        # Environment-specific configs
│   ├── dev/            # Development environment
│   ├── staging/        # Test environment (PRD section 9)
│   └── prod/           # Production environment
│       ├── main.tf      # Main configuration
│       ├── variables.tf # Input variables
│       ├── outputs.tf   # Output values
│       └── terraform.tfvars.example
└── modules/            # Reusable modules
    ├── puppet-infrastructure/  # Puppet setup
    ├── k3s-cluster/           # K3s deployment
    ├── data-platform/         # NiFi, Trino, etc.
    ├── monitoring/            # Prometheus/Grafana
    ├── security/              # Vault, OAuth2
    └── networking/            # VLANs, DNS, VPN
```

### `/k8s/` - Kubernetes Manifests
```
k8s/
├── base/               # Base manifests
│   ├── namespaces/     # Namespace definitions
│   ├── rbac/           # RBAC policies (PRD section 11)
│   └── network-policies/ # Security zones (PRD section 6)
├── overlays/           # Environment overrides
│   └── prod/
│       ├── data-platform/    # NiFi, Trino configs
│       ├── monitoring/       # Prometheus, Grafana
│       └── kustomization.yaml
├── applications/       # GitOps application definitions
│   ├── nifi-app.yaml
│   ├── trino-app.yaml
│   └── jupyterlab-app.yaml
└── helm-values/        # Helm chart configurations
    ├── nifi-values.yaml
    ├── trino-values.yaml
    └── minio-values.yaml
```

## Network Architecture (PRD Section 5)

### IP Allocation
```
# Management VLAN (10.0.0.x / 192.168.0.x)
192.168.0.120 - Pi Master (Puppet Server + K3s Master)
192.168.0.121 - Pi Worker 1 (Trino Workers)
192.168.0.122 - Pi Worker 2 (PostgreSQL + Data Storage)
192.168.0.123 - Pi Worker 3 (MinIO + Backup Storage)
192.168.0.200-250 - MetalLB IP Pool (LoadBalancer Services)

# Services VLAN (10.0.1.x) - Internal only
10.0.1.10 - NiFi Web UI
10.0.1.11 - Trino Coordinator
10.0.1.12 - Grafana Dashboard
10.0.1.13 - JupyterLab

# Pod Network (10.0.2.x) - K3s internal
10.0.2.0/24 - Pod CIDR
```

### DNS Configuration
```
# Add to your router or /etc/hosts:
192.168.0.120 puppet.cluster.local puppet
192.168.0.120 pi-master.cluster.local pi-master
192.168.0.121 pi-worker-1.cluster.local pi-worker-1
192.168.0.122 pi-worker-2.cluster.local pi-worker-2
192.168.0.123 pi-worker-3.cluster.local pi-worker-3

# Service DNS (handled by CoreDNS)
nifi.data-platform.svc.cluster.local
trino.data-platform.svc.cluster.local
minio.data-platform.svc.cluster.local
```

## Automation Flow

### Daily Operations (PRD Section 11 - Roles & Access)
```bash
# Admin Tasks
make cluster-status
make backup

# Developer Tasks
# Deploy NiFi flow
kubectl apply -f flows/my-nifi-flow.yaml

# Query data with Trino
kubectl exec -it trino-coordinator-0 -n data-platform -- trino
> SELECT * FROM hive.default.sensor_data WHERE date > CURRENT_DATE - INTERVAL '7' DAY;

# Access JupyterLab
kubectl port-forward -n data-platform svc/jupyterlab 8888:8888
# Browse to http://localhost:8888

# Guest Access (Read-only Grafana)
kubectl port-forward -n monitoring svc/grafana 3000:3000
# Browse to http://localhost:3000 (read-only user)
```

### Change Management (PRD Section 12)
```bash
# GitOps workflow
git checkout -b feature/update-nifi-flow
# Make changes
git add .
git commit -m "feat: update NiFi flow for weather data"
git push origin feature/update-nifi-flow
# Create PR, get approval, merge

# Flux CD automatically syncs (every 1 min)
flux get sources git
flux get kustomizations

# Manual sync if needed
flux reconcile source git flux-system
```

### Maintenance Tasks
```bash
# Monthly patching window
bolt plan run pi_cluster_automation::patch_nodes \
  --targets all -i inventory.yaml

# Backup before changes
make backup BACKUP_NAME=pre-patch-$(date +%Y%m%d)

# Rolling update
bolt plan run pi_cluster_automation::rolling_update \
  --targets all -i inventory.yaml
```

## Troubleshooting Guide

### Common Issues

#### 1. NiFi Connection Issues
```bash
# Check NiFi pods
kubectl logs -n data-platform deployment/nifi

# Verify certificates
kubectl get certificates -n data-platform

# Check persistent volumes
kubectl get pvc -n data-platform
```

#### 2. Trino Query Failures
```bash
# Check Trino coordinator
kubectl logs -n data-platform trino-coordinator-0

# Verify catalog configuration
kubectl exec -it trino-coordinator-0 -n data-platform -- cat /etc/trino/catalog/hive.properties

# Test connectivity to metastore
kubectl exec -it trino-coordinator-0 -n data-platform -- nc -zv postgres-service 5432
```

#### 3. Storage Issues
```bash
# Check MinIO
kubectl logs -n data-platform deployment/minio

# Verify storage capacity
df -h  # On each node

# Check Longhorn (if using)
kubectl get volumes -n longhorn-system
```

### Recovery Procedures

#### Data Recovery (PRD Section 7)
```bash
# Restore from Velero backup
velero restore create --from-backup daily-backup-20250610

# Restore PostgreSQL
kubectl exec -it postgres-0 -n data-platform -- pg_restore /backup/latest.dump

# Restore MinIO buckets
mc mirror --overwrite backup-nas/minio/ minio/
```

#### Complete Cluster Recovery
```bash
# From backup
./scripts/disaster-recovery/restore-cluster.sh latest prod

# Verify data integrity
./scripts/verify-data-integrity.sh
```

## Why This Architecture Works

1. **Meets All PRD Requirements**: 
   - Complete data engineering platform (NiFi, Trino, PostgreSQL, MinIO)
   - Full monitoring and observability
   - Security at all layers
   - GitOps-based deployment

2. **Scalability**: 
   - Easy to add more Pi nodes
   - Horizontal scaling for Trino and storage
   - Distributed workload management

3. **Resilience**: 
   - Multiple backup strategies (Velero, rsync)
   - Automated failover with K3s
   - Disaster recovery procedures

4. **Cost-Effective**: 
   - Low power consumption (~20W per Pi)
   - No licensing costs (all open source)
   - Learn enterprise patterns at home

5. **Educational Value**: 
   - Hands-on experience with modern DevOps
   - Real data engineering workflows
   - Production-like environment

<<<<<<< HEAD
This architecture provides a complete implementation of the PiClusterOps v1.0 requirements, delivering a professional-grade data engineering platform on Raspberry Pi hardware.
=======
## Benefits of Using Puppet

1. **True Cross-Platform Support**: Native support for Windows, macOS, and Linux
2. **Declarative Configuration**: Define desired state, Puppet handles implementation
3. **Puppet Forge**: Extensive module ecosystem for common tasks
4. **Bolt Orchestration**: Agentless task execution and plan orchestration
5. **Enterprise Features**: Optional Puppet Enterprise for GUI, RBAC, and compliance
6. **Hiera Data Management**: Separate configuration data from code
7. **Strong Testing Framework**: RSpec-puppet for comprehensive testing
8. **Mature Ecosystem**: Well-established tool with extensive documentation
9. **Reporting & Compliance**: Built-in reporting and compliance features
10. **Scale**: Efficiently manages thousands of nodes

This structure provides a production-ready, cross-platform Pi cluster infrastructure management solution using Puppet.
>>>>>>> a8dc482af4fde2ddf4a4c269f597aee8747859da
