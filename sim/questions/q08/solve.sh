#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
echo 2 >/opt/course/8/good-revision
kubectl rollout undo deploy/perseus-web -n perseus --to-revision=2
wait_rollout perseus perseus-web
kubectl patch deploy perseus-web -n perseus -p '{"spec":{"strategy":{"rollingUpdate":{"maxSurge":1,"maxUnavailable":0}}}}'
kubectl set image deploy/perseus-web -n perseus web=nginx:1.29-alpine
kubectl annotate deploy/perseus-web -n perseus kubernetes.io/change-cause="upgrade to 1.29" --overwrite
wait_rollout perseus perseus-web 180s
for _ in $(seq 60); do
  [ "$(kubectl get pods -n perseus -l app=perseus-web --no-headers | wc -l)" = 3 ] && break
  sleep 2
done
