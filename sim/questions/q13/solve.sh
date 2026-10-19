#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
kubectl apply -f - <<'EOF'
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
EOF

reason=""
for _ in $(seq 30); do
  reason=$(kubectl get events -n centaurus --field-selector involvedObject.name=centaurus-cache \
    -o jsonpath='{.items[*].message}')
  [ -n "$reason" ] && break
  sleep 1
done
kubectl get pvc centaurus-cache -n centaurus -o jsonpath='{.status.phase}' >/opt/course/13/status-before
echo "$reason" >/opt/course/13/pending-reason

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: cache-writer
  namespace: centaurus
spec:
  containers:
  - name: cache-writer
    image: busybox:1.37
    command: ["sh", "-c", "while true; do date >> /cache/date.log; sleep 10; done"]
    volumeMounts:
    - name: cache
      mountPath: /cache
  volumes:
  - name: cache
    persistentVolumeClaim:
      claimName: centaurus-cache
EOF
kubectl wait --for=condition=Ready pod/cache-writer -n centaurus --timeout=120s
kubectl get pvc centaurus-cache -n centaurus -o jsonpath='{.spec.volumeName}' >/opt/course/13/pv-name
sleep 1
