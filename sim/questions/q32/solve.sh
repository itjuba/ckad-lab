#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
kubectl set env deploy/pyxis-api -n pyxis MODE=production LOG_LEVEL=info
kubectl set resources deploy/pyxis-api -n pyxis --requests=cpu=50m,memory=64Mi --limits=memory=128Mi
kubectl patch deploy pyxis-api -n pyxis -p '{"spec":{"template":{"metadata":{"labels":{"version":"v2"}}}}}'
kubectl annotate deploy pyxis-api -n pyxis owner=team-pyxis
wait_rollout pyxis pyxis-api
