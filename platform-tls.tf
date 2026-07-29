# -----------------------------------------------------------------------------
# platform-tls — the self-signed wildcard cert for *.127.0.0.1.sslip.io.
#
# Generated HERE by Terraform (not read from the cluster) specifically to break
# a chicken-and-egg: Argo CD's OIDC needs Keycloak's CA for `rootCA` (argocd.tf),
# but Keycloak — and its platform-tls secret — is deployed BY Argo CD, i.e. only
# after this apply. Making the cert a Terraform resource gives argocd.tf the CA
# on the very first apply with OIDC enabled, no cluster read required.
#
# The same cert/key are written to platform-infra/bootstrap/ so create-secrets.sh
# distributes THIS cert into the openbao/harbor/keycloak/engineering-platform
# namespaces — everything ends up trusting one CA. The files are git-ignored.
# -----------------------------------------------------------------------------

variable "platform_tls_output_dir" {
  description = "Directory (relative to this module) where the generated platform-tls cert/key are written for create-secrets.sh to distribute. Defaults to the sibling platform-infra checkout's bootstrap dir."
  type        = string
  default     = "../platform-infra/bootstrap"
}

resource "tls_private_key" "platform_tls" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "platform_tls" {
  private_key_pem = tls_private_key.platform_tls.private_key_pem

  subject {
    common_name = "*.127.0.0.1.sslip.io"
  }

  # SANs must cover both the wildcard and the apex, matching the prior openssl
  # cert (subjectAltName=DNS:*.127.0.0.1.sslip.io,DNS:127.0.0.1.sslip.io).
  dns_names = ["*.127.0.0.1.sslip.io", "127.0.0.1.sslip.io"]

  validity_period_hours = 825 * 24 # 825 days, matching the prior -days 825

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# Persist the cert/key where create-secrets.sh expects them (git-ignored via
# platform-infra/.gitignore: bootstrap/platform-tls.crt|key).
resource "local_file" "platform_tls_crt" {
  filename        = "${path.module}/${var.platform_tls_output_dir}/platform-tls.crt"
  content         = tls_self_signed_cert.platform_tls.cert_pem
  file_permission = "0644"
}

resource "local_sensitive_file" "platform_tls_key" {
  filename        = "${path.module}/${var.platform_tls_output_dir}/platform-tls.key"
  content         = tls_private_key.platform_tls.private_key_pem
  file_permission = "0600"
}
