#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
kubectl apply -n circinus -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: circinus-small
spec:
  containers:
  - name: nginx
    image: nginx:1.29-alpine
    resources:
      requests: {cpu: 100m, memory: 64Mi}
      limits: {cpu: 200m, memory: 128Mi}
---
apiVersion: v1
kind: Pod
metadata:
  name: circinus-guaranteed
spec:
  containers:
  - name: nginx
    image: nginx:1.29-alpine
    resources:
      requests: {cpu: 100m, memory: 64Mi}
      limits: {cpu: 100m, memory: 64Mi}
EOF
kubectl set resources deploy circinus-api -n circinus --requests=cpu=50m,memory=32Mi
kubectl wait --for=condition=Ready pod/circinus-small pod/circinus-guaranteed -n circinus --timeout=120s
kubectl describe pod circinus-small -n circinus | grep 'QoS Class' | awk '{print $3}' >/opt/course/42/qos-small
kubectl describe pod circinus-guaranteed -n circinus | grep 'QoS Class' | awk '{print $3}' >/opt/course/42/qos-guaranteed
wait_rollout circinus circinus-api
