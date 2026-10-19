#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
cat >/opt/course/3/job.yaml <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: checksum-job
  namespace: draco
spec:
  completions: 6
  parallelism: 2
  activeDeadlineSeconds: 120
  template:
    metadata:
      labels:
        job-group: checksum
    spec:
      restartPolicy: Never
      containers:
      - name: checksum
        image: busybox:1.37
        command: ["sh", "-c", "sleep 2 && echo checksum ok"]
EOF
kubectl apply -f /opt/course/3/job.yaml
kubectl wait --for=condition=complete job/checksum-job -n draco --timeout=180s
kubectl logs -n draco job/checksum-job >/opt/course/3/job.log
