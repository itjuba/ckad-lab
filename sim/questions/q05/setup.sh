#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
course_dir 5 >/dev/null
reset_ns orion

kubectl create sa orion-ci -n orion
kubectl create sa orion-web -n orion
kubectl create secret generic orion-db-credentials -n orion \
  --from-literal=username=orion --from-literal=password=n0t-the-token
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: orion-ci-token
  namespace: orion
  annotations:
    kubernetes.io/service-account.name: orion-ci
type: kubernetes.io/service-account-token
---
apiVersion: v1
kind: Secret
metadata:
  name: orion-web-token
  namespace: orion
  annotations:
    kubernetes.io/service-account.name: orion-web
type: kubernetes.io/service-account-token
EOF

# The token controller fills in .data.token asynchronously.
for _ in $(seq 60); do
  [ -n "$(kubectl get secret orion-ci-token -n orion -o jsonpath='{.data.token}')" ] && exit 0
  sleep 1
done
exit 1
