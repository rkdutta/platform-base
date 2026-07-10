# Argo CD, installed via its official Helm chart.
# Chart docs: https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd
resource "helm_release" "argocd" {
  count = var.argocd_enabled ? 1 : 0

  name             = "argocd"
  namespace        = var.argocd_namespace
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version != "" ? var.argocd_chart_version : null

  # Block until the release's resources report ready so downstream steps can
  # rely on Argo CD being usable.
  wait    = true
  timeout = 600

  depends_on = [kind_cluster.this]
}
