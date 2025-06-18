# Backup Module Variables

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "backup_schedule" {
  description = "Cron schedule for automatic backups"
  type        = string
  default     = "0 2 * * *" # Daily at 2 AM
}

variable "backup_retention" {
  description = "Backup retention period in days"
  type        = number
  default     = 30
}

variable "backup_storage_location" {
  description = "Storage location for backups"
  type        = string
  default     = "/opt/backups"
}

variable "minio_access_key" {
  description = "MinIO access key for backup storage"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "minio_secret_key" {
  description = "MinIO secret key for backup storage"
  type        = string
  sensitive   = true
}

variable "backup_schedules" {
  description = "Map of backup schedules"
  type = map(object({
    schedule   = string
    retention  = string
    namespaces = list(string)
  }))
  default = {
    daily = {
      schedule   = "0 2 * * *"
      retention  = "720h" # 30 days
      namespaces = ["default", "kube-system", "monitoring", "data-platform"]
    }
    weekly = {
      schedule   = "0 0 * * 0" # Sunday midnight
      retention  = "2160h"     # 90 days
      namespaces = ["*"]
    }
  }
}

variable "namespace" {
  description = "Kubernetes namespace for backup components"
  type        = string
  default     = "velero"
}
