# Puppet Infrastructure Module Variables

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "cluster_name" {
  description = "Name of the K3s cluster"
  type        = string
}

variable "nodes" {
  description = "Map of cluster nodes with their configuration"
  type = map(object({
    ip         = string
    role       = string
    components = list(string)
  }))
}

variable "puppet_config" {
  description = "Puppet-specific configuration"
  type = object({
    environment     = string
    deploy_services = list(string)
    debug_mode      = bool
  })
  default = {
    environment     = "production"
    deploy_services = ["base", "k3s", "monitoring"]
    debug_mode      = false
  }
}

variable "cluster_domain" {
  description = "Domain name for the cluster"
  type        = string
  default     = "cluster.local"
}

variable "ssh_user" {
  description = "SSH user for remote connections"
  type        = string
  default     = "hezekiah"
}

variable "ssh_key_path" {
  description = "Path to SSH private key"
  type        = string
  default     = "/home/boltuser/.ssh/pi_k3s_cluster_rsa"
}
