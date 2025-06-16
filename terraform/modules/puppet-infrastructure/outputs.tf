# Puppet Infrastructure Module Outputs

output "inventory_file" {
  description = "Path to generated Bolt inventory file"
  value       = local_file.bolt_inventory.filename
}

output "puppet_nodes" {
  description = "Map of puppet-managed nodes"
  value       = var.nodes
}

output "cluster_config" {
  description = "Cluster configuration for Puppet"
  value = {
    environment   = var.environment
    cluster_name  = var.cluster_name
    cluster_domain = var.cluster_domain
  }
}
