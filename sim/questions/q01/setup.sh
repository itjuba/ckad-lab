#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
course_dir 1 >/dev/null

reset_ns nimbus-billing nimbus-search nimbus-archive nimbus-scratch
kubectl label ns nimbus-billing nimbus.io/team=billing
kubectl label ns nimbus-search nimbus.io/team=search
kubectl label ns nimbus-archive nimbus.io/team=archive
kubectl label ns nimbus-scratch purpose=scratch

kubectl run billing-ui -n nimbus-billing --image=nginx:1.29-alpine -l tier=frontend,app=billing
kubectl run billing-api -n nimbus-billing --image=nginx:1.29-alpine -l tier=backend,app=billing
kubectl run search-ui -n nimbus-search --image=nginx:1.29-alpine -l tier=frontend,app=search
kubectl run search-ui-canary -n nimbus-search --image=nginx:1.29-alpine -l tier=frontend,app=search
kubectl run archive-worker -n nimbus-archive --image=nginx:1.29-alpine -l tier=worker
kubectl run scratch-ui -n nimbus-scratch --image=nginx:1.29-alpine -l tier=frontend
kubectl annotate pod search-ui -n nimbus-search nimbus.io/role=primary
kubectl annotate pod search-ui-canary -n nimbus-search nimbus.io/role=canary
wait_pods nimbus-search app=search
