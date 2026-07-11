# Copy to terraform.tfvars and adjust as needed:
#   cp example.tfvars terraform.tfvars

cluster_name       = "platform-base"
kubernetes_version = "v1.31.0"
worker_count       = 2
ingress_ready      = true
# Host ports for ingress (avoid clashing with other local clusters on 80/443).
ingress_http_host_port      = 8080
ingress_https_host_port     = 8443
argocd_enabled              = true
argocd_namespace            = "argocd"
argocd_chart_version        = "10.1.3" # pinned; "" = latest
argo_rollouts_enabled       = true
argo_rollouts_namespace     = "argocd"
argo_rollouts_chart_version = "2.41.0" # pinned; "" = latest
kubeconfig_path             = "./kubeconfig"

# Local container registry (https://kind.sigs.k8s.io/docs/user/local-registry/).
local_registry_enabled = true
local_registry_port    = 5001
# The docker provider ignores docker contexts. On colima, point it at the socket:
docker_host = "unix:///Users/rdutta/.colima/default/docker.sock"
