#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: lacerta-web
  namespace: lacerta
spec:
  volumes:
  - name: content
    emptyDir: {}
  initContainers:
  - name: fetch
    image: busybox:1.37
    command: ["sh", "-c", "echo '<h1>Lacerta</h1>' > /work/index.html"]
    volumeMounts:
    - name: content
      mountPath: /work
  containers:
  - name: web
    image: nginx:1.29-alpine
    volumeMounts:
    - name: content
      mountPath: /usr/share/nginx/html
EOF
kubectl wait --for=condition=Ready pod/lacerta-web -n lacerta --timeout=120s
ip=$(kubectl get pod lacerta-web -n lacerta -o jsonpath='{.status.podIP}')
kubectl run tmp -n lacerta --image=busybox:1.37 --restart=Never --rm -i -- wget -qO- "http://$ip" >/opt/course/35/index.html
kubectl wait --for=delete pod/tmp -n lacerta --timeout=60s 2>/dev/null || true
