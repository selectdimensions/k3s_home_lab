# Terraform Layer - Infrastructure as Code

> **Terraform modules for K3s cluster provisioning and configuration**

📍 **Location**: `terraform/`
🏗️ **Modules**: 7
🌍 **Environments**: dev, staging, prod

[← Back to Index](./INDEX.md)

---

## Table of Contents

- [Overview](#overview)
- [Directory Structure](#directory-structure)
- [Environments](#environments)
- [Modules](#modules)
  - [k3s-cluster](#k3s-cluster)
  - [data-platform](#data-platform)
  - [monitoring](#monitoring)
  - [backup](#backup)
  - [security](#security)
  - [gitops](#gitops)
  - [puppet-infrastructure](#puppet-infrastructure)
- [Variables Reference](#variables-reference)
- [Outputs](#outputs)
- [Usage](#usage)

---

## Overview

The Terraform layer generates **configuration files** and **Helm values** for the K3s cluster. Unlike traditional Terraform deployments that provision cloud resources, this module:

1. Generates K3s configuration files for each node
2. Creates Helm values for applications
3. Outputs namespace configurations
4. Prepares configuration for Puppet to apply

### Architecture

```text
┌─────────────────────────────────────────────────────────────────┐
│                    terraform/ directory                          │
├─────────────────────────────────────────────────────────────────┤
│  main.tf                 ← Root module, invokes child modules    │
│  backend.tf              ← State storage (local)                 │
│  variables.tf            ← Input variable definitions            │
│                                                                  │
│  environments/                                                   │
│  ├── dev/main.tf         ← Dev environment config                │
│  ├── staging/main.tf     ← Staging environment config            │
│  └── prod/main.tf        ← Production environment config         │
│                                                                  │
│  modules/                                                        │
│  ├── k3s-cluster/        ← Core K3s configuration                │
│  ├── data-platform/      ← NiFi, Trino, MinIO, PostgreSQL        │
│  ├── monitoring/         ← Prometheus, Grafana                   │
│  ├── backup/             ← Backup configuration                  │
│  ├── security/           ← RBAC, network policies                │
│  ├── gitops/             ← GitOps configuration                  │
│  └── puppet-infrastructure/                                      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                 ┌────────────────────────┐
                 │  Generated Outputs:    │
                 │  • .k3s-config/*.yaml  │
                 │  • helm-values/*.yaml  │
                 │  • k8s-configs/*.yaml  │
                 └────────────────────────┘
```

---

## Directory Structure

```text
terraform/
├── main.tf                     # Root module
├── backend.tf                  # Backend configuration
├── variables.tf                # Root variables
│
├── environments/
│   ├── dev/
│   │   ├── main.tf             # Dev module invocation
│   │   └── terraform.tfvars    # Dev variable values
│   ├── staging/
│   │   └── main.tf
│   └── prod/
│       └── main.tf
│
└── modules/
    ├── k3s-cluster/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── templates/
    │       ├── k3s-master.yaml.tpl
    │       └── k3s-worker.yaml.tpl
    │
    ├── data-platform/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── monitoring/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── backup/
    │   └── ...
    ├── security/
    │   └── ...
    ├── gitops/
    │   └── ...
    └── puppet-infrastructure/
        └── ...
```

---

## Environments

### dev

Development environment with minimal resources.

```hcl
# environments/dev/main.tf
module "cluster" {
  source      = "../../modules/k3s-cluster"
  environment = "dev"
  k3s_version = "v1.32.5+k3s1"

  nodes = {
    pi-master   = { ip = "192.168.0.120", role = "master" }
    pi-worker-1 = { ip = "192.168.0.121", role = "worker" }
    pi-worker-2 = { ip = "192.168.0.122", role = "worker" }
    pi-worker-3 = { ip = "192.168.0.123", role = "worker" }
  }
}
```

### staging

Pre-production environment for testing.

### prod

Production environment with full redundancy.

---

## Modules

### k3s-cluster

**Purpose**: Core K3s cluster configuration

**Location**: `terraform/modules/k3s-cluster/`

**Providers**:
- `hashicorp/kubernetes ~> 2.23`
- `hashicorp/helm ~> 2.11`
- `hashicorp/local ~> 2.4`
- `hashicorp/random ~> 3.1`
- `hashicorp/time ~> 0.9`

**Resources Created**:
- K3s configuration files for each node
- MetalLB Helm values
- Namespace configurations

#### Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `cluster_name` | string | `"pi-k3s-cluster"` | Cluster name |
| `environment` | string | required | Environment (dev/staging/prod) |
| `k3s_version` | string | `"v1.32.5+k3s1"` | K3s version |
| `k3s_token` | string | `""` | Cluster token (auto-generated) |
| `nodes` | map | required | Node definitions |
| `cluster_cidr` | string | `"10.42.0.0/16"` | Pod CIDR |
| `service_cidr` | string | `"10.43.0.0/16"` | Service CIDR |
| `cluster_dns` | string | `"10.43.0.10"` | DNS IP |
| `metallb_ip_range` | string | `"192.168.0.200-250"` | LoadBalancer IPs |
| `disable_components` | list | `["traefik"]` | Disabled components |

#### Outputs

| Output | Description |
|--------|-------------|
| `cluster_config` | Cluster configuration object |
| `k3s_token` | Generated cluster token |
| `kubeconfig_path` | Path to kubeconfig |

---

### data-platform

**Purpose**: Data engineering stack configuration

**Location**: `terraform/modules/data-platform/`

**Generates Helm values for**:
- Apache NiFi
- Trino
- MinIO
- PostgreSQL
- JupyterLab (optional)

#### Variables

| Variable | Type | Description |
|----------|------|-------------|
| `environment` | string | Environment name |
| `namespace` | string | Kubernetes namespace |
| `cluster_name` | string | Cluster name |
| `components` | object | Component configuration |

#### Component Configuration

```hcl
components = {
  nifi = {
    enabled  = true
    replicas = 1
    resources = {
      cpu    = "2000m"
      memory = "4Gi"
    }
  }
  trino = {
    enabled              = true
    coordinator_replicas = 1
    worker_replicas      = 2
    resources = { ... }
  }
  postgresql = {
    enabled      = true
    storage_size = "10Gi"
  }
  minio = {
    enabled = true
  }
}
```

#### Outputs

| Output | Description |
|--------|-------------|
| `nifi_values_path` | Path to NiFi Helm values |
| `trino_values_path` | Path to Trino Helm values |

---

### monitoring

**Purpose**: Prometheus and Grafana configuration

**Location**: `terraform/modules/monitoring/`

**Generates**:
- Prometheus Helm values
- Grafana Helm values
- Alert rule configurations

#### Variables

| Variable | Type | Description |
|----------|------|-------------|
| `environment` | string | Environment name |
| `namespace` | string | Monitoring namespace |
| `components.prometheus` | object | Prometheus config |
| `components.grafana` | object | Grafana config |

#### Prometheus Configuration

```hcl
prometheus = {
  enabled      = true
  retention    = "15d"
  storage_size = "10Gi"
}
```

#### Grafana Configuration

```hcl
grafana = {
  enabled        = true
  admin_password = var.grafana_password  # From secrets
}
```

---

### backup

**Purpose**: Backup configuration for cluster data

**Location**: `terraform/modules/backup/`

**Configures**:
- Backup schedules
- Retention policies
- Storage locations

---

### security

**Purpose**: RBAC and network policies

**Location**: `terraform/modules/security/`

**Generates**:
- RBAC roles and bindings
- Network policies
- Pod security policies

---

### gitops

**Purpose**: GitOps configuration (Flux/ArgoCD)

**Location**: `terraform/modules/gitops/`

**Configures**:
- Git repository connections
- Sync policies
- Application definitions

---

### puppet-infrastructure

**Purpose**: Puppet Bolt infrastructure configuration

**Location**: `terraform/modules/puppet-infrastructure/`

**Generates**:
- Inventory file templates
- Hiera data
- Bolt project configuration

---

## Variables Reference

### Root Variables

```hcl
# terraform/variables.tf

variable "environment" {
  description = "Deployment environment"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "cluster_name" {
  description = "Name of the K3s cluster"
  type        = string
  default     = "pi-k3s-cluster"
}

variable "k3s_version" {
  description = "K3s version to deploy"
  type        = string
  default     = "v1.32.5+k3s1"
}
```

### Node Definition

```hcl
nodes = {
  "node-name" = {
    ip     = "192.168.0.xxx"
    role   = "master" | "worker"
    labels = {
      "node-type" = "pi4"
    }
    taints = [
      "dedicated=data:NoSchedule"
    ]
  }
}
```

---

## Outputs

### Cluster Outputs

```hcl
output "cluster_config" {
  description = "Complete cluster configuration"
  value = {
    name        = var.cluster_name
    environment = var.environment
    version     = var.k3s_version
    nodes       = var.nodes
  }
}

output "master_ip" {
  description = "Master node IP address"
  value       = local.cluster_config.master_nodes[0].ip
}

output "k3s_token" {
  description = "K3s cluster join token"
  value       = local.actual_k3s_token
  sensitive   = true
}
```

---

## Usage

### Initialize

```powershell
# Via Make.ps1
.\Make.ps1 terraform-init -Environment dev

# Direct terraform
cd terraform/environments/dev
terraform init
```

### Plan

```powershell
# Via Make.ps1
.\Make.ps1 terraform-plan -Environment dev

# Direct terraform
cd terraform/environments/dev
terraform plan -out=tfplan
```

### Apply

```powershell
# Via Make.ps1
.\Make.ps1 terraform-apply -Environment dev

# Direct terraform
cd terraform/environments/dev
terraform apply tfplan
```

### Show Outputs

```powershell
# Via Make.ps1
.\Make.ps1 terraform-output -Environment dev

# Direct terraform
terraform output
```

### Destroy

```powershell
# Via Make.ps1
.\Make.ps1 terraform-destroy -Environment dev
```

---

## Generated Files

After `terraform apply`, these files are generated:

```text
.k3s-config/
├── pi-master-master.yaml      # Master K3s config
├── pi-worker-1-worker.yaml    # Worker 1 config
├── pi-worker-2-worker.yaml    # Worker 2 config
└── pi-worker-3-worker.yaml    # Worker 3 config

helm-values/
├── metallb-dev.yaml           # MetalLB values
├── nifi-dev.yaml              # NiFi values
├── trino-dev.yaml             # Trino values
├── postgresql-dev.yaml        # PostgreSQL values
├── minio-dev.yaml             # MinIO values
├── prometheus-dev.yaml        # Prometheus values
└── grafana-dev.yaml           # Grafana values

k8s-configs/
├── namespace-data-platform.yaml
├── namespace-monitoring.yaml
├── namespace-ingress.yaml
└── namespace-metallb-system.yaml
```

---

## State Management

### Backend Configuration

```hcl
# terraform/backend.tf
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
```

For team environments, consider:
- S3 backend with DynamoDB locking
- Terraform Cloud
- GitLab/GitHub state management

---

## Best Practices

1. **Always run plan before apply**
2. **Use environment-specific tfvars files**
3. **Keep sensitive values in environment variables**
4. **Tag resources with environment and project**
5. **Use modules for reusability**

---

## Related Documentation

- [AUTOMATION.md](./AUTOMATION.md) - Make.ps1 Terraform commands
- [KUBERNETES.md](./KUBERNETES.md) - Generated manifests and Helm values
- [PUPPET.md](./PUPPET.md) - Puppet consumes Terraform outputs

---

[← Back to Index](./INDEX.md)
