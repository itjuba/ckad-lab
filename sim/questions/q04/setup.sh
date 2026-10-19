#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
course_dir 4 >/dev/null
reset_ns vega

helm repo add nimbus http://localhost:8879 --force-update
helm repo update nimbus

helm install vega-legacy nimbus/webapp --version 0.1.0 -n vega
helm install vega-api nimbus/webapp --version 0.1.0 -n vega
# Image tag that doesn't exist: --wait times out and the release ends up "failed".
helm install vega-canary nimbus/webapp --version 0.1.0 -n vega \
  --set image.tag=0.0.0-missing --wait --timeout 20s || true

wait_rollout vega vega-legacy-webapp
wait_rollout vega vega-api-webapp
