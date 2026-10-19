#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
course_dir 42 >/dev/null
reset_ns circinus

kubectl create deploy circinus-api -n circinus --image=nginx:1.29-alpine --replicas=2 >/dev/null
wait_rollout circinus circinus-api
