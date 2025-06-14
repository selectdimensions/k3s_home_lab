resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "5.46.8"

  values = [
    templatefile("${path.module}/values/argocd.yaml", {
      github_ssh_key = var.github_ssh_key
      ingress_host   = var.argocd_ingress_host
    })
  ]
}

resource "kubernetes_manifest" "argocd_apps" {
  for_each = fileset("${path.module}/applications", "*.yaml")

  manifest = yamldecode(file("${path.module}/applications/${each.value}"))

  depends_on = [helm_release.argocd]
}