#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
DEP="deploy reticulum-app -n reticulum"

check "ServiceAccount reticulum-runner exists" jp sa reticulum-runner -n reticulum
check "Pod template uses reticulum-runner" \
  is "$(jp $DEP -o jsonpath='{.spec.template.spec.serviceAccountName}')" "reticulum-runner"

no_automount() {
  local pod sa
  pod=$(jp $DEP -o jsonpath='{.spec.template.spec.automountServiceAccountToken}')
  sa=$(jp sa reticulum-runner -n reticulum -o jsonpath='{.automountServiceAccountToken}')
  [ "$pod" = false ] || { [ "$sa" = false ] && [ "$pod" != true ]; }
}
check "automatic token mounting is off" no_automount

# Every running Pod is from the new template: right ServiceAccount, 2 ready.
rolled_out() {
  local sas
  is "$(jp $DEP -o jsonpath='{.status.updatedReplicas}/{.status.readyReplicas}/{.status.replicas}')" "2/2/2" || return 1
  sas=$(jp pods -n reticulum -l app=reticulum-app --field-selector status.phase=Running \
    -o jsonpath='{range .items[*]}{.spec.serviceAccountName}{"\n"}{end}' | sort -u)
  is "$sas" "reticulum-runner"
}
check "both replicas updated and available, running as reticulum-runner" rolled_out

no_token() {
  local pod
  pod=$(jp pods -n reticulum -l app=reticulum-app --field-selector status.phase=Running \
    -o jsonpath='{range .items[?(@.spec.serviceAccountName=="reticulum-runner")]}{.metadata.name}{"\n"}{end}' | head -1)
  [ -n "$pod" ] && ! kubectl exec -n reticulum "$pod" -- test -d /var/run/secrets/kubernetes.io/serviceaccount
}
check "a live Pod has no API token mounted" no_token

check "sa-name holds reticulum-runner" \
  is "$(tr -d '[:space:]' <"$COURSE/41/sa-name" 2>/dev/null | sed 's|^serviceaccount/||')" "reticulum-runner"

finish
