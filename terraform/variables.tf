variable "ssh_user" {
  description = "SSH username for Pi nodes"
  type        = string
  default     = "hezekiah"
}

variable "ssh_key_path" {
  description = "Path to SSH private key"
  type        = string
  default     = "~/.ssh/keys/hobby/pi_k3s_cluster"
}

variable "metallb_ip_range" {
  description = "IP range for MetalLB"
  type        = string
  default     = "192.168.0.200-192.168.0.250"
}

variable "postgres_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "minio_access_key" {
  description = "MinIO access key"
  type        = string
  default     = "admin"
}

variable "minio_secret_key" {
  description = "MinIO secret key"
  type        = string
  sensitive   = true
}