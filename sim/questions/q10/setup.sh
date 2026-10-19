#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
course_dir 10 >/dev/null
reset_ns phoenix
# The default namespace is only used by this question's temporary Pod.
kubectl delete pod --all -n default --force --grace-period=0 --ignore-not-found >/dev/null 2>&1
true
