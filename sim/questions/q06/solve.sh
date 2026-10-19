#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: heartbeat
  namespace: hydra
spec:
  containers:
  - name: heartbeat
    image: nginx:1.29-alpine
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 10
    livenessProbe:
      tcpSocket:
        port: 80
      initialDelaySeconds: 10
      periodSeconds: 20
      failureThreshold: 3
EOF

kubectl get deploy hydra-api -n hydra -o yaml | sed 's/port: 8080/port: 80/' | kubectl apply -f -
wait_rollout hydra hydra-api 180s
kubectl wait --for=condition=Ready pod/heartbeat -n hydra --timeout=120s
# Let terminating pods of the old ReplicaSet disappear.
for _ in $(seq 60); do
  [ "$(kubectl get pods -n hydra -l app=hydra-api --no-headers | wc -l)" = 2 ] && break
  sleep 2
done
