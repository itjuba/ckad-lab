#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
course_dir 7 >/dev/null
reset_ns cygnus

kubectl create configmap cygnus-config -n cygnus \
  --from-literal=queue.url=amqp://queue.cygnus:5672 --from-literal=log.level=info
kubectl create deploy cygnus-frontend -n cygnus --image=nginx:1.29-alpine --replicas=2
kubectl create deploy cygnus-cache -n cygnus --image=redis:7-alpine

kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cygnus-worker
  namespace: cygnus
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cygnus-worker
  template:
    metadata:
      labels:
        app: cygnus-worker
    spec:
      containers:
      - name: worker
        image: busybox:1.37
        command:
        - sh
        - -c
        - |
          echo "cygnus-worker 2.4.1 starting"
          echo "loading settings"
          if [ -z "$QUEUE_URL" ]; then
            echo "FATAL: QUEUE_URL is not set"
            exit 1
          fi
          echo "connected to $QUEUE_URL"
          sleep 1d
EOF

wait_rollout cygnus cygnus-frontend
wait_rollout cygnus cygnus-cache
# Wait until the worker has crashed at least once.
for _ in $(seq 60); do
  r=$(kubectl get pods -n cygnus -l app=cygnus-worker -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}')
  [ "${r:-0}" -ge 1 ] && break
  sleep 2
done
