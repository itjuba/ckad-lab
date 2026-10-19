#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
course_dir 32 >/dev/null
reset_ns pyxis
kubectl create deploy pyxis-api -n pyxis --image=nginx:1.29-alpine --replicas=3 >/dev/null
wait_rollout pyxis pyxis-api
