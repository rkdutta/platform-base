provider "kind" {}

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
