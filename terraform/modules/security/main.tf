# Security Module
# Deploys Vault, cert-manager, OAuth2 Proxy, and Network Policies

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}

# Create security namespace
resource "kubernetes_namespace" "security" {
  metadata {
    name = "security"
    labels = {
      name = "security"
      tier = "security"
    }
  }
}

# Install cert-manager
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = "v1.13.3"

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "global.leaderElection.namespace"
    value = "cert-manager"
  }
}

# Install HashiCorp Vault
resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  namespace  = kubernetes_namespace.security.metadata[0].name
  version    = "0.27.0"

  values = [
    yamlencode({
      server = {
        dev = {
          enabled = true
          devRootToken = var.vault_token
        }
        standalone = {
          enabled = true
          config = <<EOF
ui = true
listener "tcp" {
  tls_disable = 1
  address = "[::]:8200"
  cluster_address = "[::]:8201"
}
storage "file" {
  path = "/vault/data"
}
EOF
        }
        dataStorage = {
          enabled = true
          size = "10Gi"
        }
        nodeSelector = {
          "node-role.kubernetes.io/control-plane" = "true"
        }
        tolerations = [{
          key = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect = "NoSchedule"
        }]
      }
      ui = {
        enabled = true
        serviceType = "LoadBalancer"
        serviceNodePort = null
        externalPort = 8200
      }
      injector = {
        enabled = true
      }
    })
  ]

  depends_on = [kubernetes_namespace.security]
}

# OAuth2 Proxy for dashboard authentication
resource "kubernetes_deployment" "oauth2_proxy" {
  metadata {
    name      = "oauth2-proxy"
    namespace = kubernetes_namespace.security.metadata[0].name
    labels = {
      app = "oauth2-proxy"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "oauth2-proxy"
      }
    }

    template {
      metadata {
        labels = {
          app = "oauth2-proxy"
        }
      }

      spec {
        container {
          name  = "oauth2-proxy"
          image = "quay.io/oauth2-proxy/oauth2-proxy:v7.5.1"

          args = [
            "--provider=oidc",
            "--email-domain=*",
            "--upstream=file:///dev/null",
            "--http-address=0.0.0.0:4180",
            "--cookie-secure=false",
            "--cookie-secret=supersecret",
            "--client-id=oauth2-proxy",
            "--client-secret=supersecret",
            "--oidc-issuer-url=http://vault.security.svc.cluster.local:8200/v1/identity/oidc"
          ]

          port {
            container_port = 4180
          }

          resources {
            requests = {
              memory = "64Mi"
              cpu    = "50m"
            }
            limits = {
              memory = "128Mi"
              cpu    = "100m"
            }
          }
        }

        node_selector = {
          "node-role.kubernetes.io/control-plane" = "true"
        }

        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.security]
}

# OAuth2 Proxy Service
resource "kubernetes_service" "oauth2_proxy" {
  metadata {
    name      = "oauth2-proxy"
    namespace = kubernetes_namespace.security.metadata[0].name
  }

  spec {
    selector = {
      app = "oauth2-proxy"
    }

    port {
      port        = 80
      target_port = 4180
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_deployment.oauth2_proxy]
}

# Network Policies for microsegmentation

# Default deny all ingress policy
resource "kubernetes_network_policy" "default_deny_all" {
  metadata {
    name      = "default-deny-all"
    namespace = "default"
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
  }
}

# Allow DNS resolution
resource "kubernetes_network_policy" "allow_dns" {
  metadata {
    name      = "allow-dns"
    namespace = "default"
  }

  spec {
    pod_selector {}
    
    policy_types = ["Egress"]
    
    egress {
      to {
        namespace_selector {
          match_labels = {
            name = "kube-system"
          }
        }
      }
      
      ports {
        protocol = "UDP"
        port     = "53"
      }
    }
  }
}

# Data platform internal communication
resource "kubernetes_network_policy" "data_platform_internal" {
  metadata {
    name      = "data-platform-internal"
    namespace = "data-platform"
  }

  spec {
    pod_selector {}
    
    policy_types = ["Ingress", "Egress"]
    
    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = "data-platform"
          }
        }
      }
    }
    
    egress {
      to {
        namespace_selector {
          match_labels = {
            name = "data-platform"
          }
        }
      }
    }
    
    # Allow egress to security namespace for Vault
    egress {
      to {
        namespace_selector {
          match_labels = {
            name = "security"
          }
        }
      }
    }
    
    # Allow DNS
    egress {
      to {
        namespace_selector {
          match_labels = {
            name = "kube-system"
          }
        }
      }
      
      ports {
        protocol = "UDP"
        port     = "53"
      }
    }
  }
}

# Monitoring access to all namespaces
resource "kubernetes_network_policy" "monitoring_access" {
  metadata {
    name      = "monitoring-access"
    namespace = "monitoring"
  }

  spec {
    pod_selector {}
    
    policy_types = ["Egress"]
    
    # Allow monitoring to scrape all namespaces
    egress {
      to {}
    }
  }
}

# Allow external LoadBalancer access to services
resource "kubernetes_network_policy" "allow_loadbalancer" {
  metadata {
    name      = "allow-loadbalancer"
    namespace = "data-platform"
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/component" = "server"
      }
    }
    
    policy_types = ["Ingress"]
    
    ingress {
      from {}
      
      ports {
        protocol = "TCP"
        port     = "8443"  # NiFi
      }
      
      ports {
        protocol = "TCP"
        port     = "8080"  # Trino
      }
      
      ports {
        protocol = "TCP"
        port     = "9000"  # MinIO API
      }
      
      ports {
        protocol = "TCP"
        port     = "9001"  # MinIO Console
      }
      
      ports {
        protocol = "TCP"
        port     = "8888"  # JupyterLab
      }
    }
  }
}
