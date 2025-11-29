# Staging Environment Outputs

output "cluster_info" {
  description = "K3s cluster information"
  value = {
    name        = local.cluster_name
    environment = local.environment
    master_ip   = local.nodes["pi-master"].ip
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

output "service_endpoints" {
  description = "Service endpoints for staging environment"
  value = {
    nifi       = module.data_platform.nifi_endpoint
    trino      = module.data_platform.trino_endpoint
    postgresql = module.data_platform.postgresql_endpoint
    minio      = module.data_platform.minio_endpoint
    grafana    = module.monitoring.grafana_endpoint
    prometheus = module.monitoring.prometheus_endpoint
  }
}

output "credentials" {
  description = "Service credentials (sensitive)"
  sensitive   = true
  value = {
    postgres_password      = random_password.postgres_password.result
    nifi_admin_password    = random_password.nifi_admin_password.result
    vault_root_token       = random_password.vault_token.result
    grafana_admin_password = var.grafana_admin_password
  }
}

output "puppet_inventory" {
  description = "Generated Puppet inventory file path"
  value       = local_file.staging_inventory.filename
}

output "secrets_file" {
  description = "Generated secrets file path"
  value       = local_sensitive_file.staging_secrets.filename
}

output "deployment_commands" {
  description = "Commands to deploy staging environment"
  value       = <<-EOT
    Staging environment configured! Deployment commands:

    1. Deploy with Puppet:
       cd puppet
       bolt plan run deploy_simple environment=staging

    2. Deploy data platform via Make.ps1:
       .\Make.ps1 quick-deploy -Environment staging

    3. Check cluster status:
       .\Make.ps1 cluster-status
  EOT
}
