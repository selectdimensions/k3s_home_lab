terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

# Generate cluster token if not provided
resource "random_password" "k3s_token" {
  count   = var.k3s_token == "" ? 1 : 0
  length  = 64
  special = false
}

locals {
  actual_k3s_token = var.k3s_token != "" ? var.k3s_token : random_password.k3s_token[0].result

  cluster_config = {
    cluster_name = var.cluster_name
    environment  = var.environment
    k3s_version  = var.k3s_version
    k3s_token    = local.actual_k3s_token

    # Network configuration
    cluster_cidr = var.cluster_cidr
    service_cidr = var.service_cidr
    cluster_dns  = var.cluster_dns

    # Node configuration
    master_nodes = [for name, node in var.nodes : merge(node, { name = name }) if node.role == "master"]
    worker_nodes = [for name, node in var.nodes : merge(node, { name = name }) if node.role == "worker"]
  }
}

# Generate K3s configuration files
resource "local_file" "k3s_config" {
  for_each = var.nodes

  content = templatefile("${path.module}/templates/k3s-${each.value.role}.yaml.tpl", {
    cluster_name       = local.cluster_config.cluster_name
    k3s_token          = local.cluster_config.k3s_token
    master_ip          = local.cluster_config.master_nodes[0].ip
    cluster_cidr       = local.cluster_config.cluster_cidr
    service_cidr       = local.cluster_config.service_cidr
    cluster_dns        = local.cluster_config.cluster_dns
    node_name          = each.key
    node_ip            = each.value.ip
    disable_components = join(",", var.disable_components)
  })

  filename        = "${path.root}/.k3s-config/${each.key}-${each.value.role}.yaml"
  file_permission = "0600"
}

# Generate Helm values and namespace configurations for development
# This allows terraform plan to work without requiring a live K8s cluster

# Generate MetalLB Helm values
resource "local_file" "metallb_helm_values" {
  filename = "${path.root}/helm-values/metallb-${var.environment}.yaml"
  content = yamlencode({
    speaker = {
      tolerations = [
        {
          effect   = "NoSchedule"
          key      = "node-role.kubernetes.io/master"
          operator = "Exists"
        }
      ]
    }
  })
}

# Generate namespace configurations
resource "local_file" "namespace_configs" {
  for_each = toset(["data-platform", "monitoring", "ingress", "metallb-system"])
  filename = "${path.root}/k8s-configs/namespace-${each.value}.yaml"
  content = yamlencode({
    apiVersion = "v1"
    kind       = "Namespace"
    metadata = {
      name = each.value
    }
  })
}

# For development: Generate MetalLB configuration files instead of applying directly
# This allows terraform plan to work without requiring a live K8s cluster

# Create directory for k8s configurations
resource "local_file" "k8s_config_dir" {
  filename = "${path.root}/k8s-configs/.gitkeep"
  content  = ""
}

# Generate MetalLB IP Pool configuration
resource "local_file" "metallb_ippool_config" {
  depends_on = [local_file.metallb_helm_values, local_file.k8s_config_dir]
  filename   = "${path.root}/k8s-configs/metallb-ippool.yaml"
  content = yamlencode({
    apiVersion = "metallb.io/v1beta1"
    kind       = "IPAddressPool"
    metadata = {
      name      = "first-pool"
      namespace = "metallb-system"
    }
    spec = {
      addresses = [var.metallb_ip_range]
    }
  })
}

# Generate MetalLB L2Advertisement configuration
resource "local_file" "metallb_l2_config" {
  depends_on = [local_file.metallb_ippool_config]
  filename   = "${path.root}/k8s-configs/metallb-l2.yaml"
  content = yamlencode({
    apiVersion = "metallb.io/v1beta1"
    kind       = "L2Advertisement"
    metadata = {
      name      = "l2-advert"
      namespace = "metallb-system"
    }
    spec = {
      ipAddressPools = ["first-pool"]
    }
  })
}
