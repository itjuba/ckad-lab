#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
course_dir 21 >/dev/null
reset_ns deneb

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ResourceQuota
metadata:
  name: deneb-quota
  namespace: deneb
spec:
  hard:
    requests.cpu: "1"
    requests.memory: 1Gi
    limits.cpu: "2"
    limits.memory: 2Gi
    pods: "5"
EOF
# Give the quota controller a moment so the Deployment is rejected, not admitted.
for _ in $(seq 30); do
  [ -n "$(kubectl get resourcequota deneb-quota -n deneb -o jsonpath='{.status.hard.pods}')" ] && break
  sleep 1
done

kubectl create deployment deneb-app -n deneb --image=nginx:1.29-alpine --replicas=3

for _ in $(seq 60); do
  kubectl get events -n deneb --field-selector reason=FailedCreate -o name | grep -q . && break
  sleep 1
done
