#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
kubectl create configmap gateway-config-v2 -n carina --from-env-file=/opt/course/15/gateway.env \
  --dry-run=client -o yaml >/tmp/q15-cm.yaml
echo 'immutable: true' >>/tmp/q15-cm.yaml
kubectl apply -f /tmp/q15-cm.yaml

kubectl patch deploy carina-gateway -n carina --type=json \
  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/envFrom/0/configMapRef/name","value":"gateway-config-v2"}]'
wait_rollout carina carina-gateway

pod=$(kubectl get pods -n carina -l app=carina-gateway -o jsonpath='{range .items[?(@.status.phase=="Running")]}{.metadata.name}{"\n"}{end}' |
  while read -r p; do
    [ "$(kubectl exec -n carina "$p" -- printenv GW_MODE 2>/dev/null)" = edge ] && echo "$p" && break
  done)
kubectl exec -n carina "$pod" -- sh -c 'env | grep ^GW_ | sort' >/opt/course/15/env.txt

kubectl delete cm gateway-config-v1 -n carina
