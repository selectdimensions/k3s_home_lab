# Staging Environment Configuration
# Production-like setup for testing deployments before prod

terraform {
  required_version = ">= 1.5"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# Staging can use remote backend or local for testing
terraform {
  backend "local" {
    path = "./terraform-staging.tfstate"
  }
}

locals {
  environment  = "staging"
  cluster_name = "pi-k3s-staging"

  # Staging uses 3 nodes (subset of prod for testing)
  nodes = {
    "pi-master" = {
      ip         = "192.168.0.120"
      role       = "master"
      components = ["puppet-server", "k3s-server", "nifi", "vault"]
    }
    "pi-worker-1" = {
      ip         = "192.168.0.121"
      role       = "worker"
      components = ["k3s-agent", "trino"]
    }
    "pi-worker-2" = {
      ip         = "192.168.0.122"
      role       = "worker"
      components = ["k3s-agent", "postgresql", "monitoring"]
    }
  }

  # Staging resource settings - between dev and prod
  resource_limits = {
    cpu_limit    = "2"
    memory_limit = "4Gi"
  }
}

# Generate random passwords for staging
resource "random_password" "postgres_password" {
  length  = 32
  special = true
}

resource "random_password" "vault_token" {
  length  = 32
  special = false
}

resource "random_password" "nifi_admin_password" {
  length  = 16
  special = true
}

# Puppet infrastructure for staging
module "puppet_infrastructure" {
  source = "../../modules/puppet-infrastructure"

  environment  = local.environment
  cluster_name = local.cluster_name
  nodes        = local.nodes

  puppet_config = {
    environment     = "staging"
    deploy_services = ["base", "security", "k3s", "monitoring", "data-platform"]
    debug_mode      = false
  }
}

# K3s cluster for staging
module "k3s_cluster" {
  source = "../../modules/k3s-cluster"

  environment        = local.environment
  cluster_name       = local.cluster_name
  nodes              = local.nodes
  resource_limits    = local.resource_limits
  disable_components = ["traefik"]

  depends_on = [module.puppet_infrastructure]
}

# Full data platform for staging testing
module "data_platform" {
  source = "../../modules/data-platform"

  cluster_name         = local.cluster_name
  environment          = local.environment
  namespace            = "data-platform"
  postgres_password    = random_password.postgres_password.result
  minio_secret_key     = random_password.vault_token.result
  nifi_admin_password  = random_password.nifi_admin_password.result
  trino_admin_password = random_password.nifi_admin_password.result # Reuse for staging

  depends_on = [module.k3s_cluster]
}

# Full monitoring stack for staging
module "monitoring" {
  source = "../../modules/monitoring"

  environment = local.environment
  namespace   = "monitoring"

  components = {
    prometheus = {
      enabled      = true
      retention    = "15d"
      storage_size = "20Gi"
    }
    grafana = {
      enabled        = true
      admin_password = var.grafana_admin_password
    }
    node_exporter = {
      enabled = true
    }
    alertmanager = {
      enabled = true
    }
  }

  depends_on = [module.k3s_cluster]
}

# Security module for staging
module "security" {
  source = "../../modules/security"

  environment = local.environment
  vault_token = random_password.vault_token.result

  depends_on = [module.k3s_cluster]
}

# Backup configuration for staging
module "backup" {
  source = "../../modules/backup"

  cluster_name            = local.cluster_name
  environment             = local.environment
  backup_schedule         = "0 2 * * *" # Daily at 2 AM
  backup_retention        = 7
  backup_storage_location = var.backup_storage_location
  minio_secret_key        = random_password.postgres_password.result # Reuse password for staging

  depends_on = [module.data_platform]
}

# Note: Kubeconfig is generated during actual K3s deployment, not Terraform
# This resource creates a placeholder that will be updated by Puppet/Bolt deployment
resource "local_file" "kubeconfig_placeholder" {
  content = yamlencode({
    apiVersion = "v1"
    kind       = "Config"
    clusters = [{
      name = "pi-k3s-${local.environment}"
      cluster = {
        server                     = "https://192.168.0.120:6443"
        "insecure-skip-tls-verify" = true
      }
    }]
    contexts = [{
      name = "pi-k3s-${local.environment}"
      context = {
        cluster = "pi-k3s-${local.environment}"
        user    = "admin"
      }
    }]
    "current-context" = "pi-k3s-${local.environment}"
    users = [{
      name = "admin"
      user = {
        token = "placeholder-update-after-deployment"
      }
    }]
  })
  filename        = "${path.root}/.kube/config-staging"
  file_permission = "0600"
}

# Generate staging inventory
resource "local_file" "staging_inventory" {
  content = templatefile("${path.module}/../../templates/inventory.yaml.tpl", {
    environment = local.environment
    nodes       = local.nodes
  })
  filename = "${path.root}/inventory-staging.yaml"
}

# Store secrets in local file (simplified - no template dependency)
resource "local_sensitive_file" "staging_secrets" {
  content = yamlencode({
    postgres_password   = random_password.postgres_password.result
    vault_token         = random_password.vault_token.result
    nifi_admin_password = random_password.nifi_admin_password.result
  })
  filename        = "${path.root}/.secrets/staging-secrets.yaml"
  file_permission = "0600"
}
