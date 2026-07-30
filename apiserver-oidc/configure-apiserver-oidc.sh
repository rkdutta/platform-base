#!/bin/sh
# Runs INSIDE the kind control-plane node (docker exec). Adds the Keycloak OIDC
# authenticator flags to the kube-apiserver static-pod manifest so human
# Keycloak tokens authenticate against the cluster (teams-operator's Group
# RoleBindings then give them effect). Replaces the manual "step 2" in
# platform-infra/bootstrap/README.md.
#
# Idempotent: if the flags are already present it only reloads the (possibly
# rotated) OIDC CA; otherwise it inserts the flags, which kubelet picks up by
# recreating the static pod. The OIDC CA file itself (oidc-ca.crt) is
# docker cp'd into place by Terraform BEFORE this runs.
#
# Inputs (env): ISSUER_URL CLIENT_ID USERNAME_CLAIM GROUPS_CLAIM CA_PATH
set -e

MANIFEST=/etc/kubernetes/manifests/kube-apiserver.yaml

# The block is inserted right after the existing --client-ca-file line, matching
# its 4-space list indentation. Why these specific flags (see README step 2):
#   --oidc-username-prefix=-  : suppress the default "<issuer>#" username prefix
#                               so plain usernames match teams-operator's RBAC.
#   --oidc-groups-claim=groups: no default prefix on groups (verified), so a
#                               token's raw groups match the namespace-derived
#                               {ns}-viewer/-maintainer Group RoleBindings.
OIDC_BLOCK="    - --oidc-issuer-url=${ISSUER_URL}
    - --oidc-client-id=${CLIENT_ID}
    - --oidc-username-claim=${USERNAME_CLAIM}
    - --oidc-username-prefix=-
    - --oidc-ca-file=${CA_PATH}
    - --oidc-groups-claim=${GROUPS_CLAIM}"

reload_apiserver() {
  # Force kubelet to recreate the static pod by moving the manifest OUT of the
  # directory briefly and back. IMPORTANT: the temp copy must live OUTSIDE
  # /etc/kubernetes/manifests/ — kubelet's static-pod file source doesn't filter
  # by extension, so a second file there defining kube-apiserver makes kubelet
  # flip-flop between configs (this bit us once; see README step 2).
  mv "$MANIFEST" /tmp/kube-apiserver.yaml.reload
  sleep 2
  mv /tmp/kube-apiserver.yaml.reload "$MANIFEST"
}

if grep -q -- '--oidc-issuer-url=' "$MANIFEST"; then
  echo ">> OIDC flags already present — reloading apiserver to pick up the current oidc-ca.crt"
  reload_apiserver
else
  echo ">> inserting OIDC flags into $MANIFEST"
  tmp=/tmp/kube-apiserver.yaml.new
  awk -v block="$OIDC_BLOCK" '
    { print }
    /--client-ca-file=/ { print block }
  ' "$MANIFEST" > "$tmp"
  # Sanity check the edit produced the flags before swapping it in.
  grep -q -- '--oidc-issuer-url=' "$tmp"
  mv "$tmp" "$MANIFEST"
  echo ">> OIDC flags added; kubelet will recreate the apiserver static pod"
fi
