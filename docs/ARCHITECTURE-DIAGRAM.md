# Architecture Diagrams

> **Mermaid diagrams showing system architecture, data flows, and automation pipelines**

[← Back to Index](./INDEX.md)

---

## Table of Contents

- [System Overview](#system-overview)
- [Infrastructure Layers](#infrastructure-layers)
- [Deployment Pipeline](#deployment-pipeline)
- [Data Flow Architecture](#data-flow-architecture)
- [Network Topology](#network-topology)
- [Automation Flow](#automation-flow)
- [Script Relationships](#script-relationships)

---

## System Overview

### High-Level Architecture

```mermaid
graph TB
    subgraph "User Interface"
        CLI["Make.ps1<br/>Command Line"]
        VSCODE["VS Code Tasks<br/>.vscode/tasks.json"]
    end

    subgraph "Automation Layer"
        MAKE["Make.ps1<br/>Central Dispatcher"]
        BOLT["bolt.ps1<br/>Docker Wrapper"]
        VALIDATE["validate-infrastructure.ps1"]
    end

    subgraph "Configuration Management"
        PUPPET["Puppet Bolt<br/>(Docker Container)"]
        PLANS["Plans<br/>deploy_robust.pp"]
        TASKS["Tasks<br/>install_k3s_*.sh"]
    end

    subgraph "Infrastructure as Code"
        TF["Terraform"]
        TFMOD["Modules<br/>k3s-cluster, data-platform"]
        TFOUT["Generated Config<br/>helm-values/*.yaml"]
    end

    subgraph "K3s Cluster"
        MASTER["pi-master<br/>192.168.0.120"]
        W1["pi-worker-1<br/>192.168.0.121"]
        W2["pi-worker-2<br/>192.168.0.122"]
        W3["pi-worker-3<br/>192.168.0.123"]
    end

    subgraph "Workloads"
        NIFI["Apache NiFi"]
        TRINO["Trino"]
        MINIO["MinIO"]
        PG["PostgreSQL"]
        PROM["Prometheus"]
        GRAF["Grafana"]
    end

    CLI --> MAKE
    VSCODE --> MAKE
    MAKE --> BOLT
    MAKE --> TF
    MAKE --> VALIDATE

    BOLT --> PUPPET
    PUPPET --> PLANS
    PUPPET --> TASKS

    TF --> TFMOD
    TFMOD --> TFOUT

    PLANS --> MASTER
    PLANS --> W1
    PLANS --> W2
    PLANS --> W3

    MASTER --> NIFI
    MASTER --> TRINO
    MASTER --> MINIO
    MASTER --> PG
    MASTER --> PROM
    MASTER --> GRAF

    style MAKE fill:#4CAF50,color:#fff
    style PUPPET fill:#FFAB00,color:#000
    style TF fill:#7B42BC,color:#fff
    style MASTER fill:#326CE5,color:#fff
```

---

## Infrastructure Layers

### Layer Stack

```mermaid
graph TB
    subgraph "Layer 6: Applications"
        L6["Data Stack<br/>NiFi, Trino, MinIO, PostgreSQL<br/>Monitoring: Prometheus, Grafana"]
    end

    subgraph "Layer 5: Kubernetes"
        L5["K3s v1.32.5+k3s1<br/>Namespaces: data-engineering, monitoring<br/>Services, Deployments, ConfigMaps"]
    end

    subgraph "Layer 4: Container Runtime"
        L4["containerd<br/>Container Images"]
    end

    subgraph "Layer 3: Operating System"
        L3["Raspberry Pi OS (Debian)<br/>systemd, cgroups"]
    end

    subgraph "Layer 2: Hardware"
        L2["Raspberry Pi 4<br/>4GB/8GB RAM<br/>SD Card Storage"]
    end

    subgraph "Layer 1: Network"
        L1["192.168.0.0/24<br/>Ethernet/WiFi"]
    end

    L6 --> L5
    L5 --> L4
    L4 --> L3
    L3 --> L2
    L2 --> L1

    style L6 fill:#FF5722,color:#fff
    style L5 fill:#326CE5,color:#fff
    style L4 fill:#2196F3,color:#fff
    style L3 fill:#4CAF50,color:#fff
    style L2 fill:#9C27B0,color:#fff
    style L1 fill:#607D8B,color:#fff
```

---

## Deployment Pipeline

### CI/CD Flow

```mermaid
flowchart LR
    subgraph "Development"
        CODE["Code Changes"]
        GIT["Git Commit"]
    end

    subgraph "Validation"
        VAL[".\Make.ps1 validate"]
        PUPPET_VAL["Puppet Syntax"]
        TF_VAL["Terraform Validate"]
        K8S_VAL["K8s YAML Check"]
    end

    subgraph "Planning"
        TF_PLAN["terraform plan"]
        REVIEW["Review Changes"]
    end

    subgraph "Deployment"
        TF_APPLY["terraform apply"]
        PUPPET_DEPLOY["puppet-deploy"]
        K8S_APPLY["kubectl apply"]
    end

    subgraph "Verification"
        STATUS["cluster-status"]
        HEALTH["Health Checks"]
    end

    CODE --> GIT
    GIT --> VAL
    VAL --> PUPPET_VAL
    VAL --> TF_VAL
    VAL --> K8S_VAL

    PUPPET_VAL --> TF_PLAN
    TF_VAL --> TF_PLAN
    K8S_VAL --> TF_PLAN

    TF_PLAN --> REVIEW
    REVIEW --> TF_APPLY
    TF_APPLY --> PUPPET_DEPLOY
    PUPPET_DEPLOY --> K8S_APPLY
    K8S_APPLY --> STATUS
    STATUS --> HEALTH
```

### Quick Deploy Flow

```mermaid
sequenceDiagram
    participant User
    participant Make as Make.ps1
    participant TF as Terraform
    participant Bolt as Puppet Bolt
    participant Master as pi-master
    participant Workers as Workers

    User->>Make: .\Make.ps1 quick-deploy
    Make->>TF: terraform init
    TF-->>Make: Initialized
    Make->>TF: terraform plan
    TF-->>Make: Plan created
    Make->>TF: terraform apply
    TF-->>Make: Config files generated

    Make->>Bolt: plan run deploy_robust
    Bolt->>Master: Phase 1: Base config
    Master-->>Bolt: Configured
    Bolt->>Workers: Phase 1: Base config
    Workers-->>Bolt: Configured

    Bolt->>Master: Phase 2: Install K3s server
    Master-->>Bolt: K3s running
    Master->>Master: Get join token

    Bolt->>Workers: Phase 3: Install K3s agent
    Workers->>Master: Join cluster
    Master-->>Bolt: Workers joined

    Bolt-->>Make: Deployment complete
    Make->>Master: kubectl get nodes
    Master-->>Make: All nodes Ready
    Make-->>User: Cluster ready!
```

---

## Data Flow Architecture

### Data Platform

```mermaid
flowchart TB
    subgraph "Data Sources"
        EXT["External APIs"]
        FILES["File Systems"]
        DB["Databases"]
    end

    subgraph "Data Ingestion"
        NIFI["Apache NiFi<br/>:8080"]
    end

    subgraph "Data Storage"
        MINIO["MinIO S3<br/>:9000/:9001"]
        PG["PostgreSQL<br/>:5432"]
    end

    subgraph "Data Processing"
        TRINO["Trino SQL<br/>:8080"]
    end

    subgraph "Visualization"
        GRAF["Grafana<br/>:3000"]
    end

    EXT --> NIFI
    FILES --> NIFI
    DB --> NIFI

    NIFI --> MINIO
    NIFI --> PG

    MINIO --> TRINO
    PG --> TRINO

    TRINO --> GRAF

    style NIFI fill:#728E9B,color:#fff
    style MINIO fill:#C72C48,color:#fff
    style PG fill:#336791,color:#fff
    style TRINO fill:#DD00A1,color:#fff
    style GRAF fill:#F46800,color:#fff
```

### Monitoring Flow

```mermaid
flowchart LR
    subgraph "Targets"
        NODES["K3s Nodes"]
        PODS["Pods"]
        SVCS["Services"]
    end

    subgraph "Collection"
        PROM["Prometheus<br/>:9090"]
    end

    subgraph "Storage"
        TSDB["Time Series DB"]
    end

    subgraph "Visualization"
        GRAF["Grafana<br/>:3000"]
    end

    subgraph "Alerting"
        AM["AlertManager<br/>:9093"]
        EMAIL["Email/Slack"]
    end

    NODES --> PROM
    PODS --> PROM
    SVCS --> PROM

    PROM --> TSDB
    PROM --> AM

    TSDB --> GRAF
    AM --> EMAIL

    style PROM fill:#E6522C,color:#fff
    style GRAF fill:#F46800,color:#fff
```

---

## Network Topology

### Cluster Network

```mermaid
graph TB
    subgraph "Home Network 192.168.0.0/24"
        ROUTER["Router<br/>192.168.0.1"]

        subgraph "K3s Cluster"
            MASTER["pi-master<br/>192.168.0.120<br/>Control Plane"]
            W1["pi-worker-1<br/>192.168.0.121"]
            W2["pi-worker-2<br/>192.168.0.122"]
            W3["pi-worker-3<br/>192.168.0.123"]
        end

        subgraph "MetalLB Pool"
            LB["LoadBalancer IPs<br/>192.168.0.200-250"]
        end

        WORKSTATION["Windows Workstation<br/>192.168.0.x"]
    end

    subgraph "Kubernetes Networks"
        POD_NET["Pod CIDR<br/>10.42.0.0/16"]
        SVC_NET["Service CIDR<br/>10.43.0.0/16"]
        DNS["Cluster DNS<br/>10.43.0.10"]
    end

    ROUTER --> MASTER
    ROUTER --> W1
    ROUTER --> W2
    ROUTER --> W3
    ROUTER --> WORKSTATION

    MASTER --> LB
    MASTER --> POD_NET
    MASTER --> SVC_NET
    POD_NET --> DNS
```

### Port Mappings

```mermaid
graph LR
    subgraph "External Access"
        U["User"]
    end

    subgraph "Port Forwards"
        PF1["localhost:8080"]
        PF2["localhost:3000"]
        PF3["localhost:9001"]
    end

    subgraph "K3s Services"
        NIFI["NiFi<br/>ClusterIP:8080"]
        GRAF["Grafana<br/>ClusterIP:3000"]
        MINIO["MinIO Console<br/>ClusterIP:9001"]
    end

    U --> PF1
    U --> PF2
    U --> PF3

    PF1 -.->|kubectl port-forward| NIFI
    PF2 -.->|kubectl port-forward| GRAF
    PF3 -.->|kubectl port-forward| MINIO
```

---

## Automation Flow

### Make.ps1 Command Dispatch

```mermaid
flowchart TB
    CMD[".\Make.ps1 -Command <cmd>"]

    CMD --> SWITCH{Command?}

    SWITCH -->|help| HELP["Show-Help"]
    SWITCH -->|init| INIT["Initialize-Project"]
    SWITCH -->|validate| VAL["Test-Configurations"]
    SWITCH -->|cluster-status| STATUS["Get-ClusterStatus"]

    SWITCH -->|terraform-*| TF_SWITCH{Terraform}
    TF_SWITCH -->|init| TF_INIT["Invoke-TerraformInit"]
    TF_SWITCH -->|plan| TF_PLAN["Invoke-TerraformPlan"]
    TF_SWITCH -->|apply| TF_APPLY["Invoke-TerraformApply"]

    SWITCH -->|puppet-*| PUPPET_SWITCH{Puppet}
    PUPPET_SWITCH -->|deploy| P_DEPLOY["Invoke-PuppetDeploy"]
    PUPPET_SWITCH -->|plan| P_PLAN["Invoke-PuppetPlan"]
    PUPPET_SWITCH -->|task| P_TASK["Invoke-PuppetTask"]

    SWITCH -->|backup| BACKUP["Invoke-Backup"]
    SWITCH -->|restore| RESTORE["Invoke-Restore"]

    SWITCH -->|nifi-ui| NIFI["Start-PortForward nifi"]
    SWITCH -->|grafana-ui| GRAF["Start-PortForward grafana"]

    SWITCH -->|quick-deploy| QD["Invoke-QuickDeploy"]
    QD --> TF_INIT
    QD --> TF_PLAN
    QD --> TF_APPLY
    QD --> P_DEPLOY
    QD --> STATUS
```

### Puppet Bolt Execution

```mermaid
flowchart TB
    subgraph "Windows Host"
        BOLT_PS["bolt.ps1"]
        DOCKER["Docker Desktop"]
    end

    subgraph "Docker Container"
        PUPPET_BOLT["puppet-bolt:latest"]
        WORKSPACE["/workspace"]
        SSH_KEYS["/root/.ssh"]
    end

    subgraph "Puppet Project"
        PROJECT["bolt-project.yaml"]
        INVENTORY["inventory.yaml"]
        PLANS["plans/*.pp"]
        TASKS["tasks/*.sh"]
    end

    subgraph "Target Nodes"
        NODES["pi-master<br/>pi-worker-1/2/3"]
    end

    BOLT_PS -->|docker run| DOCKER
    DOCKER --> PUPPET_BOLT
    PUPPET_BOLT --> WORKSPACE
    PUPPET_BOLT --> SSH_KEYS

    WORKSPACE --> PROJECT
    WORKSPACE --> INVENTORY
    WORKSPACE --> PLANS
    WORKSPACE --> TASKS

    PUPPET_BOLT -->|SSH| NODES
```

---

## Script Relationships

### Script Dependency Graph

```mermaid
graph TB
    subgraph "Entry Points"
        MAKE["Make.ps1"]
        BOLT_W["bolt.ps1"]
    end

    subgraph "Validation"
        VAL_INFRA["validate-infrastructure.ps1"]
        DEPLOY_READY["deployment-readiness.ps1"]
    end

    subgraph "Fixes"
        FIX_WORKER["fix-worker-nodes.ps1"]
        FIX_APT["fix-apt-locks.ps1"]
        CLUSTER_FIX["cluster-fix.ps1"]
    end

    subgraph "Setup"
        BOOTSTRAP["bootstrap.sh"]
        SETUP["setup-from-scratch.sh"]
    end

    subgraph "Puppet Plans"
        DEPLOY_ROBUST["deploy_robust.pp"]
        K3S_DEPLOY["k3s_deploy.pp"]
    end

    subgraph "Puppet Tasks"
        INSTALL_MASTER["install_k3s_master.sh"]
        INSTALL_WORKER["install_k3s_worker.sh"]
        CLUSTER_STATUS["cluster_status.sh"]
    end

    MAKE --> VAL_INFRA
    MAKE --> BOLT_W
    MAKE --> FIX_WORKER

    BOLT_W --> DEPLOY_ROBUST
    BOLT_W --> K3S_DEPLOY

    DEPLOY_ROBUST --> INSTALL_MASTER
    DEPLOY_ROBUST --> INSTALL_WORKER
    K3S_DEPLOY --> INSTALL_MASTER
    K3S_DEPLOY --> INSTALL_WORKER

    FIX_WORKER --> FIX_APT
    CLUSTER_FIX --> FIX_APT

    SETUP --> BOOTSTRAP
    SETUP --> INSTALL_MASTER
    SETUP --> INSTALL_WORKER
```

---

## Terraform Module Structure

```mermaid
graph TB
    subgraph "Root Module"
        ROOT["terraform/main.tf"]
    end

    subgraph "Environment"
        DEV["environments/dev"]
        STAGING["environments/staging"]
        PROD["environments/prod"]
    end

    subgraph "Modules"
        K3S["k3s-cluster"]
        DATA["data-platform"]
        MON["monitoring"]
        BACKUP["backup"]
        SEC["security"]
        GIT["gitops"]
        PUPPET["puppet-infrastructure"]
    end

    subgraph "Outputs"
        K3S_CFG["K3s Config Files"]
        HELM["Helm Values"]
        K8S["K8s Manifests"]
    end

    ROOT --> DEV
    ROOT --> STAGING
    ROOT --> PROD

    DEV --> K3S
    DEV --> DATA
    DEV --> MON
    DEV --> BACKUP
    DEV --> SEC
    DEV --> GIT
    DEV --> PUPPET

    K3S --> K3S_CFG
    DATA --> HELM
    MON --> HELM
    SEC --> K8S
```

---

## Quick Reference Diagram

### Complete System Map

```mermaid
graph TB
    subgraph "🖥️ Windows Workstation"
        USER["Developer"]
        MAKE["Make.ps1"]
        DOCKER["Docker Desktop"]
    end

    subgraph "🐳 Docker"
        BOLT_IMG["puppet-bolt:latest"]
    end

    subgraph "📁 Project Structure"
        PUPPET_DIR["puppet/"]
        TF_DIR["terraform/"]
        K8S_DIR["k8s/"]
        SCRIPTS["scripts/"]
    end

    subgraph "☸️ K3s Cluster"
        MASTER["pi-master<br/>Control Plane<br/>192.168.0.120"]

        subgraph "Workers"
            W1["pi-worker-1<br/>192.168.0.121"]
            W2["pi-worker-2<br/>192.168.0.122"]
            W3["pi-worker-3<br/>192.168.0.123"]
        end
    end

    subgraph "📊 Data Stack"
        NIFI["NiFi :8080"]
        TRINO["Trino :8080"]
        MINIO["MinIO :9000"]
        PG["PostgreSQL :5432"]
    end

    subgraph "📈 Monitoring"
        PROM["Prometheus :9090"]
        GRAF["Grafana :3000"]
    end

    USER -->|commands| MAKE
    MAKE -->|bolt.ps1| DOCKER
    DOCKER --> BOLT_IMG
    BOLT_IMG -->|SSH| MASTER
    BOLT_IMG -->|SSH| W1
    BOLT_IMG -->|SSH| W2
    BOLT_IMG -->|SSH| W3

    MAKE --> TF_DIR
    TF_DIR -->|generates| K8S_DIR

    MASTER --> NIFI
    MASTER --> TRINO
    MASTER --> MINIO
    MASTER --> PG
    MASTER --> PROM
    MASTER --> GRAF

    W1 --> MASTER
    W2 --> MASTER
    W3 --> MASTER

    style USER fill:#4CAF50,color:#fff
    style MAKE fill:#2196F3,color:#fff
    style MASTER fill:#326CE5,color:#fff
    style NIFI fill:#728E9B,color:#fff
    style GRAF fill:#F46800,color:#fff
```

---

## Legend

| Symbol | Meaning |
|--------|---------|
| 🖥️ | Workstation/Host |
| 🐳 | Docker |
| 📁 | Directory |
| ☸️ | Kubernetes |
| 📊 | Data |
| 📈 | Monitoring |

| Color | Component |
|-------|-----------|
| Green | Entry Point |
| Blue | Kubernetes |
| Orange | Puppet |
| Purple | Terraform |
| Red | Data Stack |

---

## Related Documentation

- [INDEX.md](./INDEX.md) - Documentation hub
- [AUTOMATION.md](./AUTOMATION.md) - Make.ps1 details
- [PUPPET.md](./PUPPET.md) - Puppet architecture
- [TERRAFORM.md](./TERRAFORM.md) - Terraform modules
- [KUBERNETES.md](./KUBERNETES.md) - K8s resources

---

[← Back to Index](./INDEX.md)
