# Production Environment Outputs

output "cluster_info" {
  description = "Information about the deployed cluster"
  value = {
    name         = var.cluster_name
    environment  = "prod"
    nodes        = local.nodes
    domain       = var.cluster_domain
    metallb_range = var.metallb_ip_range
  }
}

output "service_endpoints" {
  description = "Service endpoints for the cluster"
  value = {
    nifi_url     = "http://${local.nodes["pi-master"].ip}:30080"
    trino_url    = "http://${local.nodes["pi-master"].ip}:30081"
    grafana_url  = "http://${local.nodes["pi-master"].ip}:30082"
    minio_console = "http://${local.nodes["pi-worker-3"].ip}:30083"
    postgres_host = local.nodes["pi-worker-2"].ip
  }
}

output "kubeconfig_command" {
  description = "Command to get kubeconfig"
  value = "scp ${var.ssh_user}@${local.nodes["pi-master"].ip}:~/.kube/config ~/.kube/config"
}

output "cluster_status_commands" {
  description = "Commands to check cluster status"
  value = {
    nodes     = "kubectl get nodes -o wide"
    pods      = "kubectl get pods -A"
    services  = "kubectl get svc -A"
    ingress   = "kubectl get ingress -A"
    storage   = "kubectl get pv,pvc -A"
  }
}

output "access_information" {
  description = "Access information for services"
  value = {
    ssh_master = "ssh ${var.ssh_user}@${local.nodes["pi-master"].ip}"
    ssh_workers = [
      for name, node in local.nodes : "ssh ${var.ssh_user}@${node.ip}" if node.role == "worker"
    ]
    puppet_console = "https://${local.nodes["pi-master"].ip}:443"
  }
  sensitive = false
}

output "data_platform_info" {
  description = "Data platform configuration"
  value = {
    nifi = {
      namespace = "data-platform"
      service   = "nifi"
      port      = 8080
    }
    trino = {
      namespace = "data-platform"
      service   = "trino"
      port      = 8080
    }
    postgresql = {
      namespace = "data-platform"
      service   = "postgresql"
      port      = 5432
    }
    minio = {
      namespace = "data-platform"
      service   = "minio"
      api_port  = 9000
      console_port = 9001
    }
  }
}

output "monitoring_info" {
  description = "Monitoring stack information"
  value = {
    prometheus = {
      namespace = "monitoring"
      service   = "prometheus"
      port      = 9090
    }
    grafana = {
      namespace = "monitoring"
      service   = "grafana"
      port      = 3000
    }
    alertmanager = {
      namespace = "monitoring"
      service   = "alertmanager"
      port      = 9093
    }
  }
}

output "backup_info" {
  description = "Backup configuration information"
  value = {
    schedule    = var.backup_schedule
    retention   = "${var.backup_retention} days"
    velero_namespace = "velero"
  }
}
