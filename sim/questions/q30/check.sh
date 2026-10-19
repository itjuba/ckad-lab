#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
D=$COURSE/30

logger_ok() {
  local f=$D/logger.log
  [ -f "$f" ] && [ "$(grep -c . "$f")" = 5 ] && [ "$(grep -c 'fornax heartbeat' "$f")" = 5 ]
}
check "logger.log holds exactly the last 5 heartbeat lines of the logger container" logger_ok

previous_ok() {
  file_has "$D/worker-previous.log" "worker crashed: disk full" && file_has "$D/worker-previous.log" "worker starting"
}
check "worker-previous.log holds the crashed run of fornax-worker" previous_ok
check "nginx-version holds the output of nginx -v" file_has "$D/nginx-version" "nginx version: nginx/1.29"

containers_ok() {
  [ "$(sed 's/[[:space:]]//g; /^$/d' "$D/containers" 2>/dev/null | sort | tr '\n' ' ')" = "logger web " ]
}
check "containers lists web and logger, one per line" containers_ok

finish
