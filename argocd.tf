# SSO: native OIDC against Keycloak's "teams" realm (not the bundled Dex) -
# there's exactly one IdP in this cluster, so Dex's extra hop buys nothing.
# The counterpart "argocd" Keycloak client lives in a completely different
# deploy mechanism (platform-infra's teams-realm.json, applied via Argo CD's
# own Helm release of Keycloak) - these locals are the seam between the two;
# keep clientID/clientSecret/issuer in sync with that file by hand, nothing
# enforces it automatically.
#
# Argo CD's OIDC RBAC only matches the token's `groups` claim (not
# realm_access.roles), so admin access is granted to a *group*
# (var.argocd_admin_group) rather than reusing the realm's existing "admin"
# role directly - see variables.tf.
#
# Reachability: platform-auth.127.0.0.1.sslip.io resolves to 127.0.0.1 (the
# whole point of sslip.io), which from *inside* argocd-server means its own
# loopback, not the ingress - and Keycloak's issuer has :8443 hardcoded
# (its --hostname flag, platform-infra's keycloak Application), which the
# ingress-nginx Service doesn't listen on internally at all (only 80/443;
# :8443 is a kind Docker port mapping, host-only). Both fixed out-of-band,
# not by Terraform: a CoreDNS rewrite (platform-auth.127.0.0.1.sslip.io ->
# platform-auth-ingress-8443.ingress-nginx.svc.cluster.local) and that
# small additional Service (same pod selector as ingress-nginx-controller's
# own Service, just also exposing :8443) - see
# platform-infra/apps/security/keycloak/application.yaml's extraManifests.

# count (not a plain read) so this is skipped entirely when OIDC is off -
# on a from-scratch cluster this secret doesn't exist until well after the
# first terraform apply (see the rootCA comment below), and an
# unconditional read would fail that apply outright.
data "kubernetes_secret_v1" "platform_tls" {
  count = var.argocd_oidc_enabled ? 1 : 0
  metadata {
    name      = "platform-tls"
    namespace = "keycloak"
  }
}

locals {
  argocd_cm_config = merge(
    {
      # How often the application-controller re-checks git and reconciles each
      # Application (argocd-cm `timeout.reconciliation`). Default is 180s, which
      # meant a merged image-bump PR took up to 3 min to deploy. 30s makes merged
      # Renovate bumps roll out in seconds. (A git webhook would be instant, but
      # GitHub can't reach this local kind cluster, so a short poll is the lever.)
      # NOTE: the controller reads this at startup — after `terraform apply`,
      # restart it: kubectl -n argocd rollout restart statefulset argocd-application-controller
      "timeout.reconciliation" = "30s"
      # The chart's own default ("https://argocd.example.com") was never
      # overridden - Argo CD builds its OAuth redirect_uri as "<url>/auth/
      # callback", so it was sending that placeholder straight to Keycloak
      # ("Invalid redirect URL", since it obviously doesn't match what's
      # registered on the "argocd" client). Must exactly match
      # var.argocd_ingress_host's scheme+host+port, which is also what the
      # Keycloak client's redirectUris/webOrigins are registered against
      # (platform-infra/apps/security/keycloak/application.yaml).
      "url" = "http://${var.argocd_ingress_host}:${var.ingress_http_host_port}"
    },
    var.argocd_oidc_enabled ? {
      "oidc.config" = yamlencode({
        name     = "Keycloak"
        issuer   = var.argocd_oidc_issuer_url
        clientID = "argocd"
        # Argo CD's own $<secret-name>:<key> interpolation - resolved from
        # argocd-secret at read time, never written into this ConfigMap or
        # Terraform state as plaintext. The key must match what's set in
        # configs.secret.extra below.
        clientSecret    = "$argocd-secret:oidc.keycloak.clientSecret"
        requestedScopes = ["openid", "profile", "email", "groups"]
        # platform-tls is self-signed; without this argocd-server rejects
        # the connection ("x509: certificate signed by unknown authority").
        # Read live rather than pasted in, so a cert rotation doesn't leave
        # this silently stale - see data.kubernetes_secret_v1.platform_tls
        # below. NOTE: on a from-scratch cluster this secret doesn't exist
        # yet on the *first* terraform apply (it's created out-of-band,
        # after Keycloak is up - see bootstrap/README.md) - set
        # argocd_oidc_enabled=false for that first apply, then true on a
        # second one once platform-tls exists.
        rootCA = data.kubernetes_secret_v1.platform_tls[0].data["tls.crt"]
      })
    } : {}
  )

  argocd_secret_extra = var.argocd_oidc_enabled ? {
    "oidc.keycloak.clientSecret" = var.argocd_oidc_client_secret
  } : {}

  argocd_rbac_config = var.argocd_oidc_enabled ? {
    # Everyone who can log in (any "teams" realm user) gets read-only by
    # default; only var.argocd_admin_group members get full admin. Revisit
    # if "logged in => at least read-only" turns out to be too permissive.
    "policy.csv"     = "g, ${var.argocd_admin_group}, role:admin\n"
    "policy.default" = "role:readonly"
  } : {}
}

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
      cm     = local.argocd_cm_config
      secret = { extra = local.argocd_secret_extra }
      rbac   = local.argocd_rbac_config
    }
    # Dex is unused once native OIDC (above) is configured - one less
    # component to run/patch/debug. Left enabled if OIDC is off, so a
    # from-scratch cluster still gets a working (local-admin-only) Argo CD.
    dex = {
      enabled = !var.argocd_oidc_enabled
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
