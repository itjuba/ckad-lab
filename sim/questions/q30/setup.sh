#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
course_dir 30 >/dev/null
reset_ns fornax

kubectl apply -n fornax -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: fornax-app
  labels: {app: fornax-app}
spec:
  terminationGracePeriodSeconds: 3
  containers:
  - name: web
    image: nginx:1.29-alpine
  - name: logger
    image: busybox:1.37
    command: ["sh", "-c", "i=1; while true; do echo \"fornax heartbeat $i\"; i=$((i+1)); sleep 2; done"]
---
apiVersion: v1
kind: Pod
metadata:
  name: fornax-worker
  labels: {app: fornax-worker}
spec:
  terminationGracePeriodSeconds: 3
  volumes:
  - name: state
    emptyDir: {}
  containers:
  - name: worker
    image: busybox:1.37
    # First run crashes; the restarted run keeps going, so --previous always shows the crash.
    command: ["sh", "-c", "if [ -f /state/crashed ]; then echo worker restarted; sleep 1d; fi; touch /state/crashed; echo worker starting; sleep 3; echo 'worker crashed: disk full'; exit 1"]
    volumeMounts:
    - {name: state, mountPath: /state}
EOF

kubectl wait --for=condition=Ready pod/fornax-app -n fornax --timeout=120s >/dev/null
# Wait until fornax-worker has crashed at least once, so --previous has something to show,
# and the logger has printed more than 5 lines.
for _ in $(seq 60); do
  restarts=$(kubectl get pod fornax-worker -n fornax -o jsonpath='{.status.containerStatuses[0].restartCount}')
  ready=$(kubectl get pod fornax-worker -n fornax -o jsonpath='{.status.containerStatuses[0].ready}')
  [ "${restarts:-0}" -ge 1 ] && [ "$ready" = true ] && break
  sleep 2
done
sleep 4
