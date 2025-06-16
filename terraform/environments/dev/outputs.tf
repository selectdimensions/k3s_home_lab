# Development Environment Outputs

output "cluster_info" {
  description = "K3s cluster information"
  value = {
    name            = module.k3s_cluster.cluster_name
    environment     = local.environment
    master_ip       = local.nodes["pi-master"].ip
    kubeconfig_path = local_file.kubeconfig.filename
  }
}

output "nodes" {
  description = "Cluster node information"
  value = {
    for name, node in local.nodes : name => {
      ip         = node.ip
      role       = node.role
      components = node.components
    }
  }
}

output "service_urls" {
  description = "Service URLs for development environment"
  value = {
    nifi    = module.data_platform.nifi_endpoint
    grafana = module.monitoring.grafana_endpoint
    trino   = module.data_platform.trino_endpoint
  }
}

output "puppet_inventory" {
  description = "Generated Puppet inventory file path"
  value       = local_file.dev_inventory.filename
}

output "kubeconfig_command" {
  description = "Command to use the generated kubeconfig"
  value       = "export KUBECONFIG=${local_file.kubeconfig.filename}"
}

output "next_steps" {
  description = "Next steps for development environment"
  value       = <<-EOT
    Development environment ready! Next steps:

    1. Export kubeconfig:
       export KUBECONFIG=${local_file.kubeconfig.filename}

    2. Deploy with Puppet:
       cd ../../..
       .\Make.ps1 puppet-deploy -Environment dev

    3. Check cluster status:
       kubectl get nodes
       kubectl get pods -A
      4. Access services:
       - NiFi: ${module.data_platform.nifi_endpoint}
       - Grafana: ${module.monitoring.grafana_endpoint}
       - Trino: ${module.data_platform.trino_endpoint}
  EOT
}
