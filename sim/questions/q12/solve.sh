#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
kubectl apply -f - <<'EOF'
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
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: andromeda-pvc
  namespace: andromeda
spec:
  storageClassName: ""
  volumeName: andromeda-pv
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: andromeda-store
  namespace: andromeda
spec:
  replicas: 1
  selector:
    matchLabels:
      app: andromeda-store
  template:
    metadata:
      labels:
        app: andromeda-store
    spec:
      containers:
      - name: httpd
        image: httpd:2.4-alpine
        volumeMounts:
        - name: content
          mountPath: /usr/local/apache2/htdocs
      volumes:
      - name: content
        persistentVolumeClaim:
          claimName: andromeda-pvc
EOF
wait_rollout andromeda andromeda-store
