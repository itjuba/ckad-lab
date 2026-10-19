#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
course_dir 25 >/dev/null
reset_ns lynx

kubectl apply -n lynx -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: lynx-crunch
spec:
  selector:
    matchLabels: {app: lynx-crunch}
  template:
    metadata:
      labels: {app: lynx-crunch}
    spec:
      containers:
      - name: crunch
        image: busybox:1.37
        command: ["sh", "-c", "while true; do :; done"]
        resources:
          requests: {cpu: 50m, memory: 16Mi}
          limits: {cpu: 100m, memory: 32Mi}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: lynx-hoard
spec:
  selector:
    matchLabels: {app: lynx-hoard}
  template:
    metadata:
      labels: {app: lynx-hoard}
    spec:
      volumes:
      - name: cache
        emptyDir: {medium: Memory, sizeLimit: 100Mi}
      containers:
      - name: hoard
        image: busybox:1.37
        command: ["sh", "-c", "dd if=/dev/zero of=/cache/blob bs=1M count=60 && sleep 1d"]
        volumeMounts:
        - {name: cache, mountPath: /cache}
        resources:
          requests: {cpu: 10m, memory: 96Mi}
          limits: {cpu: 50m, memory: 128Mi}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: lynx-web
spec:
  replicas: 2
  selector:
    matchLabels: {app: lynx-web}
  template:
    metadata:
      labels: {app: lynx-web}
    spec:
      containers:
      - name: web
        image: nginx:1.29-alpine
---
apiVersion: v1
kind: Pod
metadata:
  name: lynx-flaky
  labels: {app: lynx-flaky}
spec:
  containers:
  - name: flaky
    image: busybox:1.37
    command: ["sh", "-c", "echo loading index; x=$(head -c 40000000 /dev/zero | tr '\\0' a); sleep 1d"]
    resources:
      limits: {memory: 16Mi}
EOF

kubectl wait --for=condition=Ready pod -n lynx -l 'app in (lynx-crunch,lynx-hoard,lynx-web)' --timeout=120s >/dev/null

# Wait until metrics-server reports the Pods and lynx-flaky has been OOM-killed at least once.
for _ in $(seq 60); do
  mem=$(kubectl top pod -n lynx -l app=lynx-hoard --no-headers 2>/dev/null | awk '{print $3}' | tr -d 'Mi')
  reason=$(kubectl get pod lynx-flaky -n lynx -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}')
  [ "${mem:-0}" -gt 50 ] 2>/dev/null && [ -n "$reason" ] && break
  sleep 5
done
