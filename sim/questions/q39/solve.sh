#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
kubectl apply -n pictor -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: pictor-app
spec:
  selector:
    app: pictor-app
  ports:
  - name: http
    port: 80
    targetPort: http
  - name: metrics
    port: 9100
    targetPort: metrics
---
apiVersion: v1
kind: Service
metadata:
  name: pictor-app-ext
spec:
  type: NodePort
  selector:
    app: pictor-app
  ports:
  - port: 80
    targetPort: http
    nodePort: 30781
EOF
for _ in $(seq 30); do
  curl -s -m 3 http://k3d-ckad-server-0:30781 >/opt/course/39/nodeport.html && grep -q nginx /opt/course/39/nodeport.html && break
  sleep 1
done
kubectl run tmp -n pictor --image=busybox:1.37 --restart=Never --rm -i -- wget -qO- http://pictor-app:9100 \
  >/opt/course/39/metrics.txt
kubectl wait --for=delete pod/tmp -n pictor --timeout=60s 2>/dev/null
true
