# K3s Cluster Module Variables

variable "cluster_name" {
  description = "Name of the K3s cluster"
  type        = string
  default     = "pi-k3s-cluster"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "k3s_version" {
  description = "K3s version to install"
  type        = string
  default     = "v1.28.4+k3s1"
}

variable "k3s_token" {
  description = "K3s cluster token (generated if empty)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "nodes" {
  description = "Map of cluster nodes with their configuration"
  type = map(object({
    ip     = string
    role   = string
    labels = optional(map(string), {})
    taints = optional(list(string), [])
  }))
}

variable "cluster_cidr" {
  description = "CIDR range for cluster pods"
  type        = string
  default     = "10.42.0.0/16"
}

variable "service_cidr" {
  description = "CIDR range for cluster services"
  type        = string
  default     = "10.43.0.0/16"
}

variable "cluster_dns" {
  description = "IP address of cluster DNS service"
  type        = string
  default     = "10.43.0.10"
}

variable "metallb_ip_range" {
  description = "IP range for MetalLB load balancer"
  type        = string
  default     = "192.168.0.200-192.168.0.250"
}

variable "disable_components" {
  description = "List of K3s components to disable"
  type        = list(string)
  default     = ["traefik"]
}

variable "kubeconfig_path" {
  description = "Path to kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "ssh_user" {
  description = "SSH user for cluster nodes"
  type        = string
  default     = "hezekiah"
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "resource_limits" {
  description = "Resource limits for the environment"
  type = object({
    cpu_limit    = string
    memory_limit = string
  })
  default = {
    cpu_limit    = "2"
    memory_limit = "4Gi"
  }
}

variable "install_cert_manager" {
  description = "Whether to install cert-manager"
  type        = bool
  default     = true
}

variable "install_ingress_nginx" {
  description = "Whether to install ingress-nginx"
  type        = bool
  default     = true
}

variable "install_monitoring" {
  description = "Whether to install monitoring stack"
  type        = bool
  default     = false
}

variable "cluster_domain" {
  description = "Domain name for the cluster"
  type        = string
  default     = "cluster.local"
}
