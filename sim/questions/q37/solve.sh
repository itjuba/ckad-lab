#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
kubectl create configmap crater-config -n crater \
  --from-file=/opt/course/37/config/app.properties \
  --from-file=/opt/course/37/config/logging.properties
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: crater-app
  namespace: crater
spec:
  terminationGracePeriodSeconds: 3
  volumes:
  - name: config
    configMap:
      name: crater-config
  - name: logging
    configMap:
      name: crater-config
      items:
      - key: logging.properties
        path: log.conf
  containers:
  - name: crater-app
    image: busybox:1.37
    command: ["sleep", "1d"]
    volumeMounts:
    - name: config
      mountPath: /etc/crater
      readOnly: true
    - name: logging
      mountPath: /etc/logging
EOF
kubectl wait --for=condition=Ready pod/crater-app -n crater --timeout=120s
kubectl exec -n crater crater-app -- cat /etc/crater/app.properties >/opt/course/37/app.properties.out
