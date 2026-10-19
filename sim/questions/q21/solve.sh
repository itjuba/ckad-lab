#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
kubectl get events -n deneb --field-selector reason=FailedCreate \
  -o jsonpath='{.items[0].message}' >/opt/course/21/reason

kubectl set resources deploy deneb-app -n deneb \
  --requests=cpu=100m,memory=64Mi --limits=cpu=200m,memory=128Mi
wait_rollout deneb deneb-app

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: LimitRange
metadata:
  name: deneb-defaults
  namespace: deneb
spec:
  limits:
  - type: Container
    defaultRequest:
      cpu: 50m
      memory: 32Mi
    default:
      cpu: 100m
      memory: 64Mi
EOF

kubectl run deneb-probe -n deneb --image=nginx:1.29-alpine
kubectl wait --for=condition=Ready pod/deneb-probe -n deneb --timeout=120s
