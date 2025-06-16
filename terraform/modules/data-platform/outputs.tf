# Data Platform Module Outputs

output "namespace" {
  description = "Kubernetes namespace for data platform"
  value       = var.namespace
}

output "data_platform_config" {
  description = "Data platform configuration"
  value = {
    environment = var.environment
    namespace   = var.namespace
    components  = var.components
  }
}

output "postgresql_endpoint" {
  description = "PostgreSQL service endpoint"
  value = var.components.postgresql.enabled ? "postgresql.${var.namespace}.svc.cluster.local:5432" : ""
}

output "minio_endpoint" {
  description = "MinIO service endpoint"
  value = var.components.minio.enabled ? "minio.${var.namespace}.svc.cluster.local:9000" : ""
}

output "nifi_endpoint" {
  description = "Apache NiFi service endpoint"
  value = var.components.nifi.enabled ? "nifi.${var.namespace}.svc.cluster.local:8443" : ""
}

output "trino_endpoint" {
  description = "Trino service endpoint"
  value = var.components.trino.enabled ? "trino.${var.namespace}.svc.cluster.local:8080" : ""
}
