# Solution 12

You can't create PVs or PVCs imperatively. Copy a skeleton from the docs
(search "PersistentVolume hostPath") and edit it:

```yaml
# 12-pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: andromeda-pv
spec:
  capacity:
    storage: 1Gi
  accessModes: ["ReadWriteOnce"]
  hostPath:
    path: /mnt/andromeda-data
  # no storageClassName on the PV
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: andromeda-pvc
  namespace: andromeda
spec:
  storageClassName: ""            # important, see below
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 1Gi
```

```bash
k apply -f 12-pv.yaml
k get pv,pvc -n andromeda           # both Bound

k create deploy andromeda-store -n andromeda --image=httpd:2.4-alpine $do > 12-deploy.yaml
vim 12-deploy.yaml
```

```yaml
    spec:
      containers:
      - name: httpd
        image: httpd:2.4-alpine
        volumeMounts:                         # added
        - name: content
          mountPath: /usr/local/apache2/htdocs
      volumes:                                # added
      - name: content
        persistentVolumeClaim:
          claimName: andromeda-pvc
```

```bash
k apply -f 12-deploy.yaml
k get deploy,pod -n andromeda
```

Remember:
- If a PVC leaves out `storageClassName`, the cluster's **default** StorageClass is filled in (here `local-path`). The PVC then never binds to a PV without a class: it gets its own dynamic volume, or sits in Pending. `storageClassName: ""` means "no class" and lets it bind to your static PV.
- Adding `volumeName: andromeda-pv` to the PVC pins it to that exact PV. It's useful when several PVs could match.
