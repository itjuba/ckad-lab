#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
D="deploy aquila-reporter -n aquila"
T='{.spec.template.spec'

check "/opt/course/9/reporter-deploy.yaml is a Deployment manifest" file_has "$COURSE/9/reporter-deploy.yaml" "kind: Deployment"
check "Deployment has 3 available replicas" \
  is "$(jp $D -o jsonpath='{.spec.replicas} {.status.availableReplicas}')" "3 3"
same_container() {
  is "$(jp $D -o jsonpath="$T.containers[0].name} $T.containers[0].image}")" "reporter busybox:1.37" &&
    has "$(jp $D -o jsonpath="$T.containers[0].command} $T.containers[0].args}")" "/tmp/report.log"
}
check "same container: reporter, busybox:1.37, writes /tmp/report.log" same_container
check "Pod securityContext: runAsUser 1000, runAsGroup 3000, fsGroup 2000" \
  is "$(jp $D -o jsonpath="$T.securityContext.runAsUser} $T.securityContext.runAsGroup} $T.securityContext.fsGroup}")" "1000 3000 2000"

container_sc() {
  local sc="$T.containers[0].securityContext"
  is "$(jp $D -o jsonpath="$sc.allowPrivilegeEscalation} $sc.readOnlyRootFilesystem}")" "false true" &&
    has "$(jp $D -o jsonpath="$sc.capabilities.drop}")" '"ALL"'
}
check "container securityContext: no privilege escalation, read-only root fs, drop ALL" container_sc

tmp_emptydir() {
  local vol
  vol=$(jp $D -o jsonpath="$T.containers[0].volumeMounts[?(@.mountPath==\"/tmp\")].name}")
  [ -n "$vol" ] && [ -n "$(jp $D -o jsonpath="$T.volumes[?(@.name==\"$vol\")].emptyDir}")" ]
}
check "an emptyDir volume is mounted at /tmp" tmp_emptydir
check "original Pod aquila-reporter is deleted" bash -c '! kubectl get pod aquila-reporter -n aquila'
check "container runs as uid 1000" is "$(kubectl exec -n aquila deploy/aquila-reporter -- id -u 2>/dev/null)" "1000"
check "/tmp/report.log is being written" kubectl exec -n aquila deploy/aquila-reporter -- test -s /tmp/report.log

finish
