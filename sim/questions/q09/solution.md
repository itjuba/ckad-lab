# Solution 9

Generate a Deployment skeleton, then copy the container over from the Pod manifest:

```bash
k create deploy aquila-reporter -n aquila --image=busybox:1.37 --replicas=3 $do > /opt/course/9/reporter-deploy.yaml
cat /opt/course/9/reporter-pod.yaml           # copy name + command from here
vim /opt/course/9/reporter-deploy.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aquila-reporter
  namespace: aquila
spec:
  replicas: 3
  selector:
    matchLabels:
      app: aquila-reporter
  template:
    metadata:
      labels:
        app: aquila-reporter
    spec:
      securityContext:                 # Pod level
        runAsUser: 1000
        runAsGroup: 3000
        fsGroup: 2000
      containers:
      - name: reporter                 # same as the Pod
        image: busybox:1.37
        command: ["sh", "-c", "while true; do date >> /tmp/report.log; sleep 5; done"]
        securityContext:               # container level
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
        volumeMounts:                  # writable /tmp despite read-only root fs
        - name: tmp
          mountPath: /tmp
      volumes:
      - name: tmp
        emptyDir: {}
```

```bash
k apply -f /opt/course/9/reporter-deploy.yaml
k delete pod aquila-reporter -n aquila $now
k get deploy,pod -n aquila
k exec -n aquila deploy/aquila-reporter -- id                    # uid=1000 gid=3000 groups=2000
k exec -n aquila deploy/aquila-reporter -- tail -2 /tmp/report.log
```

Remember:
- `fsGroup` exists only at Pod level. `allowPrivilegeEscalation`, `readOnlyRootFilesystem` and `capabilities` exist only at container level. `runAsUser` and `runAsGroup` work at both levels, and the container value wins.
- With `readOnlyRootFilesystem: true`, every path the app writes to needs a volume. Otherwise the Pod goes into CrashLoopBackOff with "Read-only file system" in its logs.
