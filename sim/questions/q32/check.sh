#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
D="deploy pyxis-api -n pyxis"
C='{.spec.template.spec.containers[0]'

env_ok() {
  is "$(jp $D -o jsonpath="$C.env[?(@.name==\"MODE\")].value}")" "production" &&
    is "$(jp $D -o jsonpath="$C.env[?(@.name==\"LOG_LEVEL\")].value}")" "info"
}
check "env MODE=production and LOG_LEVEL=info" env_ok

resources_ok() {
  is "$(jp $D -o jsonpath="$C.resources.requests.cpu} $C.resources.requests.memory} $C.resources.limits.memory}")" "50m 64Mi 128Mi"
}
check "requests cpu 50m / memory 64Mi, limit memory 128Mi" resources_ok
check "Pod template has label version=v2" is "$(jp $D -o jsonpath='{.spec.template.metadata.labels.version}')" "v2"
check "Deployment has annotation owner=team-pyxis" is "$(jp $D -o jsonpath='{.metadata.annotations.owner}')" "team-pyxis"

# Only scores once the changes are in, so a fresh reset gives 0.
rolled_out() {
  env_ok && resources_ok &&
    is "$(jp $D -o jsonpath='{.status.updatedReplicas}/{.status.availableReplicas}/{.status.replicas}')" "3/3/3" &&
    [ "$(jp pods -n pyxis -l app=pyxis-api,version=v2 --field-selector=status.phase=Running -o name | grep -c .)" -ge 3 ]
}
check "all 3 replicas updated and available, carrying version=v2" rolled_out

finish
