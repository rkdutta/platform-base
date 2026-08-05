#!/usr/bin/env bash
# platform-base e2e tests: confirm the LIVE cluster actually has the fixes
# this repo is supposed to deliver. Needs a reachable kind cluster (the
# current kubectl context) and `docker` access to its node containers.
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source tests/lib.sh

CLUSTER_NAME="${CLUSTER_NAME:-platform-base}"
API_SERVER_URL="${API_SERVER_URL:-https://127.0.0.1:6443}"
NODES=$(docker ps --format '{{.Names}}' | grep "^${CLUSTER_NAME}-" || true)

if [ -z "$NODES" ]; then
  echo "FAIL: 0/0 (0%)"
  echo "  setup :: docker :: no '${CLUSTER_NAME}-*' node containers found — is the cluster up?"
  exit 1
fi

# --- apiserver endpoint pinned (gotcha: random host port on recreate) -------
apiserver_pinned() {
  local server
  server=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
  [ "$server" = "$API_SERVER_URL" ] || { echo "server=$server, expected $API_SERVER_URL"; return 1; }
}
check "apiserver-port-pinned" "main.tf" -- apiserver_pinned

check "apiserver-livez" "apiserver-oidc.tf" -- bash -c "[ \"\$(kubectl get --raw='/livez')\" = ok ]"

# --- apiserver manifest: no stray duplicate file, oidc flags present --------
apiserver_manifest_sane() {
  local files
  files=$(docker exec "${CLUSTER_NAME}-control-plane" sh -c 'ls /etc/kubernetes/manifests | grep -c kube-apiserver')
  [ "$files" -eq 1 ] || { echo "expected exactly 1 kube-apiserver manifest file, found $files"; return 1; }
  docker exec "${CLUSTER_NAME}-control-plane" grep -q -- "--oidc-issuer-url" /etc/kubernetes/manifests/kube-apiserver.yaml \
    || { echo "--oidc-issuer-url missing from the static-pod manifest"; return 1; }
}
check "apiserver-manifest-sane" "apiserver-oidc.tf" -- apiserver_manifest_sane

# --- node-hosts: systemd unit active + entries resolve via host.docker.internal
# (not the old, now-vestigial ClusterIP mechanism) ---------------------------
node_hosts_ok() {
  local node
  for node in $NODES; do
    docker exec "$node" systemctl is-active --quiet platform-hosts.service \
      || { echo "$node: platform-hosts.service not active"; return 1; }
    docker exec "$node" grep -q "platform-auth.127.0.0.1.sslip.io" /etc/hosts \
      || { echo "$node: /etc/hosts missing platform-auth entry"; return 1; }
    docker exec "$node" grep -q "harbor.127.0.0.1.sslip.io" /etc/hosts \
      || { echo "$node: /etc/hosts missing harbor entry"; return 1; }
    if docker exec "$node" grep "harbor.127.0.0.1.sslip.io" /etc/hosts | grep -q "^10\.96\."; then
      echo "$node: harbor entry still points at a ClusterIP (stale mechanism) instead of host.docker.internal"
      return 1
    fi
  done
  return 0
}
check "node-hosts-active-and-correct" "node-hosts.tf" -- node_hosts_ok

# --- containerd trusts platform-tls -----------------------------------------
containerd_trust_ok() {
  local node
  for node in $NODES; do
    docker exec "$node" test -f /usr/local/share/ca-certificates/platform-tls.crt \
      || { echo "$node: platform-tls.crt not in containerd's trust store"; return 1; }
  done
}
check "node-containerd-trust" "node-containerd-trust.tf" -- containerd_trust_ok

# --- Harbor host-port hairpin (gotcha: push needs :8443, bare host resolves
# to :443 where nothing listens) ---------------------------------------------
harbor_port_mapping_ok() {
  local mappings
  mappings=$(docker port "${CLUSTER_NAME}-control-plane" 443 2>/dev/null | wc -l | tr -d ' ')
  [ "$mappings" -ge 2 ] || { echo "expected container port 443 mapped to 2+ host ports (443 and 8443), got $mappings"; return 1; }
}
check "harbor-port-hairpin" "main.tf" -- harbor_port_mapping_ok

# --- Argo CD + Argo Rollouts Healthy ------------------------------------------
argocd_healthy() {
  local ns="${ARGOCD_NAMESPACE:-argocd}"
  local not_ready
  not_ready=$(kubectl -n "$ns" get deploy -o json | python3 -c '
import json, sys
d = json.load(sys.stdin)
bad = [i["metadata"]["name"] for i in d["items"]
       if i.get("status", {}).get("readyReplicas", 0) != i["spec"]["replicas"]]
print(",".join(bad))
')
  [ -z "$not_ready" ] || { echo "not-ready deployments in $ns: $not_ready"; return 1; }
  local ctrl_ready ctrl_desired
  ctrl_ready=$(kubectl -n "$ns" get statefulset argocd-application-controller -o jsonpath='{.status.readyReplicas}')
  ctrl_desired=$(kubectl -n "$ns" get statefulset argocd-application-controller -o jsonpath='{.spec.replicas}')
  [ "$ctrl_ready" = "$ctrl_desired" ] || { echo "argocd-application-controller: $ctrl_ready/$ctrl_desired ready"; return 1; }
}
check "argocd-and-rollouts-healthy" "argocd.tf,rollouts.tf" -- argocd_healthy

report
