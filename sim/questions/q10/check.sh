#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
P="pod phoenix-api -n phoenix"
S="svc phoenix-api-svc -n phoenix"

pod_ok() {
  is "$(jp $P -o jsonpath='{.metadata.labels.app} {.spec.containers[0].image} {.status.phase}')" "phoenix-api nginx:1.29-alpine Running" &&
    is "$(jp $P -o jsonpath='{.spec.containers[0].ports[?(@.containerPort==80)].name}')" "http"
}
check "Pod phoenix-api: nginx:1.29-alpine, app=phoenix-api, port 80 named http, Running" pod_ok
check "Service phoenix-api-svc is ClusterIP on port 3333 -> targetPort http" \
  is "$(jp $S -o jsonpath='{.spec.type} {.spec.ports[0].port} {.spec.ports[0].targetPort}')" "ClusterIP 3333 http"

endpoints_ok() {
  local ip
  ip=$(jp $P -o jsonpath='{.status.podIP}')
  [ -n "$ip" ] && has "$(jp endpointslices -n phoenix -l kubernetes.io/service-name=phoenix-api-svc \
    -o jsonpath='{.items[*].endpoints[*].addresses[*]}')" "$ip"
}
check "Service has the Pod as its endpoint" endpoints_ok
check "response.html contains the nginx welcome page" file_has "$COURSE/10/response.html" "Welcome to nginx"
check "access.log contains the request line" file_has "$COURSE/10/access.log" "GET /"
check "temporary Pod in default is gone" \
  bash -c '[ -s /opt/course/10/response.html ] && [ -z "$(kubectl get pods -n default -o name)" ]'

finish
