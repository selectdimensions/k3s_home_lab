# Staging Environment Outputs

output "cluster_info" {
  description = "K3s cluster information"
  value = {
    name        = module.k3s_cluster.cluster_name
    environment = local.environment
    master_ip   = local.nodes["pi-master"].ip
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
  description = "Service URLs for staging environment"
  value = {
    nifi = module.data_platform.nifi_url
    grafana = module.monitoring.grafana_url
    trino = module.data_platform.trino_url
    vault = module.security.vault_url
    minio = module.data_platform.minio_url
  }
}

output "credentials" {
  description = "Service credentials (sensitive)"
  sensitive = true
  value = {
    postgres_password = random_password.postgres_password.result
    nifi_admin_password = random_password.nifi_admin_password.result
    vault_root_token = random_password.vault_token.result
    grafana_admin_password = var.grafana_admin_password
  }
}

output "monitoring_endpoints" {
  description = "Monitoring and observability endpoints"
  value = {
    prometheus = module.monitoring.prometheus_url
    grafana = module.monitoring.grafana_url
    alertmanager = module.monitoring.alertmanager_url
    elasticsearch = module.monitoring.elasticsearch_url
    kibana = module.monitoring.kibana_url
  }
}

output "puppet_inventory" {
  description = "Generated Puppet inventory file path"
  value = local_file.staging_inventory.filename
}

output "secrets_file" {
  description = "Generated secrets file path"
  value = local_sensitive_file.staging_secrets.filename
}

output "kubeconfig_command" {
  description = "Command to use the generated kubeconfig"
  value = "export KUBECONFIG=${local_file.kubeconfig.filename}"
}

output "deployment_commands" {
  description = "Commands to deploy staging environment"
  value = <<-EOT
    Staging environment configured! Deployment commands:
    
    1. Export kubeconfig:
       export KUBECONFIG=${local_file.kubeconfig.filename}
    
    2. Deploy with Puppet:
       cd ../../..
       .\Make.ps1 puppet-deploy -Environment staging -Targets all
    
    3. Deploy data platform:
       .\Make.ps1 deploy-data-platform -Environment staging
    
    4. Check cluster status:
       kubectl get nodes
       kubectl get pods -A
    
    5. Access services:
       - NiFi: ${module.data_platform.nifi_url}
       - Grafana: ${module.monitoring.grafana_url}
       - Trino: ${module.data_platform.trino_url}
       - Vault: ${module.security.vault_url}
    
    6. View secrets:
       cat ${local_sensitive_file.staging_secrets.filename}
  EOT
}
