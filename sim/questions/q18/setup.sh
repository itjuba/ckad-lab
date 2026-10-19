#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
course_dir 18 >/dev/null
reset_ns antares

for app in shop api; do
  kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: antares-$app
  namespace: antares
  labels:
    app: antares-$app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: antares-$app
  template:
    metadata:
      labels:
        app: antares-$app
    spec:
      containers:
      - name: whoami
        image: traefik/whoami:v1.11
        args: ["--name=$app"]
        ports:
        - containerPort: 80
EOF
done

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: antares-shop
  namespace: antares
spec:
  selector:
    app: antares-shop
  ports:
  - port: 8080
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: antares-api
  namespace: antares
spec:
  selector:
    app: antares-api
  ports:
  - port: 80
    targetPort: 8080
EOF
wait_rollout antares antares-shop
wait_rollout antares antares-api
