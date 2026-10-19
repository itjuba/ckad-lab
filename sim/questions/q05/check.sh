#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
SA=system:serviceaccount:orion:orion-ci

can() { [ "$(kubectl auth can-i "$@" -n orion --as=$SA 2>/dev/null)" = yes ]; }

token_ok() {
  local expected
  expected=$(jp secret orion-ci-token -n orion -o jsonpath='{.data.token}' | base64 -d)
  [ -n "$expected" ] && [ "$(tr -d '[:space:]' <"$COURSE/5/token")" = "$expected" ]
}

binding_ok() {
  jp role pod-reader -n orion >/dev/null &&
    is "$(jp rolebinding orion-ci-pod-reader -n orion -o jsonpath='{.roleRef.kind}/{.roleRef.name}')" "Role/pod-reader" &&
    has "$(jp rolebinding orion-ci-pod-reader -n orion -o jsonpath='{range .subjects[*]}{.kind}:{.namespace}:{.name} {end}')" "ServiceAccount:orion:orion-ci"
}

reads_pods() { can get pods && can list pods && can watch pods; }

least_privilege() {
  binding_ok && ! can delete pods && ! can create pods && ! can get secrets && ! can list secrets
}

check "token file holds the decoded token of orion-ci" token_ok
check "RoleBinding orion-ci-pod-reader binds Role pod-reader to orion-ci" binding_ok
check "orion-ci can get, list and watch Pods" reads_pods
check "orion-ci can read Pod logs" can get pods --subresource=log
check "orion-ci cannot change Pods or read Secrets" least_privilege
check "can-delete contains the answer: no" is "$(tr -d '[:space:]' <"$COURSE/5/can-delete" 2>/dev/null)" "no"

finish
