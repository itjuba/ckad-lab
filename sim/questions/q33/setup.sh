#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
course_dir 33 >/dev/null
reset_ns sagitta

kubectl apply -n sagitta -f - <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: sagitta-import
spec:
  backoffLimit: 2
  template:
    spec:
      restartPolicy: Never
      terminationGracePeriodSeconds: 3
      containers:
      - name: import
        image: busybox:1.37
        command: ["sh", "-c", "echo importing; cat /data/input.csv"]
EOF

kubectl wait --for=condition=Failed job/sagitta-import -n sagitta --timeout=180s >/dev/null
