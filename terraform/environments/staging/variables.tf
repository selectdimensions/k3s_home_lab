# Staging Environment Variables

variable "grafana_admin_password" {
  description = "Admin password for Grafana"
  type        = string
  sensitive   = true
}

variable "slack_webhook" {
  description = "Slack webhook URL for alertmanager notifications"
  type        = string
  default     = ""
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt certificate registration"
  type        = string
}

variable "github_org" {
  description = "GitHub organization for OAuth2 authentication"
  type        = string
  default     = ""
}

variable "backup_storage_location" {
  description = "Storage location for backups (NFS, S3, etc.)"
  type        = string
  default     = "/backup"
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
  default     = "staging"
}

variable "resource_constraints" {
  description = "Resource constraints for staging environment"
  type = object({
    max_cpu_per_pod    = string
    max_memory_per_pod = string
    max_pods_per_node  = number
  })
  default = {
    max_cpu_per_pod    = "2"
    max_memory_per_pod = "4Gi"
    max_pods_per_node  = 110
  }
}

variable "metallb_ip_range" {
  description = "IP range for MetalLB load balancer"
  type        = string
  default     = "192.168.0.200-192.168.0.210"
}
