# Production Environment Configuration
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

# Local variables
locals {
  environment  = "prod"
  cluster_name = var.cluster_name
  # Node configuration
  nodes = {
    pi-master = {
      ip         = "192.168.0.120"
      role       = "master"
      components = ["puppet-server", "k3s-server", "vault", "cert-manager"]
      labels = {
        "node-role.kubernetes.io/control-plane" = "true"
        "node-role.kubernetes.io/master"        = "true"
      }
    }
    pi-worker-1 = {
      ip         = "192.168.0.121"
      role       = "worker"
      components = ["k3s-agent", "trino", "monitoring"]
      labels = {
        "pi-cluster/workload" = "compute"
        "pi-cluster/trino"    = "worker"
      }
    }
    pi-worker-2 = {
      ip         = "192.168.0.122"
      role       = "worker"
      components = ["k3s-agent", "postgresql", "nifi"]
      labels = {
        "pi-cluster/workload" = "data"
        "pi-cluster/postgres" = "primary"
      }
    }
    pi-worker-3 = {
      ip         = "192.168.0.123"
      role       = "worker"
      components = ["k3s-agent", "minio", "backup"]
      labels = {
        "pi-cluster/workload" = "storage"
        "pi-cluster/minio"    = "primary"
      }
    }
  }
}

# Kubernetes provider configuration
provider "kubernetes" {
  config_path = var.kubeconfig_path
}

# Helm provider configuration
provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }
}

# Generate Puppet Bolt inventory
module "puppet_infrastructure" {
  source = "../../modules/puppet-infrastructure"

  environment    = local.environment
  cluster_name   = local.cluster_name
  cluster_domain = var.cluster_domain
  nodes          = local.nodes
  ssh_user       = var.ssh_user
  ssh_key_path   = var.ssh_key_path
}

# Deploy K3s cluster
module "k3s_cluster" {
  source = "../../modules/k3s-cluster"

  cluster_name     = local.cluster_name
  environment      = local.environment
  nodes            = local.nodes
  metallb_ip_range = var.metallb_ip_range
  cluster_domain   = var.cluster_domain

  depends_on = [module.puppet_infrastructure]
}

# Deploy data platform
module "data_platform" {
  source = "../../modules/data-platform"

  cluster_name         = local.cluster_name
  environment          = local.environment
  postgres_password    = var.postgres_password
  minio_secret_key     = var.minio_secret_key
  nifi_admin_password  = var.nifi_admin_password
  trino_admin_password = var.trino_admin_password

  depends_on = [module.k3s_cluster]
}

# Deploy monitoring stack
module "monitoring" {
  source = "../../modules/monitoring"

  cluster_name = local.cluster_name
  environment  = local.environment

  components = {
    prometheus = {
      enabled      = true
      retention    = "30d"
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

# Deploy security components
module "security" {
  source = "../../modules/security"

  cluster_name = local.cluster_name
  environment  = local.environment
  vault_token  = var.vault_token

  depends_on = [module.k3s_cluster]
}

# Deploy backup solution
module "backup" {
  source = "../../modules/backup"

  cluster_name            = local.cluster_name
  environment             = local.environment
  backup_schedule         = var.backup_schedule
  backup_retention        = var.backup_retention
  backup_storage_location = "/opt/backups"
  minio_access_key        = "admin"
  minio_secret_key        = var.minio_secret_key

  depends_on = [module.data_platform, module.monitoring]
}
