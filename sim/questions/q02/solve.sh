#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: lyra-web
  namespace: lyra
spec:
  containers:
  - name: lyra-web-container
    image: httpd:2.4-alpine
    ports:
    - containerPort: 80
      name: http
EOF
kubectl wait --for=condition=Ready pod/lyra-web -n lyra --timeout=120s
echo "kubectl get pod lyra-web -n lyra -o jsonpath='{.status.podIP}'" >/opt/course/2/pod-ip.sh
