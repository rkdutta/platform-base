# Copy to terraform.tfvars and adjust as needed:
#   cp example.tfvars terraform.tfvars

cluster_name       = "platform-base"
kubernetes_version = "v1.31.0"
worker_count       = 2
ingress_ready      = true
# Host ports for ingress (avoid clashing with other local clusters on 80/443).
ingress_http_host_port  = 8080
ingress_https_host_port = 8443
argocd_enabled          = true
argocd_namespace        = "argocd"
argocd_chart_version    = "10.1.3" # pinned; "" = latest
kubeconfig_path         = "./kubeconfig"
