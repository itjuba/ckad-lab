# Solution 20

There is no imperative command for NetworkPolicies. Copy an example from the
docs (search "NetworkPolicy") and edit it.

```yaml
# 20.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: altair
spec:
  podSelector: {}              # empty = every Pod in the Namespace
  policyTypes: [Ingress]       # Ingress with no rules = deny all incoming
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api
  namespace: altair
spec:
  podSelector:
    matchLabels:
      app: api                 # who the policy protects
  policyTypes: [Ingress]
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend        # who may connect
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
  - to:                        # rule 1: db on 80
    - podSelector:
        matchLabels:
          app: db
    ports:
    - protocol: TCP
      port: 80
  - ports:                     # rule 2: DNS to anywhere
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
```

```bash
k apply -f 20.yaml

k -n altair exec deploy/frontend -- wget -qO- -T 3 http://api      # works
k -n altair exec deploy/admin    -- wget -qO- -T 3 http://api      # times out
k -n altair exec deploy/frontend -- wget -qO- -T 3 http://db       # times out
k -n altair exec deploy/api      -- wget -qO- -T 3 http://db       # works
k -n altair exec deploy/api      -- wget -qO- -T 3 http://collector.altair-monitoring   # times out
```

Remember:
- Without the DNS rule, `api` can't resolve `db`. Name lookups fail before any traffic to db is even sent.
- Indentation matters. `- to: [...]` followed by a separate `- ports:` creates two rules that are ORed together. Putting `to` and `ports` in the same rule means both must match.
- In a `from` list, `- podSelector` and `- namespaceSelector` as two items are ORed. Written as one item, they are ANDed.
