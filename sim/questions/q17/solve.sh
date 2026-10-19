#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
S=/opt/course/17/kustomize/overlays/staging
mkdir -p "$S"
cat >"$S/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: sirius-staging
resources:
- ../../base
replicas:
- name: sirius-api
  count: 2
images:
- name: nginx
  newTag: 1.29-alpine
labels:
- pairs:
    env: staging
EOF
kubectl create ns sirius-staging --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -k "$S"
wait_rollout sirius-staging sirius-api
