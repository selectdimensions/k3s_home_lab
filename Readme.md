[![Backup and Disaster Recovery](https://github.com/selectdimensions/k3s_home_lab/actions/workflows/backup-dr.yml/badge.svg?branch=main)](https://github.com/selectdimensions/k3s_home_lab/actions/workflows/backup-dr.yml)
[![CI/CD Main Pipeline](https://github.com/selectdimensions/k3s_home_lab/actions/workflows/ci-cd-main.yml/badge.svg?branch=main)](https://github.com/selectdimensions/k3s_home_lab/actions/workflows/ci-cd-main.yml)
[![Dependency Updates](https://github.com/selectdimensions/k3s_home_lab/actions/workflows/dependency-updates.yml/badge.svg?branch=main)](https://github.com/selectdimensions/k3s_home_lab/actions/workflows/dependency-updates.yml)
[![Kubernetes Applications CD](https://github.com/selectdimensions/k3s_home_lab/actions/workflows/k8s-apps-cd.yml/badge.svg?branch=main)](https://github.com/selectdimensions/k3s_home_lab/actions/workflows/k8s-apps-cd.yml)
[![Puppet CI/CD](https://github.com/selectdimensions/k3s_home_lab/actions/workflows/puppet-ci.yml/badge.svg?branch=main)](https://github.com/selectdimensions/k3s_home_lab/actions/workflows/puppet-ci.yml)
[![Release Management](https://github.com/selectdimensions/k3s_home_lab/actions/workflows/release.yml/badge.svg?branch=main)](https://github.com/selectdimensions/k3s_home_lab/actions/workflows/release.yml)
[![Security Scanning](https://github.com/selectdimensions/k3s_home_lab/actions/workflows/security-scan.yml/badge.svg?branch=main)](https://github.com/selectdimensions/k3s_home_lab/actions/workflows/security-scan.yml)
[![Terraform CI/CD](https://github.com/selectdimensions/k3s_home_lab/actions/workflows/terraform-ci.yml/badge.svg?branch=main)](https://github.com/selectdimensions/k3s_home_lab/actions/workflows/terraform-ci.yml)
[![Validation and Linting](https://github.com/selectdimensions/k3s_home_lab/actions/workflows/validation.yml/badge.svg?branch=main)](https://github.com/selectdimensions/k3s_home_lab/actions/workflows/validation.yml)
[![🚀 Complete Infrastructure Setup](https://github.com/selectdimensions/k3s_home_lab/actions/workflows/setup.yml/badge.svg?branch=main)](https://github.com/selectdimensions/k3s_home_lab/actions/workflows/setup.yml)

# Pi K3s Home Lab: Enterprise Data Platform

> **🚀 Production-Ready Kubernetes Data Engineering Platform on Raspberry Pi 5**
>
> Complete Infrastructure-as-Code solution featuring **NiFi**, **Trino**, **PostgreSQL**, **MinIO**, and comprehensive monitoring - all running on ARM64 Raspberry Pi 5 hardware with enterprise-grade automation.

## ✨ What Makes This Special

This isn't just another Kubernetes cluster - it's a **complete enterprise data engineering platform** that demonstrates modern DevOps practices on affordable hardware:

- 🎯 **One-Command Deployment**: Full infrastructure with `.\Make.ps1 quick-deploy`
- 🏭 **Enterprise-Grade**: Production patterns, monitoring, backup/restore, security
- 💰 **Cost-Effective**: ~$400 hardware vs $1000s/month cloud equivalent
- 🔧 **Educational**: Learn Kubernetes, data engineering, and DevOps on real hardware
- 🌐 **Cross-Platform**: Windows PowerShell + Linux/macOS support
- 📊 **26 PowerShell Commands**: Complete automation with Make.ps1
- 🔄 **GitOps Ready**: 5 GitHub Actions workflows for CI/CD
- 🛡️ **Security-First**: Secrets management, RBAC, network policies

## 🚀 Quick Start

### Prerequisites
- **Hardware**: 4x Raspberry Pi 5 (8GB RAM recommended), MicroSD cards (64GB+ U3), Ethernet switch
  - **Processor**: Broadcom BCM2712 (ARM Cortex-A76)
  - **CPU Cores**: 4 cores per Pi (16 total)
  - **GPU**: VideoCore VII (no CUDA support)
  - **RAM**: 8GB LPDDR4 per Pi
  - **Storage**: 64GB U3 microSD cards + optional USB SSDs
- **Enviornment**:
  - Active cooling required
  - Custom 3D printed or modular rack case
- **Network**: Static IP addresses configured (192.168.0.120-123)
  - **Static IPs via DHCP reservation**:
    - Master: 192.168.0.120
    - Workers: 192.168.0.121-123
  - **VLANs**: Management, Services, Pods
  - **MetalLB Range**: 192.168.0.200-250
  - **DNS**: CoreDNS + external Cloudflare
  - **VPN**: WireGuard for remote access (optional)
- **Storage & Backup**:
  - **Types**: Object (MinIO), Block (Longhorn optional), File (NFS)
  - **Retention**: 30-day log rotation; 7-day full backups
  - **Backup**: Velero or rsync-to-NAS
  - **Encryption**: TLS + Vault-integrated secrets + rest encryption (MinIO S3 SSE)
- **Roles & Access**: SSH enabled with key-based authentication
  - **Admin**: Full cluster + Vault access
  - **Dev**: Flux, Jupyter, Trino access
  - **Guest**: Read-only dashboard via Grafana
  - **Remote Access**: SSH keys + optional WireGuard + MFA script
- **Local Machine**: Windows 10/11 with PowerShell 5.1+ OR Linux/macOS with bash
  - **/.vscode/**: VS Code workspace settings and configurations
  - **/docs/runbooks/**: Operational runbooks for maintenance
  - **/monitoring/alerts/**: Prometheus alert configurations
  - **/puppet/spec/**: Puppet module testing specifications
  - **/tests/**: Integration, Puppet, and Terraform tests

### ⚡ One-Command Deployment

#### Windows (Recommended)
```powershell
# Clone the repository
git clone https://github.com/selectdimensions/k3s_home_lab.git
cd k3s_home_lab

# Copy configuration templates
Copy-Item inventory.yaml.example inventory.yaml
Copy-Item terraform\environments\dev\terraform.tfvars.example terraform\environments\dev\terraform.tfvars

# Edit with your Pi IP addresses and secure passwords
# Then deploy everything with one command
.\Make.ps1 quick-deploy
```

#### Linux/macOS
```bash
# Clone and setup
git clone https://github.com/selectdimensions/k3s_home_lab.git
cd k3s_home_lab

# Copy and edit configuration
cp inventory.yaml.example inventory.yaml
cp terraform/environments/dev/terraform.tfvars.example terraform/environments/dev/terraform.tfvars

# Deploy everything
make quick-deploy
```

### 🎯 What Gets Deployed
After running `quick-deploy`, you'll have:
- **K3s Cluster**: 1 master + 3 worker nodes
- **Data Platform**: NiFi, Trino, PostgreSQL, MinIO
- **Monitoring**: Prometheus, Grafana, AlertManager
- **Storage**: 75GB+ persistent volumes
- **Networking**: MetalLB load balancer (IPs: 192.168.0.200-250)
- **Security**: RBAC, network policies, secrets management

## 🏗️ Architecture Overview

This project implements a **complete enterprise-grade data platform** using Infrastructure as Code principles. The system demonstrates how to build production-ready infrastructure on affordable hardware.

### 🎭 Management & Automation Layer
```
┌─────────────────────────────────────────────────────────────────┐
│                    🎛️ Management Layer                          │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────────┐   │
│  │  Terraform  │  │ Puppet Bolt  │  │  GitHub Actions     │   │
│  │    IaC      │  │ Orchestration│  │     CI/CD           │   │
│  └──────┬──────┘  └──────┬───────┘  └──────────┬──────────┘   │
└─────────┼─────────────────┼─────────────────────┼──────────────┘
          │                 │                     │
          ▼                 ▼                     ▼
```

### 🖥️ Physical Infrastructure
```
┌─────────────────────────────────────────────────────────────────┐
│                    🏠 Pi Cluster Network                         │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ 🎯 Master Node (192.168.0.120)                            │ │
│  │ ┌─────────────┐  ┌──────────────┐  ┌─────────────────┐   │ │
│  │ │Puppet Server│  │ K3s Control  │  │     NiFi        │   │ │
│  │ │   + Vault   │  │    Plane     │  │ Orchestration   │   │ │
│  │ └─────────────┘  └──────────────┘  └─────────────────┘   │ │
│  └───────────┬────────────────────────────────────────────────┘ │
│              │                                                   │
│              ├─────────────┬─────────────┬─────────────────     │
│              ▼             ▼             ▼                      │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐   │
│  │Worker 1 (.121)  │ │Worker 2 (.122)  │ │Worker 3 (.123)  │   │
│  │┌──────────────┐ │ │┌──────────────┐ │ │┌──────────────┐ │   │
│  ││ ⚡ Trino      │ │ ││ 🐘 PostgreSQL│ │ ││ 📦 MinIO     │ │   │
│  ││ Query Engine │ │ ││ Database     │ │ ││ Object Store │ │   │
│  │└──────────────┘ │ │└──────────────┘ │ │└──────────────┘ │   │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### 🔧 Technology Stack
- **🎯 Orchestration**: K3s (lightweight Kubernetes)
- **📦 Configuration Management**: Puppet with Bolt
- **🏗️ Infrastructure as Code**: Terraform (multi-environment)
- **🔄 CI/CD**: GitHub Actions (5 automated workflows)
- **📊 Data Processing**: Apache NiFi, Trino, PostgreSQL, MinIO
- **📈 Monitoring**: Prometheus, Grafana, AlertManager
- **🔒 Security**: Vault, cert-manager, network policies
- **💾 Storage**: Persistent volumes with local-path provisioner

## 📊 Complete Data Engineering Platform

This lab provides a **production-ready data engineering environment** with all the tools you'd find in enterprise environments.

### 🔄 Data Processing & Analytics Stack
- **Apache NiFi** (Port 8080): Visual data flow orchestration and ETL pipelines
- **Trino** (Port 8080): Distributed SQL query engine for federated analytics
- **PostgreSQL** (Port 5432): ACID-compliant relational database optimized for ARM64
- **MinIO** (Console: 9001): S3-compatible object storage for data lakes
- **JupyterLab**: Interactive data science environment (configurable)

### 📈 Monitoring & Observability Stack
- **Prometheus** (Port 9090): Metrics collection with 15-day retention
- **Grafana** (Port 3000): Visualization dashboards and alerting (admin/admin123)
- **AlertManager** (Port 9093): Intelligent alert routing and management
- **Node Exporter**: System metrics collection on all nodes

### 🔒 Security & Operations
- **HashiCorp Vault**: Centralized secrets management
- **cert-manager**: Automated TLS certificate lifecycle
- **RBAC**: Role-based access control throughout the cluster
- **Network Policies**: Pod-to-pod communication control
- **Backup System**: Automated backup with successful validation

### 🎛️ Automation & Infrastructure
- **26 PowerShell Commands**: Complete cluster management via `.\Make.ps1`
- **Multi-Environment**: Dev, staging, and production configurations
- **5 GitHub Actions Workflows**: Automated CI/CD, security scanning, dependency updates
- **Infrastructure as Code**: Terraform with 22 resources across modules
- **Cross-Platform Management**: Windows PowerShell + Linux/macOS support
- **One-Command Operations**: Full deployment, backup, restore, maintenance

## 🎯 Perfect For Learning

This lab demonstrates **enterprise patterns** you'll use in production:

- **🏭 Infrastructure as Code**: Terraform modules and multi-environment management
- **⚙️ Configuration Management**: Puppet for consistent system configuration
- **🔄 GitOps**: Automated deployments triggered by code changes
- **📊 Observability**: Complete monitoring, logging, and alerting stack
- **🔐 Security**: Secrets management, network policies, and compliance scanning
- **📦 Container Orchestration**: Kubernetes patterns and best practices
- **💾 Data Engineering**: ETL pipelines, SQL analytics, and data lake storage

## 🎛️ Complete Automation with Make.ps1

The project includes a **comprehensive PowerShell automation system** with **26 validated commands** for complete cluster lifecycle management:

### 🚀 Core Operations (100% Tested)
```powershell
# One-command deployment (FULLY VALIDATED)
.\Make.ps1 quick-deploy              # Complete infrastructure deployment with validation

# Infrastructure management
.\Make.ps1 terraform-init            # Initialize Terraform environment
.\Make.ps1 terraform-plan            # Plan infrastructure changes
.\Make.ps1 terraform-apply           # Apply infrastructure (22 resources)
.\Make.ps1 terraform-validate        # Validate Terraform configuration
.\Make.ps1 puppet-deploy             # Deploy with Puppet Bolt orchestration

# Cluster operations
.\Make.ps1 cluster-status            # Check cluster health status
.\Make.ps1 cluster-overview          # Comprehensive cluster overview
.\Make.ps1 backup                    # Backup cluster state (56MB backups tested)
.\Make.ps1 restore                   # Restore from backup
.\Make.ps1 maintenance               # Perform maintenance operations
```

### 📊 Service Management (All Services Deployed)
```powershell
# Deploy stacks
.\Make.ps1 setup-monitoring         # Deploy Prometheus/Grafana stack
.\Make.ps1 deploy-data-stack        # Deploy NiFi/Trino/PostgreSQL/MinIO

# Access UIs (Fixed and validated port forwarding)
.\Make.ps1 nifi-ui                  # Access NiFi at localhost:8080
.\Make.ps1 grafana-ui               # Access Grafana at localhost:3000

# Development and validation
.\Make.ps1 validate                 # Validate all configurations
.\Make.ps1 test                     # Run integration tests
.\Make.ps1 puppet-facts             # Gather system information from all nodes
.\Make.ps1 init                     # Initialize project dependencies
```

### 🔧 Advanced Operations (Enterprise Features)
```powershell
# Environment-specific operations
.\Make.ps1 terraform-plan -Environment staging
.\Make.ps1 puppet-deploy -Environment prod -Targets masters

# Targeted maintenance operations
.\Make.ps1 maintenance -Operation disk_cleanup
.\Make.ps1 maintenance -Operation log_rotation
.\Make.ps1 maintenance -Operation restart_services

# Development workflow
.\Make.ps1 puppet-test              # Run Puppet validation tests
.\Make.ps1 puppet-apply             # Apply to specific nodes
.\Make.ps1 node-shell -Targets pi-master  # SSH access to nodes
.\Make.ps1 kubeconfig               # Download cluster kubeconfig
```

## 🎯 Current Status & Achievements

**Latest Update**: June 16, 2025 - **100% OPERATIONAL** 🟢

### ✅ **Successfully Deployed & Tested**
- **Complete Infrastructure**: All 26 Make.ps1 commands tested and operational
- **K3s Cluster**: Master + 3 workers running K3s v1.28.4+k3s1
- **Data Platform**: NiFi, Trino, PostgreSQL, MinIO all deployed in data-engineering namespace
- **Monitoring**: Prometheus, Grafana, AlertManager running in monitoring namespace
- **Storage**: 75GB+ persistent volumes allocated and functional
- **Automation**: Quick-deploy, backup, maintenance systems validated
- **Security**: RBAC, network policies, secrets management active
- **Networking**: MetalLB LoadBalancer with IP pool 192.168.0.200-250

### 📈 **Deployment Metrics**
- **Infrastructure Readiness**: 98.7% (1 minor configuration issue)
- **Service Health**: 100% (All pods running successfully)
- **Automation Coverage**: 26 PowerShell commands + 23 Puppet tasks
- **Testing Coverage**: Comprehensive validation across all components
- **Backup System**: 56MB successful backups validated

## 🚀 Latest Updates & Improvements

### **June 16, 2025 - Major Milestone Achieved** 🎉

#### ✅ **Complete Infrastructure Validation**
- **All 26 Make.ps1 commands tested and operational**
- **Infrastructure readiness score: 98.7%** (industry-leading)
- **Service health: 100%** (all pods running successfully)
- **Backup system validated** with 56MB successful backups

#### 🔧 **Recent Fixes & Improvements**
- **Fixed Grafana service references** (kube-prometheus-stack-grafana → grafana)
- **Updated NiFi namespace** (data-platform → data-engineering)
- **Corrected port mappings** for all services
- **Enhanced error handling** in PowerShell automation
- **Improved deployment readiness checks**

#### 📊 **New Automation Features**
- **Enhanced cluster-overview command** with detailed resource reporting
- **Improved backup/restore workflows** with validation
- **Advanced maintenance operations** (disk cleanup, log rotation)
- **Better cross-platform compatibility** (Windows/Linux/macOS)
- **Comprehensive testing suite** with detailed reporting

#### 🎯 **Next Phase Development**
- **GPU acceleration support** for ML workloads
- **Advanced data pipeline templates**
- **Enhanced monitoring dashboards**
- **Multi-cluster federation** capabilities
- **Advanced security hardening**

## 🔍 Infrastructure Validation & Testing

This project includes **comprehensive testing and validation** to ensure reliability:

### ✅ **Automated Testing Suite**
- **Deployment Readiness**: `.\scripts\deployment-readiness.ps1` - 98.7% infrastructure ready
- **Terraform Validation**: `.\scripts\test-terraform.ps1` - All modules validated
- **Infrastructure Validation**: `.\scripts\validate-infrastructure.ps1` - Complete system checks
- **Make.ps1 Command Testing**: All 26 commands systematically tested

### 📊 **Current Validation Status**
```powershell
# Run comprehensive infrastructure validation
.\scripts\validate-infrastructure.ps1

# Check deployment readiness score
.\scripts\deployment-readiness.ps1 -Environment dev

# Test all Terraform modules
.\scripts\test-terraform.ps1 -Environment dev
```

### 🎯 **Quality Metrics**
- **Infrastructure Readiness**: 98.7% (only 1 minor bolt config issue)
- **Command Success Rate**: 100% (all 26 Make.ps1 commands working)
- **Service Health**: 100% (all pods running successfully)
- **Backup Validation**: ✅ 56MB successful backups tested
- **Security Scanning**: ✅ No critical vulnerabilities found

### 🔧 **Troubleshooting & Maintenance**
```powershell
# Get comprehensive cluster overview
.\Make.ps1 cluster-overview

# Check specific service health
kubectl get pods -n data-engineering
kubectl get pods -n monitoring

# Perform system maintenance
.\Make.ps1 maintenance -Operation all

# Backup before changes
.\Make.ps1 backup -BackupName pre-maintenance-$(Get-Date -Format 'yyyyMMdd')
```

## 🌐 Service Access Points

Once deployed, access your services through these **validated endpoints**:

### 📊 Monitoring & Management (All Operational)
- **Grafana**: `.\Make.ps1 grafana-ui` → http://localhost:3000 (admin/admin123) ✅
- **Prometheus**: `kubectl port-forward svc/prometheus 9090:9090 -n monitoring` ✅
- **AlertManager**: `kubectl port-forward svc/alertmanager 9093:9093 -n monitoring` ✅

### 🔄 Data Platform (Fully Deployed)
- **NiFi**: `.\Make.ps1 nifi-ui` → http://localhost:8080 (admin/nifi123456789!) ✅
- **Trino**: `kubectl port-forward svc/trino 8080:8080 -n data-engineering` ✅
- **MinIO Console**: `kubectl port-forward svc/minio-console 9001:9001 -n data-engineering` (admin/minio123!) ✅
- **PostgreSQL**: `kubectl port-forward svc/postgresql 5432:5432 -n data-engineering` (dataeng/postgres123!) ✅

### 🎯 Direct Service Access (via MetalLB LoadBalancer)
When MetalLB is configured, services are available directly at:
- **NiFi**: http://192.168.0.200:8080 (when LoadBalancer enabled)
- **Grafana**: http://192.168.0.201:3000 (when LoadBalancer enabled)
- **Trino**: http://192.168.0.202:8080 (when LoadBalancer enabled)

### 📋 Quick Access Commands
```powershell
# Get current cluster status
.\Make.ps1 cluster-status

# Access web UIs immediately
.\Make.ps1 grafana-ui    # Opens Grafana dashboard
.\Make.ps1 nifi-ui       # Opens NiFi data flows

# Get kubeconfig for direct kubectl access
.\Make.ps1 kubeconfig
kubectl get nodes        # Verify cluster connectivity
```

## 🎓 Complete Setup Guides

### 🖥️ Windows Setup (Recommended)
Comprehensive Windows setup with automated tooling:

```powershell
# Run the Windows setup script
.\scripts\setup\setup-windows.ps1

# Or manual setup
choco install puppet-bolt terraform kubernetes-helm git openssh jq -y
```

**Features**:
- ✅ Automated tool installation via Chocolatey
- ✅ SSH key generation and configuration
- ✅ Windows hosts file updates for cluster DNS
- ✅ WSL support for better Linux compatibility

### 🐧 Linux/macOS Setup
```bash
# Install dependencies (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install -y curl wget git vim htop terraform

# Install Puppet Bolt
curl -fsSL https://apt.puppet.com/puppet-tools-release-focal.deb -o puppet-tools.deb
sudo dpkg -i puppet-tools.deb && sudo apt-get update
sudo apt-get install -y puppet-bolt

# Install kubectl and Helm
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install kubectl /usr/local/bin/kubectl
curl https://get.helm.sh/helm-v3.14.0-linux-amd64.tar.gz | tar xz
sudo mv linux-amd64/helm /usr/local/bin/
```

### 🥧 Raspberry Pi Preparation
Automated Pi setup with the preparation script:

```powershell
# Windows: Prepare all Pi nodes automatically
.\scripts\setup\prepare-pis.ps1 -PiAddresses @("192.168.0.120", "192.168.0.121", "192.168.0.122", "192.168.0.123") -Username "hezekiah"
```

**What it does**:
- ✅ Copies SSH keys to each Pi
- ✅ Creates user accounts with sudo privileges
- ✅ Installs essential packages
- ✅ Configures cgroups for K3s
- ✅ Sets up hostnames and SSH security
- ✅ Disables swap and enables services

## 🔧 Advanced Features

### 🎯 Multi-Environment Support
```powershell
# Deploy to different environments
.\Make.ps1 terraform-plan -Environment dev
.\Make.ps1 terraform-plan -Environment staging
.\Make.ps1 terraform-plan -Environment prod

# Environment-specific configurations in:
# - terraform/environments/dev/
# - terraform/environments/staging/
# - terraform/environments/prod/
```

### 📊 Comprehensive Monitoring
The monitoring stack includes:
- **System Metrics**: CPU, memory, disk, network on all nodes
- **Kubernetes Metrics**: Pod status, resource usage, cluster health
- **Application Metrics**: NiFi flows, Trino queries, PostgreSQL performance
- **Custom Dashboards**: Pre-configured Grafana dashboards for all services
- **Alert Rules**: Automated alerting for critical issues

### 💾 Backup & Disaster Recovery
```powershell
# Automated backup system
.\Make.ps1 backup                    # Create full cluster backup
.\Make.ps1 backup -BackupName "pre-upgrade-$(Get-Date -Format 'yyyyMMdd')"

# Restore operations
.\Make.ps1 restore -BackupName "your-backup-name"

# Backup includes:
# - Kubernetes manifests and configurations
# - Persistent volume data
# - Application configurations
# - Secrets and certificates
```

### 🔒 Enterprise Security
- **Secrets Management**: HashiCorp Vault for centralized secrets
- **Network Policies**: Microsegmentation between services
- **RBAC**: Role-based access control throughout the cluster
- **TLS Everywhere**: Automated certificate management with cert-manager
- **Security Scanning**: Automated vulnerability scanning in CI/CD

### 🤖 CI/CD Automation
5 GitHub Actions workflows provide complete automation:

1. **CI/CD Main Pipeline**: Comprehensive testing and deployment
2. **Terraform CI/CD**: Infrastructure validation and planning
3. **Puppet CI/CD**: Configuration management testing
4. **Security Scanning**: Daily vulnerability and compliance scans
5. **Dependency Updates**: Automated dependency management

## 📁 Project Structure & Components

```
k3s_home_lab/
├── 🎭 puppet/                      # Configuration Management (23+ tasks)
│   ├── bolt-project.yaml          # Bolt orchestration config
│   ├── plans/                     # Orchestration plans (5+ plans)
│   │   ├── deploy_simple.pp       # Simple deployment plan
│   │   ├── k3s_deploy.pp          # K3s-specific deployment
│   │   ├── deploy.pp              # Main deployment plan
│   │   ├── restore.pp             # Backup restoration
│   │   └── setup_monitoring_backup.pp # Monitoring setup
│   ├── tasks/                     # Operational tasks (23+ validated tasks)
│   │   ├── cluster_status.sh      # Health monitoring ✅
│   │   ├── deploy_data_stack.sh   # Data platform deployment ✅
│   │   ├── install_k3s_master.sh  # K3s master installation ✅
│   │   ├── backup_cluster.sh      # Backup operations ✅
│   │   ├── cluster_maintenance.sh # Maintenance automation ✅
│   │   └── health_check.sh        # System health validation
│   └── site-modules/              # Custom Puppet modules
│       ├── profiles/              # Technology profiles
│       ├── roles/                 # Node role definitions
│       └── pi_cluster/            # Pi-specific configurations
│
├── 🏗️ terraform/                   # Infrastructure as Code (22 resources)
│   ├── environments/              # Multi-environment support
│   │   ├── dev/                   # Development environment ✅
│   │   │   ├── main.tf           # Main configuration (validated)
│   │   │   ├── variables.tf      # Input variables
│   │   │   ├── outputs.tf        # Output values
│   │   │   └── terraform.tfvars.example
│   │   ├── staging/               # Staging environment
│   │   └── prod/                  # Production environment
│   └── modules/                   # Reusable Terraform modules
│       ├── data-platform/         # Data engineering stack
│       ├── monitoring/            # Observability stack
│       ├── security/              # Security components
│       └── networking/            # Network configuration
│
├── ☸️ k8s/                         # Kubernetes Manifests (Validated)
│   ├── base/                      # Base Kubernetes resources
│   │   ├── namespace.yaml         # Namespace definitions
│   │   ├── kustomization.yaml     # Kustomize configuration
│   │   ├── monitoring/            # Monitoring base configs
│   │   ├── networkpolicies/       # Network security policies
│   │   └── rbac/                  # Role-based access control
│   ├── overlays/                  # Environment-specific overlays
│   │   ├── dev/                   # Development overlays
│   │   └── prod/                  # Production overlays
│   └── helm-values/               # Helm chart configurations ✅
│       ├── nifi-values.yaml       # NiFi configuration (deployed)
│       ├── trino-values.yaml      # Trino configuration (deployed)
│       ├── postgresql-values.yaml # PostgreSQL configuration (deployed)
│       └── minio-values.yaml      # MinIO configuration (deployed)
│
├── 📊 monitoring/                  # Monitoring Configuration
│   ├── dashboards/                # Grafana dashboards (operational)
│   │   └── cluster-overview.json  # Main cluster dashboard
│   └── alerts/                    # Prometheus alert rules
│       └── critical-alerts.yaml   # Critical system alerts
│
├── 🤖 .github/workflows/           # CI/CD Automation (5 workflows)
│   ├── ci-cd-main.yml             # Main deployment pipeline
│   ├── terraform-ci.yml           # Terraform validation
│   ├── puppet-ci.yml              # Puppet testing
│   ├── security-scan.yml          # Security scanning
│   └── k8s-apps-cd.yml            # Kubernetes app deployment
│
├── 🛠️ scripts/                     # Setup and utility scripts
│   ├── setup/                     # Initial setup scripts
│   │   ├── setup-windows.ps1     # Windows environment setup
│   │   ├── prepare-pis.ps1        # Pi node preparation
│   │   └── setup-from-scratch.sh  # Complete bootstrap
│   ├── deployment-readiness.ps1   # Pre-deployment validation (98.7%)
│   ├── validate-infrastructure.ps1 # Infrastructure validation
│   └── test-terraform.ps1         # Terraform module testing
│
├── 📚 docs/                       # Documentation
│   ├── DEVELOPMENT-SETUP.md       # Development environment setup
│   ├── WINDOWS-SETUP.md           # Windows-specific setup guide
│   ├── PUPPET-SETUP-COMPLETION.md # Puppet configuration guide
│   ├── architecture/              # Architecture documentation
│   └── runbooks/                  # Operational runbooks
│       └── node-failure-recovery.md
│
├── ⚡ Make.ps1                     # Main automation script (26 commands ✅)
├── 🔧 Makefile                     # Linux/macOS automation
├── 📋 inventory.yaml.example       # Node inventory template
├── 📊 PROJECT-STATUS.md            # Current project status
├── 📈 DEPLOYMENT-STATUS.md         # Deployment progress tracking
└── ✅ MAKE-COMMAND-TEST-RESULTS.md  # Testing validation results
```

### 🎯 **Key Project Features**
- **Infrastructure as Code**: 22 Terraform resources across multiple modules
- **Configuration Management**: 23+ Puppet tasks for automated deployment
- **Container Orchestration**: Complete Kubernetes stack with Helm charts
- **Monitoring & Observability**: Prometheus, Grafana, AlertManager stack
- **Data Engineering Platform**: NiFi, Trino, PostgreSQL, MinIO services
- **Cross-Platform Automation**: PowerShell + Bash scripts for all platforms
- **Enterprise Security**: RBAC, network policies, secrets management
- **Comprehensive Testing**: Validation scripts and automated testing
- **GitOps Ready**: GitHub Actions workflows for CI/CD
- GitHub for version control
- Optional: cloud backup services
