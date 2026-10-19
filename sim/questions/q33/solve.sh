#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
D=/opt/course/33
kubectl describe job sagitta-import -n sagitta | grep -o BackoffLimitExceeded | head -1 >$D/job-reason
pod=$(kubectl get pods -n sagitta -l job-name=sagitta-import --no-headers | awk 'NR==1{print $1}')
kubectl logs -n sagitta "$pod" | grep -i "can't open" >$D/error.log

kubectl delete job sagitta-import -n sagitta --wait=true
kubectl apply -n sagitta -f - <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: sagitta-import
spec:
  backoffLimit: 4
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: sagitta-import
        image: busybox:1.37
        command: ["sh", "-c", "mkdir -p /data && echo id,name > /data/input.csv && cat /data/input.csv"]
EOF
kubectl wait --for=condition=Complete job/sagitta-import -n sagitta --timeout=120s
kubectl logs -n sagitta job/sagitta-import >$D/job.log
