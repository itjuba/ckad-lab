# Solution 7

```bash
k -n cygnus get deploy,pods                 # one Pod in CrashLoopBackOff / Error, RESTARTS climbing
echo cygnus-worker > /opt/course/7/broken-deployment

k -n cygnus logs deploy/cygnus-worker       # add --previous if the container is restarting right now
k -n cygnus logs deploy/cygnus-worker | grep FATAL > /opt/course/7/error.log

k -n cygnus describe cm cygnus-config       # key queue.url
k -n cygnus edit deploy cygnus-worker
```

```yaml
    spec:
      containers:
      - name: worker
        image: busybox:1.37
        env:                              # added
        - name: QUEUE_URL
          valueFrom:
            configMapKeyRef:
              name: cygnus-config
              key: queue.url
        command:
        ...
```

```bash
k -n cygnus rollout status deploy cygnus-worker
k -n cygnus logs deploy/cygnus-worker       # connected to amqp://queue.cygnus:5672
```

Remember:
- `envFrom` uses each ConfigMap key as the variable name, so `queue.url` would not
  become `QUEUE_URL`. Use `env` + `valueFrom.configMapKeyRef` to choose the name.
- `kubectl logs --previous` shows the output of the last crashed container.
