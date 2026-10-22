#!/usr/bin/env bash
# Builds the candidate's kubeconfig from the clusters' kubeconfigs in /ckad-state: one
# context per line of /ckad/contexts (ckad-c1, ckad-c2, ...), like the real exam's. It also
# writes one kubeconfig per context under /run/ckad/kube, pinned to that context: the runner
# uses those to set up and grade a question in its own context, whatever context the
# candidate switched to last.
#
#   kubeconfig.sh [OUTPUT]      default output: /root/.kube/config
#
# Cluster N's kubeconfig is /ckad-state/kubeconfig (N=1) or /ckad-state/kubeconfig-N. A
# missing cluster falls back to cluster 1. CKAD_KUBE_SERVER / CKAD_KUBE_SERVER_N override
# the server URL (Docker Compose's k3s writes 127.0.0.1; the clusters answer by host name).
set -euo pipefail
STATE=${CKAD_STATE_DIR:-/ckad-state}
OUT=${1:-/root/.kube/config}
PINNED=${CKAD_KUBE_DIR:-/run/ckad/kube}
CONTEXTS=${CKAD_HOME:-/ckad}/contexts

mkdir -p "$(dirname "$OUT")" "$PINNED"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
files=()
first=
while read -r ctx cluster _; do
  [[ -z $ctx || $ctx == \#* ]] && continue
  src=$STATE/kubeconfig
  [ "${cluster:-1}" != 1 ] && [ -f "$STATE/kubeconfig-$cluster" ] && src=$STATE/kubeconfig-$cluster
  [ -f "$src" ] || { echo "kubeconfig.sh: $src not found, skipping context $ctx" >&2; continue; }
  server_var=CKAD_KUBE_SERVER
  [ "${cluster:-1}" != 1 ] && server_var=CKAD_KUBE_SERVER_$cluster
  # One standalone kubeconfig per context, with the cluster, user and context all named
  # after the context (k3d and k3s name them differently, and both clusters would clash).
  kubectl --kubeconfig "$src" config view --raw --minify --flatten -o json |
    python3 -c '
import json, sys
ctx, server = sys.argv[1], sys.argv[2]
c = json.load(sys.stdin)
c["clusters"][0]["name"] = ctx
c["users"][0]["name"] = ctx
c["contexts"][0]["name"] = ctx
c["contexts"][0]["context"].update({"cluster": ctx, "user": ctx})
c["current-context"] = ctx
if server:
    c["clusters"][0]["cluster"]["server"] = server
json.dump(c, sys.stdout)
' "$ctx" "${!server_var:-}" >"$tmp/$ctx"
  files+=("$tmp/$ctx")
  : "${first:=$ctx}"
done <"$CONTEXTS"
[ ${#files[@]} -gt 0 ] || { echo "kubeconfig.sh: no cluster kubeconfig in $STATE" >&2; exit 1; }

merged=$(IFS=:; echo "${files[*]}")
KUBECONFIG=$merged kubectl config view --raw --flatten >"$tmp/merged"
for f in "${files[@]}"; do
  ctx=$(basename "$f")
  cp "$tmp/merged" "$PINNED/$ctx"
  kubectl --kubeconfig "$PINNED/$ctx" config use-context "$ctx" >/dev/null
done
cp "$PINNED/$first" "$OUT"
chmod 600 "$OUT"
echo "kubeconfig: contexts $(kubectl --kubeconfig "$OUT" config get-contexts -o name | paste -sd' ') (current: $first)"
