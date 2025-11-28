# Scripts - Utility & Troubleshooting

> **PowerShell and Bash scripts for validation, fixes, and maintenance**

📍 **Location**: `scripts/`
🔧 **Scripts**: 15+
💻 **Languages**: PowerShell, Bash

[← Back to Index](./INDEX.md)

---

## Table of Contents

- [Overview](#overview)
- [Directory Structure](#directory-structure)
- [Validation Scripts](#validation-scripts)
- [Fix Scripts](#fix-scripts)
- [Setup Scripts](#setup-scripts)
- [Backup & Recovery Scripts](#backup--recovery-scripts)
- [Utility Scripts](#utility-scripts)

---

## Overview

The `scripts/` directory contains standalone scripts for:

- **Validation**: Pre-deployment checks and configuration validation
- **Fixes**: Automated repair for common issues
- **Setup**: Initial cluster bootstrapping
- **Backup/Recovery**: Disaster recovery procedures

### Script Categories

```text
scripts/
├── Validation      → validate-infrastructure.ps1, deployment-readiness.ps1
├── Fixes           → fix-worker-nodes.ps1, cluster-fix.ps1, fix-apt-locks.ps1
├── Setup           → bootstrap.sh, setup-from-scratch.sh
├── Backup          → backup/, disaster-recovery/
└── Utilities       → quick-diagnostic.ps1, test-terraform.ps1
```

---

## Directory Structure

```text
scripts/
├── validate-infrastructure.ps1    # Comprehensive validation
├── deployment-readiness.ps1       # Pre-deployment checks
├── fix-worker-nodes.ps1           # Worker node repair
├── cluster-fix.ps1                # General cluster fixes
├── fix-apt-locks.ps1              # Clear apt locks
├── quick-diagnostic.ps1           # Quick health check
├── test-terraform.ps1             # Terraform testing
├── enhanced-puppet-deploy.ps1     # Enhanced Puppet deployment
│
├── bootstrap.sh                   # Initial Linux setup
├── setup-from-scratch.sh          # Full cluster setup
├── prepare-sd-card.sh             # SD card preparation
│
├── backup/                        # Backup scripts
│   └── ...
├── disaster-recovery/             # DR scripts
│   └── ...
└── setup/                         # Additional setup scripts
    └── ...
```

---

## Validation Scripts

### validate-infrastructure.ps1

**Purpose**: Comprehensive infrastructure validation

**Location**: `scripts/validate-infrastructure.ps1`

**Size**: ~618 lines

**Usage**:
```powershell
# Full validation
.\scripts\validate-infrastructure.ps1

# Skip specific checks
.\scripts\validate-infrastructure.ps1 -SkipPuppet
.\scripts\validate-infrastructure.ps1 -SkipTerraform
.\scripts\validate-infrastructure.ps1 -SkipK8s

# Or via Make.ps1
.\Make.ps1 validate
```

**Parameters**:
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-Environment` | String | `"dev"` | Target environment |
| `-SkipPuppet` | Switch | `$false` | Skip Puppet validation |
| `-SkipTerraform` | Switch | `$false` | Skip Terraform validation |
| `-SkipK8s` | Switch | `$false` | Skip Kubernetes validation |

**Checks Performed**:

| Category | Tests |
|----------|-------|
| **Puppet** | Manifest syntax, plan syntax, inventory structure |
| **Terraform** | Configuration validation, format check |
| **Kubernetes** | YAML syntax, manifest validation |
| **SSH** | Key existence, connectivity to nodes |
| **Docker** | Docker running, puppet-bolt image exists |

**Output**:
- Console output with ✅ Pass / ❌ Fail / ⚠️ Warning
- JSON report: `validation-report-{timestamp}.json`
- Summary with pass rate percentage

**Example Output**:
```text
🔍 Running Infrastructure Validation
Working directory: C:\Users\Jenkins\Documents\k3s_home_lab

===== PUPPET VALIDATION =====
🔍 Checking Puppet manifest files...
✅ puppet/manifests/site.pp - Syntax OK
✅ puppet/plans/deploy.pp - Syntax OK
✅ puppet/plans/deploy_robust.pp - Syntax OK

===== TERRAFORM VALIDATION =====
🔍 Validating Terraform configuration...
✅ Terraform configuration valid

===== SUMMARY =====
Total Tests: 32
Passed: 27 (84.4%)
Failed: 0
Warnings: 5
```

---

### deployment-readiness.ps1

**Purpose**: Pre-deployment health checks

**Location**: `scripts/deployment-readiness.ps1`

**Usage**:
```powershell
.\scripts\deployment-readiness.ps1 -Environment dev
```

**Checks**:
- Node SSH connectivity
- K3s service status
- Disk space availability
- Memory availability
- Network connectivity between nodes
- Required ports open

**Output**: JSON report with deployment readiness score

---

## Fix Scripts

### fix-worker-nodes.ps1

**Purpose**: Automated worker node repair

**Location**: `scripts/fix-worker-nodes.ps1`

**Usage**:
```powershell
# Fix all workers
.\scripts\fix-worker-nodes.ps1

# Fix specific worker
.\scripts\fix-worker-nodes.ps1 -NodeName "pi-worker-3"
```

**Actions**:
1. Check node connectivity
2. Clear apt locks if present
3. Restart K3s agent if needed
4. Re-join node to cluster if disconnected
5. Verify node status after fix

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| `-NodeName` | String | Specific node to fix (optional) |
| `-ForceReinstall` | Switch | Force K3s reinstallation |
| `-MasterIP` | String | Master node IP |
| `-K3sToken` | String | Cluster join token |

---

### cluster-fix.ps1

**Purpose**: General cluster repair operations

**Location**: `scripts/cluster-fix.ps1`

**Usage**:
```powershell
.\scripts\cluster-fix.ps1
```

**Operations**:
- Restart stuck pods
- Clear evicted pods
- Fix node taints
- Restart K3s services
- Clear stale deployments

---

### fix-apt-locks.ps1

**Purpose**: Clear apt/dpkg locks on nodes

**Location**: `scripts/fix-apt-locks.ps1`

**Usage**:
```powershell
.\scripts\fix-apt-locks.ps1 -Targets all
```

**Actions**:
```bash
# Commands executed on each node:
rm -f /var/lib/apt/lists/lock
rm -f /var/cache/apt/archives/lock
rm -f /var/lib/dpkg/lock*
dpkg --configure -a
```

---

## Setup Scripts

### bootstrap.sh

**Purpose**: Initial node bootstrapping (run on each Pi)

**Location**: `scripts/bootstrap.sh`

**Usage** (on Pi node):
```bash
curl -fsSL https://raw.githubusercontent.com/.../bootstrap.sh | bash
```

**Actions**:
1. Update system packages
2. Install required tools (curl, wget, git)
3. Configure SSH
4. Set hostname
5. Enable cgroups for containers
6. Disable swap

---

### setup-from-scratch.sh

**Purpose**: Complete cluster setup from fresh OS

**Location**: `scripts/setup-from-scratch.sh`

**Usage** (on management machine):
```bash
./scripts/setup-from-scratch.sh
```

**Steps**:
1. SSH to each node
2. Run bootstrap
3. Install K3s on master
4. Join workers to cluster
5. Deploy data stack
6. Configure monitoring

---

### prepare-sd-card.sh

**Purpose**: Prepare SD card with Raspberry Pi OS

**Location**: `scripts/prepare-sd-card.sh`

**Usage**:
```bash
./scripts/prepare-sd-card.sh /dev/sdX
```

**Actions**:
- Flash Raspberry Pi OS Lite
- Configure WiFi (optional)
- Enable SSH
- Set hostname
- Configure static IP

---

## Backup & Recovery Scripts

### scripts/backup/

Backup automation scripts.

**Contents**:
- `backup-cluster.sh` - Full cluster backup
- `backup-etcd.sh` - etcd snapshot
- `backup-pvcs.sh` - PVC data backup
- `sync-to-remote.sh` - Sync to remote storage

### scripts/disaster-recovery/

Disaster recovery procedures.

**Contents**:
- `restore-cluster.sh` - Full cluster restore
- `restore-etcd.sh` - Restore from etcd snapshot
- `rebuild-node.sh` - Rebuild failed node

---

## Utility Scripts

### quick-diagnostic.ps1

**Purpose**: Quick cluster health check

**Location**: `scripts/quick-diagnostic.ps1`

**Usage**:
```powershell
.\scripts\quick-diagnostic.ps1
```

**Output**:
- Node status
- Pod status
- Service status
- Resource usage
- Recent events

---

### test-terraform.ps1

**Purpose**: Test Terraform configurations

**Location**: `scripts/test-terraform.ps1`

**Usage**:
```powershell
.\scripts\test-terraform.ps1 -Environment dev
```

**Actions**:
- Terraform fmt check
- Terraform validate
- Terraform plan (dry run)

---

### enhanced-puppet-deploy.ps1

**Purpose**: Enhanced Puppet deployment with retry logic

**Location**: `scripts/enhanced-puppet-deploy.ps1`

**Usage**:
```powershell
.\scripts\enhanced-puppet-deploy.ps1 -Targets all -MaxRetries 3
```

**Features**:
- Automatic retry on failure
- Progress reporting
- Detailed error logging
- Rollback on failure

---

## Root-Level Scripts

Located in project root (not in `scripts/`):

### Make.ps1

Main automation script (see [AUTOMATION.md](./AUTOMATION.md)).

### bolt.ps1

Docker wrapper for Puppet Bolt (see [PUPPET.md](./PUPPET.md#docker-bolt-wrapper)).

### show-project-tree.ps1

Display project structure.

```powershell
.\show-project-tree.ps1
```

### Show-ProjectStructure.ps1

Alternative project structure display.

```powershell
.\Show-ProjectStructure.ps1
```

### k3s_quick_fixer.ps1

Quick fix script for common K3s issues.

```powershell
.\k3s_quick_fixer.ps1
```

### k3s_troubleshooter.ps1

Interactive troubleshooter for K3s problems.

```powershell
.\k3s_troubleshooter.ps1
```

### Upgrade-K3sMaster.ps1

Upgrade K3s on master node.

```powershell
.\Upgrade-K3sMaster.ps1 -Version "v1.32.5+k3s1"
```

---

## Script Development Guidelines

### PowerShell Scripts

1. Use `[CmdletBinding()]` for parameter validation
2. Include help comments (`Get-Help` compatible)
3. Use approved verbs (`Get-`, `Set-`, `Invoke-`)
4. Handle errors with `try/catch`
5. Provide `-WhatIf` support for destructive operations

### Bash Scripts

1. Use `set -e` for error handling
2. Include shebang: `#!/bin/bash`
3. Quote all variables: `"$variable"`
4. Use functions for organization
5. Log to stderr, output to stdout

---

## Common Workflows

### Pre-Deployment Check

```powershell
# Run full validation
.\Make.ps1 validate

# Check deployment readiness
.\scripts\deployment-readiness.ps1 -Environment dev
```

### Fix Failing Worker

```powershell
# Quick diagnostic
.\scripts\quick-diagnostic.ps1

# Fix specific worker
.\scripts\fix-worker-nodes.ps1 -NodeName pi-worker-3

# Verify
.\Make.ps1 cluster-status
```

### Pre-Upgrade Preparation

```powershell
# Create backup
.\Make.ps1 backup -BackupName "pre-upgrade"

# Validate current state
.\Make.ps1 validate

# Check all nodes healthy
.\Make.ps1 cluster-status
```

---

## Related Documentation

- [AUTOMATION.md](./AUTOMATION.md) - Make.ps1 commands
- [PUPPET.md](./PUPPET.md) - Puppet tasks for node operations
- [INDEX.md](./INDEX.md) - Project overview

---

[← Back to Index](./INDEX.md)
