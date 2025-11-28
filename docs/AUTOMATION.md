# Make.ps1 - Automation Command Reference

> **Central automation script for all K3s Home Lab operations**

📍 **Location**: `Make.ps1` (project root)
📏 **Size**: ~920 lines
🔧 **Commands**: 26+

[← Back to Index](./INDEX.md)

---

## Table of Contents

- [Overview](#overview)
- [Parameters](#parameters)
- [Command Categories](#command-categories)
  - [Project Management](#project-management)
  - [Terraform Operations](#terraform-operations)
  - [Puppet Operations](#puppet-operations)
  - [Kubernetes Operations](#kubernetes-operations)
  - [Backup & Restore](#backup--restore)
  - [UI Access](#ui-access)
  - [Maintenance](#maintenance)
- [Function Reference](#function-reference)
- [Examples](#examples)

---

## Overview

`Make.ps1` is the **single entry point** for all cluster operations. It wraps:

- **Terraform** commands for infrastructure provisioning
- **Puppet Bolt** commands (via Docker) for node configuration
- **kubectl** commands for Kubernetes operations
- Utility functions for backup, restore, and maintenance

### Architecture

```text
┌─────────────────────────────────────────────────────────────────┐
│                         Make.ps1                                 │
│                    (Central Dispatcher)                          │
├─────────────────────────────────────────────────────────────────┤
│  Parameters:                                                     │
│  -Command     → Which operation to run                           │
│  -Environment → dev | staging | prod                             │
│  -Targets     → Puppet targets (all, masters, workers)          │
│  -BackupName  → Name for backup/restore operations              │
├─────────────────────────────────────────────────────────────────┤
│  Internal Functions:                                             │
│  ├── Show-Help              │ Initialize-Project                │
│  ├── Test-Configurations    │ Invoke-PuppetDeploy               │
│  ├── Get-ClusterStatus      │ Invoke-Backup/Restore             │
│  ├── Start-PortForward      │ Invoke-Maintenance                │
│  └── Invoke-Terraform       │ Invoke-QuickDeploy                │
├─────────────────────────────────────────────────────────────────┤
│  External Tools:                                                 │
│  ├── bolt.ps1 (Docker)      → Puppet Bolt                       │
│  ├── terraform              → Infrastructure                    │
│  └── kubectl                → Kubernetes                        │
└─────────────────────────────────────────────────────────────────┘
```

---

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-Command` | String | `"help"` | The operation to execute |
| `-Environment` | String | `"dev"` | Target environment (dev, staging, prod) |
| `-Targets` | String | `"all"` | Puppet targets (all, masters, workers, or specific nodes) |
| `-BackupName` | String | `""` | Name for backup file (auto-generated if empty) |
| `-PuppetEnv` | String | `"production"` | Puppet environment |
| `-Operation` | String | `""` | Additional operation parameter |

---

## Command Categories

### Project Management

#### `help`
Display all available commands with descriptions.

```powershell
.\Make.ps1 help
```

#### `init`
Initialize project - check Docker, SSH keys, build puppet-bolt image.

```powershell
.\Make.ps1 init
```

**Actions:**
- Verifies Docker is running
- Checks for SSH keys in `~/.ssh/`
- Builds `puppet-bolt:latest` Docker image
- Validates inventory file exists

#### `validate`
Run comprehensive infrastructure validation.

```powershell
.\Make.ps1 validate
```

**Checks:**
- Puppet syntax (manifests, plans)
- Terraform configuration
- Kubernetes manifests (YAML validation)
- Inventory file structure
- SSH connectivity to nodes

**Output:**
- Detailed test results
- Pass/Fail/Warning counts
- JSON report saved to `validation-report-*.json`

---

### Terraform Operations

All Terraform commands require the `-Environment` parameter.

#### `terraform-init`
Initialize Terraform with backend configuration.

```powershell
.\Make.ps1 terraform-init -Environment dev
```

**Actions:**
- Downloads required providers
- Initializes backend (local state)
- Prepares workspace for plan/apply

#### `terraform-plan`
Show planned infrastructure changes.

```powershell
.\Make.ps1 terraform-plan -Environment dev
```

**Output:**
- Resources to be created/modified/destroyed
- Plan file saved for apply

#### `terraform-apply`
Apply Terraform configuration.

```powershell
.\Make.ps1 terraform-apply -Environment dev
```

**Actions:**
- Applies changes from plan
- Creates configuration files
- Generates Helm values

#### `terraform-destroy`
Destroy all Terraform-managed resources.

```powershell
.\Make.ps1 terraform-destroy -Environment dev
```

⚠️ **Warning**: This is destructive!

#### `terraform-output`
Display Terraform outputs.

```powershell
.\Make.ps1 terraform-output -Environment dev
```

---

### Puppet Operations

Puppet commands use `bolt.ps1` to run Bolt in Docker.

#### `puppet-deploy`
Deploy cluster using Puppet Bolt plan.

```powershell
# Deploy to all nodes
.\Make.ps1 puppet-deploy

# Deploy to specific targets
.\Make.ps1 puppet-deploy -Targets masters
.\Make.ps1 puppet-deploy -Targets workers
.\Make.ps1 puppet-deploy -Targets pi-worker-3
```

**Uses**: `pi_cluster_automation::deploy_robust` plan

**Phases:**
1. Wait for apt locks to clear
2. Install base packages (sequential)
3. Enable cgroups for K3s
4. Install K3s on master(s)
5. Join workers to cluster

#### `puppet-plan`
Run a specific Puppet Bolt plan.

```powershell
.\Make.ps1 puppet-plan -Operation "pi_cluster_automation::deploy_simple"
```

#### `puppet-task`
Run a specific Puppet Bolt task.

```powershell
.\Make.ps1 puppet-task -Operation "pi_cluster_automation::cluster_status"
```

#### `puppet-command`
Run a shell command on targets via Bolt.

```powershell
.\Make.ps1 puppet-command -Operation "uptime" -Targets all
```

---

### Kubernetes Operations

#### `cluster-status`
Display cluster node status and version info.

```powershell
.\Make.ps1 cluster-status
```

**Output:**
```text
NAME          STATUS   ROLES                  VERSION
pi-master     Ready    control-plane,master   v1.32.5+k3s1
pi-worker-1   Ready    <none>                 v1.32.5+k3s1
pi-worker-2   Ready    <none>                 v1.32.5+k3s1
pi-worker-3   Ready    <none>                 v1.32.5+k3s1
```

#### `kubeconfig`
Retrieve kubeconfig from master node.

```powershell
.\Make.ps1 kubeconfig
```

**Actions:**
- SSH to master node
- Copy `/etc/rancher/k3s/k3s.yaml`
- Update server address to master IP
- Save to local `~/.kube/config`

#### `apply-manifests`
Apply Kubernetes manifests using kustomize.

```powershell
.\Make.ps1 apply-manifests -Environment dev
```

#### `deploy-data-stack`
Deploy the data engineering stack (NiFi, Trino, MinIO, PostgreSQL).

```powershell
.\Make.ps1 deploy-data-stack
```

#### `setup-monitoring`
Deploy Prometheus and Grafana monitoring stack.

```powershell
.\Make.ps1 setup-monitoring
```

---

### Backup & Restore

#### `backup`
Create a backup of cluster resources.

```powershell
# Auto-named backup
.\Make.ps1 backup

# Named backup
.\Make.ps1 backup -BackupName "pre-upgrade"
```

**Backed up:**
- All Kubernetes resources (YAML)
- ConfigMaps
- Secrets
- Persistent Volumes
- Node information

**Location:** `backups/pre-upgrade-{timestamp}/`

#### `restore`
Restore cluster from backup.

```powershell
.\Make.ps1 restore -BackupName "pre-upgrade-20251128-122858"
```

#### `list-backups`
List available backups.

```powershell
.\Make.ps1 list-backups
```

---

### UI Access

Port-forwarding commands to access cluster UIs.

#### `nifi-ui`
Port-forward to Apache NiFi UI.

```powershell
.\Make.ps1 nifi-ui
```

**Access:** http://localhost:8080/nifi
**Credentials:** admin / nifi123456789!

#### `grafana-ui`
Port-forward to Grafana dashboard.

```powershell
.\Make.ps1 grafana-ui
```

**Access:** http://localhost:3000
**Default credentials:** admin / admin

#### `trino-ui`
Port-forward to Trino UI.

```powershell
.\Make.ps1 trino-ui
```

#### `minio-ui`
Port-forward to MinIO console.

```powershell
.\Make.ps1 minio-ui
```

---

### Maintenance

#### `quick-deploy`
Full deployment combining Terraform and Puppet.

```powershell
.\Make.ps1 quick-deploy -Environment dev
```

**Steps:**
1. `terraform-init`
2. `terraform-plan`
3. `terraform-apply`
4. `puppet-deploy`
5. `cluster-status`

#### `drain-node`
Drain a node for maintenance.

```powershell
.\Make.ps1 drain-node -Operation "pi-worker-1"
```

#### `uncordon-node`
Return a node to service.

```powershell
.\Make.ps1 uncordon-node -Operation "pi-worker-1"
```

#### `clean`
Clean temporary files and cached data.

```powershell
.\Make.ps1 clean
```

---

## Function Reference

### Core Functions

| Function | Description |
|----------|-------------|
| `Show-Help` | Display help with all commands |
| `Initialize-Project` | Setup project prerequisites |
| `Test-Configurations` | Validate all configurations |
| `Get-ClusterStatus` | Get kubectl cluster status |

### Puppet Functions

| Function | Description |
|----------|-------------|
| `Invoke-PuppetDeploy` | Run deployment plan |
| `Invoke-PuppetPlan` | Run arbitrary plan |
| `Invoke-PuppetTask` | Run arbitrary task |
| `Invoke-PuppetCommand` | Run shell command via Bolt |

### Terraform Functions

| Function | Description |
|----------|-------------|
| `Invoke-TerraformInit` | Initialize Terraform |
| `Invoke-TerraformPlan` | Create execution plan |
| `Invoke-TerraformApply` | Apply configuration |
| `Invoke-TerraformDestroy` | Destroy resources |
| `Invoke-TerraformOutput` | Show outputs |

### Utility Functions

| Function | Description |
|----------|-------------|
| `Invoke-Backup` | Create cluster backup |
| `Invoke-Restore` | Restore from backup |
| `Start-PortForward` | Port-forward to service |
| `Invoke-Maintenance` | Node maintenance operations |

---

## Examples

### Daily Workflow

```powershell
# Morning: Check cluster status
.\Make.ps1 cluster-status

# Make changes to Terraform
# Preview changes
.\Make.ps1 terraform-plan -Environment dev

# Apply if satisfied
.\Make.ps1 terraform-apply -Environment dev
```

### Pre-Upgrade Workflow

```powershell
# Create backup before upgrade
.\Make.ps1 backup -BackupName "pre-v1.32-upgrade"

# Verify backup
.\Make.ps1 list-backups

# Perform upgrade...

# If problems, restore
.\Make.ps1 restore -BackupName "pre-v1.32-upgrade-20251128-122858"
```

### Troubleshooting Workflow

```powershell
# Validate everything
.\Make.ps1 validate

# Check cluster health
.\Make.ps1 cluster-status

# Run command on all nodes
.\Make.ps1 puppet-command -Operation "systemctl status k3s" -Targets all

# Check specific task
.\Make.ps1 puppet-task -Operation "pi_cluster_automation::cluster_overview"
```

### New Environment Setup

```powershell
# 1. Initialize project
.\Make.ps1 init

# 2. Validate configuration
.\Make.ps1 validate

# 3. Full deployment
.\Make.ps1 quick-deploy -Environment dev

# 4. Verify
.\Make.ps1 cluster-status

# 5. Deploy data stack
.\Make.ps1 deploy-data-stack

# 6. Access NiFi
.\Make.ps1 nifi-ui
```

---

## VS Code Tasks

The project includes VS Code tasks in `.vscode/tasks.json`:

| Task | Command |
|------|---------|
| 🏗️ Terraform: Init Dev | `.\Make.ps1 terraform-init -Environment dev` |
| 🏗️ Terraform: Plan Dev | `.\Make.ps1 terraform-plan -Environment dev` |
| 🏗️ Terraform: Apply Dev | `.\Make.ps1 terraform-apply -Environment dev` |
| 🎭 Puppet: Deploy | `.\Make.ps1 puppet-deploy` |
| 🚀 Quick Deploy | `.\Make.ps1 quick-deploy -Environment dev` |
| 📊 Cluster Status | `.\Make.ps1 cluster-status` |
| 🔍 Validate Configuration | `.\Make.ps1 validate` |
| 📁 Get Kubeconfig | `.\Make.ps1 kubeconfig` |
| 🌐 NiFi UI | `.\Make.ps1 nifi-ui` |
| 📊 Grafana UI | `.\Make.ps1 grafana-ui` |

Run tasks via:
- `Ctrl+Shift+P` → "Tasks: Run Task"
- Or use the Terminal menu

---

## Related Documentation

- [PUPPET.md](./PUPPET.md) - Puppet plans and tasks that Make.ps1 invokes
- [TERRAFORM.md](./TERRAFORM.md) - Terraform modules used by Make.ps1
- [SCRIPTS.md](./SCRIPTS.md) - Additional scripts for troubleshooting

---

[← Back to Index](./INDEX.md)
