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

  # Run argocd-server in insecure (plain-HTTP) mode. Behind an HTTP ingress this
  # is required: in TLS mode the server marks the auth cookie `Secure`, which
  # browsers drop over http:// — so login silently fails. ingress-nginx is the
  # edge here; TLS can be terminated at the ingress later if desired.
  values = [yamlencode({
    configs = {
      params = {
        "server.insecure" = true
      }
      # How often the application-controller re-checks git and reconciles each
      # Application (argocd-cm `timeout.reconciliation`). Default is 180s, which
      # meant a merged image-bump PR took up to 3 min to deploy. 30s makes merged
      # Renovate bumps roll out in seconds. (A git webhook would be instant, but
      # GitHub can't reach this local kind cluster, so a short poll is the lever.)
      # NOTE: the controller reads this at startup — after `terraform apply`,
      # restart it: kubectl -n argocd rollout restart statefulset argocd-application-controller
      cm = {
        "timeout.reconciliation" = "30s"
      }
    }
  })]

  # Block until the release's resources report ready so downstream steps can
  # rely on Argo CD being usable.
  wait    = true
  timeout = 600

  depends_on = [kind_cluster.this]
}

# Ingress exposing the Argo CD server UI through ingress-nginx at
# http://<argocd_ingress_host>:<ingress_http_host_port> (default
# http://argocd.127.0.0.1.sslip.io:8080).
#
# argocd-server runs in insecure (plain-HTTP) mode (see the helm_release above),
# so nginx just proxies HTTP to the server's http port. Serving over HTTP also
# keeps the auth cookie non-Secure, so it survives the http:// browser session.
#
# Note: the ingress-nginx controller itself is installed out-of-band (as an
# Argo CD Application in platform-infra), so this Ingress object may exist before
# a controller is present; it simply isn't routable until one is.
resource "kubernetes_ingress_v1" "argocd" {
  count = var.argocd_enabled && var.argocd_ingress_enabled ? 1 : 0

  metadata {
    name      = "argocd-server"
    namespace = var.argocd_namespace
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = var.argocd_ingress_host
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "argocd-server"
              port {
                name = "http"
              }
            }
          }
        }
      }
    }
  }

  # The argocd-server Service is created by the Helm release above.
  depends_on = [helm_release.argocd]
}
