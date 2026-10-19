#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
course_dir 6 >/dev/null
reset_ns hydra

# nginx listens on 80, but both probes check 8080.
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hydra-api
  namespace: hydra
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hydra-api
  template:
    metadata:
      labels:
        app: hydra-api
    spec:
      containers:
      - name: api
        image: nginx:1.29-alpine
        ports:
        - containerPort: 80
          name: http
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
          failureThreshold: 2
EOF
# The Pods never get Ready, so wait for them to be Running instead of the rollout.
for _ in $(seq 60); do
  running=$(kubectl get pods -n hydra -l app=hydra-api --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
  [ "$running" -ge 2 ] && exit 0
  sleep 2
done
exit 1
