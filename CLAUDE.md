# platform-base — cluster & platform bootstrap (Terraform)

Terraform that stands up the `kind` cluster this platform runs on, plus
Argo CD and Argo Rollouts. Own git remote (`rkdutta/platform-base`) —
changes here don't touch `platform-infra` (GitOps manifests) or
`platform-idp` (app code). See `../CLAUDE.md` for the platform-wide picture.

## Features this repo delivers

### The `kind` cluster (`main.tf`)
- One control-plane + `var.worker_count` workers (pinned to
  `kindest/node:<var.kubernetes_version>` when set).
- **Apiserver endpoint pinned** to `https://<api_server_address>:<api_server_port>`
  (default `127.0.0.1:6443`) via `networking.api_server_port` — stable across
  recreations. Without this, Docker assigns a random host port every time,
  which breaks every pinned kubeconfig/ConfigMap on a rebuild. The cluster CA
  still rotates on a full recreate, so `platform-infra`'s
  `make teams-api-access` is still needed after one.
- **Harbor host-port hairpin**: an extra `443 -> harbor_registry_host_port`
  mapping alongside the standard `80/443` ingress mappings, so in-cluster
  pull traffic that lands on the host via `host.docker.internal` can reach
  the ingress on both the default `:443` pull path and Harbor's `:8443`
  token-realm redirect.
- Optional local registry (`registry.tf`, `local_registry_enabled`), wired
  via `containerd_config_patches` as a `kindest/node` built-in mirror,
  independent of Harbor.

### Argo CD (`argocd.tf`)
- Installed via the official Helm chart (`argocd_chart_version`), namespace
  `argocd`.
- **Native OIDC** (not Dex) against Keycloak, gated by `argocd_oidc_enabled`
  / `argocd_oidc_issuer_url` / `argocd_oidc_client_secret`.
- `argocd-rbac-cm`'s **static baseline** policy (the admin group mapping);
  `teams-operator` (in `platform-idp`) layers a per-project Casbin policy
  block on top of this at runtime — see `platform-infra/CLAUDE.md`.
- Optional ingress (`argocd_ingress_enabled` / `argocd_ingress_host`).

### Argo Rollouts (`rollouts.tf`)
- Installed via Helm (`argo_rollouts_chart_version`), gated by
  `argo_rollouts_enabled`.
- Optional dashboard + ingress (`argo_rollouts_dashboard_*`).

### `platform-tls` — the wildcard cert (`platform-tls.tf`)
- Generates the self-signed `*.127.0.0.1.sslip.io` cert/key **as a Terraform
  resource**, not read from the cluster — breaks a chicken-and-egg where
  Argo CD's OIDC config needs Keycloak's CA before Keycloak (which is
  deployed BY Argo CD) exists.
- **Must stay `is_ca_certificate = true`** (+ `cert_signing`/`crl_signing` in
  `allowed_uses`) — a leaf cert here makes every OIDC login fail Go x509
  "parent certificate cannot sign this kind of certificate": `kubectl
  oidc-login` verifying Keycloak, OpenBao's and Harbor's OIDC discovery,
  containerd, and the apiserver's `oidc-ca.crt` all pin this one cert as
  their trust anchor.
- Written to `platform_tls_output_dir` (default the sibling
  `platform-infra/bootstrap/`) for `create-secrets.sh` to distribute into
  the namespaces that need it. Regenerating the cert re-triggers the
  CA-hash-keyed `node-containerd-trust`/`apiserver-oidc` resources below
  automatically — but the Kubernetes Secrets built from it are NOT
  Terraform-managed, so `create-secrets.sh`, `make teams-api-access`,
  `make openbao-sso`/`harbor-sso`, all need re-running by hand after a cert
  change.

### Durable node-level fixes (survive both restart *and* full recreate)
Each of these is a `null_resource` keyed on a hash of the cluster CA or the
cert, so it re-runs automatically on a cluster recreate — no manual `docker
exec` step needed for any of them anymore:
- **`node-hosts.tf`** — installs a `platform-hosts.service` systemd unit
  (`bootstrap/node-hosts/`) on every node, enabled and ordered
  `Before=kubelet.service`, that re-adds two `/etc/hosts` entries on every
  boot: `platform-auth.127.0.0.1.sslip.io` (so the apiserver can reach
  Keycloak for OIDC token validation) and `harbor.127.0.0.1.sslip.io` (so
  containerd can pull from Harbor). Docker regenerates node `/etc/hosts` on
  every container restart, which used to silently break both OIDC login
  (401, apiserver logs `dial tcp 127.0.0.1:8443: connection refused`) and
  Harbor pulls after every restart — fixed at the source now. The Harbor
  target IP is the ingress ClusterIP, pinned via
  `apps/resource/ingress-nginx` (`controller.service.clusterIP`) in
  `platform-infra` to match the value hardcoded in the unit.
- **`node-containerd-trust.tf`** — pushes the `platform-tls` CA into each
  node's trust store and reloads containerd, so image pulls from Harbor
  don't hit "x509: certificate signed by unknown authority".
- **`apiserver-oidc.tf`** — inserts the `--oidc-*` flags + `oidc-ca.crt` into
  the kube-apiserver static-pod manifest (an idempotent awk insert after
  `--client-ca-file`, not a duplicate-file trap — a stray second manifest
  file in `/etc/kubernetes/manifests/` makes kubelet recreate the pod from
  whichever file it picks, silently). Issuer reuses `argocd_oidc_issuer_url`
  (one issuer, no drift). New vars: `apiserver_oidc_enabled` (default true),
  `apiserver_oidc_client_id` (`teams-cli`), `apiserver_oidc_username_claim`
  (`preferred_username`), `apiserver_oidc_groups_claim` (`groups`). Blocks
  on `/livez` after the manifest-triggered apiserver bounce, and
  `helm_release.argocd`/`argo_rollouts` `depends_on` it — specifically to
  avoid a `terraform apply`/`make bootstrap` race where the reload happens
  mid-Helm-install and fails with "Kubernetes cluster unreachable ... EOF".

## Known gotchas specific to this repo

- **Provider deadlock on any `kind_cluster` ForceNew change** (e.g. editing
  a port mapping): the resource going `(known after apply)` makes the
  helm/kubernetes providers (configured from its attributes) fall back to
  localhost and fail with "cluster unreachable". Workaround: apply in two
  steps — `terraform apply -target=kind_cluster.this` first, then a plain
  `terraform apply` (sometimes needed twice more for an apiserver-startup
  race). Not structurally fixed — would need splitting cluster state from
  in-cluster resources into separate state/workspaces.
- A **full `terraform destroy` + `apply`** is the Terraform equivalent of
  `kind delete` + recreate and does **not** hit the ForceNew-replace
  deadlock above (nothing stale to reference) — prefer that over forcing a
  replace in place when rebuilding from scratch.
