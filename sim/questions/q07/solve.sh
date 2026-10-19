#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
echo cygnus-worker >/opt/course/7/broken-deployment
{
  kubectl logs -n cygnus deploy/cygnus-worker
  kubectl logs -n cygnus deploy/cygnus-worker --previous
} 2>/dev/null | grep -m1 FATAL >/opt/course/7/error.log

kubectl patch deploy cygnus-worker -n cygnus --type=json -p '[{"op":"add","path":"/spec/template/spec/containers/0/env","value":[
  {"name":"QUEUE_URL","valueFrom":{"configMapKeyRef":{"name":"cygnus-config","key":"queue.url"}}}]}]'
wait_rollout cygnus cygnus-worker
for _ in $(seq 60); do
  [ "$(kubectl get pods -n cygnus -l app=cygnus-worker --no-headers | wc -l)" = 1 ] && break
  sleep 2
done
