#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
D=/opt/course/40
pod=$(kubectl get pod -n volans -l app=volans-api --no-headers | head -1 | awk '{print $1}')
kubectl describe pod "$pod" -n volans | grep FailedScheduling | head -1 >$D/api-reason
kubectl label node k3d-ckad-agent-0 disktype=ssd --overwrite
wait_rollout volans volans-api

kubectl describe pod volans-batch -n volans | grep FailedScheduling | head -1 >$D/batch-reason
kubectl delete pod volans-batch -n volans --force --grace-period=0 2>/dev/null
kubectl apply -n volans -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: volans-batch
  labels: {app: volans-batch}
spec:
  containers:
  - name: batch
    image: nginx:1.29-alpine
    resources:
      requests:
        cpu: 100m
EOF
kubectl wait --for=condition=Ready pod/volans-batch -n volans --timeout=120s
