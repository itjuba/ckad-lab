# Solution 32

Most changes to a running Deployment have a `k set` command:

```bash
# 1. env vars
k set env deploy/pyxis-api -n pyxis MODE=production LOG_LEVEL=info

# 2. resources (requests and limits in one command)
k set resources deploy/pyxis-api -n pyxis --requests=cpu=50m,memory=64Mi --limits=memory=128Mi

# 3. Pod template label: no k set for that, so edit
k edit deploy pyxis-api -n pyxis
```

```yaml
spec:
  template:
    metadata:
      labels:
        app: pyxis-api
        version: v2          # added under template.metadata, not the top-level metadata
```

```bash
# 4. annotation on the Deployment object itself
k annotate deploy pyxis-api -n pyxis owner=team-pyxis

k rollout status deploy/pyxis-api -n pyxis
k get pod -n pyxis --show-labels                 # 3 new Pods with version=v2
k describe deploy pyxis-api -n pyxis | grep -A4 -i environment
```

Remember:
- `k label deploy pyxis-api version=v2` labels the **Deployment**, not its Pods. Pod
  labels live in `spec.template.metadata.labels`.
- Don't touch `spec.selector`: it can't be changed, and adding a label to the template
  doesn't require it.
- Every template change (env, resources, labels) rolls out new Pods. Several `k set`
  commands in a row are fine, and the rollout settles on the last one.
