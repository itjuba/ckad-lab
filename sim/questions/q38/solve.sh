#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
kubectl create secret generic norma-api -n norma --from-file=api-key=/opt/course/38/api-key.txt
kubectl create secret generic norma-db -n norma --from-env-file=/opt/course/38/db.env
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: norma-worker
  namespace: norma
spec:
  replicas: 1
  selector:
    matchLabels:
      app: norma-worker
  template:
    metadata:
      labels:
        app: norma-worker
    spec:
      terminationGracePeriodSeconds: 3
      containers:
      - name: busybox
        image: busybox:1.37
        command: ["sleep", "1d"]
        envFrom:
        - secretRef:
            name: norma-db
        env:
        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: norma-api
              key: api-key
EOF
wait_rollout norma norma-worker
kubectl exec -n norma deploy/norma-worker -- sh -c 'env | grep -e DB_ -e API_KEY | sort' >/opt/course/38/env.txt
