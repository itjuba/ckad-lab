# Solution 42

`kubectl run` has no resource flags, so generate the Pod and add a `resources` block
(docs search: "resource management for pods and containers"):

```bash
k run circinus-small -n circinus --image=nginx:1.29-alpine $do > 42-small.yaml
vim 42-small.yaml
```

```yaml
spec:
  containers:
  - name: circinus-small
    image: nginx:1.29-alpine
    resources:                  # added
      requests:
        cpu: 100m
        memory: 64Mi
      limits:
        cpu: 200m
        memory: 128Mi
```

```bash
k apply -f 42-small.yaml
k describe pod circinus-small -n circinus | grep -i qos     # QoS Class: Burstable
echo Burstable > /opt/course/42/qos-small
```

Same for `circinus-guaranteed`, with requests equal to limits (`cpu: 100m`,
`memory: 64Mi` in both):

```bash
k describe pod circinus-guaranteed -n circinus | grep -i qos   # QoS Class: Guaranteed
echo Guaranteed > /opt/course/42/qos-guaranteed
```

The Deployment doesn't need any YAML:

```bash
k set resources deploy circinus-api -n circinus --requests=cpu=50m,memory=32Mi
k rollout status deploy circinus-api -n circinus
```

Remember:
- **Guaranteed**: every container has requests = limits for both CPU and memory.
  **Burstable**: some requests or limits are set, but not that. **BestEffort**: none at all.
- If you set only limits, Kubernetes copies them into requests, which makes the Pod
  Guaranteed.
- `k apply` can't change a running Pod's resources (in-place resize goes through the
  separate `resize` subresource). The simple way is to recreate the Pod
  (`k replace --force -f file.yaml`), or to change the Deployment, which rolls out new Pods.
