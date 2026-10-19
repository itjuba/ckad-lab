# Solution 28

Read the policies first. They tell you which labels are expected:

```bash
k get netpol -n hydrus
k describe netpol cache-access -n hydrus     # allows from pods with role=cache-client
k get pod -n hydrus --show-labels            # web Pods don't have role=cache-client
```

**1.** Add the label to the Pod template of `web` (labelling a running Pod wouldn't
survive its next restart):

```bash
k edit deploy web -n hydrus
```

```yaml
  template:
    metadata:
      labels:
        app: web
        role: cache-client          # added
```

```bash
k exec -n hydrus deploy/web -- wget -qO- -T 3 http://cache
```

**2.** Allow `app=metrics` Pods from `hydrus-monitoring`. Namespace and Pod selector go
in the **same** `from` entry (AND):

```bash
k edit netpol cache-access -n hydrus
```

```yaml
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: cache-client
    - namespaceSelector:                       # new entry...
        matchLabels:
          kubernetes.io/metadata.name: hydrus-monitoring
      podSelector:                             # ...no dash: same entry = AND
        matchLabels:
          app: metrics
    ports:
    - protocol: TCP
      port: 80
```

```bash
k exec -n hydrus-monitoring deploy/metrics -- wget -qO- -T 3 http://cache.hydrus   # works
k exec -n hydrus-monitoring deploy/debug   -- wget -qO- -T 3 http://cache.hydrus   # times out
```

Remember:
- `- namespaceSelector: ...` followed by `- podSelector: ...` (two dashes) means OR. That
  would let **every** Pod in hydrus-monitoring in, plus `app=metrics` Pods from hydrus.
- Every namespace carries the label `kubernetes.io/metadata.name: <name>` automatically.
- A bare `podSelector` in `from` only matches Pods in the policy's own namespace.
