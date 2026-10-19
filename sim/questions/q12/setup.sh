#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
course_dir 12 >/dev/null
reset_ns andromeda
kubectl delete pv andromeda-pv --ignore-not-found --wait=true --timeout=60s
