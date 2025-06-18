# Security Module Variables

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "cluster_name" {
  description = "Name of the K3s cluster"
  type        = string
  default     = "pi-k3s-cluster"
}

variable "namespace" {
  description = "Kubernetes namespace for security components"
  type        = string
  default     = "security"
}

variable "vault_token" {
  description = "HashiCorp Vault root token"
  type        = string
  sensitive   = true
}

variable "vault_config" {
  description = "Vault configuration"
  type = object({
    enabled         = bool
    dev_mode        = bool
    storage_size    = string
    auto_unseal     = bool
    storage_backend = string
  })
  default = {
    enabled         = true
    dev_mode        = true
    storage_size    = "10Gi"
    auto_unseal     = false
    storage_backend = "file"
  }
}

variable "cert_manager_config" {
  description = "cert-manager configuration"
  type = object({
    enabled = bool
    version = string
    email   = string
  })
  default = {
    enabled = true
    version = "v1.13.3"
    email   = "admin@cluster.local"
  }
}

variable "oauth2_proxy_config" {
  description = "OAuth2 Proxy configuration"
  type = object({
    enabled    = bool
    github_org = string
  })
  default = {
    enabled    = false
    github_org = ""
  }
}

variable "network_policies" {
  description = "Network policies configuration"
  type = object({
    enabled        = bool
    default_deny   = bool
    allow_dns      = bool
    allow_internal = bool
  })
  default = {
    enabled        = true
    default_deny   = true
    allow_dns      = true
    allow_internal = true
  }
}
