#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: phoenix-api
  namespace: phoenix
  labels:
    app: phoenix-api
spec:
  containers:
  - name: phoenix-api
    image: nginx:1.29-alpine
    ports:
    - containerPort: 80
      name: http
---
apiVersion: v1
kind: Service
metadata:
  name: phoenix-api-svc
  namespace: phoenix
spec:
  type: ClusterIP
  selector:
    app: phoenix-api
  ports:
  - port: 3333
    targetPort: http
EOF
kubectl wait --for=condition=Ready pod/phoenix-api -n phoenix --timeout=120s

kubectl run tmp -n default --image=busybox:1.37 --restart=Never \
  -- wget -qO- http://phoenix-api-svc.phoenix.svc.cluster.local:3333
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/tmp -n default --timeout=60s
kubectl logs tmp -n default >/opt/course/10/response.html
kubectl delete pod tmp -n default --force --grace-period=0
kubectl logs phoenix-api -n phoenix | grep 'GET /' | tail -1 >/opt/course/10/access.log
