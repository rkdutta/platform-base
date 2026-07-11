output "cluster_name" {
  description = "Name of the created kind cluster."
  value       = kind_cluster.this.name
}

output "kubeconfig_path" {
  description = "Path to the generated kubeconfig file."
  value       = kind_cluster.this.kubeconfig_path
}

output "endpoint" {
  description = "Kubernetes API server endpoint."
  value       = kind_cluster.this.endpoint
}

output "kubectl_context" {
  description = "kubectl context name for this cluster."
  value       = "kind-${kind_cluster.this.name}"
}

output "argocd_namespace" {
  description = "Namespace Argo CD is installed into (null when disabled)."
  value       = var.argocd_enabled ? var.argocd_namespace : null
}

output "argocd_admin_password_cmd" {
  description = "Command to read the initial Argo CD admin password."
  value       = "kubectl -n ${var.argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

output "argocd_port_forward_cmd" {
  description = "Command to expose the Argo CD UI locally on https://localhost:8081."
  value       = "kubectl -n ${var.argocd_namespace} port-forward svc/argocd-server 8081:443"
}

output "argo_rollouts_namespace" {
  description = "Namespace Argo Rollouts is installed into (null when disabled)."
  value       = var.argo_rollouts_enabled ? var.argo_rollouts_namespace : null
}

output "local_registry" {
  description = "Host address of the local registry (null when disabled). Tag and push images here."
  value       = var.local_registry_enabled ? "localhost:${var.local_registry_port}" : null
}
