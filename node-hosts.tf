# -----------------------------------------------------------------------------
# Durable kind-node /etc/hosts routing fix.
#
# Docker regenerates each kind node container's /etc/hosts on every start,
# wiping the manual *.127.0.0.1.sslip.io routing entries the platform needs
# from the node itself:
#   - kube-apiserver (hostNetwork static pod) -> Keycloak, for OIDC token
#     validation. Without it, every OIDC kubectl login fails with 401.
#   - containerd -> Harbor, for pulling tenant images (ErrImagePull otherwise).
#
# This installs a systemd oneshot unit (ordered Before=kubelet.service) on every
# node that re-adds those entries on each boot. Because it's baked in here, it
# survives not just node restarts but full cluster recreation (kind delete +
# apply). The unit/script are versioned under ./node-hosts/. This is node-level
# plumbing outside Kubernetes' reach, so it cannot be GitOps-managed.
# -----------------------------------------------------------------------------

locals {
  # kind names the control-plane "<cluster>-control-plane" and workers
  # "<cluster>-worker", "<cluster>-worker2", "<cluster>-worker3", ...
  kind_nodes = concat(
    ["${var.cluster_name}-control-plane"],
    [for i in range(var.worker_count) : i == 0 ? "${var.cluster_name}-worker" : "${var.cluster_name}-worker${i + 1}"],
  )
}

resource "null_resource" "node_hosts_fix" {
  for_each = toset(local.kind_nodes)

  triggers = {
    # cluster_ca_certificate is reissued when the cluster is recreated, so this
    # re-runs the install on a fresh cluster (node names alone are stable and
    # would not trigger a re-run).
    cluster_ca  = sha256(kind_cluster.this.cluster_ca_certificate)
    script_hash = filemd5("${path.module}/node-hosts/platform-hosts-fix.sh")
    unit_hash   = filemd5("${path.module}/node-hosts/platform-hosts.service")
    node        = each.value
  }

  provisioner "local-exec" {
    interpreter = ["/bin/sh", "-c"]
    # Point the docker CLI at the same daemon the docker provider uses (colima).
    environment = {
      DOCKER_HOST = var.docker_host
    }
    command = <<-EOT
      set -e
      node="${each.value}"
      docker cp "${path.module}/node-hosts/platform-hosts-fix.sh"  "$node:/usr/local/bin/platform-hosts-fix.sh"
      docker cp "${path.module}/node-hosts/platform-hosts.service" "$node:/etc/systemd/system/platform-hosts.service"
      docker exec "$node" sh -c 'chmod +x /usr/local/bin/platform-hosts-fix.sh && systemctl daemon-reload && systemctl enable --now platform-hosts.service'
      echo "platform-hosts.service installed on $node"
    EOT
  }

  # wait_for_ready on the cluster ensures the node containers exist first.
  depends_on = [kind_cluster.this]
}
