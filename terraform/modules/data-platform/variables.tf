variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "postgres_password" {
  description = "PostgreSQL admin password"
  type        = string
  sensitive   = true
}

variable "minio_secret_key" {
  description = "MinIO secret access key"
  type        = string
  sensitive   = true
}

variable "nifi_admin_password" {
  description = "Apache NiFi admin password"
  type        = string
  sensitive   = true
}

variable "trino_admin_password" {
  description = "Trino admin password"
  type        = string
  sensitive   = true
}

variable "jupyter_token" {
  description = "JupyterLab access token"
  type        = string
  sensitive   = true
  default     = "jupyter123"
}

variable "namespace" {
  description = "Kubernetes namespace for data platform"
  type        = string
  default     = "data-platform"
}

variable "components" {
  description = "Data platform components configuration"
  type = object({
    nifi = object({
      enabled  = bool
      replicas = number
      resources = object({
        requests = map(string)
        limits   = map(string)
      })
    })
    trino = object({
      enabled              = bool
      coordinator_replicas = number
      worker_replicas      = number
      resources = object({
        requests = map(string)
        limits   = map(string)
      })
    })
    postgresql = object({
      enabled      = bool
      storage_size = string
    })
    minio = object({
      enabled = bool
    })
  })
  default = {
    nifi = {
      enabled  = true
      replicas = 1
      resources = {
        requests = { cpu = "500m", memory = "1Gi" }
        limits   = { cpu = "1", memory = "2Gi" }
      }
    }
    trino = {
      enabled              = true
      coordinator_replicas = 1
      worker_replicas      = 2
      resources = {
        requests = { cpu = "500m", memory = "1Gi" }
        limits   = { cpu = "1", memory = "2Gi" }
      }
    }
    postgresql = {
      enabled      = true
      storage_size = "10Gi"
    }
    minio = {
      enabled = true
    }
  }
}
