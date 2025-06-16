# Data Platform Module
# Generates configuration for NiFi, Trino, PostgreSQL, MinIO, and JupyterLab

# Generate data platform configuration
resource "local_file" "data_platform_config" {
  filename = "${path.root}/data-platform-${var.environment}.yaml"
  content = yamlencode({
    environment  = var.environment
    namespace    = var.namespace
    components   = var.components
    cluster_name = var.cluster_name
  })
}

# Generate Helm values for each component
resource "local_file" "nifi_values" {
  count    = var.components.nifi.enabled ? 1 : 0
  filename = "${path.root}/helm-values/nifi-${var.environment}.yaml"
  content = yamlencode({
    replicaCount = var.components.nifi.replicas
    resources    = var.components.nifi.resources
    persistence = {
      enabled = true
      size    = "10Gi"
    }
  })
}

resource "local_file" "trino_values" {
  count    = var.components.trino.enabled ? 1 : 0
  filename = "${path.root}/helm-values/trino-${var.environment}.yaml"
  content = yamlencode({
    coordinator = {
      replicas  = var.components.trino.coordinator_replicas
      resources = var.components.trino.resources
    }
    worker = {
      replicas  = var.components.trino.worker_replicas
      resources = var.components.trino.resources
    }
  })
}

resource "local_file" "postgresql_values" {
  count    = var.components.postgresql.enabled ? 1 : 0
  filename = "${path.root}/helm-values/postgresql-${var.environment}.yaml"
  content = yamlencode({
    persistence = {
      enabled = true
      size    = var.components.postgresql.storage_size
    }
    auth = {
      database = "dataplatform"
    }
  })
}

resource "local_file" "minio_values" {
  count    = var.components.minio.enabled ? 1 : 0
  filename = "${path.root}/helm-values/minio-${var.environment}.yaml"
  content = yamlencode({
    mode = "standalone"
    persistence = {
      enabled = true
      size    = "20Gi"
    }
  })
}
