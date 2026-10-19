# Solution 13

```yaml
# 13-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: centaurus-cache
  namespace: centaurus
spec:
  storageClassName: local-path
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 500Mi
```

```bash
k apply -f 13-pvc.yaml
k get sc local-path                  # VOLUMEBINDINGMODE: WaitForFirstConsumer
k get pvc centaurus-cache -n centaurus                  # STATUS: Pending
echo Pending > /opt/course/13/status-before
k describe pvc centaurus-cache -n centaurus      # Events at the bottom
echo "waiting for first consumer to be created before binding" > /opt/course/13/pending-reason
```

```bash
k run cache-writer -n centaurus --image=busybox:1.37 $do \
  -- sh -c 'while true; do date >> /cache/date.log; sleep 10; done' > 13-pod.yaml
vim 13-pod.yaml
```

```yaml
spec:
  containers:
  - name: cache-writer
    image: busybox:1.37
    args: ["sh", "-c", "while true; do date >> /cache/date.log; sleep 10; done"]
    volumeMounts:                   # added
    - name: cache
      mountPath: /cache
  volumes:                          # added
  - name: cache
    persistentVolumeClaim:
      claimName: centaurus-cache
```

```bash
k apply -f 13-pod.yaml
k get pvc,pv -n centaurus           # the PVC is now Bound and a pvc-<uid> PV exists
k get pvc centaurus-cache -n centaurus --no-headers | awk '{print $3}' > /opt/course/13/pv-name   # VOLUME column
k exec -n centaurus cache-writer -- cat /cache/date.log
```

Remember:
- With `volumeBindingMode: WaitForFirstConsumer`, a PVC stays Pending until a Pod uses it. That's expected, not an error. The scheduler first picks a node, then the volume is provisioned on that node.
- Dynamically provisioned PVs get generated names (`pvc-<uid>`). Read the name from the PVC's VOLUME column (its `spec.volumeName`).
