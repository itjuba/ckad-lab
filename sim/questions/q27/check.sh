#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
S="svc columba-web -n columba"

check "cause mentions the selector" grep -qi "selector\|label" "$COURSE/27/cause"

endpoints_ok() {
  local svc_ips pod_ips
  svc_ips=$(jp endpointslices -n columba -l kubernetes.io/service-name=columba-web \
    -o jsonpath='{range .items[*].endpoints[?(@.conditions.ready==true)]}{.addresses[0]}{"\n"}{end}' | sort)
  pod_ips=$(jp pods -n columba -l app=columba-web -o jsonpath='{range .items[*]}{.status.podIP}{"\n"}{end}' | sort)
  [ -n "$pod_ips" ] && is "$svc_ips" "$pod_ips"
}
check "Service columba-web has both Deployment Pods as endpoints" endpoints_ok

deploy_untouched() {
  endpoints_ok && is "$(jp deploy columba-web -n columba -o jsonpath='{.spec.template.metadata.labels.app}/{.spec.replicas}')" "columba-web/2"
}
check "Deployment columba-web unchanged (labels, 2 replicas)" deploy_untouched

check "Service type is NodePort" is "$(jp $S -o jsonpath='{.spec.type}')" "NodePort"
check "nodePort is 30780" is "$(jp $S -o jsonpath='{.spec.ports[0].nodePort}')" "30780"
check "website answers on k3d-ckad-server-0:30780" \
  has "$(curl -s -m 5 http://k3d-ckad-server-0:30780)" "Welcome to nginx"
check "nodeport.html holds the response" file_has "$COURSE/27/nodeport.html" "Welcome to nginx"

finish
