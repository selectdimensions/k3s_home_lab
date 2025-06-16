# Production Environment Variables

variable "cluster_name" {
  description = "Name of the K3s cluster"
  type        = string
  default     = "pi-k3s-cluster"
}

variable "cluster_domain" {
  description = "Domain for the cluster"
  type        = string
  default     = "cluster.local"
}

variable "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "ssh_user" {
  description = "SSH user for Pi nodes"
  type        = string
  default     = "hezekiah"
}

variable "ssh_key_path" {
  description = "Path to SSH private key"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "metallb_ip_range" {
  description = "IP range for MetalLB LoadBalancer"
  type        = string
  default     = "192.168.0.200-192.168.0.250"
}

# Database passwords
variable "postgres_password" {
  description = "PostgreSQL admin password"
  type        = string
  sensitive   = true
}

variable "minio_secret_key" {
  description = "MinIO secret key"
  type        = string
  sensitive   = true
}

# Application passwords
variable "nifi_admin_password" {
  description = "NiFi admin password"
  type        = string
  sensitive   = true
}

variable "trino_admin_password" {
  description = "Trino admin password"
  type        = string
  sensitive   = true
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  default     = ""
}

# Security
variable "vault_token" {
  description = "Vault root token"
  type        = string
  sensitive   = true
}

# Backup configuration
variable "backup_schedule" {
  description = "Backup schedule in cron format"
  type        = string
  default     = "0 2 * * *" # Daily at 2 AM
}

variable "backup_retention" {
  description = "Backup retention period in days"
  type        = number
  default     = 30
}

# Node configuration
variable "node_labels" {
  description = "Labels to apply to nodes"
  type        = map(map(string))
  default     = {}
}

variable "node_taints" {
  description = "Taints to apply to nodes"
  type = map(list(object({
    key    = string
    value  = string
    effect = string
  })))
  default = {}
}
