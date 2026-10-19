#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
kubectl apply -n tucana -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: checkout-green
spec:
  replicas: 3
  selector:
    matchLabels: {app: checkout, version: green}
  template:
    metadata:
      labels: {app: checkout, version: green}
    spec:
      containers:
      - name: whoami
        image: traefik/whoami:v1.11
        args: ["--name=green"]
        ports:
        - containerPort: 80
EOF
wait_rollout tucana checkout-green
kubectl patch svc checkout -n tucana -p '{"spec":{"selector":{"app":"checkout","version":"green"}}}'
sleep 2
kubectl run tmp -n tucana --image=busybox:1.37 --restart=Never --rm -i -- wget -qO- http://checkout \
  | grep -v 'pod "tmp" deleted' >/opt/course/26/after-switch
kubectl scale deploy checkout-blue -n tucana --replicas=0
kubectl wait --for=delete pod -n tucana -l version=blue --timeout=60s
