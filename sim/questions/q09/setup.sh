#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
D=$(course_dir 9)
reset_ns aquila

cat >"$D/reporter-pod.yaml" <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: aquila-reporter
  namespace: aquila
  labels:
    app: aquila-reporter
spec:
  containers:
  - name: reporter
    image: busybox:1.37
    command: ["sh", "-c", "while true; do date >> /tmp/report.log; sleep 5; done"]
EOF
kubectl apply -f "$D/reporter-pod.yaml"
wait_pods aquila app=aquila-reporter
