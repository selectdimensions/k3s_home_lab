# K3s Home Lab - Technical Documentation

> **Comprehensive technical documentation for the K3s Raspberry Pi cluster automation project**

## 📖 Table of Contents

| Document | Description |
|----------|-------------|
| [Architecture Diagram](./ARCHITECTURE-DIAGRAM.md) | Mermaid diagrams showing system architecture and data flows |
| [Automation (Make.ps1)](./AUTOMATION.md) | Central automation script - 26+ commands for cluster management |
| [Puppet Layer](./PUPPET.md) | Configuration management with Bolt plans and tasks |
| [Terraform Layer](./TERRAFORM.md) | Infrastructure as Code - 7 modules for cluster provisioning |
| [Kubernetes Layer](./KUBERNETES.md) | Manifests, Kustomize overlays, and Helm values |
| [Scripts](./SCRIPTS.md) | Utility scripts for validation, fixes, and maintenance |

---

## 🏗️ Project Overview

### What is this project?

A fully automated **K3s Kubernetes cluster** running on **Raspberry Pi** hardware, designed for home lab use with a complete **data engineering stack**.

### Architecture Summary

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           K3s Home Lab Cluster                               │
├─────────────────────────────────────────────────────────────────────────────┤
│  Hardware Layer                                                              │
│  ├── pi-master (192.168.0.120) - Control plane, etcd, API server            │
│  ├── pi-worker-1 (192.168.0.121) - Workload node                            │
│  ├── pi-worker-2 (192.168.0.122) - Workload node                            │
│  └── pi-worker-3 (192.168.0.123) - Workload node                            │
├─────────────────────────────────────────────────────────────────────────────┤
│  Data Stack (data-engineering namespace)                                     │
│  ├── Apache NiFi - Data flow automation                                      │
│  ├── Trino - Distributed SQL query engine                                    │
│  ├── MinIO - S3-compatible object storage                                    │
│  └── PostgreSQL - Relational database                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│  Infrastructure (monitoring namespace)                                       │
│  ├── Prometheus - Metrics collection                                         │
│  └── Grafana - Visualization dashboards                                      │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Technology Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Orchestration** | K3s v1.32.5+k3s1 | Lightweight Kubernetes |
| **Automation** | PowerShell + Make.ps1 | Central command interface |
| **Config Management** | Puppet Bolt (Docker) | Node configuration & deployment |
| **Infrastructure** | Terraform | IaC for cluster provisioning |
| **Workloads** | Kubernetes + Helm | Application deployment |
| **Data Platform** | NiFi, Trino, MinIO, PostgreSQL | Data engineering stack |
| **Monitoring** | Prometheus + Grafana | Observability |

---

## 📁 Project Structure (Tree View)

```
k3s_home_lab/
│
├── Make.ps1                    # 🎯 Main entry point - 26+ automation commands
├── bolt.ps1                    # Docker wrapper for Puppet Bolt
├── Dockerfile                  # Puppet-bolt container image
├── Makefile                    # Linux/macOS alternative to Make.ps1
│
├── docs/                       # 📚 Documentation
│   ├── INDEX.md               # This file - documentation hub
│   ├── ARCHITECTURE-DIAGRAM.md # Mermaid architecture diagrams
│   ├── AUTOMATION.md          # Make.ps1 command reference
│   ├── PUPPET.md              # Puppet plans and tasks
│   ├── TERRAFORM.md           # Terraform modules
│   ├── KUBERNETES.md          # K8s manifests and Helm
│   ├── SCRIPTS.md             # Utility scripts
│   └── architecture/          # Architecture decision records
│
├── puppet/                     # 🎭 Configuration Management
│   ├── bolt-project.yaml      # Bolt project configuration
│   ├── Puppetfile             # Module dependencies
│   ├── hiera.yaml             # Hierarchical data lookup
│   ├── inventory.yaml         # Node inventory
│   ├── plans/                 # Bolt plans (orchestration)
│   │   ├── deploy.pp          # Standard deployment plan
│   │   ├── deploy_robust.pp   # Robust deploy with apt lock handling
│   │   ├── deploy_simple.pp   # Minimal deployment
│   │   ├── k3s_deploy.pp      # K3s-specific deployment
│   │   ├── restore.pp         # Cluster restoration
│   │   └── setup_monitoring_backup.pp
│   ├── tasks/                 # Bolt tasks (atomic operations)
│   │   ├── cluster_status.sh  # Get cluster status
│   │   ├── cluster_overview.sh
│   │   ├── install_k3s_master.sh
│   │   ├── install_k3s_worker.sh
│   │   ├── backup_cluster.sh
│   │   ├── restore_cluster.sh
│   │   ├── deploy_data_stack.sh
│   │   └── setup_monitoring.sh
│   └── data/                  # Hiera data
│       └── common.yaml
│
├── terraform/                  # 🏗️ Infrastructure as Code
│   ├── main.tf                # Root module entry point
│   ├── backend.tf             # State backend configuration
│   ├── variables.tf           # Variable definitions
│   ├── environments/          # Environment-specific configs
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   └── modules/               # Reusable modules
│       ├── k3s-cluster/       # K3s cluster configuration
│       ├── data-platform/     # NiFi, Trino, MinIO, PostgreSQL
│       ├── monitoring/        # Prometheus, Grafana
│       ├── backup/            # Backup configuration
│       ├── security/          # RBAC, network policies
│       ├── gitops/            # GitOps configuration
│       └── puppet-infrastructure/
│
├── k8s/                        # ☸️ Kubernetes Manifests
│   ├── base/                  # Base configurations
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   ├── monitoring/
│   │   ├── networkpolicies/
│   │   └── rbac/
│   ├── overlays/              # Environment overlays
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   ├── helm-values/           # Helm chart values
│   │   ├── nifi-values.yaml
│   │   ├── trino-values.yaml
│   │   ├── minio-values.yaml
│   │   └── postgresql-values.yaml
│   └── applications/          # Application-specific manifests
│
├── scripts/                    # 🔧 Utility Scripts
│   ├── validate-infrastructure.ps1  # Comprehensive validation
│   ├── deployment-readiness.ps1     # Pre-deploy checks
│   ├── fix-worker-nodes.ps1         # Worker node repair
│   ├── cluster-fix.ps1              # General cluster fixes
│   ├── bootstrap.sh                 # Initial setup
│   ├── setup-from-scratch.sh        # Full setup
│   ├── backup/                      # Backup scripts
│   └── disaster-recovery/           # DR scripts
│
├── monitoring/                 # 📊 Monitoring Configuration
│   ├── alerts/                # Alert rules
│   └── dashboards/            # Grafana dashboards
│
├── tests/                      # 🧪 Test Suites
│   ├── integration/
│   ├── puppet/
│   └── terraform/
│
└── backups/                    # 💾 Cluster Backups
    └── pre-upgrade-*/
```

---

## 🚀 Quick Start

### Prerequisites

- Windows 10/11 with PowerShell 5.1+
- Docker Desktop (for Puppet Bolt)
- SSH access to Raspberry Pi nodes
- SSH keys configured in `~/.ssh/`

### 1. Initialize Project

```powershell
.\Make.ps1 init
```

### 2. Validate Configuration

```powershell
.\Make.ps1 validate
```

### 3. Deploy Cluster

```powershell
# Full deployment (Terraform + Puppet)
.\Make.ps1 quick-deploy -Environment dev

# Or step by step:
.\Make.ps1 terraform-init -Environment dev
.\Make.ps1 terraform-plan -Environment dev
.\Make.ps1 terraform-apply -Environment dev
.\Make.ps1 puppet-deploy
```

### 4. Check Status

```powershell
.\Make.ps1 cluster-status
```

### 5. Access UIs

```powershell
# NiFi UI (http://localhost:8080/nifi)
.\Make.ps1 nifi-ui

# Grafana (http://localhost:3000)
.\Make.ps1 grafana-ui
```

---

## 📋 Command Reference (Quick)

| Command | Description |
|---------|-------------|
| `.\Make.ps1 help` | Show all available commands |
| `.\Make.ps1 init` | Initialize project (Docker, SSH check) |
| `.\Make.ps1 validate` | Run comprehensive validation |
| `.\Make.ps1 cluster-status` | Show cluster node status |
| `.\Make.ps1 quick-deploy` | Full deployment (Terraform + Puppet) |
| `.\Make.ps1 puppet-deploy` | Deploy via Puppet Bolt |
| `.\Make.ps1 terraform-plan` | Show Terraform changes |
| `.\Make.ps1 backup` | Create cluster backup |
| `.\Make.ps1 nifi-ui` | Port-forward to NiFi UI |

📖 See [AUTOMATION.md](./AUTOMATION.md) for the complete command reference.

---

## 🔗 Cross-References

### By Use Case

| I want to... | See... |
|--------------|--------|
| Understand the architecture | [ARCHITECTURE-DIAGRAM.md](./ARCHITECTURE-DIAGRAM.md) |
| Run Make.ps1 commands | [AUTOMATION.md](./AUTOMATION.md) |
| Deploy nodes with Puppet | [PUPPET.md](./PUPPET.md) |
| Provision infrastructure | [TERRAFORM.md](./TERRAFORM.md) |
| Deploy Kubernetes workloads | [KUBERNETES.md](./KUBERNETES.md) |
| Troubleshoot issues | [SCRIPTS.md](./SCRIPTS.md) |
| Access NiFi/Grafana | [AUTOMATION.md](./AUTOMATION.md#ui-access) |
| Create backups | [AUTOMATION.md](./AUTOMATION.md#backup-operations) |

### By Component

| Component | Documentation |
|-----------|---------------|
| Make.ps1 | [AUTOMATION.md](./AUTOMATION.md) |
| bolt.ps1 | [PUPPET.md](./PUPPET.md#bolt-wrapper) |
| Puppet Plans | [PUPPET.md](./PUPPET.md#plans) |
| Puppet Tasks | [PUPPET.md](./PUPPET.md#tasks) |
| Terraform Modules | [TERRAFORM.md](./TERRAFORM.md) |
| K8s Manifests | [KUBERNETES.md](./KUBERNETES.md) |
| Validation Scripts | [SCRIPTS.md](./SCRIPTS.md) |

---

## 📊 Current Cluster Status

| Node | IP Address | Role | Version |
|------|------------|------|---------|
| pi-master | 192.168.0.120 | control-plane, master | v1.32.5+k3s1 |
| pi-worker-1 | 192.168.0.121 | worker | v1.32.5+k3s1 |
| pi-worker-2 | 192.168.0.122 | worker | v1.32.5+k3s1 |
| pi-worker-3 | 192.168.0.123 | worker | v1.32.5+k3s1 |

### Data Platform Status

| Service | Namespace | Port | Access |
|---------|-----------|------|--------|
| NiFi | data-engineering | 8080 | `.\Make.ps1 nifi-ui` |
| Trino | data-engineering | 8080 | Port-forward required |
| MinIO | data-engineering | 9000/9001 | Port-forward required |
| PostgreSQL | data-engineering | 5432 | Internal only |
| Grafana | monitoring | 3000 | `.\Make.ps1 grafana-ui` |

---

## 📝 Documentation Conventions

- **Code blocks**: Commands are shown for PowerShell on Windows
- **Paths**: Use Windows-style paths (`\`) unless noted
- **Icons**:
  - 🎯 Entry point
  - 📁 Directory
  - 📄 File
  - ⚙️ Configuration
  - 🔧 Script
  - 🎭 Puppet
  - 🏗️ Terraform

---

*Last updated: Generated from project analysis*
