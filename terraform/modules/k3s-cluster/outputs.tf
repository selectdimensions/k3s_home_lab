# K3s Cluster Module Outputs

output "cluster_name" {
  description = "Name of the K3s cluster"
  value       = var.cluster_name
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "k3s_token" {
  description = "K3s cluster token"
  value       = local.actual_k3s_token
  sensitive   = true
}

output "master_nodes" {
  description = "List of master nodes"
  value       = local.cluster_config.master_nodes
}

output "worker_nodes" {
  description = "List of worker nodes"
  value       = local.cluster_config.worker_nodes
}

output "cluster_cidr" {
  description = "Cluster pod CIDR"
  value       = var.cluster_cidr
}

output "service_cidr" {
  description = "Cluster service CIDR"
  value       = var.service_cidr
}

output "metallb_ip_range" {
  description = "MetalLB IP range"
  value       = var.metallb_ip_range
}

output "kubeconfig_template_path" {
  description = "Path to kubeconfig template"
  value       = "${path.root}/.kube/config-${var.environment}-template"
}

output "deployment_params" {
  description = "Parameters for Puppet deployment"
  value = {
    environment      = var.environment
    cluster_name     = var.cluster_name
    k3s_version      = var.k3s_version
    k3s_token        = local.actual_k3s_token
    cluster_cidr     = var.cluster_cidr
    service_cidr     = var.service_cidr
    metallb_ip_range = var.metallb_ip_range
    master_ip        = local.cluster_config.master_nodes[0].ip
  }
  sensitive = true
}

output "kubeconfig" {
  description = "Generated kubeconfig content"
  value = templatefile("${path.module}/templates/kubeconfig.yaml.tpl", {
    cluster_name = var.cluster_name
    master_ip    = local.cluster_config.master_nodes[0].ip
    environment  = var.environment
  })
  sensitive = true
}
