#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
D=$COURSE/40
P="pod volans-batch -n volans"

check "api-reason holds the node selector scheduling message" grep -qi "affinity/selector" "$D/api-reason"
check "node k3d-ckad-agent-0 carries disktype=ssd" \
  is "$(jp node k3d-ckad-agent-0 -o jsonpath='{.metadata.labels.disktype}')" "ssd"

api_running() {
  local nodes
  is "$(jp deploy volans-api -n volans -o jsonpath='{.spec.template.spec.nodeSelector.disktype}/{.spec.replicas}')" "ssd/2" &&
    is "$(jp deploy volans-api -n volans -o jsonpath='{.status.readyReplicas}')" "2" || return 1
  nodes=$(jp pods -n volans -l app=volans-api --field-selector status.phase=Running -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort -u)
  is "$nodes" "k3d-ckad-agent-0"
}
check "Deployment unchanged, both volans-api Pods run on k3d-ckad-agent-0" api_running

check "batch-reason says there isn't enough CPU" grep -qi "insufficient cpu" "$D/batch-reason"

batch_ok() {
  is "$(jp $P -o jsonpath='{.spec.containers[0].image}')" "nginx:1.29-alpine" &&
    is "$(jp $P -o jsonpath='{.spec.containers[0].resources.requests.cpu}')" "100m" &&
    is "$(jp $P -o jsonpath='{.status.phase}')" "Running"
}
check "volans-batch (nginx:1.29-alpine) requests 100m CPU and is Running" batch_ok

finish
