#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
NS=auriga
D="deploy auriga-ledger -n $NS"
SC='{.spec.template.spec.initContainers[?(@.name=="log-shipper")]'

check "log-shipper is an initContainer with restartPolicy: Always (native sidecar)" \
  is "$(jp $D -o jsonpath="$SC.restartPolicy}")" "Always"

runs_tail() {
  local cmd
  cmd=$(jp $D -o jsonpath="$SC.image} $SC.command} $SC.args}")
  has "$cmd" "busybox:1.37" && has "$cmd" "tail" && has "$cmd" "/var/log/ledger/ledger.log"
}
check "log-shipper runs busybox:1.37 with tail -F /var/log/ledger/ledger.log" runs_tail
check "log-shipper mounts volume logs at /var/log/ledger" \
  is "$(jp $D -o jsonpath="$SC.volumeMounts[?(@.name==\"logs\")].mountPath}")" "/var/log/ledger"

# Name of a live Pod whose log-shipper sidecar is ready.
sidecar_pod() {
  local p
  for p in $(jp pods -n $NS -l app=auriga-ledger -o name); do
    [ -n "$(jp "$p" -n $NS -o jsonpath='{.metadata.deletionTimestamp}')" ] && continue
    [ "$(jp "$p" -n $NS -o jsonpath='{.status.initContainerStatuses[?(@.name=="log-shipper")].ready}')" = "true" ] && echo "$p" && return
  done
  return 1
}
rollout_ok() { kubectl rollout status deploy/auriga-ledger -n $NS --timeout=5s && sidecar_pod; }
check "Rollout is complete and the log-shipper sidecar is running" rollout_ok

check "/opt/course/16/ledger.log contains ledger entries" file_has "$COURSE/16/ledger.log" "ledger entry"

live_logs() {
  local p
  p=$(sidecar_pod) || return 1
  kubectl logs -n $NS "$p" -c log-shipper --tail=5 | grep -q "ledger entry"
}
check "kubectl logs -c log-shipper shows the ledger log" live_logs

finish
