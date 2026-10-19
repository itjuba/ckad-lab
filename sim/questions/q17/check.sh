#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
K=$COURSE/17/kustomize
NS=sirius-staging
D="deploy sirius-api -n $NS"

rendered=$(kubectl kustomize "$K/overlays/staging" 2>/dev/null)
check "overlays/staging/kustomization.yaml exists and renders" \
  bash -c "[ -f '$K/overlays/staging/kustomization.yaml' ] && kubectl kustomize '$K/overlays/staging'"

renders_staging() {
  has "$rendered" "namespace: sirius-staging" && has "$rendered" "replicas: 2" &&
    has "$rendered" "image: nginx:1.29-alpine" && has "$rendered" "env: staging"
}
check "staging overlay renders namespace, 2 replicas, nginx:1.29-alpine, env=staging" renders_staging

base_untouched() {
  local base dev
  renders_staging || return 1   # only scores once the staging overlay is done
  base=$(kubectl kustomize "$K/base") && dev=$(kubectl kustomize "$K/overlays/dev") || return 1
  has "$base" "image: nginx:1.27-alpine" && has "$base" "replicas: 1" &&
    has "$dev" "namespace: sirius" && has "$dev" "image: nginx:1.27-alpine" &&
    [ "$(jp deploy sirius-api -n sirius -o jsonpath='{.spec.template.spec.containers[0].image}')" = "nginx:1.27-alpine" ]
}
check "base and dev overlay unchanged (dev still runs nginx:1.27-alpine)" base_untouched

check "Deployment sirius-api in sirius-staging has 2 available replicas" \
  is "$(jp $D -o jsonpath='{.spec.replicas}/{.status.availableReplicas}')" "2/2"
check "Deployment in sirius-staging runs nginx:1.29-alpine" \
  is "$(jp $D -o jsonpath='{.spec.template.spec.containers[0].image}')" "nginx:1.29-alpine"
check "Deployment and Service in sirius-staging have label env=staging" \
  is "$(jp $D -o jsonpath='{.metadata.labels.env}') $(jp svc sirius-api -n $NS -o jsonpath='{.metadata.labels.env}')" "staging staging"

finish
