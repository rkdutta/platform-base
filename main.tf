resource "kind_cluster" "this" {
  name            = var.cluster_name
  node_image      = var.kubernetes_version != "" ? "kindest/node:${var.kubernetes_version}" : null
  kubeconfig_path = var.kubeconfig_path
  wait_for_ready  = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    # Pin the apiserver host address/port so the cluster endpoint is stable
    # across recreations. Without this, Docker assigns a random host port each
    # time (e.g. 50655, 58309, ...), which is exactly what makes teams-api's
    # kubeconfig server URL and any pinned endpoint go stale on every rebuild.
    # The cluster CA still rotates per recreate, so teams-api-k8s-access still
    # needs refreshing — but the endpoint no longer moves. See variables
    # api_server_address / api_server_port.
    networking {
      api_server_address = var.api_server_address
      api_server_port    = var.api_server_port
    }

    # Point containerd at the local registry: images tagged
    # localhost:<port>/... are pulled from the kind-registry container over the
    # shared "kind" docker network. See registry.tf.
    containerd_config_patches = var.local_registry_enabled ? [
      <<-EOT
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${var.local_registry_port}"]
        endpoint = ["http://${var.local_registry_name}:5000"]
      EOT
    ] : []

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
      # The extra 443->443 mapping (alongside 443->8443) lets in-cluster
      # clients reach the ingress on the DEFAULT https port via
      # host.docker.internal — needed for Harbor: containerd pulls
      # harbor.127.0.0.1.sslip.io/... (port 443) and then follows Harbor's
      # token realm to :8443, and the node routes that host to
      # host.docker.internal (see node-hosts/platform-hosts-fix.sh), so BOTH
      # host ports must forward to the ingress. Same hairpin the apiserver
      # already uses to reach Keycloak on :8443.
      dynamic "extra_port_mappings" {
        for_each = var.ingress_ready ? [
          { container = 80, host = var.ingress_http_host_port },
          { container = 443, host = var.ingress_https_host_port },
          { container = 443, host = var.harbor_registry_host_port },
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
