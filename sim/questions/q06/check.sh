#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
P="pod heartbeat -n hydra"
D="deploy hydra-api -n hydra"
C='{.spec.containers[0]'

# Port given as 80 or as the name of a container port that is 80.
port80() {
  [ "$1" = 80 ] && return
  [ -n "$1" ] && is "$(jp $2 -o jsonpath="{..containers[0].ports[?(@.name==\"$1\")].containerPort}")" "80"
}

readiness_http() {
  is "$(jp $P -o jsonpath="$C.readinessProbe.httpGet.path}")" "/" &&
    port80 "$(jp $P -o jsonpath="$C.readinessProbe.httpGet.port}")" "$P"
}
liveness_tcp() { port80 "$(jp $P -o jsonpath="$C.livenessProbe.tcpSocket.port}")" "$P"; }

api_probes_fixed() {
  port80 "$(jp $D -o jsonpath='{.spec.template.spec.containers[0].livenessProbe..port}')" "$D" &&
    port80 "$(jp $D -o jsonpath='{.spec.template.spec.containers[0].readinessProbe..port}')" "$D" &&
    is "$(jp $D -o jsonpath='{.spec.template.spec.containers[0].image}')" "nginx:1.29-alpine"
}

api_healthy() {
  local restarts
  is "$(jp $D -o jsonpath='{.status.replicas}/{.status.updatedReplicas}/{.status.readyReplicas}')" "2/2/2" || return 1
  restarts=$(jp pods -n hydra -l app=hydra-api -o jsonpath='{range .items[*]}{.status.containerStatuses[0].restartCount}{"\n"}{end}')
  [ -n "$restarts" ] && ! grep -qv '^0$' <<<"$restarts"
}

check "Pod heartbeat runs nginx:1.29-alpine" is "$(jp $P -o jsonpath="$C.image}")" "nginx:1.29-alpine"
check "readiness probe: HTTP GET / on port 80" readiness_http
check "readiness probe: initialDelaySeconds 5, periodSeconds 10" \
  is "$(jp $P -o jsonpath="$C.readinessProbe.initialDelaySeconds} $C.readinessProbe.periodSeconds}")" "5 10"
check "liveness probe: TCP on port 80" liveness_tcp
check "liveness probe: initialDelaySeconds 10, periodSeconds 20, failureThreshold 3" \
  is "$(jp $P -o jsonpath="$C.livenessProbe.initialDelaySeconds} $C.livenessProbe.periodSeconds} $C.livenessProbe.failureThreshold}")" "10 20 3"
check "Pod heartbeat is Ready" is "$(jp $P -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" "True"
check "hydra-api probes check port 80 (image unchanged)" api_probes_fixed
check "hydra-api rollout complete: 2/2 Ready, no restarts" api_healthy

finish
