#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: musca-pair
  namespace: musca
spec:
  terminationGracePeriodSeconds: 3
  volumes:
  - name: shared
    emptyDir: {}
  containers:
  - name: producer
    image: busybox:1.37
    command: ["sh", "-c", "while true; do date >> /shared/out.log; sleep 3; done"]
    volumeMounts:
    - name: shared
      mountPath: /shared
  - name: consumer
    image: busybox:1.37
    command: ["tail", "-F", "/shared/out.log"]
    volumeMounts:
    - name: shared
      mountPath: /shared
EOF
kubectl wait --for=condition=Ready pod/musca-pair -n musca --timeout=120s
sleep 7
kubectl logs -n musca musca-pair -c consumer >/opt/course/36/consumer.log
kubectl exec -n musca musca-pair -c consumer -- ls /shared >/opt/course/36/shared-ls
