#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
course_dir 39 >/dev/null
reset_ns pictor

kubectl apply -n pictor -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pictor-app
spec:
  replicas: 2
  selector:
    matchLabels: {app: pictor-app}
  template:
    metadata:
      labels: {app: pictor-app}
    spec:
      containers:
      - name: web
        image: nginx:1.29-alpine
        ports:
        - containerPort: 80
          name: http
      - name: metrics
        image: traefik/whoami:v1.11
        args: ["--port=9100"]
        ports:
        - containerPort: 9100
          name: metrics
EOF
wait_rollout pictor pictor-app
