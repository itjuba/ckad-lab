#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: greeter
  namespace: mensa
  labels:
    team: mensa
spec:
  terminationGracePeriodSeconds: 3
  containers:
  - name: greeter
    image: busybox:1.37
    env:
    - name: GREETING
      value: hello
    - name: TARGET
      value: ckad
    command: ["sh", "-c"]
    args: ['echo "$GREETING, $TARGET"; sleep 3600']
EOF
kubectl wait --for=condition=Ready pod/greeter -n mensa --timeout=120s
sleep 1
kubectl logs greeter -n mensa >/opt/course/29/greeting.log
kubectl exec greeter -n mensa -- printenv TARGET >/opt/course/29/target
