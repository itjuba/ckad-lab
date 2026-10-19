#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
kubectl apply -f - <<'EOF'
apiVersion: nimbus.io/v1
kind: Backup
metadata:
  name: nightly
  namespace: pollux
spec:
  schedule: "0 2 * * *"
  retentionDays: 7
  target: pollux-web
EOF

kubectl get crd backups.nimbus.io -o jsonpath='{.spec.names.shortNames[0]}' >/opt/course/23/short-name

cat >/opt/course/23/legacy/hpa.yaml <<'EOF'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: pollux-web
  namespace: pollux
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: pollux-web
  minReplicas: 2
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
EOF
sed -i 's#^apiVersion: policy/v1beta1#apiVersion: policy/v1#' /opt/course/23/legacy/pdb.yaml
kubectl apply -f /opt/course/23/legacy/
