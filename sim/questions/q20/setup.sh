#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
course_dir 20 >/dev/null
# altair-monitoring is a target outside altair, used to prove api's egress is locked down.
reset_ns altair altair-monitoring

for app in frontend api db admin; do
  kubectl create deployment "$app" -n altair --image=nginx:1.29-alpine
done
kubectl expose deployment api -n altair --port=80
kubectl expose deployment db -n altair --port=80

kubectl create deployment collector -n altair-monitoring --image=nginx:1.29-alpine
kubectl expose deployment collector -n altair-monitoring --port=80

for app in frontend api db admin; do wait_rollout altair "$app"; done
wait_rollout altair-monitoring collector
