resource "helm_release" "prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = "51.0.3"

  values = [
    templatefile("${path.module}/values/prometheus-stack.yaml", {
      grafana_password      = var.grafana_password
      alertmanager_config   = var.alertmanager_config
      retention_days        = var.retention_days
      storage_class         = var.storage_class
    })
  ]

  set {
    name  = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
    value = "false"
  }
}

resource "helm_release" "loki_stack" {
  name             = "loki"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki-stack"
  namespace        = "monitoring"
  version          = "2.9.11"

  values = [
    file("${path.module}/values/loki-stack.yaml")
  ]

  depends_on = [helm_release.prometheus_stack]
}