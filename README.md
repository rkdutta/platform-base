# platform-base

Provisions a local Kubernetes cluster on macOS using [kind](https://kind.sigs.k8s.io/),
managed with Terraform via the [`tehcyx/kind`](https://registry.terraform.io/providers/tehcyx/kind/latest)
provider.

## Prerequisites

- [Docker](https://www.docker.com/) running
- [Terraform](https://developer.hashicorp.com/terraform) >= 1.6
- [kind](https://kind.sigs.k8s.io/) and [kubectl](https://kubernetes.io/docs/tasks/tools/) (kind is driven by the provider; kubectl is for using the cluster)

## Usage

```sh
terraform init
terraform plan
terraform apply
```

This creates the kind cluster and installs Argo CD into it in a single apply.

Point kubectl at the new cluster:

```sh
export KUBECONFIG=$(pwd)/kubeconfig   # or: kubectl config use-context kind-platform-base
kubectl get nodes
```

### Argo CD

Argo CD is installed via its Helm chart (toggle with `argocd_enabled`). After apply:

```sh
# Initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo

# Open the UI at https://localhost:8081 (user: admin)
kubectl -n argocd port-forward svc/argocd-server 8081:443
```

The `terraform output` values `argocd_admin_password_cmd` and `argocd_port_forward_cmd` print these commands.

### Argo Rollouts

Argo Rollouts (progressive delivery: canary / blue-green) is installed via its
Helm chart (toggle with `argo_rollouts_enabled`). The controller runs in the
`argocd` namespace:

```sh
kubectl -n argocd get pods -l app.kubernetes.io/name=argo-rollouts
```

Manage `Rollout` resources with the kubectl plugin (installed separately):

```sh
kubectl argo rollouts dashboard   # UI at http://localhost:3100
```

Tear it down:

```sh
terraform destroy
```

## Configuration

Override defaults with a `terraform.tfvars` file (see `example.tfvars`):

| Variable             | Default         | Description                                                                   |
| -------------------- | --------------- | ----------------------------------------------------------------------------- |
| `cluster_name`       | `platform-base` | Name of the kind cluster.                                                      |
| `kubernetes_version` | `v1.31.0`       | kind node image tag. Empty string uses the provider default.                  |
| `worker_count`       | `2`             | Worker nodes in addition to the control-plane.                                |
| `ingress_ready`      | `true`          | Label the control-plane and map ingress host ports for an ingress controller.  |
| `ingress_http_host_port`  | `8080`     | Host port mapped to container port 80 (HTTP ingress).                          |
| `ingress_https_host_port` | `8443`     | Host port mapped to container port 443 (HTTPS ingress).                        |
| `argocd_enabled`     | `true`          | Install Argo CD via its Helm chart.                                            |
| `argocd_namespace`   | `argocd`        | Namespace Argo CD is installed into.                                           |
| `argocd_chart_version` | `10.1.3`      | Version of the `argo-cd` Helm chart to install.                               |
| `argo_rollouts_enabled` | `true`       | Install Argo Rollouts via its Helm chart.                                     |
| `argo_rollouts_namespace` | `argocd`     | Namespace Argo Rollouts is installed into.                                     |
| `argo_rollouts_chart_version` | `2.41.0` | Version of the `argo-rollouts` Helm chart to install.                         |
| `kubeconfig_path`    | `./kubeconfig`  | Where the generated kubeconfig is written.                                     |

## Releases

This repo is versioned with [Semantic Versioning](https://semver.org/) and Git
tags (`vX.Y.Z`). Changes are tracked in [`CHANGELOG.md`](CHANGELOG.md); the
release process is documented in [`RELEASING.md`](RELEASING.md). Pushing a
`vX.Y.Z` tag triggers the Release workflow, which validates the Terraform and
publishes a GitHub Release from the matching changelog section.

## Layout

- `versions.tf` — Terraform and provider version constraints
- `providers.tf` — provider configuration
- `variables.tf` — input variables
- `main.tf` — the `kind_cluster` resource
- `argocd.tf` — Argo CD Helm release
- `rollouts.tf` — Argo Rollouts Helm release
- `outputs.tf` — cluster name, endpoint, kubeconfig path, kubectl context, Argo CD helpers
- `CHANGELOG.md` / `RELEASING.md` — release notes and release process
- `.github/workflows/` — `ci.yml` (validate) and `release.yml` (publish releases)
