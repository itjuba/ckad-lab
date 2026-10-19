#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
kubectl apply -f - <<'EOF'
apiVersion: batch/v1
kind: CronJob
metadata:
  name: rigel-report
  namespace: rigel
spec:
  schedule: "*/15 * * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 2
  failedJobsHistoryLimit: 1
  startingDeadlineSeconds: 60
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: rigel-report
            image: busybox:1.37
            command: ["sh", "-c", "date; echo report generated"]
EOF
kubectl create job rigel-report-manual --from=cronjob/rigel-report -n rigel
kubectl wait --for=condition=complete job/rigel-report-manual -n rigel --timeout=120s
kubectl logs job/rigel-report-manual -n rigel >/opt/course/19/manual.log
