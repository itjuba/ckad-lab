# Solution 36

Generate the first container, then copy it for the second one and add the volume:

```bash
k run musca-pair -n musca --image=busybox:1.37 $do --command -- sh -c 'while true; do date >> /shared/out.log; sleep 3; done' > 36.yaml
vim 36.yaml
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: musca-pair
  namespace: musca
spec:
  volumes:                          # added
  - name: shared
    emptyDir: {}
  containers:
  - name: producer                  # was: musca-pair
    image: busybox:1.37
    command: ["sh", "-c", "while true; do date >> /shared/out.log; sleep 3; done"]
    volumeMounts:                   # added
    - name: shared
      mountPath: /shared
  - name: consumer                  # added: a second regular container
    image: busybox:1.37
    command: ["tail", "-F", "/shared/out.log"]
    volumeMounts:
    - name: shared
      mountPath: /shared
```

```bash
k apply -f 36.yaml
k get pod musca-pair -n musca                   # READY 2/2

k logs musca-pair -n musca -c consumer > /opt/course/36/consumer.log
k exec musca-pair -n musca -c consumer -- ls /shared > /opt/course/36/shared-ls
```

Remember:
- With more than one container, `logs` and `exec` need `-c <container>`. Without it kubectl
  picks the default container and prints a hint.
- `--command` tells `k run` that what follows `--` is the `command`, not the `args`.
- This is a plain two-container Pod: both containers start together and nothing guarantees
  their order. A native sidecar (question 16) is an init container with
  `restartPolicy: Always`. It starts before the main containers and stops after them.
