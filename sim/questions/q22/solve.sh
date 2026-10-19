#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: castor-v2
  namespace: castor
spec:
  replicas: 1
  selector:
    matchLabels:
      app: castor
      version: v2
  template:
    metadata:
      labels:
        app: castor
        version: v2
    spec:
      containers:
      - name: whoami
        image: traefik/whoami:v1.11
        args: ["--name=v2"]
EOF
kubectl scale deploy castor-v1 -n castor --replicas=3
wait_rollout castor castor-v2
wait_rollout castor castor-v1
# The Service picks endpoints at random; retry in the rare case one version is missed.
for _ in $(seq 5); do
  kubectl run tmp -n castor --rm -i --restart=Never --image=busybox:1.37 -- \
    sh -c 'for i in $(seq 20); do wget -qO- http://castor; done' 2>/dev/null |
    grep '^Name:' >/opt/course/22/responses
  grep -q 'Name: v1' /opt/course/22/responses && grep -q 'Name: v2' /opt/course/22/responses && break
done
