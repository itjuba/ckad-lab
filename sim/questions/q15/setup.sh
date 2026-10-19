#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
D=$(course_dir 15)
reset_ns carina

printf 'GW_MODE=edge\nGW_TIMEOUT=30s\nGW_REGION=eu-west\n' >"$D/gateway.env"

kubectl create configmap gateway-config-v1 -n carina --from-literal=GW_MODE=legacy --from-literal=GW_TIMEOUT=10s
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: carina-gateway
  namespace: carina
  labels:
    app: carina-gateway
spec:
  replicas: 2
  selector:
    matchLabels:
      app: carina-gateway
  template:
    metadata:
      labels:
        app: carina-gateway
    spec:
      terminationGracePeriodSeconds: 3
      containers:
      - name: gateway
        image: busybox:1.37
        command: ["sh", "-c", "env | grep ^GW_ | sort; sleep 1d"]
        envFrom:
        - configMapRef:
            name: gateway-config-v1
EOF
wait_rollout carina carina-gateway
