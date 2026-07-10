variable "cluster_name" {
  description = "Name of the kind cluster."
  type        = string
  default     = "platform-base"
}

variable "kubernetes_version" {
  description = "Kubernetes version, given as a kind node image tag (e.g. v1.31.0). Leave empty to use the kind provider default."
  type        = string
  default     = "v1.31.0"
}

variable "worker_count" {
  description = "Number of worker nodes to create in addition to the control-plane node."
  type        = number
  default     = 2

  validation {
    condition     = var.worker_count >= 0
    error_message = "worker_count must be zero or greater."
  }
}

variable "ingress_ready" {
  description = "Label the control-plane node and map host ports so an ingress controller can be installed later."
  type        = bool
  default     = true
}

variable "ingress_http_host_port" {
  description = "Host port mapped to the control-plane's container port 80 (HTTP ingress)."
  type        = number
  default     = 8080
}

variable "ingress_https_host_port" {
  description = "Host port mapped to the control-plane's container port 443 (HTTPS ingress)."
  type        = number
  default     = 8443
}

variable "argocd_enabled" {
  description = "Install Argo CD into the cluster."
  type        = bool
  default     = true
}

variable "argocd_namespace" {
  description = "Namespace Argo CD is installed into."
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "Version of the argo-cd Helm chart. Pinned for reproducible releases; empty string installs the latest available version."
  type        = string
  default     = "10.1.3"
}

variable "kubeconfig_path" {
  description = "Path where the generated kubeconfig is written."
  type        = string
  default     = "./kubeconfig"
}
