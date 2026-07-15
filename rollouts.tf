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

  # Enable the Rollouts dashboard (a read/write web UI for rollouts) as part of
  # the same chart release. It deploys an `argo-rollouts-dashboard` Deployment +
  # Service listening on port 3100.
  values = [yamlencode({
    dashboard = {
      enabled = var.argo_rollouts_dashboard_enabled
    }
  })]

  # Block until the controller reports ready.
  wait    = true
  timeout = 600

  depends_on = [kind_cluster.this]
}

# Ingress exposing the Argo Rollouts dashboard through ingress-nginx at
# http://<dashboard_ingress_host>:<ingress_http_host_port> (default
# http://rollouts.127.0.0.1.sslip.io:8080).
#
# Like the Argo CD ingress, the ingress-nginx controller itself is installed
# out-of-band (as an Argo CD Application in platform-infra), so this Ingress may
# exist before a controller is present; it simply isn't routable until one is.
resource "kubernetes_ingress_v1" "argo_rollouts_dashboard" {
  count = var.argo_rollouts_enabled && var.argo_rollouts_dashboard_enabled && var.argo_rollouts_dashboard_ingress_enabled ? 1 : 0

  metadata {
    name      = "argo-rollouts-dashboard"
    namespace = var.argo_rollouts_namespace

    # The dashboard keeps a long-lived server-stream open for live rollout
    # updates. nginx's default 60s proxy-read-timeout cuts it, so the UI is stuck
    # "loading" and reconnects in a loop. Disable response buffering and raise
    # the read/send timeouts so the stream stays open.
    annotations = {
      "nginx.ingress.kubernetes.io/proxy-buffering"    = "off"
      "nginx.ingress.kubernetes.io/proxy-read-timeout" = "3600"
      "nginx.ingress.kubernetes.io/proxy-send-timeout" = "3600"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = var.argo_rollouts_dashboard_ingress_host
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              # Service created by the Helm release above (chart fullname is just
              # the release name "argo-rollouts", so the dashboard Service is
              # named "argo-rollouts-dashboard").
              name = "argo-rollouts-dashboard"
              port {
                number = 3100
              }
            }
          }
        }
      }
    }
  }

  # The dashboard Service is created by the Helm release above.
  depends_on = [helm_release.argo_rollouts]
}
