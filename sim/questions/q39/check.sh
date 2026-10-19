#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
S="svc pictor-app -n pictor"
E="svc pictor-app-ext -n pictor"

# port_ok SVC_ARGS NAME PORT TARGET_NAME TARGET_NUMBER : named port with the right port and target.
port_ok() {
  local svc=$1 name=$2 port=$3 tname=$4 tnum=$5 target
  is "$(jp $svc -o jsonpath="{.spec.ports[?(@.name==\"$name\")].port}")" "$port" || return 1
  target=$(jp $svc -o jsonpath="{.spec.ports[?(@.name==\"$name\")].targetPort}")
  [ "$target" = "$tname" ] || [ "$target" = "$tnum" ]
}

check "Service pictor-app is ClusterIP" is "$(jp $S -o jsonpath='{.spec.type}')" "ClusterIP"
check "pictor-app port http: 80 -> http" port_ok "$S" http 80 http 80
check "pictor-app port metrics: 9100 -> metrics" port_ok "$S" metrics 9100 metrics 9100

endpoints_ok() {
  local ips
  ips=$(jp endpointslices -n pictor -l kubernetes.io/service-name=pictor-app \
    -o jsonpath='{range .items[*].endpoints[?(@.conditions.ready==true)]}{.addresses[0]}{"\n"}{end}' | sort -u | grep -c .)
  [ "$ips" = 2 ]
}
check "pictor-app selects both Deployment Pods" endpoints_ok

ext_ok() {
  is "$(jp $E -o jsonpath='{.spec.type}')" "NodePort" &&
    is "$(jp $E -o jsonpath='{.spec.ports[*].port}')" "80" &&
    is "$(jp $E -o jsonpath='{.spec.ports[0].nodePort}')" "30781" &&
    { t=$(jp $E -o jsonpath='{.spec.ports[0].targetPort}'); [ "$t" = http ] || [ "$t" = 80 ]; }
}
check "pictor-app-ext: NodePort, only port 80 -> http, nodePort 30781" ext_ok
check "website answers on k3d-ckad-server-0:30781" \
  has "$(curl -s -m 5 http://k3d-ckad-server-0:30781)" "Welcome to nginx"
check "nodeport.html holds the website" file_has "$COURSE/39/nodeport.html" "Welcome to nginx"
check "metrics.txt holds the response from port 9100" file_has "$COURSE/39/metrics.txt" "Hostname: pictor-app"

tmp_gone() {
  [ -s "$COURSE/39/metrics.txt" ] && is "$(jp pods -n pictor -o name | grep -v '^pod/pictor-app-')" ""
}
check "temporary Pod is gone" tmp_gone

finish
