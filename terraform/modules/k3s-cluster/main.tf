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
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

# Install MetalLB
resource "helm_release" "metallb" {
  name             = "metallb"
  repository       = "https://metallb.github.io/metallb"
  chart            = "metallb"
  namespace        = "metallb-system"
  create_namespace = true
  
  wait = true
  
  values = [<<EOF
speaker:
  tolerations:
  - effect: NoSchedule
    key: node-role.kubernetes.io/master
    operator: Exists
EOF
  ]
}

# Configure MetalLB
resource "kubernetes_manifest" "metallb_ippool" {
  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "IPAddressPool"
    metadata = {
      name      = "first-pool"
      namespace = "metallb-system"
    }
    spec = {
      addresses = [var.metallb_ip_range]
    }
  }
  
  depends_on = [helm_release.metallb]
}

resource "kubernetes_manifest" "metallb_l2" {
  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "L2Advertisement"
    metadata = {
      name      = "l2-advert"
      namespace = "metallb-system"
    }
  }
  
  depends_on = [kubernetes_manifest.metallb_ippool]
}

# Create namespaces
resource "kubernetes_namespace" "namespaces" {
  for_each = toset(["data-platform", "monitoring", "ingress"])
  
  metadata {
    name = each.value
  }
}