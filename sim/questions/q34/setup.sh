#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
course_dir 34 >/dev/null
reset_ns scutum

kubectl apply -n scutum -f - <<'EOF'
apiVersion: batch/v1
kind: CronJob
metadata:
  name: scutum-backup
spec:
  schedule: "* * * * *"
  suspend: true
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          terminationGracePeriodSeconds: 3
          containers:
          - name: backup
            image: busybox:1.37
            command: ["sh", "-c", "date; echo backup done"]
EOF
