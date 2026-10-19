#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
course_dir 28 >/dev/null
reset_ns hydrus hydrus-monitoring

deploy() { # NS NAME
  kubectl create deploy "$2" -n "$1" --image=nginx:1.29-alpine >/dev/null
}
deploy hydrus web
deploy hydrus cache
kubectl expose deploy cache -n hydrus --port=80 >/dev/null
deploy hydrus-monitoring metrics
deploy hydrus-monitoring debug

kubectl apply -n hydrus -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
spec:
  podSelector: {}
  policyTypes: [Ingress]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: cache-access
spec:
  podSelector:
    matchLabels:
      app: cache
  policyTypes: [Ingress]
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: cache-client
    ports:
    - protocol: TCP
      port: 80
EOF

for d in web cache; do wait_rollout hydrus $d; done
for d in metrics debug; do wait_rollout hydrus-monitoring $d; done
