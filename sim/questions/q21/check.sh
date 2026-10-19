#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
D="deploy deneb-app -n deneb"
R='{.spec.template.spec.containers[0].resources'
L="limitrange deneb-defaults -n deneb"
P="pod deneb-probe -n deneb"

limitrange_ok() {
  local c='{.spec.limits[?(@.type=="Container")]'
  is "$(jp $L -o jsonpath="$c.defaultRequest.cpu} $c.defaultRequest.memory} $c.default.cpu} $c.default.memory}")" \
    "50m 32Mi 100m 64Mi"
}
probe_defaults() {
  local r='{.spec.containers[0].resources'
  # The LimitRanger admission plugin leaves this annotation when it fills in resources.
  [ -n "$(jp $P -o jsonpath='{.metadata.annotations.kubernetes\.io/limit-ranger}')" ] &&
    is "$(jp $P -o jsonpath="$r.requests.cpu} $r.requests.memory} $r.limits.cpu} $r.limits.memory}")" \
      "50m 32Mi 100m 64Mi"
}

check "reason contains the quota error (must specify ...)" file_has "$COURSE/21/reason" "must specify"
check "deneb-app requests cpu 100m, memory 64Mi" is "$(jp $D -o jsonpath="$R.requests.cpu} $R.requests.memory}")" "100m 64Mi"
check "deneb-app limits cpu 200m, memory 128Mi" is "$(jp $D -o jsonpath="$R.limits.cpu} $R.limits.memory}")" "200m 128Mi"
check "deneb-app has 3 available replicas" is "$(jp $D -o jsonpath='{.status.availableReplicas}')" "3"
check "LimitRange deneb-defaults sets the container defaults" limitrange_ok
check "deneb-probe got its resources from the LimitRange" probe_defaults
check "deneb-probe is Running" is "$(jp $P -o jsonpath='{.status.phase}')" "Running"

finish
