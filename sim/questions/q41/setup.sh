#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
course_dir 41 >/dev/null
reset_ns reticulum

kubectl create deploy reticulum-app -n reticulum --image=nginx:1.29-alpine --replicas=2 >/dev/null
wait_rollout reticulum reticulum-app
