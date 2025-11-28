# Puppet Layer - Configuration Management

> **Puppet Bolt plans and tasks for K3s cluster deployment and management**

📍 **Location**: `puppet/`
🐳 **Wrapper**: `bolt.ps1` (Docker-based)
📦 **Plans**: 6 | **Tasks**: 11

[← Back to Index](./INDEX.md)

---

## Table of Contents

- [Overview](#overview)
- [Docker Bolt Wrapper](#docker-bolt-wrapper)
- [Project Structure](#project-structure)
- [Inventory](#inventory)
- [Plans](#plans)
- [Tasks](#tasks)
- [Hiera Data](#hiera-data)
- [Common Workflows](#common-workflows)

---

## Overview

The Puppet layer uses **Puppet Bolt** to orchestrate node configuration and K3s deployment. Bolt runs in a Docker container to ensure consistent execution across platforms.

### Architecture

```text
┌─────────────────────────────────────────────────────────────────┐
│                         bolt.ps1                                 │
│                    (Docker Wrapper)                              │
├─────────────────────────────────────────────────────────────────┤
│  docker run -it --rm                                             │
│    -v ${PWD}:/workspace                                          │
│    -v ~/.ssh:/root/.ssh:ro                                       │
│    puppet-bolt:latest                                            │
│    bolt <command> --project /workspace/puppet ...                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      puppet/ directory                           │
├─────────────────────────────────────────────────────────────────┤
│  bolt-project.yaml    ← Project configuration                   │
│  inventory.yaml       ← Node inventory with roles               │
│  hiera.yaml           ← Hierarchical data lookup                │
│  Puppetfile           ← Module dependencies                     │
│                                                                  │
│  plans/               ← Orchestration workflows                 │
│  ├── deploy.pp                                                   │
│  ├── deploy_robust.pp     ← Primary deployment plan             │
│  ├── deploy_simple.pp                                            │
│  ├── k3s_deploy.pp                                               │
│  ├── restore.pp                                                  │
│  └── setup_monitoring_backup.pp                                  │
│                                                                  │
│  tasks/               ← Atomic operations                       │
│  ├── cluster_status.{json,sh}                                    │
│  ├── install_k3s_master.{json,sh}                                │
│  ├── install_k3s_worker.{json,sh}                                │
│  └── ...                                                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## Docker Bolt Wrapper

### bolt.ps1

The `bolt.ps1` script wraps Puppet Bolt in Docker:

```powershell
# Location: project root
# Usage: .\bolt.ps1 <bolt-command> [arguments]
```

### Key Features

| Feature | Description |
|---------|-------------|
| **No local installation** | Uses `puppet-bolt:latest` Docker image |
| **Mounts workspace** | Project available at `/workspace` in container |
| **SSH key access** | Mounts `~/.ssh` read-only for node access |
| **Auto-detects workdir** | Sets `--project` based on command type |

### Examples

```powershell
# Run a plan
.\bolt.ps1 plan run pi_cluster_automation::deploy_robust --targets all

# Run a task
.\bolt.ps1 task run pi_cluster_automation::cluster_status --targets masters

# Run a command
.\bolt.ps1 command run "uptime" --targets all

# Show inventory
.\bolt.ps1 inventory show
```

### Building the Docker Image

```powershell
# Build from Dockerfile in project root
docker build -t puppet-bolt:latest .

# Or via Make.ps1
.\Make.ps1 init  # Includes image build
```

---

## Project Structure

```text
puppet/
├── bolt-project.yaml          # Bolt project configuration
├── inventory.yaml             # Node inventory
├── hiera.yaml                 # Hiera configuration
├── Puppetfile                 # Module dependencies
├── Gemfile                    # Ruby dependencies
│
├── plans/                     # Bolt plans (orchestration)
│   ├── deploy.pp
│   ├── deploy_robust.pp       # Primary deployment plan
│   ├── deploy_simple.pp
│   ├── k3s_deploy.pp
│   ├── restore.pp
│   └── setup_monitoring_backup.pp
│
├── tasks/                     # Bolt tasks (atomic operations)
│   ├── cluster_status.json    # Task metadata
│   ├── cluster_status.sh      # Task script
│   ├── cluster_overview.json
│   ├── cluster_overview.sh
│   ├── install_k3s_master.json
│   ├── install_k3s_master.sh
│   ├── install_k3s_worker.json
│   ├── install_k3s_worker.sh
│   ├── backup_cluster.json
│   ├── backup_cluster.sh
│   ├── restore_cluster.json
│   ├── restore_cluster.sh
│   ├── deploy_data_stack.json
│   ├── deploy_data_stack.sh
│   ├── setup_monitoring.json
│   ├── setup_monitoring.sh
│   └── ...
│
├── data/                      # Hiera data
│   └── common.yaml
│
├── site-modules/              # Custom modules
├── spec/                      # Tests
└── vendor/                    # Vendored modules
```

---

## Inventory

### inventory.yaml

Defines all nodes with their roles and connection details:

```yaml
groups:
  - name: pi_cluster
    config:
      transport: ssh
      ssh:
        user: pi
        run-as: root
        host-key-check: false
        private-key: ~/.ssh/id_ed25519
    groups:
      - name: masters
        targets:
          - uri: 192.168.0.120
            name: pi-master
            vars:
              role: master
              k3s_role: server
      - name: workers
        targets:
          - uri: 192.168.0.121
            name: pi-worker-1
            vars:
              role: worker
              k3s_role: agent
          - uri: 192.168.0.122
            name: pi-worker-2
            vars:
              role: worker
              k3s_role: agent
          - uri: 192.168.0.123
            name: pi-worker-3
            vars:
              role: worker
              k3s_role: agent
```

### Target Groups

| Group | Description | Nodes |
|-------|-------------|-------|
| `all` | All nodes | pi-master, pi-worker-1, pi-worker-2, pi-worker-3 |
| `masters` | Control plane | pi-master |
| `workers` | Workload nodes | pi-worker-1, pi-worker-2, pi-worker-3 |
| `pi_cluster` | Entire cluster | All nodes |

---

## Plans

Plans orchestrate complex, multi-step operations across nodes.

### deploy_robust.pp (Primary)

**Purpose**: Full cluster deployment with apt lock handling

**File**: `puppet/plans/deploy_robust.pp`

**Parameters**:
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `targets` | TargetSpec | required | Nodes to deploy to |
| `deploy_env` | String | `'dev'` | Environment name |
| `skip_k3s` | Boolean | `false` | Skip K3s installation |
| `wait_for_apt` | Boolean | `true` | Wait for apt locks |

**Phases**:
1. **Phase 0**: Wait for apt/dpkg processes to complete
2. **Phase 1**: Base system configuration (sequential per node)
   - Clear apt locks
   - Install base packages (curl, wget, git, vim, htop)
   - Enable cgroups
   - Disable swap
3. **Phase 2**: Install K3s master
   - Install K3s server with `v1.32.5+k3s1`
   - Wait for API server ready
   - Retrieve join token
4. **Phase 3**: Install K3s workers (sequential)
   - Install K3s agent on each worker
   - Join to master

**Usage**:
```powershell
.\bolt.ps1 plan run pi_cluster_automation::deploy_robust --targets all
```

### deploy.pp

**Purpose**: Standard deployment plan

Similar to `deploy_robust.pp` but without apt lock handling.

### deploy_simple.pp

**Purpose**: Minimal deployment for quick testing

Only installs K3s without base package configuration.

### k3s_deploy.pp

**Purpose**: K3s-specific deployment

Focused on K3s installation only, assumes base packages are installed.

### restore.pp

**Purpose**: Restore cluster from backup

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| `targets` | TargetSpec | Nodes to restore |
| `backup_name` | String | Name of backup to restore |

### setup_monitoring_backup.pp

**Purpose**: Deploy monitoring and backup infrastructure

---

## Tasks

Tasks are atomic operations that run on a single node.

### cluster_status

**Purpose**: Get K3s cluster node status

**File**: `puppet/tasks/cluster_status.sh`

**Parameters**: None

**Output**: JSON with node status

**Usage**:
```powershell
.\bolt.ps1 task run pi_cluster_automation::cluster_status --targets masters
```

### cluster_overview

**Purpose**: Comprehensive cluster health check

**Output**: Detailed cluster information including:
- Node status
- Pod status
- Resource usage
- K3s service status

### install_k3s_master

**Purpose**: Install K3s server on master node

**File**: `puppet/tasks/install_k3s_master.sh`

**Parameters**:
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `k3s_version` | String | `v1.28.4+k3s1` | K3s version |
| `k3s_token` | String | required | Cluster token (sensitive) |
| `cluster_cidr` | String | `10.42.0.0/16` | Pod CIDR |
| `service_cidr` | String | `10.43.0.0/16` | Service CIDR |
| `cluster_dns` | String | `10.43.0.10` | DNS IP |
| `install_traefik` | Boolean | `false` | Install Traefik |
| `debug_mode` | Boolean | `false` | Enable debug |

**Actions**:
1. Check existing K3s installation
2. Download and install K3s
3. Configure kubelet args for Pi optimization
4. Wait for API server ready

### install_k3s_worker

**Purpose**: Install K3s agent on worker node

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| `k3s_version` | String | K3s version |
| `k3s_url` | String | Master API URL |
| `k3s_token` | String | Join token |
| `node_name` | String | Node name |

### backup_cluster

**Purpose**: Create cluster backup

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| `backup_name` | String | Backup identifier |
| `backup_path` | String | Storage location |

**Backed up**:
- All Kubernetes resources
- ConfigMaps
- Secrets
- Persistent Volumes

### restore_cluster

**Purpose**: Restore from backup

### deploy_data_stack

**Purpose**: Deploy data engineering stack

**Deploys**:
- Apache NiFi
- Trino
- MinIO
- PostgreSQL

### setup_monitoring

**Purpose**: Deploy monitoring stack

**Deploys**:
- Prometheus
- Grafana
- Alert rules

---

## Hiera Data

### hiera.yaml

```yaml
---
version: 5
defaults:
  datadir: data
  data_hash: yaml_data
hierarchy:
  - name: "Per-node data"
    path: "nodes/%{trusted.certname}.yaml"
  - name: "Per-environment data"
    path: "environments/%{environment}.yaml"
  - name: "Common data"
    path: "common.yaml"
```

### data/common.yaml

Contains shared configuration:
- K3s version
- Cluster CIDR ranges
- Default settings

---

## Common Workflows

### Initial Cluster Deployment

```powershell
# Via Make.ps1 (recommended)
.\Make.ps1 puppet-deploy

# Direct Bolt command
.\bolt.ps1 plan run pi_cluster_automation::deploy_robust \
  --targets all \
  deploy_env=dev
```

### Check Cluster Status

```powershell
# Via Make.ps1
.\Make.ps1 cluster-status

# Direct Bolt
.\bolt.ps1 task run pi_cluster_automation::cluster_status \
  --targets masters
```

### Run Command on All Nodes

```powershell
# Via Make.ps1
.\Make.ps1 puppet-command -Operation "uptime" -Targets all

# Direct Bolt
.\bolt.ps1 command run "uptime" --targets all
```

### Deploy Only Workers

```powershell
.\bolt.ps1 plan run pi_cluster_automation::deploy_robust \
  --targets workers \
  skip_k3s=false
```

### Run Custom Task

```powershell
.\bolt.ps1 task run pi_cluster_automation::cluster_overview \
  --targets masters \
  --format json
```

---

## Task/Plan Reference Table

### Plans

| Plan | Purpose | Targets |
|------|---------|---------|
| `deploy_robust` | Full deployment with apt handling | all |
| `deploy` | Standard deployment | all |
| `deploy_simple` | Minimal deployment | all |
| `k3s_deploy` | K3s only | all |
| `restore` | Restore from backup | all |
| `setup_monitoring_backup` | Monitoring/backup setup | masters |

### Tasks

| Task | Purpose | Targets |
|------|---------|---------|
| `cluster_status` | Node status | masters |
| `cluster_overview` | Health check | masters |
| `install_k3s_master` | Install server | masters |
| `install_k3s_worker` | Install agent | workers |
| `backup_cluster` | Create backup | masters |
| `restore_cluster` | Restore backup | masters |
| `deploy_data_stack` | Deploy data apps | masters |
| `setup_monitoring` | Deploy monitoring | masters |

---

## Troubleshooting

### SSH Connection Issues

```powershell
# Test SSH connectivity
.\bolt.ps1 command run "echo 'connected'" --targets all

# Verify inventory
.\bolt.ps1 inventory show
```

### Task Failures

```powershell
# Run with verbose output
.\bolt.ps1 task run pi_cluster_automation::cluster_status \
  --targets masters \
  --verbose
```

### Apt Lock Issues

The `deploy_robust` plan handles apt locks automatically. For manual intervention:

```powershell
.\bolt.ps1 command run "rm -f /var/lib/apt/lists/lock /var/cache/apt/archives/lock" --targets all
```

---

## Related Documentation

- [AUTOMATION.md](./AUTOMATION.md) - Make.ps1 commands that invoke Puppet
- [INDEX.md](./INDEX.md) - Project overview

---

[← Back to Index](./INDEX.md)
