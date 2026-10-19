#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
D=$COURSE/33
J="job sagitta-import -n sagitta"
T='{.spec.template.spec'

check "job-reason is BackoffLimitExceeded" is "$(tr -d '[:space:]' <"$D/job-reason" 2>/dev/null)" "BackoffLimitExceeded"
check "error.log holds the error line from the Pod logs" file_has "$D/error.log" "can't open '/data/input.csv'"

spec_ok() {
  is "$(jp $J -o jsonpath='{.spec.backoffLimit}')" "4" &&
    is "$(jp $J -o jsonpath="$T.restartPolicy}")" "Never" &&
    is "$(jp $J -o jsonpath="$T.containers[0].image}")" "busybox:1.37" &&
    cmd_ok
}
# jsonpath prints the command as JSON, which escapes > and &, so match the plain parts.
cmd_ok() {
  local cmd
  cmd=$(jp $J -o jsonpath="$T.containers[0].command} $T.containers[0].args}")
  has "$cmd" "mkdir -p /data" && has "$cmd" "echo id,name" && has "$cmd" "cat /data/input.csv"
}
check "new Job sagitta-import: busybox:1.37, the new command, backoffLimit 4, restartPolicy Never" spec_ok
check "new Job completed" is "$(jp $J -o jsonpath='{.status.succeeded}')" "1"
check "job.log holds the new Job's output" file_has "$D/job.log" "id,name"

finish
