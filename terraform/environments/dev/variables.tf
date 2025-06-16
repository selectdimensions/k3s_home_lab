# Development Environment Variables

variable "grafana_admin_password" {
  description = "Admin password for Grafana"
  type        = string
  sensitive   = true
  default     = "admin123"
}

variable "node_ssh_user" {
  description = "SSH user for Pi nodes"
  type        = string
  default     = "hezekiah"
}

variable "node_ssh_private_key_path" {
  description = "Path to SSH private key for Pi nodes"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "puppet_environment" {
  description = "Puppet environment to use"
  type        = string
  default     = "development"
}

variable "debug_mode" {
  description = "Enable debug mode for development"
  type        = bool
  default     = true
}

variable "resource_constraints" {
  description = "Resource constraints for development environment"
  type = object({
    max_cpu_per_pod    = string
    max_memory_per_pod = string
    max_pods_per_node  = number
  })
  default = {
    max_cpu_per_pod    = "1"
    max_memory_per_pod = "2Gi"
    max_pods_per_node  = 50
  }
}
