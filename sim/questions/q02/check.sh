#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
P="pod lyra-web -n lyra"

check "Pod lyra-web exists in lyra" jp $P
check "image is httpd:2.4-alpine" is "$(jp $P -o jsonpath='{.spec.containers[0].image}')" "httpd:2.4-alpine"
check "container is named lyra-web-container" is "$(jp $P -o jsonpath='{.spec.containers[0].name}')" "lyra-web-container"
check "port 80 is named http" is "$(jp $P -o jsonpath='{.spec.containers[0].ports[?(@.containerPort==80)].name}')" "http"
check "Pod is Running" is "$(jp $P -o jsonpath='{.status.phase}')" "Running"

script_ok() {
  local f=$COURSE/2/pod-ip.sh ip
  ip=$(jp $P -o jsonpath='{.status.podIP}')
  [ -n "$ip" ] && ! grep -qE '(^|[;&|[:space:]])k[[:space:]]' "$f" && [ "$(bash "$f" | tr -d '[:space:]')" = "$ip" ]
}
check "pod-ip.sh prints only the Pod IP (using kubectl)" script_ok

finish
