#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
D=$COURSE/42
R='{.spec.containers[0].resources.requests.cpu}/{.spec.containers[0].resources.requests.memory}'
L='{.spec.containers[0].resources.limits.cpu}/{.spec.containers[0].resources.limits.memory}'

# pod_ok NAME REQUESTS LIMITS : image, resources and Running.
pod_ok() {
  local p="pod $1 -n circinus"
  is "$(jp $p -o jsonpath='{.spec.containers[0].image}')" "nginx:1.29-alpine" &&
    is "$(jp $p -o jsonpath="$R")" "$2" && is "$(jp $p -o jsonpath="$L")" "$3" &&
    is "$(jp $p -o jsonpath='{.status.phase}')" "Running"
}
# qos_ok FILE POD : the file names the Pod's live QoS class.
qos_ok() {
  local want
  want=$(jp pod "$2" -n circinus -o jsonpath='{.status.qosClass}')
  [ -n "$want" ] && [ "$(tr -d '[:space:]' <"$D/$1" 2>/dev/null | tr '[:upper:]' '[:lower:]')" = "$(tr '[:upper:]' '[:lower:]' <<<"$want")" ]
}

check "circinus-small: requests 100m/64Mi, limits 200m/128Mi, Running" pod_ok circinus-small 100m/64Mi 200m/128Mi
check "qos-small holds its QoS class" qos_ok qos-small circinus-small
check "circinus-guaranteed: requests = limits = 100m/64Mi, Running" pod_ok circinus-guaranteed 100m/64Mi 100m/64Mi
check "qos-guaranteed holds its QoS class" qos_ok qos-guaranteed circinus-guaranteed

api_ok() {
  local req
  req=$(jp deploy circinus-api -n circinus -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}/{.spec.template.spec.containers[0].resources.requests.memory}')
  is "$req" "50m/32Mi" &&
    is "$(jp deploy circinus-api -n circinus -o jsonpath='{.status.updatedReplicas}/{.status.readyReplicas}/{.status.replicas}')" "2/2/2"
}
check "circinus-api requests 50m/32Mi, both replicas updated and available" api_ok

finish
