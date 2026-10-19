#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
G="deploy checkout-green -n tucana"

green_spec() {
  is "$(jp $G -o jsonpath='{.spec.template.metadata.labels.app}/{.spec.template.metadata.labels.version}')" "checkout/green" &&
    is "$(jp $G -o jsonpath='{.spec.template.spec.containers[0].image}')" "traefik/whoami:v1.11" &&
    has "$(jp $G -o jsonpath='{.spec.template.spec.containers[0].args}')" "--name=green"
}
check "checkout-green: whoami image, --name=green, labels app=checkout,version=green" green_spec
check "checkout-green has 3 ready replicas" is "$(jp $G -o jsonpath='{.status.readyReplicas}')" "3"

# Every ready endpoint of the Service belongs to a green Pod, and there are 3 of them.
only_green() {
  local svc_ips green_ips
  svc_ips=$(jp endpointslices -n tucana -l kubernetes.io/service-name=checkout \
    -o jsonpath='{range .items[*].endpoints[?(@.conditions.ready==true)]}{.addresses[0]}{"\n"}{end}' | sort)
  green_ips=$(jp pods -n tucana -l app=checkout,version=green -o jsonpath='{range .items[*]}{.status.podIP}{"\n"}{end}' | sort)
  [ "$(wc -l <<<"$svc_ips")" = 3 ] && is "$svc_ips" "$green_ips" &&
    is "$(jp svc checkout -n tucana -o jsonpath='{.spec.ports[0].port}')" "80"
}
check "Service checkout (port 80) sends traffic only to the green Pods" only_green

check "after-switch holds a response from green" file_has "$COURSE/26/after-switch" "Name: green"
tmp_gone() {
  [ -s "$COURSE/26/after-switch" ] && is "$(jp pods -n tucana -o name | grep -v -e checkout-green -e checkout-blue)" ""
}
check "temporary Pod is gone (only blue/green Pods left)" tmp_gone

blue_parked() {
  is "$(jp deploy checkout-blue -n tucana -o jsonpath='{.spec.replicas}')" "0"
}
check "checkout-blue still exists, scaled to 0" blue_parked

finish
