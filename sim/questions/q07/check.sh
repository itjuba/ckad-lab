#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
D="deploy cygnus-worker -n cygnus"
ENV='{.spec.template.spec.containers[0].env[?(@.name=="QUEUE_URL")]'

from_configmap() {
  is "$(jp $D -o jsonpath="$ENV.valueFrom.configMapKeyRef.name}/$ENV.valueFrom.configMapKeyRef.key}")" "cygnus-config/queue.url" &&
    is "$(jp $D -o jsonpath="$ENV.value}")" ""
}

running() {
  local restarts
  is "$(jp $D -o jsonpath='{.spec.replicas}/{.status.replicas}/{.status.updatedReplicas}/{.status.readyReplicas}')" "1/1/1/1" || return 1
  restarts=$(jp pods -n cygnus -l app=cygnus-worker -o jsonpath='{range .items[*]}{.status.containerStatuses[0].restartCount}{"\n"}{end}')
  [ -n "$restarts" ] && ! grep -qv '^0$' <<<"$restarts"
}

check "broken-deployment contains cygnus-worker" is "$(tr -d '[:space:]' <"$COURSE/7/broken-deployment" 2>/dev/null)" "cygnus-worker"
check "error.log contains the FATAL line" file_has "$COURSE/7/error.log" "FATAL: QUEUE_URL is not set"
check "QUEUE_URL comes from ConfigMap cygnus-config, key queue.url" from_configmap
check "cygnus-worker Pods run without restarts" running
check "worker logs show it connected to the queue" has "$(kubectl logs -n cygnus deploy/cygnus-worker 2>/dev/null)" "connected to amqp://queue.cygnus:5672"

finish
