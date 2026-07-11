# Local container registry for the kind cluster, following the official recipe:
# https://kind.sigs.k8s.io/docs/user/local-registry/
#
# Usage once applied:
#   docker tag myapp:dev localhost:5001/myapp:dev
#   docker push localhost:5001/myapp:dev
#   # then reference image: localhost:5001/myapp:dev in your manifests

resource "docker_image" "registry" {
  count = var.local_registry_enabled ? 1 : 0
  name  = var.local_registry_image
}

# The registry itself. Published on 127.0.0.1:<port> for pushes from the host,
# and attached to the "kind" docker network (below) so in-cluster pulls resolve
# http://kind-registry:5000.
resource "docker_container" "registry" {
  count = var.local_registry_enabled ? 1 : 0

  name    = var.local_registry_name
  image   = docker_image.registry[0].image_id
  restart = "always"

  ports {
    internal = 5000
    external = var.local_registry_port
    ip       = "127.0.0.1"
  }

  networks_advanced {
    name = data.docker_network.kind[0].name
  }
}

# The "kind" docker network is created by kind when it stands up the cluster, so
# read it only after the cluster exists. Attaching the registry to this network
# is the Terraform equivalent of `docker network connect kind kind-registry`.
data "docker_network" "kind" {
  count      = var.local_registry_enabled ? 1 : 0
  name       = "kind"
  depends_on = [kind_cluster.this]
}

# Advertises the registry to cluster tooling per the KEP-1755 standard. This is
# what makes `kubectl`, Tilt, Skaffold, etc. discover localhost:<port>.
resource "kubernetes_config_map" "local_registry_hosting" {
  count = var.local_registry_enabled ? 1 : 0

  metadata {
    name      = "local-registry-hosting"
    namespace = "kube-public"
  }

  data = {
    "localRegistryHosting.v1" = yamlencode({
      host = "localhost:${var.local_registry_port}"
      help = "https://kind.sigs.k8s.io/docs/user/local-registry/"
    })
  }

  depends_on = [kind_cluster.this]
}
