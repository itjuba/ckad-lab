# Solution 23

```bash
# 1. Find the CRD and its schema
k get crd | grep nimbus
k api-resources --api-group=nimbus.io        # NAME, SHORTNAMES, APIVERSION, KIND
k explain backup.spec                        # field names + types
```

```yaml
# 23-backup.yaml
apiVersion: nimbus.io/v1
kind: Backup
metadata:
  name: nightly
  namespace: pollux
spec:
  schedule: "0 2 * * *"     # quote it: a bare * is special in YAML
  retentionDays: 7          # integer, not "7"
  target: pollux-web
```

```bash
k apply -f 23-backup.yaml
k get bk -n pollux

# 2.
echo bk > /opt/course/23/short-name

# 3. Which versions does the cluster serve?
k api-versions | grep -E 'autoscaling|policy'      # autoscaling/v1, autoscaling/v2, policy/v1
k apply -f /opt/course/23/legacy/                   # error: no matches for kind ... in version ...
k explain hpa.spec.metrics.resource --api-version=autoscaling/v2
vim /opt/course/23/legacy/hpa.yaml
```

```yaml
apiVersion: autoscaling/v2              # was: autoscaling/v2beta1
kind: HorizontalPodAutoscaler
metadata:
  name: pollux-web
  namespace: pollux
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: pollux-web
  minReplicas: 2
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:                           # was: targetAverageUtilization: 70
        type: Utilization
        averageUtilization: 70
```

```bash
sed -i 's#policy/v1beta1#policy/v1#' /opt/course/23/legacy/pdb.yaml   # same fields in v1
k apply -f /opt/course/23/legacy/
k -n pollux get hpa,pdb
```

Remember:
- `kubectl api-resources` shows short names and the API group/version of every type, including CRDs.
- `kubectl explain <type>.<field> --api-version=<group/version>` shows the schema for a specific version. That's the fastest way to see what a field moved to.
- Removed versions to know: `autoscaling/v2beta1` and `v2beta2` → `autoscaling/v2`, `policy/v1beta1` → `policy/v1`, `networking.k8s.io/v1beta1` Ingress → `networking.k8s.io/v1`, `batch/v1beta1` CronJob → `batch/v1`.
