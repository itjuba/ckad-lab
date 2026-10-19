# Solution 24

There's no `kubectl create daemonset`. Generate a Deployment and turn it into a DaemonSet:

```bash
k create deploy node-agent -n vela --image=busybox:1.37 $do > 24.yaml
vim 24.yaml
```

Change `kind`, then delete `replicas`, `strategy` and `status`:

```yaml
apiVersion: apps/v1
kind: DaemonSet                     # was: Deployment
metadata:
  name: node-agent
  namespace: vela
spec:
  selector:
    matchLabels:
      app: node-agent
  template:
    metadata:
      labels:
        app: node-agent
    spec:
      tolerations:                  # run on the control plane too
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      volumes:
      - name: config
        emptyDir: {}
      initContainers:
      - name: init-config
        image: busybox:1.37
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName      # Downward API
        command: ["sh", "-c", "echo node=$NODE_NAME > /config/agent.conf"]
        volumeMounts:
        - name: config
          mountPath: /config
      containers:
      - name: agent
        image: busybox:1.37
        command: ["sh", "-c", "cat /config/agent.conf; sleep 1d"]
        volumeMounts:
        - name: config
          mountPath: /config
```

```bash
k apply -f 24.yaml
k get ds,pod -n vela -o wide          # one Pod per node
k logs -n vela <pod-on-k3d-ckad-agent-0> -c agent > /opt/course/24/agent.log
```

Remember:
- Pick the Pod by node with `k get pod -o wide`, or
  `--field-selector spec.nodeName=k3d-ckad-agent-0`.
- `$NODE_NAME` expands inside `sh -c`. `$(NODE_NAME)` would be expanded by Kubernetes
  itself, and only in `command`/`args`.
- On the exam, `k describe node <cp> | grep Taints` shows which taint to tolerate.
