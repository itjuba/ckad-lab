#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
D=/opt/course/30
kubectl logs fornax-app -n fornax -c logger --tail=5 >$D/logger.log
kubectl logs fornax-worker -n fornax --previous >$D/worker-previous.log
kubectl exec fornax-app -n fornax -c web -- nginx -v >$D/nginx-version 2>&1
printf 'web\nlogger\n' >$D/containers
