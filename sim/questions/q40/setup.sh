#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
course_dir 40 >/dev/null
reset_ns volans
# The fix is a node label, so a reset must remove it again.
kubectl label nodes --all disktype- >/dev/null 2>&1

kubectl apply -n volans -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: volans-api
spec:
  replicas: 2
  selector:
    matchLabels: {app: volans-api}
  template:
    metadata:
      labels: {app: volans-api}
    spec:
      nodeSelector:
        disktype: ssd
      containers:
      - name: nginx
        image: nginx:1.29-alpine
---
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
        cpu: "64"
EOF

# Wait until the scheduler has reported on both workloads.
for _ in $(seq 60); do
  api=$(kubectl get events -n volans --field-selector reason=FailedScheduling -o name 2>/dev/null | wc -l)
  batch=$(kubectl get events -n volans --field-selector reason=FailedScheduling,involvedObject.name=volans-batch -o name 2>/dev/null | wc -l)
  [ "$api" -ge 2 ] && [ "$batch" -ge 1 ] && break
  sleep 1
done
