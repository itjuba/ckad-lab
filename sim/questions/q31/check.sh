#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
D="deploy octans-web -n octans"
S="svc octans-web -n octans"

spec_ok() {
  is "$(jp $D -o jsonpath='{.spec.template.metadata.labels.app}')" "octans-web" &&
    is "$(jp $D -o jsonpath='{.spec.template.spec.containers[0].ports[0].containerPort}')" "80"
}
check "Deployment octans-web exists with Pod label app=octans-web and container port 80" spec_ok
check "4 replicas" is "$(jp $D -o jsonpath='{.spec.replicas}')" "4"
check "image is nginx:1.29-alpine" is "$(jp $D -o jsonpath='{.spec.template.spec.containers[0].image}')" "nginx:1.29-alpine"

rolled_out() {
  is "$(jp $D -o jsonpath='{.status.updatedReplicas}/{.status.availableReplicas}/{.status.replicas}')" "4/4/4"
}
check "rollout finished: 4/4 Pods updated and available" rolled_out

history_ok() {
  local f=$COURSE/31/history
  [ -f "$f" ] && grep -q "REVISION" "$f" && [ "$(grep -cE '^[0-9]+' "$f")" -ge 2 ]
}
check "history holds the rollout history with at least 2 revisions" history_ok

svc_ok() {
  is "$(jp $S -o jsonpath='{.spec.type} {.spec.ports[0].port} {.spec.ports[0].targetPort}')" "ClusterIP 8080 80"
}
check "Service octans-web: ClusterIP, port 8080 -> 80" svc_ok

endpoints_ok() {
  [ "$(jp endpointslices -n octans -l kubernetes.io/service-name=octans-web \
    -o jsonpath='{range .items[*].endpoints[?(@.conditions.ready==true)]}{.addresses[0]}{"\n"}{end}' | grep -c .)" = 4 ]
}
check "Service octans-web has 4 ready endpoints" endpoints_ok

finish
