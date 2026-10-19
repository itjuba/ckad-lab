#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
course_dir 26 >/dev/null
reset_ns tucana

kubectl apply -n tucana -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: checkout-blue
spec:
  replicas: 3
  selector:
    matchLabels: {app: checkout, version: blue}
  template:
    metadata:
      labels: {app: checkout, version: blue}
    spec:
      containers:
      - name: whoami
        image: traefik/whoami:v1.11
        args: ["--name=blue"]
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: checkout
spec:
  selector: {app: checkout, version: blue}
  ports:
  - port: 80
    targetPort: 80
EOF
wait_rollout tucana checkout-blue
