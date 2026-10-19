#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
D="deploy perseus-web -n perseus"

# rs_field IMAGE JSONPATH : field of the ReplicaSet whose Pods run IMAGE.
rs_field() {
  jp rs -n perseus -l app=perseus-web -o jsonpath="{range .items[?(@.spec.template.spec.containers[0].image==\"$1\")]}$2{\"\n\"}{end}" | head -1
}

# Rolling back to revision 2 re-activates its ReplicaSet under a new revision number (>= 4).
rolled_back() {
  local rev
  rev=$(rs_field nginx:1.28-alpine '{.metadata.annotations.deployment\.kubernetes\.io/revision}')
  [ -n "$rev" ] && [ "$rev" -ge 4 ]
}

check "good-revision contains 2" is "$(tr -d '[:space:]' <"$COURSE/8/good-revision" 2>/dev/null)" "2"
check "Deployment was rolled back to revision 2" rolled_back
check "strategy: maxSurge 1, maxUnavailable 0" \
  is "$(jp $D -o jsonpath='{.spec.strategy.type} {.spec.strategy.rollingUpdate.maxSurge} {.spec.strategy.rollingUpdate.maxUnavailable}')" "RollingUpdate 1 0"
check "image is nginx:1.29-alpine" is "$(jp $D -o jsonpath='{.spec.template.spec.containers[0].image}')" "nginx:1.29-alpine"
check "3/3 replicas updated and available" \
  is "$(jp $D -o jsonpath='{.status.replicas}/{.status.updatedReplicas}/{.status.availableReplicas}')" "3/3/3"
check "rollout history shows change cause 'upgrade to 1.29'" \
  is "$(rs_field nginx:1.29-alpine '{.metadata.annotations.kubernetes\.io/change-cause}')" "upgrade to 1.29"

finish
