# Solution 16

A native sidecar is an entry under `initContainers` with `restartPolicy: Always`.
Kubernetes starts it before the app containers, doesn't wait for it to exit, and
keeps it running until the Pod stops.

```bash
k edit deploy auriga-ledger -n auriga
```

```yaml
    spec:
      initContainers:                       # added
      - name: log-shipper
        image: busybox:1.37
        restartPolicy: Always               # this is what makes it a native sidecar
        command: ["tail", "-F", "/var/log/ledger/ledger.log"]
        volumeMounts:
        - name: logs                        # the existing emptyDir volume
          mountPath: /var/log/ledger
      containers:
      - name: ledger
        ...
```

```bash
k rollout status deploy auriga-ledger -n auriga
k get pod -n auriga                         # READY 2/2: the sidecar counts too
k logs -n auriga deploy/auriga-ledger -c log-shipper --tail=20 > /opt/course/16/ledger.log
cat /opt/course/16/ledger.log
```

Remember:
- Without `restartPolicy: Always`, an init container must finish before the app starts. `tail -F` never exits, so the Pod would hang in `Init:0/1`.
- The older way is a second entry under `containers`. It also works, but nothing guarantees it starts first or stops last. The task asked for a native sidecar.
- `tail -F` retries until the file exists. That matters here because the sidecar starts before the app has created the file.
