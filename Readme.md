*Thinking...*

> The user wants to switch from Ansible to Puppet for configuration management since Puppet is compatible with Windows, Mac, and Ubuntu. I need to restructure the entire project to use Puppet instead of Ansible while maintaining all the professional DevOps practices, CI/CD pipelines, and enhanced features they requested.
> 
> I'll need to:
> 1. Replace all Ansible components with Puppet equivalents
> 2. Maintain the same level of sophistication and features
> 3. Keep the Terraform parts
> 4. Update the CI/CD pipelines to work with Puppet
> 5. Ensure the structure is comprehensive and production-ready
> 6. Include Puppet modules, manifests, Hiera for data management
> 7. Add Puppet testing with rspec-puppet
> 8. Include Puppet Bolt for orchestration tasks

I'll redesign your Pi Cluster project using Puppet for cross-platform compatibility while maintaining professional DevOps practices.

## Enhanced Project Structure with Puppet

```
pi-cluster-automation/
├── .github/
│   ├── workflows/
│   │   ├── terraform-ci.yml
│   │   ├── puppet-ci.yml
│   │   ├── k8s-apps-cd.yml
│   │   └── security-scan.yml
│   └── dependabot.yml
├── terraform/
│   ├── environments/
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   ├── modules/
│   │   ├── puppet-infrastructure/
│   │   ├── k3s-cluster/
│   │   ├── monitoring/
│   │   ├── gitops/
│   │   └── backup/
│   └── backend.tf
├── puppet/
│   ├── bolt-project.yaml
│   ├── Puppetfile
│   ├── hiera.yaml
│   ├── data/
│   │   ├── common.yaml
│   │   ├── nodes/
│   │   └── environments/
│   ├── site-modules/
│   │   ├── profiles/
│   │   ├── roles/
│   │   └── pi_cluster/
│   ├── manifests/
│   │   └── site.pp
│   ├── plans/
│   │   ├── deploy.pp
│   │   └── restore.pp
│   ├── tasks/
│   │   └── health_check.json
│   └── spec/
├── k8s/
│   ├── base/
│   ├── overlays/
│   └── applications/
├── scripts/
│   ├── setup/
│   ├── backup/
│   └── disaster-recovery/
├── tests/
│   ├── terraform/
│   ├── puppet/
│   └── integration/
├── docs/
│   ├── architecture/
│   ├── runbooks/
│   └── puppet-guides/
├── monitoring/
│   ├── dashboards/
│   └── alerts/
├── inventory.yaml
├── Makefile
└── README.md
```

## 1. Enhanced GitHub Actions CI/CD

### .github/workflows/terraform-ci.yml

```yaml
name: Terraform CI/CD

on:
  pull_request:
    paths:
      - 'terraform/**'
      - '.github/workflows/terraform-ci.yml'
  push:
    branches:
      - main
    paths:
      - 'terraform/**'
      - '.github/workflows/terraform-ci.yml'

env:
  TF_VERSION: '1.6.0'
  TFLINT_VERSION: 'v0.48.0'
  TERRAFORM_DOCS_VERSION: 'v0.16.0'

jobs:
  validate:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, staging, prod]
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Terraform Format Check
        run: terraform fmt -check -recursive

      - name: Setup TFLint
        uses: terraform-linters/setup-tflint@v4
        with:
          tflint_version: ${{ env.TFLINT_VERSION }}

      - name: Init TFLint
        run: tflint --init

      - name: Run TFLint
        run: tflint --recursive

      - name: Terraform Init
        working-directory: terraform/environments/${{ matrix.environment }}
        run: terraform init -backend=false

      - name: Terraform Validate
        working-directory: terraform/environments/${{ matrix.environment }}
        run: terraform validate

      - name: Terraform Security Scan
        uses: aquasecurity/tfsec-action@v1.0.3
        with:
          working_directory: terraform/

  plan:
    needs: validate
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    strategy:
      matrix:
        environment: [dev, staging, prod]
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Terraform Init
        working-directory: terraform/environments/${{ matrix.environment }}
        run: terraform init

      - name: Terraform Plan
        id: plan
        working-directory: terraform/environments/${{ matrix.environment }}
        run: |
          terraform plan -out=tfplan -var-file=terraform.tfvars
          terraform show -no-color tfplan > plan.txt

      - name: Comment PR
        uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          script: |
            const fs = require('fs');
            const plan = fs.readFileSync('terraform/environments/${{ matrix.environment }}/plan.txt', 'utf8');
            const output = `#### Terraform Plan - ${{ matrix.environment }} 📖
            <details><summary>Show Plan</summary>
            
            \`\`\`terraform
            ${plan}
            \`\`\`
            
            </details>`;
            
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            });

  deploy:
    needs: validate
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    strategy:
      matrix:
        environment: [dev, staging, prod]
      max-parallel: 1
    environment: ${{ matrix.environment }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Terraform Init
        working-directory: terraform/environments/${{ matrix.environment }}
        run: terraform init

      - name: Terraform Apply
        working-directory: terraform/environments/${{ matrix.environment }}
        run: terraform apply -auto-approve -var-file=terraform.tfvars
        env:
          TF_VAR_postgres_password: ${{ secrets.POSTGRES_PASSWORD }}
          TF_VAR_minio_secret_key: ${{ secrets.MINIO_SECRET_KEY }}
```

### .github/workflows/puppet-ci.yml

```yaml
name: Puppet CI/CD

on:
  pull_request:
    paths:
      - 'puppet/**'
      - '.github/workflows/puppet-ci.yml'
  push:
    branches:
      - main
    paths:
      - 'puppet/**'

env:
  PUPPET_VERSION: '7.26.0'
  PDK_VERSION: '3.0.0'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.1'
          bundler-cache: true

      - name: Install PDK
        run: |
          wget https://puppet.com/download-puppet-development-kit
          sudo dpkg -i puppet-development-kit_${PDK_VERSION}-1focal_amd64.deb

      - name: Validate Puppet manifests
        run: |
          cd puppet
          pdk validate

      - name: Run Puppet lint
        run: |
          cd puppet
          pdk validate puppet

      - name: Check Puppet style
        run: |
          cd puppet
          pdk validate ruby

  test:
    needs: validate
    runs-on: ubuntu-latest
    strategy:
      matrix:
        puppet_version: ['7.26.0', '8.0.0']
        os: ['debian-11', 'ubuntu-22.04']
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.1'

      - name: Install dependencies
        run: |
          cd puppet
          bundle install
          
      - name: Run rspec tests
        run: |
          cd puppet
          bundle exec rake spec
        env:
          PUPPET_VERSION: ${{ matrix.puppet_version }}
          FACTER_os_family: ${{ matrix.os }}

      - name: Run acceptance tests
        run: |
          cd puppet
          bundle exec rake beaker
        if: github.event_name == 'push'

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    strategy:
      matrix:
        environment: [dev, staging, prod]
      max-parallel: 1
    environment: ${{ matrix.environment }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Puppet Bolt
        run: |
          wget -O - https://apt.puppet.com/puppet-tools-release-focal.deb | sudo dpkg -i -
          sudo apt-get update
          sudo apt-get install -y puppet-bolt

      - name: Configure SSH key
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.PI_CLUSTER_SSH_KEY }}" > ~/.ssh/pi_cluster_key
          chmod 600 ~/.ssh/pi_cluster_key

      - name: Run Puppet Bolt deployment
        run: |
          cd puppet
          bolt plan run pi_cluster_automation::deploy \
            --targets @../inventory.yaml \
            --inventoryfile ../inventory.yaml \
            environment=${{ matrix.environment }} \
            --run-as root \
            --no-host-key-check
```

## 3. Enhanced Terraform Configuration

### terraform/backend.tf

```hcl
terraform {
  backend "s3" {
    bucket         = "pi-cluster-terraform-state"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "pi-cluster-terraform-locks"
    
    # Enable versioning for state file history
    versioning = true
  }
}
```

### terraform/modules/monitoring/main.tf

```hcl
resource "helm_release" "prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = "51.0.3"

  values = [
    templatefile("${path.module}/values/prometheus-stack.yaml", {
      grafana_password      = var.grafana_password
      alertmanager_config   = var.alertmanager_config
      retention_days        = var.retention_days
      storage_class         = var.storage_class
    })
  ]

  set {
    name  = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
    value = "false"
  }
}

resource "helm_release" "loki_stack" {
  name             = "loki"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki-stack"
  namespace        = "monitoring"
  version          = "2.9.11"

  values = [
    file("${path.module}/values/loki-stack.yaml")
  ]

  depends_on = [helm_release.prometheus_stack]
}
```

### terraform/modules/gitops/main.tf

```hcl
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "5.46.8"

  values = [
    templatefile("${path.module}/values/argocd.yaml", {
      github_ssh_key = var.github_ssh_key
      ingress_host   = var.argocd_ingress_host
    })
  ]
}

resource "kubernetes_manifest" "argocd_apps" {
  for_each = fileset("${path.module}/applications", "*.yaml")

  manifest = yamldecode(file("${path.module}/applications/${each.value}"))

  depends_on = [helm_release.argocd]
}
```

### terraform/modules/backup/main.tf

```hcl
resource "helm_release" "velero" {
  name             = "velero"
  repository       = "https://vmware-tanzu.github.io/helm-charts"
  chart            = "velero"
  namespace        = "velero"
  create_namespace = true
  version          = "5.0.2"

  values = [
    templatefile("${path.module}/values/velero.yaml", {
      backup_storage_location = var.backup_storage_location
      minio_access_key       = var.minio_access_key
      minio_secret_key       = var.minio_secret_key
    })
  ]
}

# Create backup schedules
resource "kubernetes_manifest" "backup_schedules" {
  for_each = var.backup_schedules

  manifest = {
    apiVersion = "velero.io/v1"
    kind       = "Schedule"
    metadata = {
      name      = each.key
      namespace = "velero"
    }
    spec = {
      schedule = each.value.schedule
      template = {
        ttl = each.value.retention
        includedNamespaces = each.value.namespaces
        storageLocation = var.backup_storage_location
        volumeSnapshotLocations = ["default"]
      }
    }
  }

  depends_on = [helm_release.velero]
}
```

## 3. Kubernetes Manifests with Kustomize

### k8s/base/kustomization.yaml

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - namespace.yaml
  - networkpolicies/
  - rbac/
  - monitoring/

components:
  - ../components/security-hardening
```

### k8s/overlays/prod/kustomization.yaml

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
  - ../../base

patchesStrategicMerge:
  - patches/increase-replicas.yaml
  - patches/resource-limits.yaml

configMapGenerator:
  - name: app-config
    envs:
      - config/prod.env

secretGenerator:
  - name: app-secrets
    envs:
      - secrets/prod.env

images:
  - name: myapp
    newTag: v1.2.3

replicas:
  - name: deployment-app
    count: 3
```

## 4. Enhanced Scripts

### scripts/disaster-recovery/restore-cluster.sh

```bash
#!/bin/bash
# Disaster Recovery Script

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Configuration
BACKUP_NAME="${1:-latest}"
ENVIRONMENT="${2:-prod}"
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/config}"

# Pre-flight checks
preflight_checks() {
    log "Running preflight checks..."
    
    # Check required tools
    for tool in kubectl velero terraform ansible; do
        if ! command -v $tool &> /dev/null; then
            error "$tool is not installed"
            exit 1
        fi
    done
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log "Preflight checks passed"
}

# Restore cluster state
restore_cluster() {
    log "Starting cluster restoration..."
    
    # 1. Restore Terraform state
    log "Restoring Terraform state..."
    cd terraform/environments/$ENVIRONMENT
    terraform init
    terraform refresh
    
    # 2. Ensure nodes are configured
    log "Verifying node configuration..."
    cd ../../../ansible
    ansible-playbook -i inventories/$ENVIRONMENT/hosts.yml playbooks/verify-nodes.yml
    
    # 3. Restore Kubernetes resources via Velero
    log "Restoring Kubernetes resources..."
    if [ "$BACKUP_NAME" == "latest" ]; then
        BACKUP_NAME=$(velero backup get --output json | jq -r '.items | sort_by(.metadata.creationTimestamp) | last | .metadata.name')
    fi
    
    log "Using backup: $BACKUP_NAME"
    velero restore create --from-backup $BACKUP_NAME --wait
    
    # 4. Verify restoration
    log "Verifying restoration..."
    kubectl get nodes
    kubectl get pods -A
    
    # 5. Run post-restore hooks
    log "Running post-restore hooks..."
    ./scripts/post-restore-hooks.sh
    
    log "Restoration complete!"
}

# Main execution
main() {
    log "Pi Cluster Disaster Recovery"
    log "============================"
    
    preflight_checks
    
    warning "This will restore the cluster to backup: $BACKUP_NAME"
    read -p "Continue? (yes/no) " -r
    
    if [[ $REPLY == "yes" ]]; then
        restore_cluster
    else
        log "Restoration cancelled"
        exit 0
    fi
}

main
```

## 5. Monitoring Configuration

### monitoring/dashboards/cluster-overview.json

```json
{
  "dashboard": {
    "title": "Pi Cluster Overview",
    "panels": [
      {
        "title": "Node Status",
        "targets": [
          {
            "expr": "up{job=\"node-exporter\"}"
          }
        ]
      },
      {
        "title": "CPU Usage per Node",
        "targets": [
          {
            "expr": "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)"
          }
        ]
      },
      {
        "title": "Memory Usage per Node",
        "targets": [
          {
            "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100"
          }
        ]
      },
      {
        "title": "Disk Usage",
        "targets": [
          {
            "expr": "(node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes * 100"
          }
        ]
      }
    ]
  }
}
```

### monitoring/alerts/critical-alerts.yaml

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: critical-alerts
  namespace: monitoring
spec:
  groups:
    - name: node.alerts
      interval: 30s
      rules:
        - alert: NodeDown
          expr: up{job="node-exporter"} == 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Node {{ $labels.instance }} is down"
            
        - alert: HighCPUUsage
          expr: 100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 85
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "High CPU usage on {{ $labels.instance }}"
            
        - alert: HighMemoryUsage
          expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "High memory usage on {{ $labels.instance }}"
            
        - alert: DiskSpaceLow
          expr: (node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes * 100 > 85
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "Low disk space on {{ $labels.instance }}"
            
    - name: kubernetes.alerts
      rules:
        - alert: PodCrashLooping
          expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} is crash looping"
```

## 6. Makefile for Easy Operations

```makefile
.PHONY: help init validate plan apply destroy test backup restore

ENVIRONMENT ?= dev
BACKUP_NAME ?= manual-$(shell date +%Y%m%d-%H%M%S)

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

init: ## Initialize the project
	cd terraform/environments/$(ENVIRONMENT) && terraform init
	cd ansible && ansible-galaxy install -r requirements.yml
	helm repo update

validate: ## Validate configurations
	cd terraform/environments/$(ENVIRONMENT) && terraform validate
	cd ansible && ansible-lint
	kubectl --dry-run=client apply -k k8s/overlays/$(ENVIRONMENT)

plan: ## Plan infrastructure changes
	cd terraform/environments/$(ENVIRONMENT) && terraform plan -var-file=terraform.tfvars

apply: ## Apply infrastructure changes
	cd terraform/environments/$(ENVIRONMENT) && terraform apply -var-file=terraform.tfvars -auto-approve

destroy: ## Destroy infrastructure (use with caution!)
	@echo "WARNING: This will destroy all infrastructure in $(ENVIRONMENT)"
	@read -p "Type 'destroy-$(ENVIRONMENT)' to confirm: " confirm && \
	if [ "$$confirm" = "destroy-$(ENVIRONMENT)" ]; then \
		cd terraform/environments/$(ENVIRONMENT) && terraform destroy -var-file=terraform.tfvars -auto-approve; \
	else \
		echo "Destruction cancelled"; \
	fi

test: ## Run all tests
	cd tests/terraform && go test -v ./...
	cd ansible && molecule test
	cd tests/integration && pytest -v

backup: ## Create a manual backup
	velero backup create $(BACKUP_NAME) --wait
	@echo "Backup $(BACKUP_NAME) created successfully"

restore: ## Restore from backup
	./scripts/disaster-recovery/restore-cluster.sh $(BACKUP_NAME) $(ENVIRONMENT)

deploy-app: ## Deploy application via GitOps
	kubectl apply -f k8s/applications/$(APP).yaml

monitor: ## Open monitoring dashboards
	@echo "Opening Grafana..."
	kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

logs: ## Tail logs for a specific app
	kubectl logs -n $(NAMESPACE) -l app=$(APP) -f --tail=100

ssh-node: ## SSH into a node
	ssh -i ~/.ssh/keys/hobby/pi_k3s_cluster $(USER)@$(NODE)
```

## 7. Enhanced Documentation

### docs/runbooks/node-failure-recovery.md

```markdown
# Node Failure Recovery Runbook

## Overview
This runbook describes the process for recovering from a node failure in the Pi cluster.

## Prerequisites
- Access to the cluster
- SSH access to healthy nodes
- Backup of failed node's data (if applicable)

## Detection
Node failure is detected through:
1. Prometheus alerts (NodeDown)
2. `kubectl get nodes` showing NotReady status
3. Physical inspection

## Recovery Steps

### 1. Assess the Situation
```bash
# Check node status
kubectl get nodes

# Check recent events
kubectl get events --sort-by='.lastTimestamp'

# Check node conditions
kubectl describe node <failed-node>
```

### 2. Hardware Recovery

#### Option A: Soft Recovery
```bash
# Try to SSH into the node
ssh pi@<node-ip>

# If accessible, check system logs
sudo journalctl -xe

# Restart K3s service
sudo systemctl restart k3s-agent
```

#### Option B: Hard Recovery
1. Power cycle the Raspberry Pi
2. Wait for boot (2-3 minutes)
3. Verify connectivity: `ping <node-ip>`

### 3. Node Replacement
If hardware failure is confirmed:

```bash
# Cordon the node
kubectl cordon <failed-node>

# Drain workloads
kubectl drain <failed-node> --ignore-daemonsets --delete-emptydir-data

# Remove from cluster
kubectl delete node <failed-node>

# Prepare new SD card
./scripts/prepare-sd-card.sh <node-name> <node-ip>

# Re-run Ansible playbook
cd ansible
ansible-playbook -i inventories/prod/hosts.yml playbooks/install-k3s.yml --limit <node-name>
```

### 4. Verification
```bash
# Verify node joined cluster
kubectl get nodes

# Check pod distribution
kubectl get pods -A -o wide | grep <node-name>

# Run cluster health check
./scripts/health-check.sh
```

## Rollback
If recovery fails:
1. Remove problematic node from load balancer
2. Scale up deployments on remaining nodes
3. Schedule hardware replacement

## Post-Incident
1. Update monitoring alerts if needed
2. Document failure cause
3. Update hardware inventory
4. Schedule preventive maintenance

## Benefits of This Enhanced Structure

1. **CI/CD Pipeline**: Automated testing and deployment with GitHub Actions
2. **GitOps**: ArgoCD for declarative application deployment
3. **Disaster Recovery**: Velero for backup/restore capabilities
4. **Monitoring**: Comprehensive monitoring with Prometheus, Grafana, and Loki
5. **Security**: Security scanning, secrets management, and network policies
6. **Multi-Environment**: Support for dev, staging, and production
7. **Testing**: Automated testing with Molecule, Terratest, and integration tests
8. **Documentation**: Comprehensive runbooks and architecture docs
9. **Resilience**: Automated health checks and recovery procedures
10. **Ease of Use**: Makefile for common operations

This structure provides a production-ready, resilient, and easily maintainable Pi cluster infrastructure.




## 1. Puppet Configuration

### puppet/bolt-project.yaml

```yaml
name: pi_cluster_automation
modules:
  - git: https://github.com/puppetlabs/puppetlabs-stdlib.git
    ref: 8.5.0
  - git: https://github.com/puppetlabs/puppetlabs-docker.git
    ref: 6.0.0
  - git: https://github.com/puppetlabs/puppetlabs-kubernetes.git
    ref: 7.1.0

plans:
  - pi_cluster_automation::deploy
  - pi_cluster_automation::restore
  - pi_cluster_automation::health_check

tasks:
  - pi_cluster_automation::node_info
  - pi_cluster_automation::k3s_status

inventory-config:
  ssh:
    user: hezekiah
    private-key: ~/.ssh/keys/hobby/pi_k3s_cluster
    host-key-check: false
```

### puppet/Puppetfile

```ruby
forge 'https://forge.puppet.com'

# Core modules
mod 'puppetlabs-stdlib', '8.5.0'
mod 'puppetlabs-concat', '7.3.3'
mod 'puppetlabs-firewall', '3.6.0'
mod 'puppetlabs-apt', '9.0.2'
mod 'puppetlabs-vcsrepo', '5.4.0'
mod 'puppetlabs-docker', '6.0.0'
mod 'puppetlabs-kubernetes', '7.1.0'
mod 'puppetlabs-helm', '0.2.0'

# Additional modules for Pi cluster
mod 'puppet-systemd', '3.10.0'
mod 'puppet-archive', '6.1.1'
mod 'puppet-python', '6.3.0'
mod 'camptocamp-kmod', '3.2.0'
mod 'puppet-alternatives', '4.1.0'

# Monitoring modules
mod 'puppet-prometheus', '12.4.0'
mod 'puppet-grafana', '11.1.0'
```

### puppet/hiera.yaml

```yaml
---
version: 5

defaults:
  datadir: data
  data_hash: yaml_data

hierarchy:
  - name: "Per-node data"
    paths:
      - "nodes/%{facts.networking.hostname}.yaml"
      - "nodes/%{facts.networking.fqdn}.yaml"
  
  - name: "Per-environment data"
    paths:
      - "environments/%{environment}/common.yaml"
      - "environments/%{environment}/%{facts.os.family}.yaml"
  
  - name: "Per-OS defaults"
    paths:
      - "os/%{facts.os.family}.yaml"
      - "os/%{facts.os.name}/%{facts.os.release.major}.yaml"
  
  - name: "Common data"
    path: "common.yaml"
```

### puppet/data/common.yaml

```yaml
---
# Common configuration for all nodes
pi_cluster::cluster_name: 'pi-k3s-cluster'
pi_cluster::cluster_domain: 'cluster.local'
pi_cluster::timezone: 'UTC'

# Network configuration
pi_cluster::network::cidr: '192.168.0.0/24'
pi_cluster::network::gateway: '192.168.0.1'
pi_cluster::network::dns_servers:
  - '8.8.8.8'
  - '1.1.1.1'

# K3s configuration
pi_cluster::k3s::version: 'v1.28.4+k3s1'
pi_cluster::k3s::disable_components:
  - 'traefik'
  - 'servicelb'

# MetalLB configuration
pi_cluster::metallb::version: '0.13.12'
pi_cluster::metallb::ip_range: '192.168.0.200-192.168.0.250'

# Storage configuration
pi_cluster::storage::default_class: 'local-path'

# Backup configuration
pi_cluster::backup::schedule: '0 2 * * *'
pi_cluster::backup::retention_days: 30

# Security settings
pi_cluster::security::enable_firewall: true
pi_cluster::security::fail2ban::enabled: true
pi_cluster::security::ssh::permit_root_login: false
```

### puppet/site-modules/roles/manifests/pi_master.pp

```puppet
# Role for Pi Master Node
class roles::pi_master {
  include profiles::base
  include profiles::networking
  include profiles::security
  include profiles::k3s_server
  include profiles::monitoring_server
  include profiles::backup_server
  
  Class['profiles::base']
  -> Class['profiles::networking']
  -> Class['profiles::security']
  -> Class['profiles::k3s_server']
  -> Class['profiles::monitoring_server']
  -> Class['profiles::backup_server']
}
```

### puppet/site-modules/roles/manifests/pi_worker.pp

```puppet
# Role for Pi Worker Node
class roles::pi_worker {
  include profiles::base
  include profiles::networking
  include profiles::security
  include profiles::k3s_agent
  include profiles::monitoring_agent
  
  Class['profiles::base']
  -> Class['profiles::networking']
  -> Class['profiles::security']
  -> Class['profiles::k3s_agent']
  -> Class['profiles::monitoring_agent']
}
```

### puppet/site-modules/profiles/manifests/base.pp

```puppet
# Base profile for all Pi nodes
class profiles::base (
  String $timezone = lookup('pi_cluster::timezone'),
) {
  # Set timezone
  class { 'timezone':
    timezone => $timezone,
  }
  
  # Essential packages
  $base_packages = [
    'curl',
    'wget',
    'git',
    'vim',
    'htop',
    'iotop',
    'ncdu',
    'tmux',
    'python3-pip',
    'jq',
  ]
  
  package { $base_packages:
    ensure => present,
  }
  
  # Configure system limits
  file { '/etc/security/limits.d/pi-cluster.conf':
    ensure  => file,
    content => template('profiles/limits.conf.erb'),
  }
  
  # Enable cgroups for K3s
  augeas { 'enable_cgroups':
    context => '/files/boot/cmdline.txt',
    changes => [
      'set /files/boot/cmdline.txt/1 "$(cat /boot/cmdline.txt) cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1"',
    ],
    onlyif  => 'match /files/boot/cmdline.txt/*[. =~ regexp(".*cgroup_enable=memory.*")] size == 0',
    notify  => Reboot['after_cgroups'],
  }
  
  reboot { 'after_cgroups':
    when => refreshed,
  }
  
  # Disable swap
  exec { 'disable_swap':
    command => '/sbin/dphys-swapfile swapoff && /sbin/dphys-swapfile uninstall',
    onlyif  => '/usr/bin/test -f /var/swap',
  }
  
  service { 'dphys-swapfile':
    ensure => stopped,
    enable => false,
  }
}
```

### puppet/site-modules/profiles/manifests/k3s_server.pp

```puppet
# K3s server profile
class profiles::k3s_server (
  String $version = lookup('pi_cluster::k3s::version'),
  Array[String] $disable_components = lookup('pi_cluster::k3s::disable_components'),
) {
  
  # Install K3s server
  exec { 'install_k3s_server':
    command => @("CMD"/L),
      curl -sfL https://get.k3s.io | \
      INSTALL_K3S_VERSION=${version} \
      sh -s - server \
      --write-kubeconfig-mode 644 \
      --disable ${disable_components.join(' --disable ')} \
      --node-name ${facts['networking']['hostname']}
      | CMD
    path    => ['/usr/bin', '/usr/local/bin'],
    creates => '/usr/local/bin/k3s',
  }
  
  # Ensure K3s service is running
  service { 'k3s':
    ensure  => running,
    enable  => true,
    require => Exec['install_k3s_server'],
  }
  
  # Export node token for workers
  file { '/etc/rancher/k3s/node-token':
    ensure  => file,
    mode    => '0640',
    require => Service['k3s'],
  }
  
  # Configure kubectl for local use
  file { '/root/.kube':
    ensure => directory,
  }
  
  file { '/root/.kube/config':
    ensure  => link,
    target  => '/etc/rancher/k3s/k3s.yaml',
    require => [File['/root/.kube'], Service['k3s']],
  }
}
```

### puppet/plans/deploy.pp

```puppet
# Deployment plan for Pi cluster
plan pi_cluster_automation::deploy (
  TargetSpec $targets,
  String $environment = 'prod',
  Boolean $skip_k3s = false,
) {
  # Gather facts
  $target_facts = run_task('facts', $targets)
  
  # Group targets by role
  $masters = $targets.filter |$target| {
    $target.vars['role'] == 'master'
  }
  
  $workers = $targets.filter |$target| {
    $target.vars['role'] == 'worker'
  }
  
  # Phase 1: Base configuration
  out::message("Phase 1: Configuring base system on all nodes")
  apply($targets, _catch_errors => false) {
    include profiles::base
    include profiles::networking
    include profiles::security
  }
  
  # Phase 2: Install K3s on master
  unless $skip_k3s {
    out::message("Phase 2: Installing K3s on master nodes")
    apply($masters, _catch_errors => false) {
      include profiles::k3s_server
    }
    
    # Get token from master
    $token_result = run_command('cat /var/lib/rancher/k3s/server/node-token', $masters)
    $k3s_token = $token_result.first.stdout.chomp
    $master_ip = $masters.first.vars['ip']
    
    # Phase 3: Install K3s on workers
    out::message("Phase 3: Installing K3s on worker nodes")
    apply($workers, _catch_errors => false) {
      class { 'profiles::k3s_agent':
        server_url => "https://${master_ip}:6443",
        token      => $k3s_token,
      }
    }
  }
  
  # Phase 4: Deploy cluster services
  out::message("Phase 4: Deploying cluster services")
  run_task('pi_cluster_automation::deploy_services', $masters.first, {
    'environment' => $environment,
  })
  
  # Phase 5: Verify deployment
  out::message("Phase 5: Verifying deployment")
  $health_check = run_task('pi_cluster_automation::health_check', $targets)
  
  out::message("Deployment complete!")
  return $health_check
}
```

## 3. Terraform Integration with Puppet

### terraform/modules/puppet-infrastructure/main.tf

```hcl
resource "null_resource" "puppet_server" {
  # Deploy Puppet server on a dedicated node or use Puppet Enterprise
  provisioner "remote-exec" {
    inline = [
      "curl -k https://puppet.com/download-puppet-enterprise | sudo bash",
      "sudo puppet config set server puppet.${var.cluster_domain}",
      "sudo puppet config set certname ${var.puppet_server_hostname}"
    ]
    
    connection {
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.ssh_key_path)
      host        = var.puppet_server_ip
    }
  }
}

# Generate Puppet Bolt inventory from Terraform
resource "local_file" "bolt_inventory" {
  filename = "../inventory.yaml"
  content  = yamlencode({
    version = 2
    groups = [
      {
        name = "masters"
        targets = [
          for name, node in local.nodes : {
            uri  = "${node.ip}"
            name = name
            vars = {
              role = node.role
              ip   = node.ip
            }
          } if node.role == "master"
        ]
      },
      {
        name = "workers"
        targets = [
          for name, node in local.nodes : {
            uri  = "${node.ip}"
            name = name
            vars = {
              role = node.role
              ip   = node.ip
            }
          } if node.role == "worker"
        ]
      }
    ]
    config = {
      ssh = {
        user        = var.ssh_user
        private-key = var.ssh_key_path
        host-key-check = false
      }
    }
  })
}

# Run Puppet Bolt plan
resource "null_resource" "run_puppet_deployment" {
  depends_on = [local_file.bolt_inventory]
  
  triggers = {
    always_run = timestamp()
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      cd ../puppet
      bolt plan run pi_cluster_automation::deploy \
        --inventoryfile ../inventory.yaml \
        environment=${var.environment}
    EOT
  }
}
```

## 4. Cross-Platform Management Scripts

### scripts/setup/install-puppet-agent.ps1

```powershell
# PowerShell script for Windows nodes
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$PuppetServer,
    
    [Parameter(Mandatory=$true)]
    [string]$Environment = "prod",
    
    [string]$PuppetVersion = "7.26.0"
)

# Download and install Puppet agent
$puppetMSI = "puppet-agent-$PuppetVersion-x64.msi"
$downloadUrl = "https://downloads.puppet.com/windows/puppet7/$puppetMSI"

Write-Host "Downloading Puppet Agent..."
Invoke-WebRequest -Uri $downloadUrl -OutFile $puppetMSI

Write-Host "Installing Puppet Agent..."
Start-Process msiexec.exe -ArgumentList "/i $puppetMSI /qn /norestart PUPPET_MASTER_SERVER=$PuppetServer" -Wait

# Configure Puppet
$puppetConf = @"
[main]
server = $PuppetServer
environment = $Environment
runinterval = 30m
"@

Set-Content -Path "C:\ProgramData\PuppetLabs\puppet\etc\puppet.conf" -Value $puppetConf

# Start Puppet service
Start-Service -Name puppet
Set-Service -Name puppet -StartupType Automatic

Write-Host "Puppet Agent installed and configured successfully!"
```

### scripts/setup/install-puppet-agent.sh

```bash
#!/bin/bash
# Cross-platform Puppet agent installation script

set -euo pipefail

PUPPET_SERVER=${1:-puppet.cluster.local}
ENVIRONMENT=${2:-prod}
OS_TYPE=$(uname -s)

install_puppet_debian() {
    wget https://apt.puppet.com/puppet7-release-$(lsb_release -cs).deb
    sudo dpkg -i puppet7-release-$(lsb_release -cs).deb
    sudo apt-get update
    sudo apt-get install -y puppet-agent
}

install_puppet_redhat() {
    sudo rpm -Uvh https://yum.puppet.com/puppet7-release-el-$(rpm -E %{rhel}).noarch.rpm
    sudo yum install -y puppet-agent
}

install_puppet_macos() {
    brew install --cask puppet-agent
}

configure_puppet() {
    sudo /opt/puppetlabs/bin/puppet config set server $PUPPET_SERVER --section main
    sudo /opt/puppetlabs/bin/puppet config set environment $ENVIRONMENT --section main
    sudo /opt/puppetlabs/bin/puppet config set runinterval 30m --section main
}

case "$OS_TYPE" in
    Linux)
        if [ -f /etc/debian_version ]; then
            install_puppet_debian
        elif [ -f /etc/redhat-release ]; then
            install_puppet_redhat
        fi
        ;;
    Darwin)
        install_puppet_macos
        ;;
    *)
        echo "Unsupported OS: $OS_TYPE"
        exit 1
        ;;
esac

configure_puppet

# Enable and start Puppet
sudo /opt/puppetlabs/bin/puppet resource service puppet ensure=running enable=true

echo "Puppet agent installed and configured successfully!"
```

## 5. Enhanced Puppet Testing

### puppet/spec/spec_helper.rb

```ruby
require 'puppetlabs_spec_helper/module_spec_helper'
require 'rspec-puppet-facts'

include RspecPuppetFacts

default_facts = {
  puppetversion: Puppet.version,
  facterversion: Facter.version,
}

default_fact_files = [
  File.expand_path(File.join(File.dirname(__FILE__), 'default_facts.yml')),
  File.expand_path(File.join(File.dirname(__FILE__), 'default_module_facts.yml')),
]

default_fact_files.each do |f|
  next unless File.exist?(f) && File.readable?(f) && File.size?(f)

  begin
    default_facts.merge!(YAML.safe_load(File.read(f), [], [], true))
  rescue => e
    RSpec.configuration.reporter.message "WARNING: Unable to load #{f}: #{e}"
  end
end

RSpec.configure do |c|
  c.default_facts = default_facts
  c.before :each do
    Puppet.settings[:strict] = :error
  end
  c.filter_run_excluding(bolt: true) unless ENV['GEM_BOLT']
  c.after(:suite) do
  end
end
```

### puppet/spec/classes/profiles/k3s_server_spec.rb

```ruby
require 'spec_helper'

describe 'profiles::k3s_server' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:params) do
        {
          version: 'v1.28.4+k3s1',
          disable_components: ['traefik', 'servicelb']
        }
      end

      it { is_expected.to compile }

      it { is_expected.to contain_exec('install_k3s_server')
        .with_command(/INSTALL_K3S_VERSION=v1.28.4\+k3s1/)
        .with_creates('/usr/local/bin/k3s')
      }

      it { is_expected.to contain_service('k3s')
        .with_ensure('running')
        .with_enable(true)
      }

      it { is_expected.to contain_file('/root/.kube/config')
        .with_ensure('link')
        .with_target('/etc/rancher/k3s/k3s.yaml')
      }
    end
  end
end
```

## 6. Enhanced Makefile with Puppet

```makefile
.PHONY: help init validate plan apply destroy test backup restore puppet-deploy

ENVIRONMENT ?= dev
BACKUP_NAME ?= manual-$(shell date +%Y%m%d-%H%M%S)
PUPPET_ENV ?= production

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

init: ## Initialize the project
	cd terraform/environments/$(ENVIRONMENT) && terraform init
	cd puppet && bundle install
	cd puppet && bolt module install
	helm repo update

validate: ## Validate configurations
	cd terraform/environments/$(ENVIRONMENT) && terraform validate
	cd puppet && pdk validate
	cd puppet && bolt plan show
	kubectl --dry-run=client apply -k k8s/overlays/$(ENVIRONMENT)

puppet-deploy: ## Deploy using Puppet Bolt
	cd puppet && bolt plan run pi_cluster_automation::deploy \
		--inventoryfile ../inventory.yaml \
		environment=$(ENVIRONMENT) \
		--run-as root

puppet-test: ## Run Puppet tests
	cd puppet && pdk test unit
	cd puppet && pdk test unit --parallel

puppet-facts: ## Gather facts from all nodes
	bolt task run facts --targets all --inventoryfile inventory.yaml

puppet-apply: ## Apply Puppet configuration to specific nodes
	bolt apply puppet/manifests/site.pp \
		--targets $(TARGETS) \
		--inventoryfile inventory.yaml \
		--hiera-config puppet/hiera.yaml

plan: ## Plan infrastructure changes
	cd terraform/environments/$(ENVIRONMENT) && terraform plan -var-file=terraform.tfvars

apply: ## Apply infrastructure changes and run Puppet
	cd terraform/environments/$(ENVIRONMENT) && terraform apply -var-file=terraform.tfvars -auto-approve
	$(MAKE) puppet-deploy

destroy: ## Destroy infrastructure
	@echo "WARNING: This will destroy all infrastructure in $(ENVIRONMENT)"
	@read -p "Type 'destroy-$(ENVIRONMENT)' to confirm: " confirm && \
	if [ "$$confirm" = "destroy-$(ENVIRONMENT)" ]; then \
		cd terraform/environments/$(ENVIRONMENT) && terraform destroy -var-file=terraform.tfvars -auto-approve; \
	else \
		echo "Destruction cancelled"; \
	fi

test: ## Run all tests
	cd tests/terraform && go test -v ./...
	cd puppet && pdk test unit
	cd tests/integration && pytest -v

backup: ## Create a manual backup
	velero backup create $(BACKUP_NAME) --wait
	bolt task run pi_cluster_automation::backup_configs \
		--targets masters \
		--inventoryfile inventory.yaml

restore: ## Restore from backup
	bolt plan run pi_cluster_automation::restore \
		backup_name=$(BACKUP_NAME) \
		environment=$(ENVIRONMENT) \
		--inventoryfile inventory.yaml

monitor: ## Open monitoring dashboards
	@echo "Opening Grafana..."
	kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

puppet-console: ## Open Puppet console (if using PE)
	@echo "Opening Puppet Console..."
	@echo "https://puppet.$(CLUSTER_DOMAIN)"

node-shell: ## Get shell on a node
	bolt command run 'sudo -i' --targets $(TARGET) --inventoryfile inventory.yaml

cluster-status: ## Check cluster status
	bolt task run pi_cluster_automation::cluster_status \
		--targets masters \
		--inventoryfile inventory.yaml
```

## 7. Cross-Platform Node Configuration

### puppet/site-modules/profiles/manifests/base/windows.pp

```puppet
# Windows-specific base configuration
class profiles::base::windows {
  # Windows Update configuration
  class { 'windows_updates':
    ensure => 'enabled',
    day    => 'Sunday',
    time   => '03:00',
  }
  
  # Essential Windows packages via Chocolatey
  include chocolatey
  
  $windows_packages = [
    'git',
    'vscode',
    'powershell-core',
    'kubernetes-cli',
    'helm',
  ]
  
  package { $windows_packages:
    ensure   => present,
    provider => 'chocolatey',
  }
  
  # Configure Windows Defender exclusions
  windows_defender_exclusion { 'C:\k':
    ensure => present,
    type   => 'folder',
  }
}
```

### puppet/site-modules/profiles/manifests/base/darwin.pp

```puppet
# macOS-specific base configuration
class profiles::base::darwin {
  # Homebrew package management
  include homebrew
  
  $mac_packages = [
    'kubectl',
    'helm',
    'k9s',
    'stern',
    'jq',
    'yq',
  ]
  
  package { $mac_packages:
    ensure   => present,
    provider => 'homebrew',
  }
  
  # Configure macOS firewall
  exec { 'enable_firewall':
    command => '/usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on',
    unless  => '/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate | grep "enabled"',
  }
}
```

## 8. Documentation Updates

### docs/puppet-guides/cross-platform-setup.md

```markdown
# Cross-Platform Setup Guide

## Overview
This guide covers setting up Puppet agents on different operating systems to manage your Pi cluster infrastructure.

## Supported Platforms
- Raspberry Pi OS (ARM)
- Ubuntu/Debian (x86_64)
- Windows Server 2019/2022
- macOS (for development)

## Installation

### Raspberry Pi / Linux
```bash
./scripts/setup/install-puppet-agent.sh puppet.cluster.local prod
```

### Windows
```powershell
.\scripts\setup\install-puppet-agent.ps1 -PuppetServer puppet.cluster.local -Environment prod
```

### macOS
```bash
brew install --cask puppet-agent
./scripts/setup/install-puppet-agent.sh puppet.cluster.local dev
```

## Verification
```bash
# Check Puppet agent status
sudo puppet agent --test

# View last run report
sudo puppet last_run_report print
```

## Bolt Usage

### Running commands across platforms
```bash
# Run on all nodes
bolt command run 'echo "Hello from $(hostname)"' --targets all

# Run on specific OS
bolt command run 'uname -a' --targets linux_nodes
bolt command run 'Get-ComputerInfo' --targets windows_nodes
```

### Applying configurations
```bash
# Apply a specific profile
bolt apply --execute 'include profiles::monitoring_agent' --targets workers
```

## Troubleshooting

### Certificate Issues
```bash
# Clean certificates
sudo puppet ssl clean $(hostname -f)

# Regenerate certificates
sudo puppet agent -t --waitforcert 60
```

### Connectivity Issues
```bash
# Test Puppet server connection
telnet puppet.cluster.local 8140

# Check Puppet configuration
puppet config print --section agent
```
```

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