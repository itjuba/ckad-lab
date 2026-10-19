# Solution 8

```bash
k -n perseus get deploy,rs,pods             # new Pod in ImagePullBackOff, 3 old Pods still serve
k -n perseus rollout history deploy perseus-web
# REVISION  CHANGE-CAUSE
# 1         initial release 1.27
# 2         upgrade to 1.28
# 3         upgrade to 1.99                  <- nginx:1.99-missing doesn't exist
k -n perseus rollout history deploy perseus-web --revision=3   # shows the image
echo 2 > /opt/course/8/good-revision

# 2. Revision 2 comes back as revision 4
k -n perseus rollout undo deploy perseus-web --to-revision=2
k -n perseus rollout status deploy perseus-web

# 3.
k -n perseus edit deploy perseus-web
```

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1          # was 25%
      maxUnavailable: 0    # was 25%
```

```bash
# 4. The container is named "web", not "nginx"
k -n perseus set image deploy perseus-web web=nginx:1.29-alpine
k -n perseus annotate deploy perseus-web kubernetes.io/change-cause="upgrade to 1.29" --overwrite
k -n perseus rollout status deploy perseus-web
k -n perseus rollout history deploy perseus-web           # revision 5: upgrade to 1.29
```

Remember:
- Rolling back doesn't restore the old revision number. That revision becomes
  the newest one.
- `kubectl set image` needs the **container** name. Find it with
  `k get deploy perseus-web -o jsonpath='{..containers[*].name}'`.
- `--record` is deprecated. Set the `kubernetes.io/change-cause` annotation yourself.
