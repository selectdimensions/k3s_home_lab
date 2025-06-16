# Development Environment Configuration
# Simplified setup for testing and development

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

# Development uses local backend for simplicity
terraform {
  backend "local" {
    path = "./terraform.tfstate"
  }
}

locals {
  environment = "dev"
  cluster_name = "pi-k3s-dev"

  # Development node configuration (minimal for testing)
  nodes = {
    "pi-master" = {
      ip = "192.168.0.120"
      role = "master"
      components = ["puppet-server", "k3s-server", "nifi"]
    }
    "pi-worker-1" = {
      ip = "192.168.0.121"
      role = "worker"
      components = ["k3s-agent", "trino"]
    }
  }

  # Development-specific settings
  resource_limits = {
    cpu_limit = "0.5"
    memory_limit = "1Gi"
  }
}

# Generate development inventory
module "puppet_infrastructure" {
  source = "../../modules/puppet-infrastructure"

  environment   = local.environment
  cluster_name  = local.cluster_name
  nodes        = local.nodes

  # Development-specific Puppet configuration
  puppet_config = {
    environment = "development"
    deploy_services = ["base", "k3s", "minimal-monitoring"]
    debug_mode = true
  }
}

# Simplified K3s cluster for development
module "k3s_cluster" {
  source = "../../modules/k3s-cluster"

  environment    = local.environment
  cluster_name   = local.cluster_name
  nodes         = local.nodes
  resource_limits = local.resource_limits

  # Dev-specific K3s settings
  disable_components = ["traefik"] # We'll use our own ingress
  k3s_version = "v1.28.4+k3s1"

  # Infrastructure settings
  ssh_user = var.node_ssh_user
  ssh_private_key_path = var.node_ssh_private_key_path
}

# Minimal data platform for development testing
module "data_platform" {
  source = "../../modules/data-platform"

  environment = local.environment
  namespace   = "data-platform-dev"
  cluster_name = local.cluster_name

  # Required password variables for dev
  postgres_password = var.grafana_admin_password  # Reuse for dev simplicity
  minio_secret_key = var.grafana_admin_password   # Reuse for dev simplicity
  nifi_admin_password = var.grafana_admin_password # Reuse for dev simplicity
  trino_admin_password = var.grafana_admin_password # Reuse for dev simplicity

  # Minimal components for dev
  components = {
    nifi = {
      enabled = true
      replicas = 1
      resources = {
        requests = { cpu = "200m", memory = "512Mi" }
        limits   = { cpu = "500m", memory = "1Gi" }
      }
    }
    trino = {
      enabled = true
      coordinator_replicas = 1
      worker_replicas = 1
      resources = {
        requests = { cpu = "200m", memory = "512Mi" }
        limits   = { cpu = "500m", memory = "1Gi" }      }
    }
    postgresql = {
      enabled = true
      storage_size = "5Gi"
    }
    minio = {
      enabled = false # Disabled in dev to save resources
    }
  }
}

# Basic monitoring for development
module "monitoring" {
  source = "../../modules/monitoring"

  environment = local.environment
  namespace   = "monitoring-dev"

  # Minimal monitoring stack
  components = {    prometheus = {
      enabled = true
      retention = "7d"
      storage_size = "5Gi"
    }
    grafana = {
      enabled = true
      admin_password = var.grafana_admin_password
    }
    node_exporter = {
      enabled = true
    }
    alertmanager = {
      enabled = false # Disabled in dev
    }
  }
}

# Generate kubeconfig for development
resource "local_file" "kubeconfig" {
  content = module.k3s_cluster.kubeconfig
  filename = "${path.root}/.kube/config-dev"
  file_permission = "0600"
}

# Generate development-specific inventory
resource "local_file" "dev_inventory" {
  content = templatefile("${path.module}/../../templates/inventory.yaml.tpl", {
    environment = local.environment
    nodes       = local.nodes
  })
  filename = "${path.root}/inventory-dev.yaml"
}
