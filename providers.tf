provider "kind" {}

# Talks to the local Docker daemon to run the local registry container. The
# provider ignores docker contexts, so point it at the right socket explicitly
# via var.docker_host (needed for colima); empty falls back to DOCKER_HOST/default.
provider "docker" {
  host = var.docker_host != "" ? var.docker_host : null
}

# Applies the local-registry-hosting ConfigMap into the kind cluster. Credentials
# come from the cluster resource, so this provider depends on the cluster too.
provider "kubernetes" {
  host                   = kind_cluster.this.endpoint
  client_certificate     = kind_cluster.this.client_certificate
  client_key             = kind_cluster.this.client_key
  cluster_ca_certificate = kind_cluster.this.cluster_ca_certificate
}

# Connect Helm to the kind cluster using the credentials the cluster resource
# exposes. Referencing kind_cluster.this here makes every Helm release depend on
# the cluster, so Terraform creates the cluster before installing charts.
provider "helm" {
  kubernetes {
    host                   = kind_cluster.this.endpoint
    client_certificate     = kind_cluster.this.client_certificate
    client_key             = kind_cluster.this.client_key
    cluster_ca_certificate = kind_cluster.this.cluster_ca_certificate
  }
}
