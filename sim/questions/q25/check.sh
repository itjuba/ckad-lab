#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
D=$COURSE/25
pod_of() { jp pods -n lynx -l "app=$1" -o jsonpath='{.items[0].metadata.name}'; }
answer() { tr -d '[:space:]' <"$D/$1" 2>/dev/null | sed 's|^pod/||'; }

check "top-cpu names the Pod using the most CPU" is "$(answer top-cpu)" "$(pod_of lynx-crunch)"
check "top-mem names the Pod using the most memory" is "$(answer top-mem)" "$(pod_of lynx-hoard)"

script_ok() {
  local out
  out=$(bash "$D/node-usage.sh" 2>/dev/null)
  has "$out" "k3d-ckad-server-0" && has "$out" "k3d-ckad-agent-0" && grep -qi "memory" <<<"$out"
}
check "node-usage.sh shows CPU and memory for every node" script_ok

check "flaky-reason is the last termination reason" \
  is "$(answer flaky-reason)" "$(jp pod lynx-flaky -n lynx -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}')"

finish
