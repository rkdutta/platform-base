#!/usr/bin/env bash
# platform-base unit tests: static/local checks, no live cluster needed.
# Run from anywhere: cd "$(dirname "$0")/../.." && tests/unit/run.sh
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source tests/lib.sh

PLATFORM_INFRA="${PLATFORM_INFRA:-../platform-infra}"
TLS_CRT="${PLATFORM_TLS_CERT:-$PLATFORM_INFRA/bootstrap/platform-tls.crt}"

# --- Terraform ---------------------------------------------------------------
check "terraform-fmt" "*.tf" -- terraform fmt -check -recursive

terraform init -backend=false >/tmp/tf-init.log 2>&1
check "terraform-validate" "*.tf" -- terraform validate

# --- platform-tls must be a CA (gotcha: platform-tls-must-be-ca) -------------
tls_is_ca() {
  [ -f "$TLS_CRT" ] || { echo "cert not found at $TLS_CRT — run 'terraform apply' first"; return 1; }
  openssl x509 -in "$TLS_CRT" -noout -text | grep -q "CA:TRUE" || { echo "cert exists but is not CA:TRUE"; return 1; }
}
check "platform-tls-is-ca" "platform-tls.tf" -- tls_is_ca

# --- node-hosts fix script must stay identical in both repos (gotcha found --
# this drifted once already: platform-infra's copy silently fell behind the
# operative one when Harbor routing moved from the ClusterIP to
# host.docker.internal) ---------------------------------------------------
node_hosts_in_sync() {
  local infra_copy="$PLATFORM_INFRA/bootstrap/node-hosts/platform-hosts-fix.sh"
  [ -f "$infra_copy" ] || { echo "reference copy not found at $infra_copy"; return 1; }
  diff -q node-hosts/platform-hosts-fix.sh "$infra_copy" >/dev/null || { echo "node-hosts/platform-hosts-fix.sh differs from $infra_copy"; return 1; }
}
check "node-hosts-two-copies-in-sync" "node-hosts/platform-hosts-fix.sh" -- node_hosts_in_sync

report
