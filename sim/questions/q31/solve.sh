#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
kubectl create deploy octans-web -n octans --image=nginx:1.28-alpine --replicas=2 --port=80
wait_rollout octans octans-web
kubectl scale deploy octans-web -n octans --replicas=4
wait_rollout octans octans-web
kubectl set image deploy/octans-web -n octans nginx=nginx:1.29-alpine
wait_rollout octans octans-web
kubectl rollout history deploy/octans-web -n octans >/opt/course/31/history
kubectl expose deploy octans-web -n octans --port=8080 --target-port=80
for _ in $(seq 30); do
  n=$(kubectl get endpointslices -n octans -l kubernetes.io/service-name=octans-web \
    -o jsonpath='{range .items[*].endpoints[?(@.conditions.ready==true)]}{.addresses[0]}{"\n"}{end}' | grep -c .)
  [ "$n" = 4 ] && break
  sleep 1
done
