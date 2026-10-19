#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
kubectl create sa reticulum-runner -n reticulum
kubectl patch deploy reticulum-app -n reticulum -p \
  '{"spec":{"template":{"spec":{"serviceAccountName":"reticulum-runner","automountServiceAccountToken":false}}}}'
wait_rollout reticulum reticulum-app
kubectl wait --for=delete pod -n reticulum -l app=reticulum-app --field-selector spec.serviceAccountName!=reticulum-runner --timeout=60s 2>/dev/null
pod=$(kubectl get pods -n reticulum -l app=reticulum-app -o name | head -1)
kubectl get -n reticulum "$pod" -o yaml | grep 'serviceAccountName:' | awk '{print $2}' >/opt/course/41/sa-name
