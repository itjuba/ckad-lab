#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
kubectl get secret orion-ci-token -n orion -o jsonpath='{.data.token}' | base64 -d >/opt/course/5/token

kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: orion
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get"]
EOF
kubectl create rolebinding orion-ci-pod-reader -n orion --role=pod-reader --serviceaccount=orion:orion-ci

kubectl auth can-i delete pods -n orion --as=system:serviceaccount:orion:orion-ci >/opt/course/5/can-delete
