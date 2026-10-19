#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
course_dir 27 >/dev/null
reset_ns columba

kubectl apply -n columba -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: columba-web
spec:
  replicas: 2
  selector:
    matchLabels: {app: columba-web}
  template:
    metadata:
      labels: {app: columba-web, team: columba}
    spec:
      containers:
      - name: nginx
        image: nginx:1.29-alpine
        ports:
        - containerPort: 80
          name: web
---
apiVersion: v1
kind: Service
metadata:
  name: columba-web
spec:
  selector: {app: columba-website, team: columba}
  ports:
  - port: 80
    targetPort: web
EOF
wait_rollout columba columba-web
