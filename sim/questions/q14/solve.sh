#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
kubectl create secret generic db-credentials -n pegasus \
  --from-literal=user=pegasus-app --from-literal='password=Sup3rS3cret!'
sed 's/namespace: default/namespace: pegasus/' /opt/course/14/tls-bundle.yaml | kubectl apply -f -

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: db-client
  namespace: pegasus
spec:
  containers:
  - name: db-client
    image: busybox:1.37
    command: ["sh", "-c", "sleep 1d"]
    env:
    - name: DB_USER
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: user
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: password
    volumeMounts:
    - name: tls
      mountPath: /etc/tls
      readOnly: true
  volumes:
  - name: tls
    secret:
      secretName: tls-bundle
      items:
      - key: ca.crt
        path: ca.pem
        mode: 0400
EOF
kubectl wait --for=condition=Ready pod/db-client -n pegasus --timeout=120s
