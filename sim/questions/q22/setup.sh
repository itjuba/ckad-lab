#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
course_dir 22 >/dev/null
reset_ns castor

kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: castor-v1
  namespace: castor
spec:
  replicas: 4
  selector:
    matchLabels:
      app: castor
      version: v1
  template:
    metadata:
      labels:
        app: castor
        version: v1
    spec:
      containers:
      - name: whoami
        image: traefik/whoami:v1.11
        args: ["--name=v1"]
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: castor
  namespace: castor
spec:
  selector:
    app: castor
  ports:
  - port: 80
    targetPort: 80
EOF
wait_rollout castor castor-v1
