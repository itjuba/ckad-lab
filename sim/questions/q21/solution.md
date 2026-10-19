# Solution 21

```bash
# 1. The Deployment is fine. Its ReplicaSet is the one failing to create Pods.
k -n deneb get deploy,rs,pod
k -n deneb describe rs -l app=deneb-app | grep -A3 Events
k -n deneb get events --field-selector reason=FailedCreate
# Error creating: pods "deneb-app-..." is forbidden: failed quota: deneb-quota:
#   must specify limits.cpu for: nginx; limits.memory for: nginx; requests.cpu ...
vim /opt/course/21/reason        # paste the message

# 2.
k -n deneb set resources deploy deneb-app \
  --requests=cpu=100m,memory=64Mi --limits=cpu=200m,memory=128Mi
k -n deneb rollout status deploy deneb-app
k -n deneb describe quota deneb-quota            # see what is used now
```

```yaml
# 3. 21-lr.yaml  (docs: search "LimitRange")
apiVersion: v1
kind: LimitRange
metadata:
  name: deneb-defaults
  namespace: deneb
spec:
  limits:
  - type: Container
    defaultRequest:        # requests when the container sets none
      cpu: 50m
      memory: 32Mi
    default:               # limits when the container sets none
      cpu: 100m
      memory: 64Mi
```

```bash
k apply -f 21-lr.yaml

# 4.
k -n deneb run deneb-probe --image=nginx:1.29-alpine
k -n deneb describe pod deneb-probe | grep -A2 -E 'Limits|Requests'   # filled in by the LimitRange
```

Remember:
- When a quota covers cpu or memory, every new Pod must set those values, or a LimitRange must fill them in. Otherwise the Pod is rejected.
- In a LimitRange, `default` sets the limits and `defaultRequest` sets the requests. The names are easy to mix up.
- A LimitRange only affects Pods created after it exists. It never changes running Pods.
