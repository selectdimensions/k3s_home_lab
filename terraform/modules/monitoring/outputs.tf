# Monitoring Module Outputs

output "namespace" {
  description = "Kubernetes namespace for monitoring"
  value       = var.namespace
}

output "prometheus_endpoint" {
  description = "Prometheus service endpoint"
  value       = var.components.prometheus.enabled ? "http://prometheus.${var.namespace}.svc.cluster.local:9090" : ""
}

output "grafana_endpoint" {
  description = "Grafana service endpoint"
  value       = var.components.grafana.enabled ? "http://grafana.${var.namespace}.svc.cluster.local:3000" : ""
}

output "monitoring_config" {
  description = "Monitoring stack configuration"
  value = {
    environment = var.environment
    namespace   = var.namespace
    components  = var.components
  }
}
