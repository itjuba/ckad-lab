#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: altair
spec:
  podSelector: {}
  policyTypes: [Ingress]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api
  namespace: altair
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes: [Ingress]
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 80
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-db
  namespace: altair
spec:
  podSelector:
    matchLabels:
      app: db
  policyTypes: [Ingress]
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: api
    ports:
    - protocol: TCP
      port: 80
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-egress
  namespace: altair
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes: [Egress]
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: db
    ports:
    - protocol: TCP
      port: 80
  - ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
EOF

# Policies take a few seconds to be enforced.
reach() { kubectl exec -n altair "deploy/$1" -- wget -qO- -T 3 "$2" >/dev/null 2>&1; }
for _ in $(seq 30); do
  if ! reach admin http://api && reach api http://db && ! reach api http://collector.altair-monitoring; then
    break
  fi
  sleep 2
done
