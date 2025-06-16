# Monitoring Module Variables

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for monitoring components"
  type        = string
  default     = "monitoring"
}

variable "components" {
  description = "Monitoring components configuration"
  type = object({
    prometheus = object({
      enabled      = bool
      retention    = string
      storage_size = string
    })
    grafana = object({
      enabled        = bool
      admin_password = string
    })
    node_exporter = object({
      enabled = bool
    })
    alertmanager = object({
      enabled = bool
    })
  })
  default = {
    prometheus = {
      enabled      = true
      retention    = "15d"
      storage_size = "10Gi"
    }
    grafana = {
      enabled        = true
      admin_password = "changeme"
    }
    node_exporter = {
      enabled = true
    }
    alertmanager = {
      enabled = true
    }
  }
}

variable "cluster_name" {
  description = "Name of the K3s cluster"
  type        = string
  default     = "pi-k3s"
}
