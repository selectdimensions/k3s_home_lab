resource "helm_release" "velero" {
  name             = "velero"
  repository       = "https://vmware-tanzu.github.io/helm-charts"
  chart            = "velero"
  namespace        = "velero"
  create_namespace = true
  version          = "5.0.2"

  values = [
    templatefile("${path.module}/values/velero.yaml", {
      backup_storage_location = var.backup_storage_location
      minio_access_key        = var.minio_access_key
      minio_secret_key        = var.minio_secret_key
    })
  ]
}

# Create backup schedules
resource "kubernetes_manifest" "backup_schedules" {
  for_each = var.backup_schedules

  manifest = {
    apiVersion = "velero.io/v1"
    kind       = "Schedule"
    metadata = {
      name      = each.key
      namespace = "velero"
    }
    spec = {
      schedule = each.value.schedule
      template = {
        ttl                     = each.value.retention
        includedNamespaces      = each.value.namespaces
        storageLocation         = var.backup_storage_location
        volumeSnapshotLocations = ["default"]
      }
    }
  }

  depends_on = [helm_release.velero]
}