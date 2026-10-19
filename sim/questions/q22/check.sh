#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
V2="deploy castor-v2 -n castor"

v2_spec() {
  is "$(jp $V2 -o jsonpath='{.spec.template.spec.containers[0].image}')" "traefik/whoami:v1.11" &&
    is "$(jp $V2 -o jsonpath='{.spec.template.metadata.labels.app} {.spec.template.metadata.labels.version}')" "castor v2"
}
# The v2 Pod really answers as v2 (asked through the API server's pod proxy).
v2_answers() {
  local pod
  pod=$(jp pods -n castor -l version=v2 -o jsonpath='{.items[0].metadata.name}')
  [ -n "$pod" ] && kubectl get --raw "/api/v1/namespaces/castor/pods/$pod:80/proxy/" | grep -q '^Name: v2'
}
replicas_ok() {
  is "$(jp deploy castor-v1 -n castor -o jsonpath='{.spec.replicas} {.status.readyReplicas}')" "3 3" &&
    is "$(jp $V2 -o jsonpath='{.spec.replicas} {.status.readyReplicas}')" "1 1"
}
endpoints_ok() {
  local ready v2ip
  ready=$(jp endpointslices -n castor -l kubernetes.io/service-name=castor \
    -o jsonpath='{range .items[*].endpoints[?(@.conditions.ready==true)]}{.addresses[0]}{"\n"}{end}')
  v2ip=$(jp pods -n castor -l version=v2 -o jsonpath='{.items[0].status.podIP}')
  [ "$(grep -c . <<<"$ready")" = 4 ] && [ -n "$v2ip" ] && grep -qx "$v2ip" <<<"$ready"
}
responses_ok() { file_has "$COURSE/22/responses" "Name: v1" && file_has "$COURSE/22/responses" "Name: v2"; }

check "castor-v2 runs traefik/whoami:v1.11 with labels app=castor, version=v2" v2_spec
check "castor-v2 Pods answer with Name: v2" v2_answers
check "castor-v1 has 3 replicas and castor-v2 has 1" replicas_ok
selector_kept() { v2_spec && is "$(jp svc castor -n castor -o jsonpath='{.spec.selector}')" '{"app":"castor"}'; }
check "Service castor still selects only app=castor" selector_kept
check "Service castor has 4 ready endpoints, one of them v2" endpoints_ok
check "responses contain both Name: v1 and Name: v2" responses_ok

finish
