#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
NS=carina
CM="cm gateway-config-v2 -n $NS"
EXPECTED=$(printf 'GW_MODE=edge\nGW_REGION=eu-west\nGW_TIMEOUT=30s')

check "ConfigMap gateway-config-v2 has keys GW_MODE, GW_TIMEOUT, GW_REGION from the env file" \
  is "$(jp $CM -o jsonpath='{.data.GW_MODE} {.data.GW_TIMEOUT} {.data.GW_REGION}')" "edge 30s eu-west"
check "gateway-config-v2 is immutable" is "$(jp $CM -o jsonpath='{.immutable}')" "true"

refs_only_v2() {
  local tpl
  tpl=$(jp deploy carina-gateway -n $NS -o jsonpath='{.spec.template}')
  has "$tpl" "gateway-config-v2" && ! has "$tpl" "gateway-config-v1"
}
check "Deployment references gateway-config-v2 and not gateway-config-v1" refs_only_v2

new_pods_ok() {
  local pod
  kubectl rollout status deploy/carina-gateway -n $NS --timeout=5s || return 1
  for pod in $(jp pods -n $NS -l app=carina-gateway --field-selector=status.phase=Running -o name); do
    [ -n "$(jp "$pod" -n $NS -o jsonpath='{.metadata.deletionTimestamp}')" ] && continue
    [ "$(kubectl exec -n $NS "$pod" -- printenv GW_MODE 2>/dev/null)" = "edge" ] || return 1
  done
}
check "Rollout is complete and running Pods have GW_MODE=edge" new_pods_ok

check "/opt/course/15/env.txt has the sorted GW_ variables" \
  is "$(sed 's/[[:space:]]*$//; /^$/d' "$COURSE/15/env.txt" 2>/dev/null)" "$EXPECTED"
check "ConfigMap gateway-config-v1 is deleted" bash -c '! kubectl get cm gateway-config-v1 -n carina'

finish
