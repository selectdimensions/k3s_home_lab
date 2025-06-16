# Monitoring Stack Module
# Manages Prometheus, Grafana, and related monitoring components

# Generate monitoring configuration
resource "local_file" "monitoring_config" {
  filename = "${path.root}/monitoring-${var.environment}.yaml"
  content = yamlencode({
    environment = var.environment
    namespace   = var.namespace
    components  = var.components
    cluster_name = var.cluster_name
  })
}

# Placeholder for Kubernetes manifests generation
# In a real implementation, this would generate Helm values or K8s manifests
resource "local_file" "prometheus_values" {
  count    = var.components.prometheus.enabled ? 1 : 0
  filename = "${path.root}/helm-values/prometheus-${var.environment}.yaml"
  content = yamlencode({
    prometheus = {
      retention = var.components.prometheus.retention
      storage = {
        size = var.components.prometheus.storage_size
      }
    }
  })
}

resource "local_file" "grafana_values" {
  count    = var.components.grafana.enabled ? 1 : 0
  filename = "${path.root}/helm-values/grafana-${var.environment}.yaml"
  content = yamlencode({
    grafana = {
      adminPassword = var.components.grafana.admin_password
      persistence = {
        enabled = true
        size = "5Gi"
      }
    }  })
}
