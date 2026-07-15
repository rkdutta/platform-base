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
  default     = 1

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

variable "argocd_ingress_enabled" {
  description = "Create an Ingress exposing the Argo CD server UI via ingress-nginx."
  type        = bool
  default     = true
}

variable "argocd_ingress_host" {
  description = "Hostname for the Argo CD UI Ingress. Reachable on the ingress HTTP host port, e.g. http://argocd.127.0.0.1.sslip.io:8080."
  type        = string
  default     = "argocd.127.0.0.1.sslip.io"
}

variable "argo_rollouts_enabled" {
  description = "Install Argo Rollouts (progressive delivery controller) into the cluster."
  type        = bool
  default     = true
}

variable "argo_rollouts_namespace" {
  description = "Namespace Argo Rollouts is installed into."
  type        = string
  default     = "argocd"
}

variable "argo_rollouts_chart_version" {
  description = "Version of the argo-rollouts Helm chart. Pinned for reproducible releases; empty string installs the latest available version."
  type        = string
  default     = "2.41.0"
}

variable "argo_rollouts_dashboard_enabled" {
  description = "Enable the Argo Rollouts dashboard (web UI) in the argo-rollouts Helm release."
  type        = bool
  default     = true
}

variable "argo_rollouts_dashboard_ingress_enabled" {
  description = "Create an Ingress exposing the Argo Rollouts dashboard via ingress-nginx."
  type        = bool
  default     = true
}

variable "argo_rollouts_dashboard_ingress_host" {
  description = "Hostname for the Argo Rollouts dashboard Ingress. Reachable on the ingress HTTP host port, e.g. http://rollouts.127.0.0.1.sslip.io:8080."
  type        = string
  default     = "rollouts.127.0.0.1.sslip.io"
}

variable "local_registry_enabled" {
  description = "Run a local OCI registry container and wire the cluster to it (https://kind.sigs.k8s.io/docs/user/local-registry/)."
  type        = bool
  default     = true
}

variable "docker_host" {
  description = "Docker daemon socket for the docker provider. Needed because the provider ignores docker contexts and only honours DOCKER_HOST/this. Leave empty to use DOCKER_HOST or the default socket; on colima set e.g. unix:///Users/<you>/.colima/default/docker.sock."
  type        = string
  default     = "unix:///Users/rdutta/.colima/default/docker.sock"
}

variable "local_registry_name" {
  description = "Name of the registry container. Also its DNS name on the kind docker network, so cluster nodes reach it at http://<name>:5000."
  type        = string
  default     = "kind-registry"
}

variable "local_registry_port" {
  description = "Host port the registry is published on. Push images to localhost:<port> and reference them from manifests the same way."
  type        = number
  default     = 5001
}

variable "local_registry_image" {
  description = "Registry container image. Pinned for reproducibility."
  type        = string
  default     = "registry:2.8.3"
}

variable "kubeconfig_path" {
  description = "Path where the generated kubeconfig is written."
  type        = string
  default     = "./kubeconfig"
}
