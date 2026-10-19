#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
D=/opt/course/25
kubectl top pod -n lynx --sort-by=cpu --no-headers | head -1 | awk '{print $1}' >$D/top-cpu
kubectl top pod -n lynx --sort-by=memory --no-headers | head -1 | awk '{print $1}' >$D/top-mem
echo "kubectl top node" >$D/node-usage.sh
kubectl get pod lynx-flaky -n lynx -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}' >$D/flaky-reason
