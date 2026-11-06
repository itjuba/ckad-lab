#!/usr/bin/env bash
# Docker Compose one-shot (the `setup` service): wait for the clusters, then set up every
# question, like `.\sim.ps1 up` does. Only the first time: a ConfigMap in cluster 1 records
# that it's done, so `docker compose up` again never resets your work. `docker compose
# down -v` deletes the clusters, marker included, and the next `up` starts fresh.
set -euo pipefail
export CKAD_HOME=/ckad PATH=/ckad/bin:$PATH
MARKER='--context ckad-c1 -n kube-system configmap ckad-lab-setup'

echo '==> Waiting for both nodes of cluster 1 (ckad-c1)'
until [ "$(kubectl --context ckad-c1 get nodes --no-headers 2>/dev/null | wc -l)" -ge 2 ]; do sleep 3; done
kubectl --context ckad-c1 wait --for=condition=Ready nodes --all --timeout=300s

echo '==> Waiting for cluster 2 (ckad-c2)'
kubectl --context ckad-c2 wait --for=condition=Ready nodes --all --timeout=300s

echo '==> Waiting for the ingress controller (traefik, cluster 1)'
until kubectl --context ckad-c1 -n kube-system get deploy/traefik >/dev/null 2>&1; do sleep 3; done
kubectl --context ckad-c1 -n kube-system rollout status deploy/traefik --timeout=300s

if kubectl get $MARKER >/dev/null 2>&1; then
  echo '==> Questions are already set up (your work is untouched)'
elif [ -s /opt/course/.ckad/passed ] && [ "${CKAD_SETUP_FORCE:-}" != 1 ]; then
  # A fresh Compose cluster, but course/ already holds progress: most likely the sim.ps1
  # environment's. Resetting would delete that work, so don't.
  cat <<'EOF'
==> Not setting up: /opt/course already holds progress from another environment (sim.ps1?).
    Use one environment at a time (see README). To set this Compose environment up anyway,
    which RESETS every question and deletes the answer files in course/:
      docker compose run --rm -e CKAD_SETUP_FORCE=1 setup
EOF
  exit 0
else
  echo '==> Setting up questions'
  ckad reset all
  kubectl create $MARKER --from-literal=date="$(date -Is)" >/dev/null
fi
echo '==> Ready. Web UI: http://localhost:8090   Terminal: docker compose exec terminal bash'
