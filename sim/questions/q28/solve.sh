#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
kubectl patch deploy web -n hydrus -p '{"spec":{"template":{"metadata":{"labels":{"role":"cache-client"}}}}}'
wait_rollout hydrus web

kubectl apply -n hydrus -f - <<'EOF'
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
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: hydrus-monitoring
      podSelector:
        matchLabels:
          app: metrics
    ports:
    - protocol: TCP
      port: 80
EOF

for _ in $(seq 20); do
  kubectl exec -n hydrus-monitoring deploy/metrics -- wget -qO- -T 2 http://cache.hydrus >/dev/null 2>&1 &&
    kubectl exec -n hydrus deploy/web -- wget -qO- -T 2 http://cache >/dev/null 2>&1 && break
  sleep 2
done
