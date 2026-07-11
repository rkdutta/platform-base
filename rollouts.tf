# Argo Rollouts, installed via its official Helm chart.
# Chart: https://artifacthub.io/packages/helm/argo/argo-rollouts
resource "helm_release" "argo_rollouts" {
  count = var.argo_rollouts_enabled ? 1 : 0

  name             = "argo-rollouts"
  namespace        = var.argo_rollouts_namespace
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-rollouts"
  version    = var.argo_rollouts_chart_version != "" ? var.argo_rollouts_chart_version : null

  # Block until the controller reports ready.
  wait    = true
  timeout = 600

  depends_on = [kind_cluster.this]
}
