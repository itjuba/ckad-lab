#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
cat >/opt/course/9/reporter-deploy.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aquila-reporter
  namespace: aquila
spec:
  replicas: 3
  selector:
    matchLabels:
      app: aquila-reporter
  template:
    metadata:
      labels:
        app: aquila-reporter
    spec:
      securityContext:
        runAsUser: 1000
        runAsGroup: 3000
        fsGroup: 2000
      containers:
      - name: reporter
        image: busybox:1.37
        command: ["sh", "-c", "while true; do date >> /tmp/report.log; sleep 5; done"]
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
        volumeMounts:
        - name: tmp
          mountPath: /tmp
      volumes:
      - name: tmp
        emptyDir: {}
EOF
kubectl apply -f /opt/course/9/reporter-deploy.yaml
kubectl delete pod aquila-reporter -n aquila --force --grace-period=0
wait_rollout aquila aquila-reporter
sleep 6
