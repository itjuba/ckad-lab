#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
course_dir 16 >/dev/null
reset_ns auriga

kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: auriga-ledger
  namespace: auriga
  labels:
    app: auriga-ledger
spec:
  replicas: 1
  selector:
    matchLabels:
      app: auriga-ledger
  template:
    metadata:
      labels:
        app: auriga-ledger
    spec:
      terminationGracePeriodSeconds: 3
      containers:
      - name: ledger
        image: busybox:1.37
        command:
        - sh
        - -c
        - |
          i=0
          while true; do
            i=$((i+1))
            echo "$(date +%FT%T) ledger entry $i" >> /var/log/ledger/ledger.log
            sleep 2
          done
        volumeMounts:
        - name: logs
          mountPath: /var/log/ledger
      volumes:
      - name: logs
        emptyDir: {}
EOF
wait_rollout auriga auriga-ledger
