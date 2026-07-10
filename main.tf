resource "kind_cluster" "this" {
  name            = var.cluster_name
  node_image      = var.kubernetes_version != "" ? "kindest/node:${var.kubernetes_version}" : null
  kubeconfig_path = var.kubeconfig_path
  wait_for_ready  = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    # Control-plane node.
    node {
      role = "control-plane"

      # Label the node so ingress-nginx's default nodeSelector schedules onto it.
      kubeadm_config_patches = var.ingress_ready ? [
        <<-EOT
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
        EOT
      ] : []

      # Expose host ports into the cluster for an ingress controller.
      dynamic "extra_port_mappings" {
        for_each = var.ingress_ready ? [
          { container = 80, host = var.ingress_http_host_port },
          { container = 443, host = var.ingress_https_host_port },
        ] : []
        content {
          container_port = extra_port_mappings.value.container
          host_port      = extra_port_mappings.value.host
          protocol       = "TCP"
        }
      }
    }

    # Worker nodes.
    dynamic "node" {
      for_each = range(var.worker_count)
      content {
        role = "worker"
      }
    }
  }
}
